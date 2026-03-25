import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinCompanyService {
  JoinCompanyService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<String> createJoinRequestDraft({
    required String inviteCode,
    required String fullName,
    required String email,
    required String password,
  }) async {
    final emailLower = email.trim().toLowerCase();

    final methods = await _auth.fetchSignInMethodsForEmail(emailLower);
    if (methods.isNotEmpty) {
      throw Exception(
        'This email is already registered. Please login using your existing account.',
      );
    }

    final callable = _functions.httpsCallable('sendJoinCompanyOtp');

    final result = await callable.call({
      'inviteCode': inviteCode.trim().toUpperCase(),
      'fullName': fullName.trim(),
      'email': emailLower,
      'password': password,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final draftId = (data['draftId'] ?? '').toString().trim();

    if (draftId.isEmpty) {
      throw Exception('Draft ID not returned from server.');
    }

    return draftId;
  }

  Future<void> resendJoinRequestOtp({
    required String draftId,
  }) async {
    final callable = _functions.httpsCallable('resendJoinCompanyOtp');
    await callable.call({
      'draftId': draftId,
    });
  }

  Future<void> verifyJoinRequestOtpAndComplete({
    required String draftId,
    required String otp,
  }) async {
    final callable = _functions.httpsCallable('verifyJoinCompanyOtp');

    final result = await callable.call({
      'draftId': draftId,
      'otp': otp.trim(),
    });

    final data = Map<String, dynamic>.from(result.data as Map);

    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final password = (data['password'] ?? '').toString();
    final fullName = (data['fullName'] ?? '').toString();
    final companyId = (data['companyId'] ?? '').toString().trim();
    final companyName = (data['companyName'] ?? '').toString().trim();
    final inviteId = (data['inviteId'] ?? '').toString().trim();
    final role = (data['role'] ?? 'sales').toString().trim();
    final isAdmin = (data['isAdmin'] ?? false) == true;
    final phone = (data['phone'] ?? '').toString().trim();
    final permissions =
    Map<String, dynamic>.from(data['permissions'] ?? const {});

    if (email.isEmpty || password.isEmpty || companyId.isEmpty) {
      throw Exception('Incomplete verification response from server.');
    }

    final methods = await _auth.fetchSignInMethodsForEmail(email);
    if (methods.isNotEmpty) {
      throw Exception('This email is already registered.');
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;
    final batch = _firestore.batch();

    final rootUserRef = _firestore.collection('users').doc(uid);
    final companyUserRef = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid);

    batch.set(
      rootUserRef,
      {
        'uid': uid,
        'companyId': companyId,
        'companyName': companyName,
        'role': role,
        'isAdmin': isAdmin,
        'isActive': true,
        'email': email,
        'name': fullName,
        'phone': phone,
        'permissions': permissions,
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      companyUserRef,
      {
        'uid': uid,
        'companyId': companyId,
        'companyName': companyName,
        'name': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'isAdmin': isAdmin,
        'isActive': true,
        'permissions': permissions,
        'joinedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (inviteId.isNotEmpty) {
      final inviteRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('invites')
          .doc(inviteId);

      batch.update(inviteRef, {
        'status': 'accepted',
        'acceptedByUid': uid,
        'acceptedByEmail': email,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    }

    final joinRequestRef =
    _firestore.collection('join_company_requests').doc(draftId);

    batch.set(
      joinRequestRef,
      {
        'draftId': draftId,
        'status': 'completed',
        'verified': true,
        'companyId': companyId,
        'finalUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}