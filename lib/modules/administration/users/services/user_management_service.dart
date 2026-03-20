import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class UserQueryParams {
  final String? status;
  final String? role;
  final String? department;
  final String? branchId;
  final bool? isActive;
  final bool includeArchived;
  final int limit;
  final String orderByField;
  final bool descending;
  final DocumentSnapshot<Map<String, dynamic>>? startAfterDocument;

  const UserQueryParams({
    this.status,
    this.role,
    this.department,
    this.branchId,
    this.isActive,
    this.includeArchived = false,
    this.limit = 20,
    this.orderByField = 'createdAt',
    this.descending = true,
    this.startAfterDocument,
  });
}

class UserPageResult {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const UserPageResult({
    required this.docs,
    required this.lastDocument,
    required this.hasMore,
  });
}

class InviteCreationResult {
  final String inviteId;
  final String inviteCode;

  const InviteCreationResult({
    required this.inviteId,
    required this.inviteCode,
  });
}

class ReportingManagerOption {
  final String uid;
  final String name;
  final String role;
  final String department;
  final String? designation;
  final String? branchId;
  final String? branchName;

  const ReportingManagerOption({
    required this.uid,
    required this.name,
    required this.role,
    required this.department,
    this.designation,
    this.branchId,
    this.branchName,
  });
}

class BranchOption {
  final String branchId;
  final String branchName;
  final bool isHeadOffice;

  const BranchOption({
    required this.branchId,
    required this.branchName,
    this.isHeadOffice = false,
  });
}

class UserManagementService {
  final FirebaseFirestore firestore;

  UserManagementService({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _companyUsersCollection(
      String companyId,
      ) {
    return firestore.collection('companies').doc(companyId).collection('users');
  }

  CollectionReference<Map<String, dynamic>> _companyInvitesCollection(
      String companyId,
      ) {
    return firestore
        .collection('companies')
        .doc(companyId)
        .collection('invites');
  }

  CollectionReference<Map<String, dynamic>> _companyBranchesCollection(
      String companyId,
      ) {
    return firestore
        .collection('companies')
        .doc(companyId)
        .collection('branches');
  }

  CollectionReference<Map<String, dynamic>> get _globalUsersCollection =>
      firestore.collection('users');

  DocumentReference<Map<String, dynamic>> _companyDoc(String companyId) {
    return firestore.collection('companies').doc(companyId);
  }

  DocumentReference<Map<String, dynamic>> _companyUserDoc({
    required String companyId,
    required String userUid,
  }) {
    return _companyUsersCollection(companyId).doc(userUid);
  }

  DocumentReference<Map<String, dynamic>> _globalUserDoc({
    required String userUid,
  }) {
    return _globalUsersCollection.doc(userUid);
  }

  DocumentReference<Map<String, dynamic>> _inviteDoc({
    required String companyId,
    required String inviteId,
  }) {
    return _companyInvitesCollection(companyId).doc(inviteId);
  }

  String _normalizeText(String? value) {
    return (value ?? '').trim();
  }

  String _normalizeRole(String? role) {
    return _normalizeText(role).toLowerCase();
  }

  String _normalizeStatus(String? status) {
    return _normalizeText(status).toLowerCase();
  }

  String _normalizeEmail(String? email) {
    return _normalizeText(email).toLowerCase();
  }

  String _normalizePhone(String? phone) {
    return _normalizeText(phone).replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _deriveStatus({
    required bool isActive,
    required bool isDeleted,
  }) {
    if (isDeleted) return 'archived';
    return isActive ? 'active' : 'inactive';
  }

  Map<String, dynamic> _baseUpdateAudit({
    required String updatedByUid,
  }) {
    return {
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
    };
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(
      8,
          (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  BranchOption _defaultHeadOfficeBranch() {
    return const BranchOption(
      branchId: 'head_office',
      branchName: 'Head Office',
      isHeadOffice: true,
    );
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

  Map<String, dynamic> _companyUserPayload({
    required String companyId,
    required String userUid,
    required String role,
    required bool isActive,
    required bool isDeleted,
    required Map<String, dynamic> permissions,
    required String updatedByUid,
    String? department,
    String? designation,
    String? employeeCode,
    String? branchId,
    String? branchName,
    String? reportingManagerUid,
    String? reportingManagerName,
    String? accessScope,
    String? email,
    String? displayName,
    String? phone,
    String? photoUrl,
  }) {
    final normalizedRole = _normalizeRole(role);
    final normalizedDepartment = _normalizeText(department);
    final normalizedDesignation = _normalizeText(designation);
    final normalizedEmployeeCode = _normalizeText(employeeCode);
    final normalizedBranchName = _normalizeText(branchName).isEmpty
        ? 'Head Office'
        : _normalizeText(branchName);
    final normalizedBranchId = _safeBranchId(branchId, normalizedBranchName);
    final normalizedReportingManagerUid = _normalizeText(reportingManagerUid);
    final normalizedReportingManagerName = _normalizeText(reportingManagerName);
    final normalizedAccessScope = _normalizeText(accessScope);
    final normalizedEmail = _normalizeEmail(email);
    final normalizedDisplayName = _normalizeText(displayName);
    final normalizedPhone = _normalizePhone(phone);
    final normalizedPhotoUrl = _normalizeText(photoUrl);

    final status = _deriveStatus(
      isActive: isActive,
      isDeleted: isDeleted,
    );

    return {
      'companyId': companyId,
      'uid': userUid,
      'role': normalizedRole,
      'roleLabel': _normalizeText(role),
      'department': normalizedDepartment,
      'designation': normalizedDesignation,
      'employeeCode': normalizedEmployeeCode,
      'branchId': normalizedBranchId,
      'branchName': normalizedBranchName,
      'reportingManagerUid': normalizedReportingManagerUid,
      'reportingManagerName': normalizedReportingManagerName,
      'accessScope':
      normalizedAccessScope.isEmpty ? 'company' : normalizedAccessScope,
      'isAdmin': normalizedRole == 'admin',
      'isActive': isActive,
      'isDeleted': isDeleted,
      'status': status,
      'permissions': permissions,
      if (normalizedEmail.isNotEmpty) 'email': normalizedEmail,
      if (normalizedDisplayName.isNotEmpty) 'displayName': normalizedDisplayName,
      if (normalizedPhone.isNotEmpty) 'phone': normalizedPhone,
      if (normalizedPhotoUrl.isNotEmpty) 'photoUrl': normalizedPhotoUrl,
      ..._baseUpdateAudit(updatedByUid: updatedByUid),
    };
  }

  Map<String, dynamic> _globalMembershipPayload({
    required String companyId,
    required String role,
    required bool isActive,
    required bool isDeleted,
    required String updatedByUid,
  }) {
    final normalizedRole = _normalizeRole(role);
    final status = _deriveStatus(
      isActive: isActive,
      isDeleted: isDeleted,
    );

    return {
      'companyIds': FieldValue.arrayUnion([companyId]),
      'memberships.$companyId': {
        'companyId': companyId,
        'role': normalizedRole,
        'isAdmin': normalizedRole == 'admin',
        'isActive': isActive,
        'isDeleted': isDeleted,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': updatedByUid,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
    };
  }

  Future<void> upsertUser({
    required String companyId,
    required String userUid,
    required String role,
    required bool isActive,
    required Map<String, dynamic> permissions,
    required String updatedByUid,
    String? department,
    String? designation,
    String? employeeCode,
    String? branchId,
    String? branchName,
    String? reportingManagerUid,
    String? reportingManagerName,
    String? accessScope,
    String? email,
    String? displayName,
    String? phone,
    String? photoUrl,
    bool isDeleted = false,
  }) async {
    if (isDeleted && isActive) {
      throw ArgumentError(
        'Invalid user state: a deleted user cannot be active.',
      );
    }

    final companyRef = _companyUserDoc(
      companyId: companyId,
      userUid: userUid,
    );

    final globalRef = _globalUserDoc(
      userUid: userUid,
    );

    await firestore.runTransaction((transaction) async {
      final companySnap = await transaction.get(companyRef);

      final companyPayload = _companyUserPayload(
        companyId: companyId,
        userUid: userUid,
        role: role,
        isActive: isActive,
        isDeleted: isDeleted,
        permissions: permissions,
        updatedByUid: updatedByUid,
        department: department,
        designation: designation,
        employeeCode: employeeCode,
        branchId: branchId,
        branchName: branchName,
        reportingManagerUid: reportingManagerUid,
        reportingManagerName: reportingManagerName,
        accessScope: accessScope,
        email: email,
        displayName: displayName,
        phone: phone,
        photoUrl: photoUrl,
      );

      final companyCreateAudit = companySnap.exists
          ? <String, dynamic>{}
          : <String, dynamic>{
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': updatedByUid,
      };

      transaction.set(
        companyRef,
        {
          ...companyPayload,
          ...companyCreateAudit,
        },
        SetOptions(merge: true),
      );

      final globalPayload = _globalMembershipPayload(
        companyId: companyId,
        role: role,
        isActive: isActive,
        isDeleted: isDeleted,
        updatedByUid: updatedByUid,
      );

      transaction.set(
        globalRef,
        {
          'uid': userUid,
          if (_normalizeEmail(email).isNotEmpty) 'email': _normalizeEmail(email),
          if (_normalizeText(displayName).isNotEmpty)
            'displayName': _normalizeText(displayName),
          if (_normalizePhone(phone).isNotEmpty) 'phone': _normalizePhone(phone),
          if (_normalizeText(photoUrl).isNotEmpty)
            'photoUrl': _normalizeText(photoUrl),
          ...globalPayload,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> updateUser({
    required String companyId,
    required String userUid,
    required String role,
    required bool isActive,
    required Map<String, dynamic> permissions,
    required String updatedByUid,
    String? department,
    String? designation,
    String? employeeCode,
    String? branchId,
    String? branchName,
    String? reportingManagerUid,
    String? reportingManagerName,
    String? accessScope,
    String? email,
    String? displayName,
    String? phone,
    String? photoUrl,
    bool isDeleted = false,
  }) {
    return upsertUser(
      companyId: companyId,
      userUid: userUid,
      role: role,
      isActive: isActive,
      permissions: permissions,
      updatedByUid: updatedByUid,
      department: department,
      designation: designation,
      employeeCode: employeeCode,
      branchId: branchId,
      branchName: branchName,
      reportingManagerUid: reportingManagerUid,
      reportingManagerName: reportingManagerName,
      accessScope: accessScope,
      email: email,
      displayName: displayName,
      phone: phone,
      photoUrl: photoUrl,
      isDeleted: isDeleted,
    );
  }

  Future<void> toggleUserStatus({
    required String companyId,
    required String userUid,
    required String updatedByUid,
  }) async {
    final companyRef = _companyUserDoc(
      companyId: companyId,
      userUid: userUid,
    );

    final globalRef = _globalUserDoc(
      userUid: userUid,
    );

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(companyRef);

      if (!snap.exists) {
        throw StateError('User not found in company scope.');
      }

      final data = snap.data() ?? <String, dynamic>{};
      final isDeleted = data['isDeleted'] == true;

      if (isDeleted) {
        throw StateError('Deleted user cannot be toggled. Restore first.');
      }

      final currentIsActive = data['isActive'] == true;
      final newIsActive = !currentIsActive;
      final role = _normalizeText(data['role']).isEmpty ? 'user' : data['role'];

      final newStatus = _deriveStatus(
        isActive: newIsActive,
        isDeleted: false,
      );

      transaction.set(
        companyRef,
        {
          'isActive': newIsActive,
          'isDeleted': false,
          'status': newStatus,
          ..._baseUpdateAudit(updatedByUid: updatedByUid),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        globalRef,
        {
          'memberships.$companyId': {
            'companyId': companyId,
            'role': role,
            'isAdmin': _normalizeRole(role) == 'admin',
            'isActive': newIsActive,
            'isDeleted': false,
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': updatedByUid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': updatedByUid,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> softDeleteUser({
    required String companyId,
    required String userUid,
    required String deletedByUid,
  }) async {
    final companyRef = _companyUserDoc(
      companyId: companyId,
      userUid: userUid,
    );

    final globalRef = _globalUserDoc(
      userUid: userUid,
    );

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(companyRef);

      if (!snap.exists) {
        throw StateError('User not found in company scope.');
      }

      final data = snap.data() ?? <String, dynamic>{};
      final role = _normalizeText(data['role']).isEmpty ? 'user' : data['role'];

      transaction.set(
        companyRef,
        {
          'isActive': false,
          'isDeleted': true,
          'status': 'deleted',
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedByUid': deletedByUid,
          ..._baseUpdateAudit(updatedByUid: deletedByUid),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        globalRef,
        {
          'memberships.$companyId': {
            'companyId': companyId,
            'role': role,
            'isAdmin': _normalizeRole(role) == 'admin',
            'isActive': false,
            'isDeleted': true,
            'status': 'deleted',
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': deletedByUid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': deletedByUid,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> deleteUser({
    required String companyId,
    required String userUid,
    required String deletedByUid,
  }) {
    return softDeleteUser(
      companyId: companyId,
      userUid: userUid,
      deletedByUid: deletedByUid,
    );
  }

  Future<void> restoreUser({
    required String companyId,
    required String userUid,
    required String restoredByUid,
  }) async {
    final companyRef = _companyUserDoc(
      companyId: companyId,
      userUid: userUid,
    );

    final globalRef = _globalUserDoc(
      userUid: userUid,
    );

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(companyRef);

      if (!snap.exists) {
        throw StateError('User not found in company scope.');
      }

      final data = snap.data() ?? <String, dynamic>{};
      final role = _normalizeText(data['role']).isEmpty ? 'user' : data['role'];

      transaction.set(
        companyRef,
        {
          'isActive': true,
          'isDeleted': false,
          'status': 'active',
          'deletedAt': null,
          'deletedByUid': null,
          'restoredAt': FieldValue.serverTimestamp(),
          'restoredByUid': restoredByUid,
          ..._baseUpdateAudit(updatedByUid: restoredByUid),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        globalRef,
        {
          'memberships.$companyId': {
            'companyId': companyId,
            'role': role,
            'isAdmin': _normalizeRole(role) == 'admin',
            'isActive': true,
            'isDeleted': false,
            'status': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': restoredByUid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': restoredByUid,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> updateUserPermissions({
    required String companyId,
    required String userUid,
    required Map<String, dynamic> permissions,
    required String updatedByUid,
  }) async {
    await _companyUserDoc(
      companyId: companyId,
      userUid: userUid,
    ).set(
      {
        'permissions': permissions,
        ..._baseUpdateAudit(updatedByUid: updatedByUid),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateUserRole({
    required String companyId,
    required String userUid,
    required String role,
    required String updatedByUid,
  }) async {
    final normalizedRole = _normalizeRole(role);

    final companyRef = _companyUserDoc(
      companyId: companyId,
      userUid: userUid,
    );

    final globalRef = _globalUserDoc(
      userUid: userUid,
    );

    await firestore.runTransaction((transaction) async {
      final companySnap = await transaction.get(companyRef);
      final companyData = companySnap.data() ?? <String, dynamic>{};
      final isActive = companyData['isActive'] == true;
      final isDeleted = companyData['isDeleted'] == true;

      transaction.set(
        companyRef,
        {
          'role': normalizedRole,
          'roleLabel': _normalizeText(role),
          'isAdmin': normalizedRole == 'admin',
          ..._baseUpdateAudit(updatedByUid: updatedByUid),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        globalRef,
        {
          'memberships.$companyId': {
            'companyId': companyId,
            'role': normalizedRole,
            'isAdmin': normalizedRole == 'admin',
            'isActive': isActive,
            'isDeleted': isDeleted,
            'status': _deriveStatus(
              isActive: isActive,
              isDeleted: isDeleted,
            ),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': updatedByUid,
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': updatedByUid,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> updateUserProfileFields({
    required String companyId,
    required String userUid,
    required String updatedByUid,
    String? department,
    String? designation,
    String? employeeCode,
    String? branchId,
    String? branchName,
    String? reportingManagerUid,
    String? reportingManagerName,
    String? accessScope,
    String? email,
    String? displayName,
    String? phone,
    String? photoUrl,
  }) async {
    final companyUpdate = <String, dynamic>{
      if (department != null) 'department': _normalizeText(department),
      if (designation != null) 'designation': _normalizeText(designation),
      if (employeeCode != null) 'employeeCode': _normalizeText(employeeCode),
      if (branchId != null) 'branchId': _safeBranchId(branchId, branchName),
      if (branchName != null)
        'branchName': _normalizeText(branchName).isEmpty
            ? 'Head Office'
            : _normalizeText(branchName),
      if (reportingManagerUid != null)
        'reportingManagerUid': _normalizeText(reportingManagerUid),
      if (reportingManagerName != null)
        'reportingManagerName': _normalizeText(reportingManagerName),
      if (accessScope != null)
        'accessScope': _normalizeText(accessScope).isEmpty
            ? 'company'
            : _normalizeText(accessScope),
      if (email != null) 'email': _normalizeEmail(email),
      if (displayName != null) 'displayName': _normalizeText(displayName),
      if (phone != null) 'phone': _normalizePhone(phone),
      if (photoUrl != null) 'photoUrl': _normalizeText(photoUrl),
      ..._baseUpdateAudit(updatedByUid: updatedByUid),
    };

    await _companyUserDoc(
      companyId: companyId,
      userUid: userUid,
    ).set(
      companyUpdate,
      SetOptions(merge: true),
    );

    final globalUpdate = <String, dynamic>{
      if (email != null) 'email': _normalizeEmail(email),
      if (displayName != null) 'displayName': _normalizeText(displayName),
      if (phone != null) 'phone': _normalizePhone(phone),
      if (photoUrl != null) 'photoUrl': _normalizeText(photoUrl),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': updatedByUid,
    };

    await _globalUserDoc(userUid: userUid).set(
      globalUpdate,
      SetOptions(merge: true),
    );
  }

  Future<bool> hasPendingInviteForEmail({
    required String companyId,
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) return false;

    final snapshot = await _companyInvitesCollection(companyId)
        .where('email', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<InviteCreationResult> createInvite({
    required String companyId,
    required String email,
    required String role,
    required Map<String, dynamic> permissions,
    required String invitedByUid,
    String? name,
    String? phone,
    String? department,
    String? designation,
    String? branchId,
    String? branchName,
    String? reportingManagerUid,
    String? reportingManagerName,
    String? accessScope,
    Duration expiry = const Duration(days: 7),
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPhone = _normalizePhone(phone);
    final normalizedBranchName = _normalizeText(branchName).isEmpty
        ? 'Head Office'
        : _normalizeText(branchName);
    final normalizedBranchId = _safeBranchId(branchId, normalizedBranchName);

    if (normalizedEmail.isEmpty) {
      throw ArgumentError('Email is required to create an invite.');
    }

    final duplicate = await hasPendingInviteForEmail(
      companyId: companyId,
      email: normalizedEmail,
    );

    if (duplicate) {
      throw StateError('A pending invite already exists for this email.');
    }

    final inviteRef = _companyInvitesCollection(companyId).doc();

    String inviteCode = _generateInviteCode();
    for (int i = 0; i < 5; i++) {
      final existing = await _companyInvitesCollection(companyId)
          .where('code', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) break;
      inviteCode = _generateInviteCode();
    }

    await inviteRef.set({
      'inviteId': inviteRef.id,
      'companyId': companyId,
      'code': inviteCode,
      'name': _normalizeText(name),
      'email': normalizedEmail,
      'phone': normalizedPhone,
      'role': _normalizeRole(role),
      'roleLabel': _normalizeText(role),
      'permissions': permissions,
      'department': _normalizeText(department),
      'designation': _normalizeText(designation),
      'branchId': normalizedBranchId,
      'branchName': normalizedBranchName,
      'reportingManagerUid': _normalizeText(reportingManagerUid),
      'reportingManagerName': _normalizeText(reportingManagerName),
      'accessScope': _normalizeText(accessScope).isEmpty
          ? 'company'
          : _normalizeText(accessScope),
      'status': 'pending',
      'isActive': true,
      'isDeleted': false,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(expiry)),
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': invitedByUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': invitedByUid,
    });

    return InviteCreationResult(
      inviteId: inviteRef.id,
      inviteCode: inviteCode,
    );
  }

  Future<void> cancelInvite({
    required String companyId,
    required String inviteId,
    required String cancelledByUid,
  }) async {
    await _inviteDoc(
      companyId: companyId,
      inviteId: inviteId,
    ).set(
      {
        'status': 'cancelled',
        'isDeleted': true,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledByUid': cancelledByUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': cancelledByUid,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markInviteAccepted({
    required String companyId,
    required String inviteId,
    required String acceptedByUid,
  }) async {
    await _inviteDoc(
      companyId: companyId,
      inviteId: inviteId,
    ).set(
      {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedByUid': acceptedByUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': acceptedByUid,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteInvite({
    required String companyId,
    required String inviteId,
  }) async {
    await _inviteDoc(
      companyId: companyId,
      inviteId: inviteId,
    ).delete();
  }

  Query<Map<String, dynamic>> buildUsersQuery({
    required String companyId,
    UserQueryParams params = const UserQueryParams(),
  }) {
    Query<Map<String, dynamic>> query = _companyUsersCollection(companyId);

    final normalizedStatus = _normalizeStatus(params.status);
    final normalizedRole = _normalizeRole(params.role);
    final normalizedDepartment = _normalizeText(params.department);
    final normalizedBranchId = _normalizeText(params.branchId);

    if (normalizedStatus == 'deleted') {
      query = query.where('isDeleted', isEqualTo: true);
    } else if (normalizedStatus == 'archived') {
      query = query.where('isDeleted', isEqualTo: true);
    } else if (normalizedStatus == 'active') {
      query = query.where('status', isEqualTo: 'active');
    } else if (normalizedStatus == 'inactive') {
      query = query.where('status', isEqualTo: 'inactive');
    } else if (!params.includeArchived) {
      query = query.where('isDeleted', isEqualTo: false);
    }

    if (params.isActive != null) {
      query = query.where('isActive', isEqualTo: params.isActive);
    }

    if (normalizedRole.isNotEmpty) {
      query = query.where('role', isEqualTo: normalizedRole);
    }

    if (normalizedDepartment.isNotEmpty) {
      query = query.where('department', isEqualTo: normalizedDepartment);
    }

    if (normalizedBranchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: normalizedBranchId);
    }

    final shouldOrder = params.orderByField.trim().isNotEmpty &&
        params.orderByField.trim() == 'createdAt';

    if (shouldOrder) {
      query = query.orderBy('createdAt', descending: params.descending);
    }

    query = query.limit(params.limit);

    if (params.startAfterDocument != null) {
      query = query.startAfterDocument(params.startAfterDocument!);
    }

    return query;
  }

  Future<UserPageResult> fetchUsersPage({
    required String companyId,
    UserQueryParams params = const UserQueryParams(),
  }) async {
    final snapshot = await buildUsersQuery(
      companyId: companyId,
      params: params,
    ).get();

    final docs = snapshot.docs;
    return UserPageResult(
      docs: docs,
      lastDocument: docs.isNotEmpty ? docs.last : null,
      hasMore: docs.length == params.limit,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsers({
    required String companyId,
    UserQueryParams params = const UserQueryParams(),
  }) {
    return buildUsersQuery(
      companyId: companyId,
      params: params,
    ).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingInvites({
    required String companyId,
  }) {
    return _companyInvitesCollection(companyId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<ReportingManagerOption>> fetchReportingManagers({
    required String companyId,
    String? department,
    String? branchId,
  }) async {
    Query<Map<String, dynamic>> query = _companyUsersCollection(companyId)
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true);

    final normalizedDepartment = _normalizeText(department);
    final normalizedBranchId = _normalizeText(branchId);

    if (normalizedDepartment.isNotEmpty) {
      query = query.where('department', isEqualTo: normalizedDepartment);
    }

    if (normalizedBranchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: normalizedBranchId);
    }

    final snapshot = await query.get();

    final results = snapshot.docs
        .map((doc) {
      final data = doc.data();
      final displayName = _normalizeText(data['displayName']);
      final fallbackName = _normalizeText(data['name']);

      return ReportingManagerOption(
        uid: doc.id,
        name: displayName.isNotEmpty ? displayName : fallbackName,
        role: _normalizeText(data['role']),
        department: _normalizeText(data['department']),
        designation: _normalizeText(data['designation']),
        branchId: _normalizeText(data['branchId']),
        branchName: _normalizeText(data['branchName']),
      );
    })
        .where((e) => e.name.isNotEmpty)
        .toList();

    results.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return results;
  }

  Future<List<BranchOption>> fetchCompanyBranches({
    required String companyId,
  }) async {
    final List<BranchOption> branches = [];

    try {
      final branchSnapshot = await _companyBranchesCollection(companyId)
          .where('isDeleted', isEqualTo: false)
          .get();

      for (final doc in branchSnapshot.docs) {
        final data = doc.data();
        final branchName = _normalizeText(
          data['name'] ?? data['branchName'],
        );
        final branchId = _normalizeText(data['branchId']).isNotEmpty
            ? _normalizeText(data['branchId'])
            : doc.id;

        if (branchName.isNotEmpty) {
          branches.add(
            BranchOption(
              branchId: branchId,
              branchName: branchName,
              isHeadOffice: data['isHeadOffice'] == true,
            ),
          );
        }
      }

      branches.sort(
            (a, b) => a.branchName.toLowerCase().compareTo(
          b.branchName.toLowerCase(),
        ),
      );
    } catch (_) {}

    if (branches.isNotEmpty) {
      return branches;
    }

    try {
      final companySnap = await _companyDoc(companyId).get();
      final companyData = companySnap.data() ?? <String, dynamic>{};

      final companyBranchName = _normalizeText(
        companyData['headOfficeName'] ??
            companyData['registeredBranchName'] ??
            companyData['branchName'],
      );

      if (companyBranchName.isNotEmpty) {
        return [
          BranchOption(
            branchId: _safeBranchId(null, companyBranchName),
            branchName: companyBranchName,
            isHeadOffice: true,
          ),
        ];
      }
    } catch (_) {}

    return [_defaultHeadOfficeBranch()];
  }

  Future<BranchOption> fetchDefaultBranch({
    required String companyId,
  }) async {
    final branches = await fetchCompanyBranches(companyId: companyId);

    for (final branch in branches) {
      if (branch.isHeadOffice) return branch;
    }

    if (branches.isNotEmpty) {
      return branches.first;
    }

    return _defaultHeadOfficeBranch();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsersBase({
    required String companyId,
    bool includeArchived = false,
  }) {
    Query<Map<String, dynamic>> query = _companyUsersCollection(companyId);

    if (!includeArchived) {
      query = query.where('isDeleted', isEqualTo: false);
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchInvitesBase({
    required String companyId,
  }) {
    return _companyInvitesCollection(companyId).snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchUsersBaseOnce({
    required String companyId,
    bool includeArchived = false,
  }) async {
    Query<Map<String, dynamic>> query = _companyUsersCollection(companyId);

    if (!includeArchived) {
      query = query.where('isDeleted', isEqualTo: false);
    }

    final snapshot = await query.get();
    return snapshot.docs;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> applyUsersLocalFilters({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    UserQueryParams params = const UserQueryParams(),
  }) {
    final normalizedStatus = _normalizeStatus(params.status);
    final normalizedRole = _normalizeRole(params.role);
    final normalizedDepartment = _normalizeText(params.department);
    final normalizedBranchId = _normalizeText(params.branchId);

    final filtered = docs.where((doc) {
      final data = doc.data();

      final bool isDeleted = data['isDeleted'] == true;
      final bool isActive = data['isActive'] == true;
      final String status = _normalizeStatus(data['status']);
      final String role = _normalizeRole(data['role']);
      final String department = _normalizeText(data['department']);
      final String branchId = _normalizeText(data['branchId']);

      if (!params.includeArchived && isDeleted) {
        return false;
      }

      if (normalizedStatus == 'deleted' && !isDeleted) {
        return false;
      }
      if (normalizedStatus == 'archived' && !isDeleted) {
        return false;
      }
      if (normalizedStatus == 'active' && status != 'active') {
        return false;
      }
      if (normalizedStatus == 'inactive' && status != 'inactive') {
        return false;
      }

      if (params.isActive != null && isActive != params.isActive) {
        return false;
      }

      if (normalizedRole.isNotEmpty && role != normalizedRole) {
        return false;
      }

      if (normalizedDepartment.isNotEmpty &&
          department.toLowerCase() != normalizedDepartment.toLowerCase()) {
        return false;
      }

      if (normalizedBranchId.isNotEmpty && branchId != normalizedBranchId) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final ad = a.data();
      final bd = b.data();

      if (params.orderByField == 'displayName') {
        final av = _normalizeText(
          (ad['displayName'] ?? ad['name'] ?? '').toString(),
        );
        final bv = _normalizeText(
          (bd['displayName'] ?? bd['name'] ?? '').toString(),
        );
        return params.descending ? bv.compareTo(av) : av.compareTo(bv);
      }

      if (params.orderByField == 'email') {
        final av = _normalizeEmail(ad['email']);
        final bv = _normalizeEmail(bd['email']);
        return params.descending ? bv.compareTo(av) : av.compareTo(bv);
      }

      final aTs = ad['createdAt'];
      final bTs = bd['createdAt'];

      DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);

      if (aTs is Timestamp) aDate = aTs.toDate();
      if (bTs is Timestamp) bDate = bTs.toDate();

      return params.descending
          ? bDate.compareTo(aDate)
          : aDate.compareTo(bDate);
    });

    return filtered.take(params.limit).toList();
  }
}