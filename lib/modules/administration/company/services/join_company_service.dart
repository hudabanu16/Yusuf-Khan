import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class JoinCompanyService {
  JoinCompanyService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String _normalizeText(String? value) {
    return (value ?? '').trim();
  }

  String _normalizeEmail(String? value) {
    return _normalizeText(value).toLowerCase();
  }

  String _normalizeRole(String? value) {
    return _normalizeText(value).toLowerCase();
  }

  String _normalizePhone(String? value) {
    return _normalizeText(value).replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _safeBranchId(String? branchId, String? branchName) {
    final normalizedBranchId = _normalizeText(branchId);
    if (normalizedBranchId.isNotEmpty) return normalizedBranchId;

    final normalizedBranchName = _normalizeText(branchName);
    if (normalizedBranchName.isEmpty) return 'head_office';

    return normalizedBranchName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'y') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized == 'n' ||
          normalized.isEmpty) {
        return false;
      }
    }
    return false;
  }

  Map<String, dynamic> _sanitizePermissions(Map<String, dynamic>? input) {
    if (input == null || input.isEmpty) {
      return <String, dynamic>{};
    }

    final sanitized = <String, dynamic>{};

    for (final entry in input.entries) {
      final key = _normalizeText(entry.key);
      if (key.isEmpty) continue;

      final value = entry.value;

      if (value is Map) {
        sanitized[key] = _sanitizePermissions(Map<String, dynamic>.from(value));
      } else if (value == null) {
        sanitized[key] = false;
      } else {
        sanitized[key] = _toBool(value);
      }
    }

    return sanitized;
  }

  String _deriveStatus({required bool isActive, required bool isDeleted}) {
    if (isDeleted) return 'archived';
    return isActive ? 'active' : 'inactive';
  }

  Future<String> createJoinRequestDraft({
    required String inviteCode,
    required String fullName,
    required String email,
  }) async {
    final normalizedInviteCode = _normalizeText(inviteCode).toUpperCase();
    final normalizedFullName = _normalizeText(fullName);
    final emailLower = _normalizeEmail(email);

    if (normalizedInviteCode.isEmpty) {
      throw Exception('Invite code is required.');
    }

    if (normalizedFullName.isEmpty) {
      throw Exception('Full name is required.');
    }

    if (emailLower.isEmpty) {
      throw Exception('Email is required.');
    }

    final callable = _functions.httpsCallable('sendJoinCompanyOtp');

    final result = await callable.call({
      'inviteCode': normalizedInviteCode,
      'fullName': normalizedFullName,
      'email': emailLower,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final draftId = _normalizeText(data['draftId']);

    if (draftId.isEmpty) {
      throw Exception('Draft ID not returned from server.');
    }

    await _deleteLegacyJoinRequestSecrets(draftId);

    return draftId;
  }

  Future<void> resendJoinRequestOtp({required String draftId}) async {
    final normalizedDraftId = _normalizeText(draftId);
    if (normalizedDraftId.isEmpty) {
      throw Exception('Draft ID is required.');
    }

    final callable = _functions.httpsCallable('resendJoinCompanyOtp');
    await callable.call({'draftId': normalizedDraftId});
    await _deleteLegacyJoinRequestSecrets(normalizedDraftId);
  }

  Future<void> verifyJoinRequestOtpAndComplete({
    required String draftId,
    required String otp,
    required String password,
  }) async {
    final normalizedDraftId = _normalizeText(draftId);
    final normalizedOtp = _normalizeText(otp);

    if (normalizedDraftId.isEmpty) {
      throw Exception('Draft ID is required.');
    }

    if (normalizedOtp.isEmpty) {
      throw Exception('OTP is required.');
    }

    if (password.isEmpty) {
      throw Exception('Password is required.');
    }

    final callable = _functions.httpsCallable('verifyJoinCompanyOtp');

    final result = await callable.call({
      'draftId': normalizedDraftId,
      'otp': normalizedOtp,
    });

    await _deleteLegacyJoinRequestSecrets(normalizedDraftId);

    final data = Map<String, dynamic>.from(result.data as Map);

    final email = _normalizeEmail(data['email']);
    final fullName = _normalizeText(data['fullName']);
    final companyId = _normalizeText(data['companyId']);
    final companyName = _normalizeText(data['companyName']);
    final inviteId = _normalizeText(data['inviteId']);
    final role = _normalizeRole((data['role'] ?? 'sales').toString());
    final phone = _normalizePhone(data['phone']);
    final department = _normalizeText(data['department']);
    final designation = _normalizeText(data['designation']);
    final employeeCode = _normalizeText(data['employeeCode']);
    final accessScope = _normalizeText(data['accessScope']).isEmpty
        ? 'company'
        : _normalizeText(data['accessScope']);
    final branchName = _normalizeText(data['branchName']).isEmpty
        ? 'Head Office'
        : _normalizeText(data['branchName']);
    final branchId = _safeBranchId(data['branchId']?.toString(), branchName);
    final reportingManagerUid = _normalizeText(data['reportingManagerUid']);
    final reportingManagerName = _normalizeText(data['reportingManagerName']);
    final permissions = _sanitizePermissions(
      Map<String, dynamic>.from(data['permissions'] ?? const {}),
    );

    if (email.isEmpty || companyId.isEmpty) {
      throw Exception('Incomplete verification response from server.');
    }

    final authResolution = await _getOrCreateVerifiedAuthUser(
      email: email,
      password: password,
    );

    final user = authResolution.user;

    final uid = user.uid;
    final isActive = true;
    final isDeleted = false;
    final status = _deriveStatus(isActive: isActive, isDeleted: isDeleted);

    final rootUserRef = _firestore.collection('users').doc(uid);
    final companyUserRef = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid);
    final joinRequestRef = _firestore
        .collection('join_company_requests')
        .doc(normalizedDraftId);

    final inviteRef = inviteId.isNotEmpty
        ? _firestore
              .collection('companies')
              .doc(companyId)
              .collection('invites')
              .doc(inviteId)
        : null;

    try {
      await _firestore.runTransaction((transaction) async {
        final companySnap = await transaction.get(
          _firestore.collection('companies').doc(companyId),
        );

        if (!companySnap.exists) {
          throw Exception('Company not found.');
        }

        if (inviteRef != null) {
          final inviteSnap = await transaction.get(inviteRef);
          if (!inviteSnap.exists) {
            throw Exception('Invite not found or already removed.');
          }

          final inviteData = inviteSnap.data() ?? <String, dynamic>{};
          final inviteCompanyId = _normalizeText(inviteData['companyId']);
          final inviteStatus = _normalizeText(
            inviteData['status'],
          ).toLowerCase();
          final inviteEmail = _normalizeEmail(inviteData['email']);

          if (inviteCompanyId.isNotEmpty && inviteCompanyId != companyId) {
            throw Exception('Invite company mismatch.');
          }

          if (inviteStatus.isNotEmpty && inviteStatus != 'pending') {
            throw Exception('This invite is no longer pending.');
          }

          if (inviteEmail.isNotEmpty && inviteEmail != email) {
            throw Exception('Invite email does not match the verified email.');
          }
        }

        final rootPayload = <String, dynamic>{
          'uid': uid,
          'email': email,
          'displayName': fullName,
          'name': fullName,
          if (phone.isNotEmpty) 'phone': phone,
          'companyIds': FieldValue.arrayUnion([companyId]),
          'memberships.$companyId': {
            'companyId': companyId,
            'role': role,
            'isAdmin': role == 'admin',
            'isActive': isActive,
            'isDeleted': isDeleted,
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': uid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': uid,
          'joinedAt': FieldValue.serverTimestamp(),
        };

        final companyUserPayload = <String, dynamic>{
          'uid': uid,
          'companyId': companyId,
          'companyName': companyName,
          'displayName': fullName,
          'name': fullName,
          'email': email,
          if (phone.isNotEmpty) 'phone': phone,
          'role': role,
          'roleLabel': role,
          'department': department,
          'designation': designation,
          'employeeCode': employeeCode,
          'branchId': branchId,
          'branchName': branchName,
          'reportingManagerUid': reportingManagerUid,
          'reportingManagerName': reportingManagerName,
          'accessScope': accessScope,
          'isAdmin': role == 'admin',
          'isActive': isActive,
          'isDeleted': isDeleted,
          'status': status,
          'permissions': permissions,
          'joinedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdByUid': uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': uid,
        };

        transaction.set(rootUserRef, rootPayload, SetOptions(merge: true));

        transaction.set(
          companyUserRef,
          companyUserPayload,
          SetOptions(merge: true),
        );

        if (inviteRef != null) {
          transaction.set(inviteRef, {
            'status': 'accepted',
            'acceptedByUid': uid,
            'acceptedByEmail': email,
            'acceptedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': uid,
          }, SetOptions(merge: true));
        }

        transaction.set(joinRequestRef, {
          'draftId': normalizedDraftId,
          'status': 'completed',
          'verified': true,
          'companyId': companyId,
          'finalUid': uid,
          'password': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      if (authResolution.createdNewUser) {
        try {
          await user.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> _deleteLegacyJoinRequestSecrets(String draftId) async {
    final normalizedDraftId = draftId.trim();
    if (normalizedDraftId.isEmpty) return;

    try {
      await _firestore
          .collection('join_company_requests')
          .doc(normalizedDraftId)
          .update({'password': FieldValue.delete()});
      debugPrint('JoinCompanyService: cleaned legacy join request secrets');
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      debugPrint('JoinCompanyService: legacy join cleanup skipped: ${e.code}');
    } catch (e) {
      debugPrint('JoinCompanyService: legacy join cleanup skipped');
    }
  }

  Future<_AuthUserResolution> _getOrCreateVerifiedAuthUser({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    debugPrint(
      'JoinCompanyService auth create/recover email: $normalizedEmail',
    );
    debugPrint('JoinCompanyService auth password length: ${password.length}');

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to create user account.');
      }

      return _AuthUserResolution(user: user, createdNewUser: true);
    } on FirebaseAuthException catch (e) {
      debugPrint('JoinCompanyService create auth error code: ${e.code}');
      debugPrint('JoinCompanyService create auth error message: ${e.message}');
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

      return _AuthUserResolution(user: user, createdNewUser: false);
    }
  }
}

class _AuthUserResolution {
  const _AuthUserResolution({required this.user, required this.createdNewUser});

  final User user;
  final bool createdNewUser;
}
