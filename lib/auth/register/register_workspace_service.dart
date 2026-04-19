// FILE PATH: lib/auth/register/register_workspace_service.dart

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:QUIK/data/local_database.dart';

class RegisterWorkspaceService {
  RegisterWorkspaceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

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

        final companyId = (rootData['companyId'] ??
            localUser['companyId'] ??
            '')
            .toString()
            .trim();

        Map<String, dynamic> companyData = {};
        if (companyId.isNotEmpty) {
          final companySnap =
          await _firestore.collection('companies').doc(companyId).get();
          companyData = companySnap.data() ?? {};
        }

        return {
          ...localUser,
          ...companyData,
          ...rootData,
          'id': localUser['id'] ?? -1,
          'uid': uid,
          'companyId': companyId,
          'email': (rootData['email'] ??
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
        final companySnap =
        await _firestore.collection('companies').doc(companyId).get();
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

      await ref.putData(
        logoBytes,
        SettableMetadata(contentType: 'image/png'),
      );

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
    required String password,
    required String displayName,
    required String? logoUrl,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> adminPermissions,
  }) async {
    final emailLower = email.trim().toLowerCase();

    final existingMethods = await _auth.fetchSignInMethodsForEmail(emailLower);
    if (existingMethods.isNotEmpty) {
      throw Exception('This email is already registered.');
    }

    final callable = _functions.httpsCallable('sendWorkspaceOtp');

    final result = await callable.call({
      'email': emailLower,
      'password': password,
      'displayName': displayName,
      'logoUrl': logoUrl ?? '',
      'companyData': companyData,
      'adminPermissions': adminPermissions,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final registrationId = (data['registrationId'] ?? '').toString().trim();

    if (registrationId.isEmpty) {
      throw Exception('Registration ID not returned from server.');
    }

    return registrationId;
  }

  Future<void> sendWorkspaceOtp({
    required String registrationId,
  }) async {
    final callable = _functions.httpsCallable('resendWorkspaceOtp');
    await callable.call({
      'registrationId': registrationId,
    });
  }

  Future<void> verifyWorkspaceOtpAndCreateWorkspace({
    required String registrationId,
    required String otp,
  }) async {
    final callable =
    _functions.httpsCallable('verifyWorkspaceOtpAndCreateWorkspace');

    final result = await callable.call({
      'registrationId': registrationId,
      'otp': otp.trim(),
    });

    final data = Map<String, dynamic>.from(result.data as Map);

    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final password = (data['password'] ?? '').toString();
    final displayName = (data['displayName'] ?? '').toString();
    final logoUrl = (data['logoUrl'] ?? '').toString();
    final companyId = (data['companyId'] ?? '').toString().trim();

    final companyData =
    Map<String, dynamic>.from(data['companyData'] ?? const {});
    final adminPermissions =
    Map<String, dynamic>.from(data['adminPermissions'] ?? const {});

    if (email.isEmpty || password.isEmpty) {
      throw Exception('Incomplete verification response from server.');
    }

    if (companyId.isEmpty) {
      throw Exception('Company ID not returned from server.');
    }

    final existingMethods = await _auth.fetchSignInMethodsForEmail(email);
    if (existingMethods.isNotEmpty) {
      throw Exception('This email is already registered.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;

    await _firestore.collection('companies').doc(companyId).set({
      ...companyData,
      'companyId': companyId,
      'email': email,
      'logoUrl': logoUrl,
      'createdByUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'plan': 'trial',
      'isActive': true,
      'emailVerified': true,
      'registrationId': registrationId,
    }, SetOptions(merge: true));

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
      'emailVerified': true,
      'permissions': adminPermissions,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(uid).set({
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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final int userId = await LocalDatabase.instance.registerUser(
      email: email,
      password: password,
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