// FILE PATH: lib/auth/register/register_workspace_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:QUIK/core/inventory/services/inventory_config_service.dart';
import 'package:QUIK/core/modules/services/tenant_module_service.dart';
import 'package:QUIK/data/local_database.dart';

class RegisterWorkspaceService {
  RegisterWorkspaceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    TenantModuleService? tenantModuleService,
    InventoryConfigService? inventoryConfigService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _tenantModuleService =
           tenantModuleService ??
           TenantModuleService(
             firestore: firestore ?? FirebaseFirestore.instance,
           ),
       _inventoryConfigService =
           inventoryConfigService ??
           InventoryConfigService(
             firestore: firestore ?? FirebaseFirestore.instance,
           );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final TenantModuleService _tenantModuleService;
  final InventoryConfigService _inventoryConfigService;

  Future<Map<String, dynamic>?> getLocalCurrentUser() async {
    final localUser = await LocalDatabase.instance.getCurrentUser();

    if (localUser != null) {
      final uid = _auth.currentUser?.uid;

      if (uid == null) {
        return localUser;
      }

      try {
        final rootSnap = await _firestore.collection('users').doc(uid).get();
        final rootData = rootSnap.data() ?? {};

        final companyId =
            (rootData['companyId'] ?? localUser['companyId'] ?? '')
                .toString()
                .trim();

        Map<String, dynamic> companyData = {};
        if (companyId.isNotEmpty) {
          final companySnap = await _firestore
              .collection('companies')
              .doc(companyId)
              .get();
          companyData = companySnap.data() ?? {};
        }

        return {
          ...localUser,
          ...companyData,
          ...rootData,
          'id': localUser['id'] ?? -1,
          'uid': uid,
          'companyId': companyId,
          'email':
              (rootData['email'] ??
                      localUser['email'] ??
                      _auth.currentUser?.email ??
                      '')
                  .toString(),
        };
      } catch (_) {
        return localUser;
      }
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final uid = firebaseUser.uid;
      final rootSnap = await _firestore.collection('users').doc(uid).get();
      final rootData = rootSnap.data() ?? {};

      final companyId = (rootData['companyId'] ?? '').toString().trim();

      Map<String, dynamic> companyData = {};
      if (companyId.isNotEmpty) {
        final companySnap = await _firestore
            .collection('companies')
            .doc(companyId)
            .get();
        companyData = companySnap.data() ?? {};
      }

      return {
        ...companyData,
        ...rootData,
        'id': -1,
        'uid': uid,
        'companyId': companyId,
        'email': (rootData['email'] ?? firebaseUser.email ?? '').toString(),
        'name': (rootData['name'] ?? firebaseUser.displayName ?? '').toString(),
      };
    } catch (_) {
      return {
        'id': -1,
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'name': firebaseUser.displayName ?? '',
      };
    }
  }

  Future<String?> uploadLogoIfNeeded({
    required String uid,
    required Uint8List? logoBytes,
    required String? existingLogoUrl,
  }) async {
    String? nextLogoUrl = existingLogoUrl;

    if (logoBytes != null) {
      final path =
          'entity_logos/$uid/${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = _storage.ref().child(path);

      await ref.putData(logoBytes, SettableMetadata(contentType: 'image/png'));

      nextLogoUrl = await ref.getDownloadURL();
    }

    return nextLogoUrl;
  }

  Future<String> ensureCompanyForExistingUser({
    required String uid,
    required String email,
    required String displayName,
    required String? logoUrl,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> adminPermissions,
  }) async {
    final rootUserRef = _firestore.collection('users').doc(uid);
    final rootUserSnap = await rootUserRef.get();
    final rootData = rootUserSnap.data() ?? {};

    String companyId = (rootData['companyId'] ?? '').toString().trim();
    if (companyId.isNotEmpty) {
      return companyId;
    }

    final companyRef = _firestore.collection('companies').doc();

    await companyRef.set({
      ...companyData,
      'companyId': companyRef.id,
      'email': email,
      'logoUrl': logoUrl ?? '',
      'createdByUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'plan': 'trial',
      'isActive': true,
      'emailVerified': true,
    });

    await _tenantModuleService.ensureTenantModulesInitialized(
      tenantId: companyRef.id,
      source: 'new_workspace_existing_user',
    );
    await _inventoryConfigService.ensureDefaultProfile(
      tenantId: companyRef.id,
      source: 'new_workspace_existing_user',
      companyData: companyData,
    );

    await companyRef.collection('users').doc(uid).set({
      'uid': uid,
      'companyId': companyRef.id,
      'name': displayName,
      'email': email,
      'phone': companyData['phone'] ?? '',
      'role': 'admin',
      'isAdmin': true,
      'isActive': true,
      'emailVerified': true,
      'permissions': adminPermissions,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await rootUserRef.set({
      'uid': uid,
      'companyId': companyRef.id,
      'role': 'admin',
      'isAdmin': true,
      'isActive': true,
      'email': email,
      'name': displayName,
      ...companyData,
      'logoUrl': logoUrl ?? '',
      'emailVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return companyRef.id;
  }

  Future<void> updateWorkspaceForExistingUser({
    required String uid,
    required String companyId,
    required String email,
    required String displayName,
    required String? logoUrl,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> adminPermissions,
  }) async {
    await _firestore.collection('companies').doc(companyId).set({
      ...companyData,
      'companyId': companyId,
      'email': email,
      'logoUrl': logoUrl ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    }, SetOptions(merge: true));

    await _tenantModuleService.ensureTenantModulesInitialized(
      tenantId: companyId,
      source: 'workspace_update',
    );
    await _inventoryConfigService.ensureDefaultProfile(
      tenantId: companyId,
      source: 'workspace_update',
      companyData: companyData,
    );

    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid)
        .set({
          'uid': uid,
          'companyId': companyId,
          'name': displayName,
          'email': email,
          'phone': companyData['phone'] ?? '',
          'role': 'admin',
          'isAdmin': true,
          'isActive': true,
          'permissions': adminPermissions,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'companyId': companyId,
      'role': 'admin',
      'isAdmin': true,
      'isActive': true,
      'email': email,
      'name': displayName,
      ...companyData,
      'logoUrl': logoUrl ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> createWorkspaceRegistrationDraft({
    required String email,
    required String displayName,
    required String? logoUrl,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> adminPermissions,
    required Set<String> enabledModuleIds,
  }) async {
    final emailLower = email.trim().toLowerCase();

    final callable = _functions.httpsCallable('sendWorkspaceOtp');

    final result = await callable.call({
      'email': emailLower,
      'displayName': displayName,
      'logoUrl': logoUrl ?? '',
      'companyData': companyData,
      'adminPermissions': adminPermissions,
      'selectedModuleIds': enabledModuleIds.toList(growable: false),
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final registrationId = (data['registrationId'] ?? data['draftId'] ?? '')
        .toString()
        .trim();

    if (registrationId.isEmpty) {
      throw Exception('Registration ID not returned from server.');
    }

    await _deleteLegacyWorkspaceRequestSecrets(registrationId);

    return registrationId;
  }

  Future<void> sendWorkspaceOtp({required String registrationId}) async {
    final callable = _functions.httpsCallable('resendWorkspaceOtp');
    await callable.call({
      'registrationId': registrationId,
      'draftId': registrationId,
    });
    await _deleteLegacyWorkspaceRequestSecrets(registrationId);
  }

  Future<void> verifyWorkspaceOtpAndCreateWorkspace({
    required String registrationId,
    required String otp,
    required String password,
    required Set<String> enabledModuleIds,
  }) async {
    final callable = _functions.httpsCallable(
      'verifyWorkspaceOtpAndCreateWorkspace',
    );

    final result = await callable.call({
      'registrationId': registrationId,
      'draftId': registrationId,
      'otp': otp.trim(),
    });

    await _deleteLegacyWorkspaceRequestSecrets(registrationId);

    final data = Map<String, dynamic>.from(result.data as Map);

    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final displayName = (data['displayName'] ?? '').toString();
    final logoUrl = (data['logoUrl'] ?? '').toString();
    final companyId = (data['companyId'] ?? '').toString().trim();

    final companyData = Map<String, dynamic>.from(
      data['companyData'] ?? const {},
    );
    final adminPermissions = Map<String, dynamic>.from(
      data['adminPermissions'] ?? const {},
    );
    final verifiedModuleIds = _stringSetFromValue(data['selectedModuleIds']);
    final moduleIdsForTenant = verifiedModuleIds.isEmpty
        ? enabledModuleIds
        : verifiedModuleIds;

    if (email.isEmpty || password.isEmpty) {
      throw Exception('Incomplete verification response from server.');
    }

    if (companyId.isEmpty) {
      throw Exception('Company ID not returned from server.');
    }

    final user = await _getOrCreateVerifiedAuthUser(
      email: email,
      password: password,
    );

    final uid = user.uid;

    await _completeVerifiedWorkspaceDocuments(
      uid: uid,
      email: email,
      displayName: displayName,
      logoUrl: logoUrl,
      companyId: companyId,
      registrationId: registrationId,
      companyData: companyData,
      adminPermissions: adminPermissions,
    );

    await _tenantModuleService.configureNewWorkspaceModules(
      tenantId: companyId,
      enabledModuleIds: moduleIdsForTenant,
      source: 'new_workspace_otp',
    );
    await _inventoryConfigService.ensureDefaultProfile(
      tenantId: companyId,
      source: 'new_workspace_otp',
      companyData: companyData,
    );

    await _syncLocalWorkspaceUser(
      uid: uid,
      email: email,
      displayName: displayName,
      logoUrl: logoUrl,
      companyId: companyId,
      companyData: companyData,
    );
  }

  Future<User> _getOrCreateVerifiedAuthUser({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    debugPrint(
      'RegisterWorkspaceService auth create/recover email: $normalizedEmail',
    );
    debugPrint(
      'RegisterWorkspaceService auth password length: ${password.length}',
    );

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to create user account.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('RegisterWorkspaceService create auth error code: ${e.code}');
      debugPrint(
        'RegisterWorkspaceService create auth error message: ${e.message}',
      );
      if (e.code != 'email-already-in-use') {
        rethrow;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to recover existing user account.');
      }
      return user;
    }
  }

  Future<void> _completeVerifiedWorkspaceDocuments({
    required String uid,
    required String email,
    required String displayName,
    required String logoUrl,
    required String companyId,
    required String registrationId,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> adminPermissions,
  }) async {
    final companyRef = _firestore.collection('companies').doc(companyId);
    final rootUserRef = _firestore.collection('users').doc(uid);
    final companyUserRef = companyRef.collection('users').doc(uid);
    final requestRef = _firestore
        .collection('workspace_requests')
        .doc(registrationId);

    await _firestore.runTransaction((transaction) async {
      final companySnap = await transaction.get(companyRef);
      final rootUserSnap = await transaction.get(rootUserRef);
      final companyUserSnap = await transaction.get(companyUserRef);

      final rootData = rootUserSnap.data() ?? const <String, dynamic>{};
      final existingCompanyId = (rootData['companyId'] ?? '').toString().trim();

      if (existingCompanyId.isNotEmpty && existingCompanyId != companyId) {
        throw Exception(
          'This email is already linked to another workspace. Please login.',
        );
      }

      if (companySnap.exists) {
        final existingCompany = companySnap.data() ?? <String, dynamic>{};
        final existingOwner = (existingCompany['createdByUid'] ?? '')
            .toString()
            .trim();
        final existingRegistrationId = (existingCompany['registrationId'] ?? '')
            .toString()
            .trim();

        if (existingOwner.isNotEmpty &&
            existingOwner != uid &&
            existingRegistrationId != registrationId) {
          throw Exception('Workspace already exists for another account.');
        }
      }

      final companyPayload = <String, dynamic>{
        ...companyData,
        'companyId': companyId,
        'email': email,
        'logoUrl': logoUrl,
        'createdByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'plan': 'trial',
        'isActive': true,
        'emailVerified': true,
        'registrationId': registrationId,
      };

      if (!companySnap.exists) {
        companyPayload['createdAt'] = FieldValue.serverTimestamp();
      }

      final companyUserPayload = <String, dynamic>{
        'uid': uid,
        'companyId': companyId,
        'name': displayName,
        'email': email,
        'phone': companyData['phone'] ?? '',
        'role': 'admin',
        'isAdmin': true,
        'isActive': true,
        'emailVerified': true,
        'permissions': adminPermissions,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!companyUserSnap.exists) {
        companyUserPayload['createdAt'] = FieldValue.serverTimestamp();
      }

      final rootUserPayload = <String, dynamic>{
        'uid': uid,
        'companyId': companyId,
        'role': 'admin',
        'isAdmin': true,
        'isActive': true,
        'email': email,
        'name': displayName,
        ...companyData,
        'logoUrl': logoUrl,
        'emailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!rootUserSnap.exists) {
        rootUserPayload['createdAt'] = FieldValue.serverTimestamp();
      }

      transaction.set(companyRef, companyPayload, SetOptions(merge: true));
      transaction.set(
        companyUserRef,
        companyUserPayload,
        SetOptions(merge: true),
      );
      transaction.set(rootUserRef, rootUserPayload, SetOptions(merge: true));
      transaction.set(requestRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completedByUid': uid,
        'companyId': companyId,
        'password': FieldValue.delete(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _deleteLegacyWorkspaceRequestSecrets(
    String registrationId,
  ) async {
    final normalizedRegistrationId = registrationId.trim();
    if (normalizedRegistrationId.isEmpty) return;

    try {
      await _firestore
          .collection('workspace_requests')
          .doc(normalizedRegistrationId)
          .update({'password': FieldValue.delete()});
      debugPrint(
        'RegisterWorkspaceService: cleaned legacy workspace request secrets',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      debugPrint(
        'RegisterWorkspaceService: legacy workspace cleanup skipped: ${e.code}',
      );
    } catch (e) {
      debugPrint('RegisterWorkspaceService: legacy workspace cleanup skipped');
    }
  }

  Set<String> _stringSetFromValue(Object? value) {
    if (value is! Iterable) return const {};

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  Future<void> _syncLocalWorkspaceUser({
    required String uid,
    required String email,
    required String displayName,
    required String logoUrl,
    required String companyId,
    required Map<String, dynamic> companyData,
  }) async {
    int userId = -1;

    try {
      userId = await LocalDatabase.instance.registerUser(
        email: email,
        password: '',
        companyName: (companyData['companyName'] ?? '').toString(),
        address: (companyData['address'] ?? '').toString(),
        city: (companyData['city'] ?? '').toString(),
        state: (companyData['state'] ?? '').toString(),
        pincode: (companyData['pincode'] ?? '').toString(),
        phone: (companyData['phone'] ?? '').toString(),
        gstin: (companyData['gstin'] ?? '').toString(),
        pan: (companyData['pan'] ?? '').toString(),
        website: (companyData['website'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('RegisterWorkspaceService: skipped local user sync: $e');
    }

    if (userId <= 0) return;

    await LocalDatabase.instance.updateUser(userId, {
      ...companyData,
      'employeeDisplayName': displayName,
      'logoUrl': logoUrl,
      'companyId': companyId,
      'emailVerified': true,
      'uid': uid,
    });
  }

  Future<void> updateLocalUser({
    required int localUserId,
    required Map<String, dynamic> data,
  }) async {
    if (localUserId <= 0) return;
    await LocalDatabase.instance.updateUser(localUserId, data);
  }

  User? get currentFirebaseUser => _auth.currentUser;
}
