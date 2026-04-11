import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/services/user_management_service.dart';

typedef UserDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

class UserFilterState {
  final String searchQuery;
  final String selectedRole;
  final String selectedStatus;
  final String selectedDepartment;
  final String? selectedBranchId;
  final String sortField;
  final bool sortAscending;
  final int limit;
  final DocumentSnapshot<Map<String, dynamic>>? startAfterDocument;

  const UserFilterState({
    this.searchQuery = '',
    this.selectedRole = 'all',
    this.selectedStatus = 'all',
    this.selectedDepartment = 'all',
    this.selectedBranchId,
    this.sortField = 'createdAt',
    this.sortAscending = false,
    this.limit = 20,
    this.startAfterDocument,
  });

  UserFilterState copyWith({
    String? searchQuery,
    String? selectedRole,
    String? selectedStatus,
    String? selectedDepartment,
    String? selectedBranchId,
    String? sortField,
    bool? sortAscending,
    int? limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) {
    return UserFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRole: selectedRole ?? this.selectedRole,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      limit: limit ?? this.limit,
      startAfterDocument: startAfterDocument ?? this.startAfterDocument,
    );
  }
}

/// Converts UI filter state into service-level backend query params.
/// This should be used for Firestore-backed filtering and pagination.
UserQueryParams buildUserQueryParams(UserFilterState state) {
  final normalizedStatus = _normalize(state.selectedStatus);
  final normalizedRole = _normalize(state.selectedRole);
  final normalizedDepartment = _normalize(state.selectedDepartment);
  final normalizedBranchId = _normalize(state.selectedBranchId);

  final isArchivedFilter =
      normalizedStatus == 'archived' || normalizedStatus == 'deleted';

  return UserQueryParams(
    status: normalizedStatus == 'all' ? null : normalizedStatus,
    role: normalizedRole == 'all' ? null : normalizedRole,
    department: normalizedDepartment == 'all' ? null : normalizedDepartment,
    branchId: normalizedBranchId.isEmpty ? null : normalizedBranchId,
    includeArchived: isArchivedFilter,
    isActive: _mapStatusToIsActive(normalizedStatus),
    limit: state.limit,
    orderByField: _mapSortFieldForBackend(state.sortField),
    descending: !state.sortAscending,
    startAfterDocument: state.startAfterDocument,
  );
}

/// Local fallback filter for already-fetched docs.
/// Keep this only for search-on-current-page or temporary hybrid mode.
List<UserDoc> filterUsersLocally({
  required List<UserDoc> docs,
  required UserFilterState state,
}) {
  final normalizedQuery = _normalize(state.searchQuery);
  final normalizedRole = _normalize(state.selectedRole);
  final normalizedStatus = _normalize(state.selectedStatus);
  final normalizedDepartment = _normalize(state.selectedDepartment);
  final normalizedBranchId = _normalize(state.selectedBranchId);

  final filtered = docs.where((doc) {
    final data = doc.data();

    final displayName = _normalize(_readDisplayName(data));
    final email = _normalize(data['email']);
    final phone = _normalize(data['phone']);
    final role = _normalize(data['role']);
    final department = _normalize(data['department']);
    final designation = _normalize(data['designation']);
    final employeeCode = _normalize(data['employeeCode']);
    final branchName = _normalize(data['branchName']);
    final branchId = _normalize(data['branchId']);
    final reportingManagerName = _normalize(data['reportingManagerName']);

    final currentStatus = _readNormalizedStatus(data);

    final matchesSearch = normalizedQuery.isEmpty ||
        displayName.contains(normalizedQuery) ||
        email.contains(normalizedQuery) ||
        phone.contains(normalizedQuery) ||
        role.contains(normalizedQuery) ||
        department.contains(normalizedQuery) ||
        designation.contains(normalizedQuery) ||
        employeeCode.contains(normalizedQuery) ||
        branchName.contains(normalizedQuery) ||
        branchId.contains(normalizedQuery) ||
        reportingManagerName.contains(normalizedQuery);

    final matchesRole = normalizedRole == 'all' || role == normalizedRole;

    final matchesStatus =
        normalizedStatus == 'all' || currentStatus == normalizedStatus;

    final matchesDepartment = normalizedDepartment == 'all' ||
        department == normalizedDepartment;

    final matchesBranch = normalizedBranchId.isEmpty ||
        normalizedBranchId == 'all' ||
        branchId == normalizedBranchId;

    return matchesSearch &&
        matchesRole &&
        matchesStatus &&
        matchesDepartment &&
        matchesBranch;
  }).toList();

  filtered.sort(
        (a, b) => _compareUsers(
      a: a,
      b: b,
      sortField: state.sortField,
      sortAscending: state.sortAscending,
    ),
  );

  return filtered;
}

List<String> extractDepartments(List<UserDoc> docs) {
  final departments = <String>{};

  for (final doc in docs) {
    final department = (doc.data()['department'] ?? '').toString().trim();
    if (department.isNotEmpty) {
      departments.add(department);
    }
  }

  final sortedDepartments = departments.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return sortedDepartments;
}

List<String> extractBranches(List<UserDoc> docs) {
  final branches = <String>{};

  for (final doc in docs) {
    final branchName = (doc.data()['branchName'] ?? '').toString().trim();
    if (branchName.isNotEmpty) {
      branches.add(branchName);
    }
  }

  final sortedBranches = branches.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return sortedBranches;
}

List<String> extractRoles(List<UserDoc> docs) {
  final roles = <String>{};

  for (final doc in docs) {
    final role = (doc.data()['role'] ?? '').toString().trim().toLowerCase();
    if (role.isNotEmpty) {
      roles.add(role);
    }
  }

  final sortedRoles = roles.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return sortedRoles;
}

int _compareUsers({
  required UserDoc a,
  required UserDoc b,
  required String sortField,
  required bool sortAscending,
}) {
  final aData = a.data();
  final bData = b.data();

  final dynamic aValue = _getSortValue(
    data: aData,
    sortField: sortField,
  );

  final dynamic bValue = _getSortValue(
    data: bData,
    sortField: sortField,
  );

  int result;

  if (aValue is num && bValue is num) {
    result = aValue.compareTo(bValue);
  } else {
    result = aValue.toString().compareTo(bValue.toString());
  }

  if (result == 0) {
    final fallbackA = _normalize(_readDisplayName(aData));
    final fallbackB = _normalize(_readDisplayName(bData));
    result = fallbackA.compareTo(fallbackB);
  }

  return sortAscending ? result : -result;
}

dynamic _getSortValue({
  required Map<String, dynamic> data,
  required String sortField,
}) {
  switch (sortField) {
    case 'name':
    case 'displayName':
      return _normalize(_readDisplayName(data));

    case 'email':
      return _normalize(data['email']);

    case 'phone':
      return _normalize(data['phone']);

    case 'role':
      return _normalize(data['role']);

    case 'department':
      return _normalize(data['department']);

    case 'designation':
      return _normalize(data['designation']);

    case 'employeeCode':
      return _normalize(data['employeeCode']);

    case 'branchName':
      return _normalize(data['branchName']);

    case 'reportingManagerName':
      return _normalize(data['reportingManagerName']);

    case 'status':
      return _readNormalizedStatus(data);

    case 'lastLoginAt':
      return _timestampToEpoch(data['lastLoginAt']);

    case 'updatedAt':
      return _timestampToEpoch(data['updatedAt']);

    case 'createdAt':
    default:
      return _timestampToEpoch(data['createdAt']);
  }
}

String _mapSortFieldForBackend(String sortField) {
  switch (sortField) {
    case 'name':
    case 'displayName':
      return 'displayName';
    case 'email':
      return 'email';
    case 'role':
      return 'role';
    case 'department':
      return 'department';
    case 'status':
      return 'status';
    case 'lastLoginAt':
      return 'lastLoginAt';
    case 'updatedAt':
      return 'updatedAt';
    case 'createdAt':
    default:
      return 'createdAt';
  }
}

bool? _mapStatusToIsActive(String normalizedStatus) {
  if (normalizedStatus == 'active') return true;
  if (normalizedStatus == 'inactive') return false;
  return null;
}

String _readDisplayName(Map<String, dynamic> data) {
  final displayName = (data['displayName'] ?? '').toString().trim();
  if (displayName.isNotEmpty) return displayName;
  return (data['name'] ?? '').toString().trim();
}

String _readNormalizedStatus(Map<String, dynamic> data) {
  final storedStatus = _normalize(data['status']);
  if (storedStatus.isNotEmpty) return storedStatus;

  return _normalize(
    statusLabel(
      isActive: (data['isActive'] ?? true) == true,
      isDeleted: (data['isDeleted'] ?? false) == true,
    ),
  );
}

int _timestampToEpoch(dynamic value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }
  return 0;
}

String _normalize(dynamic value) {
  return (value ?? '').toString().trim().toLowerCase();
}