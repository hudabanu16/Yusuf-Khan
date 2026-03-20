import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:QUIK/data/local_database.dart';

class RegisterWorkspaceService {
  RegisterWorkspaceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<Map<String, dynamic>?> getLocalCurrentUser() async {
    return LocalDatabase.instance.getCurrentUser();
  }

  Future<String?> uploadLogoIfNeeded({
    required String uid,
    required Uint8List? logoBytes,
    required String? existingLogoUrl,
  }) async {
    String? logoUrl = existingLogoUrl;

    if (logoBytes != null) {
      final path = 'entity_logos/$uid/${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = _storage.ref().child(path);

      await ref.putData(
        logoBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      logoUrl = await ref.getDownloadURL();
    }

    return logoUrl;
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

  Future<int> createWorkspaceForNewUser({
    required String email,
    required String password,
    required String displayName,
    required String? logoUrl,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> adminPermissions,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;
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
      'permissions': adminPermissions,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'companyId': companyRef.id,
      'role': 'admin',
      'isAdmin': true,
      'isActive': true,
      'email': email,
      'name': displayName,
      ...companyData,
      'logoUrl': logoUrl ?? '',
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
      'logoUrl': logoUrl ?? '',
    });

    return userId;
  }

  Future<void> updateLocalUser({
    required int localUserId,
    required Map<String, dynamic> data,
  }) async {
    await LocalDatabase.instance.updateUser(localUserId, data);
  }

  User? get currentFirebaseUser => _auth.currentUser;
}