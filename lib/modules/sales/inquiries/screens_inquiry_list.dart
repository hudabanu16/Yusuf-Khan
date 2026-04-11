import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/models/inquiry_model.dart';
import 'package:QUIK/modules/sales/inquiries/screens_add_inquiry.dart';
import 'package:QUIK/modules/sales/inquiries/screens_inquiry_form.dart';
import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';

class ScreensInquiryList extends StatefulWidget {
  const ScreensInquiryList({super.key});

  @override
  State<ScreensInquiryList> createState() => _ScreensInquiryListState();
}

class _ScreensInquiryListState extends State<ScreensInquiryList> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadCurrentUserProfile(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  bool _isAdminOrManager(String role) {
    final r = role.trim().toLowerCase();
    return r == 'admin' || r == 'manager';
  }

  bool _hasInquiryPermission(Map<String, dynamic> userData) {
    final role = (userData['role'] ?? '').toString().trim().toLowerCase();

    if (_isAdminOrManager(role)) return true;

    final permissions = Map<String, dynamic>.from(userData['permissions'] ?? {});
    return permissions['inquiries'] == true;
    final firestore = FirebaseFirestore.instance;

    // 1. Fetch Global User
    final globalDoc = await firestore.collection('users').doc(uid).get();
    final globalData = globalDoc.data() ?? <String, dynamic>{};

    // 2. Safely extract dynamic companyId
    String companyId = (globalData['companyId'] ?? '').toString();
    if (companyId.isEmpty) {
      final companyIds = globalData['companyIds'];
      if (companyIds is List && companyIds.isNotEmpty) {
        companyId = companyIds.first.toString();
      } else {
        final memberships = globalData['memberships'];
        if (memberships is Map && memberships.isNotEmpty) {
          companyId = memberships.keys.first.toString();
        }
      }
    }

    if (companyId.isEmpty) return globalData;

    // 3. Fetch Company-Scoped User Document
    final companyUserDoc = await firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid)
        .get();

    final companyData = companyUserDoc.data() ?? <String, dynamic>{};

    // 4. Merge data
    return {
      ...globalData,
      ...companyData,
      'companyId': companyId,
    };
  }

  bool _isAdminOrManager(String role) {
    final r = role.toLowerCase().trim();
    return r == 'owner' ||
        r == 'founder' ||
        r == 'ceo' ||
        r == 'superadmin' ||
        r == 'admin' ||
        r == 'manager';
  }

  // 🔴 FIX 1: Make permission checker dynamic for view, create, edit, delete
  bool _hasInquiryPermission(Map<String, dynamic> userData, {String action = 'view'}) {
    final role = (userData['role'] ?? '').toString();
    if (_isAdminOrManager(role)) return true;

    final permissions = userData['permissions'];
    if (permissions is! Map) return false;

    // New nested structure check
    final sales = permissions['sales'];
    if (sales is Map) {
      final inquiries = sales['inquiries'];
      if (inquiries is Map && inquiries[action] == true) {
        return true;
      }
    }

    // Legacy fallback check
    if (permissions['inquiries'] == true && action == 'view') return true;
    if (permissions['inquiries'] is Map && permissions['inquiries'][action] == true) return true;

    return false;
  }

  String _safeString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _formatCompactDate(DateTime? date) {
    if (date == null) return '-';
    return _formatDate(date);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String role,
    required String currentUserUid,
  }) {
    final normalizedSearch = _searchText.trim().toLowerCase();
    final normalizedRole = role.trim().toLowerCase();

    final filtered = docs.where((doc) {
      final data = doc.data();

      bool matchesRole = true;

      if (!_isAdminOrManager(normalizedRole)) {
        final assignedToUid = (data['assignedToUid'] ?? '').toString().trim();
        final createdByUid = (data['createdByUid'] ?? data['createdBy'] ?? '')
            .toString()
            .trim();

        matchesRole =
            assignedToUid == currentUserUid || createdByUid == currentUserUid;
      }

      final inquiryCode = (data['inquiryCode'] ?? data['inquiryNumber'] ?? '')
          .toString()
          .toLowerCase();

      final customerCode =
          (data['customerCode'] ?? '').toString().toLowerCase();

      final customerName = (data['customerName'] ?? data['companyName'] ?? '')
          .toString()
          .toLowerCase();

      final subject = (data['subject'] ?? data['inquirySubject'] ?? '')
          .toString()
          .toLowerCase();

      final contactName = (data['contactName'] ?? data['contactPerson'] ?? '')
          .toString()
          .toLowerCase();

      final mobile = (data['contactMobile'] ??
              data['contactPhone'] ??
              data['mobile'] ??
              '')
          .toString()
          .toLowerCase();

      final projectName =
          (data['projectName'] ?? '').toString().toLowerCase();

      final source = (data['source'] ?? '').toString().toLowerCase();

      final requiredProducts =
          (data['requiredProducts'] ?? '').toString().toLowerCase();

      final status = (data['status'] ?? '').toString().trim();
      final priority = (data['priority'] ?? '').toString().trim();

      final matchesSearch = normalizedSearch.isEmpty ||
          inquiryCode.contains(normalizedSearch) ||
          customerCode.contains(normalizedSearch) ||
          customerName.contains(normalizedSearch) ||
          subject.contains(normalizedSearch) ||
          contactName.contains(normalizedSearch) ||
          mobile.contains(normalizedSearch) ||
          projectName.contains(normalizedSearch) ||
          source.contains(normalizedSearch) ||
          requiredProducts.contains(normalizedSearch);

      final matchesStatus = _statusFilter == 'All' || status == _statusFilter;
      final matchesPriority =
          _priorityFilter == 'All' || priority == _priorityFilter;

      return matchesRole && matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    filtered.sort((a, b) {
      final aTs = a.data()['createdAt'];
      final bTs = b.data()['createdAt'];

      final aDate = aTs is Timestamp ? aTs.toDate() : null;
      final bDate = bTs is Timestamp ? bTs.toDate() : null;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'hot':
        return const Color(0xFFDC2626);
      case 'warm':
        return const Color(0xFFD97706);
      case 'cold':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF2563EB);
      case 'qualified':
        return const Color(0xFF7C3AED);
      case 'quotation pending':
        return const Color(0xFFD97706);
      case 'quotation sent':
        return const Color(0xFF0F766E);
      case 'follow-up pending':
        return const Color(0xFFEA580C);
      case 'won':
        return const Color(0xFF16A34A);
      case 'lost':
        return const Color(0xFFDC2626);
      case 'not qualified':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color tone,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tone, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    final tone = selectedColor ?? const Color(0xFF2563EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? tone.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? tone : const Color(0xFFD9E1EC),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? tone : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaPill({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final tone = color ?? const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tone == const Color(0xFF6B7280)
                    ? const Color(0xFF374151)
                    : tone,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Inquiry inquiry,
    required String role,
    required String currentUserUid,
    required bool canEdit, // Pass edit permission to card
  }) {
    final assignedToUid = inquiry.assignedToUid;
    final createdByUid = inquiry.createdBy;

    final isAssignedToCurrentUser = assignedToUid == currentUserUid;
    final isCreatedByCurrentUser = createdByUid == currentUserUid;

    final priority = inquiry.priority.isEmpty ? 'Warm' : inquiry.priority;
    final status = inquiry.status.isEmpty ? 'Open' : inquiry.status;
    final subject = inquiry.subject;
    final inquiryNumber = inquiry.inquiryNumber;
    final source = inquiry.source;
    final inquiryType = inquiry.inquiryType;
    final location = inquiry.location;
    final quantityScope = inquiry.quantityScope;
    final expectedValue = inquiry.expectedValue;
    final assignedToName = inquiry.assignedToName;
    final channelRef = inquiry.sourceReference;
    final createdAtText =
    inquiry.createdAt == null ? '-' : _formatDate(inquiry.createdAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          // 🔴 FIX 2: Check if user can actually click into the record
          // They can enter if they have 'edit' permission OR if they are assigned to it
          if (!canEdit && !isAssignedToCurrentUser && !isCreatedByCurrentUser) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You do not have permission to open this record.')),
            );
            return;
          }

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScreensInquiryForm(
                existingDoc: doc.reference,
                existingInquiry: inquiry,
                currentUserId: currentUserUid,
              ),
            ),
          );

          if (result == true && mounted) {
            setState(() {});
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 760;

              final header = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.support_agent_outlined,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subject.isNotEmpty)
                          Text(
                            subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        if (subject.isNotEmpty) const SizedBox(height: 4),
                        Text(
                          inquiry.customerName.isEmpty
                              ? '(No Customer Name)'
                              : inquiry.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (inquiry.contactName.isNotEmpty)
                              _buildMetaPill(
                                icon: Icons.person_outline,
                                text: inquiry.contactName,
                              ),
                            if (inquiry.contactPhone.isNotEmpty)
                              _buildMetaPill(
                                icon: Icons.phone_outlined,
                                text: inquiry.contactPhone,
                              ),
                            if (source.isNotEmpty)
                              _buildMetaPill(
                                icon: Icons.hub_outlined,
                                text: source,
                              ),
                            if (inquiryType.isNotEmpty)
                              _buildMetaPill(
                                icon: Icons.category_outlined,
                                text: inquiryType,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMetaPill(
                        icon: Icons.flag_outlined,
                        text: status,
                        color: _statusColor(status),
                      ),
                      const SizedBox(height: 8),
                      _buildMetaPill(
                        icon: Icons.local_fire_department_outlined,
                        text: priority,
                        color: _priorityColor(priority),
                      ),
                    ],
                  ),
                ],
              );

              final details = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (inquiryNumber.isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.tag_outlined,
                      text: inquiryNumber,
                    ),
                  if (channelRef.isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.link_outlined,
                      text: channelRef,
                    ),
                  if (location.isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.location_on_outlined,
                      text: location,
                    ),
                  if (quantityScope.isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.numbers_outlined,
                      text: quantityScope,
                    ),
                  if (expectedValue.isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.currency_rupee_outlined,
                      text: expectedValue,
                    ),
                  if (inquiry.deliveryTimeline.isNotEmpty)
                    _buildMetaPill(
                      icon: Icons.local_shipping_outlined,
                      text: inquiry.deliveryTimeline,
                    ),
                ],
              );

              final footer = Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: isTight
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFooterLeft(
                      inquiry: inquiry,
                      assignedToUid: assignedToUid,
                      isAssignedToCurrentUser: isAssignedToCurrentUser,
                      isCreatedByCurrentUser: isCreatedByCurrentUser,
                      isAdminOrManager: _isAdminOrManager(role),
                      assignedToName: assignedToName,
                      createdAtText: createdAtText,
                    ),
                    const SizedBox(height: 10),
                    _buildFooterRight(inquiry),
                  ],
                )
                    : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildFooterLeft(
                        inquiry: inquiry,
                        assignedToUid: assignedToUid,
                        isAssignedToCurrentUser: isAssignedToCurrentUser,
                        isCreatedByCurrentUser: isCreatedByCurrentUser,
                        isAdminOrManager: _isAdminOrManager(role),
                        assignedToName: assignedToName,
                        createdAtText: createdAtText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildFooterRight(inquiry),
                  ],
                ),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  if (inquiry.requiredProducts.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      inquiry.requiredProducts,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  details,
                  footer,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLeft({
    required Inquiry inquiry,
    required String assignedToUid,
    required bool isAssignedToCurrentUser,
    required bool isCreatedByCurrentUser,
    required bool isAdminOrManager,
    required String assignedToName,
    required String createdAtText,
  }) {
    Color assignmentColor;
    String assignmentText;

    if (assignedToUid.isEmpty) {
      assignmentColor = Colors.red;
      assignmentText = 'Unassigned';
    } else if (isAssignedToCurrentUser) {
      assignmentColor = Colors.green;
      assignmentText = 'Assigned to you';
    } else if (assignedToName.isNotEmpty) {
      assignmentColor = const Color(0xFF2563EB);
      assignmentText = 'Assigned to $assignedToName';
    } else {
      assignmentColor = Colors.green;
      assignmentText = 'Assigned';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          assignmentText,
          style: TextStyle(
            fontSize: 12,
            color: assignmentColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (isCreatedByCurrentUser &&
            !isAssignedToCurrentUser &&
            !isAdminOrManager) ...[
          const SizedBox(height: 4),
          const Text(
            'Created by you',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Created: $createdAtText',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterRight(Inquiry inquiry) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        _buildMetaPill(
          icon: Icons.event_outlined,
          text: inquiry.nextFollowUpDate == null
              ? 'No follow-up'
              : 'Follow-up ${_formatCompactDate(inquiry.nextFollowUpDate)}',
          color: inquiry.nextFollowUpDate == null
              ? const Color(0xFF6B7280)
              : const Color(0xFF7C3AED),
        ),
        if (inquiry.linkedQuotationId.isNotEmpty)
          _buildMetaPill(
            icon: Icons.receipt_long_outlined,
            text: 'Quotation linked',
            color: const Color(0xFF0F766E),
          ),
      ],
    );
  }

  Future<void> _openEditInquiry({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Inquiry inquiry,
    required String currentUserUid,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensInquiryForm(
          existingDoc: doc.reference,
          existingInquiry: inquiry,
          currentUserId: currentUserUid,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openQuotationFromInquiry({
    required Inquiry inquiry,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(
          userId:
              (FirebaseAuth.instance.currentUser?.uid.hashCode ?? 0).abs() %
                  1000000,
        ),
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          inquiry.customerName.isEmpty
              ? 'Quotation screen opened'
              : 'Quotation screen opened for ${inquiry.customerName}',
        ),
      ),
    );
  }

  Widget _buildInquiryCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Inquiry inquiry,
    required String role,
    required String currentUserUid,
  }) {
    final assignedToUid = inquiry.assignedToUid;
    final createdByUid = inquiry.createdBy;

    final isAssignedToCurrentUser = assignedToUid == currentUserUid;
    final isCreatedByCurrentUser = createdByUid == currentUserUid;

    final priority = inquiry.priority.isEmpty ? 'Warm' : inquiry.priority;
    final status = inquiry.status.isEmpty ? 'Open' : inquiry.status;
    final subject = inquiry.subject;
    final inquiryNumber =
        inquiry.inquiryNumber.isEmpty ? '-' : inquiry.inquiryNumber;
    final source = inquiry.source;
    final inquiryType = inquiry.inquiryType;
    final location = inquiry.location;
    final quantityScope = inquiry.quantityScope;
    final expectedValue = inquiry.expectedValue;
    final assignedToName = inquiry.assignedToName;
    final channelRef = inquiry.sourceReference;
    final createdAtText =
        inquiry.createdAt == null ? '-' : _formatDate(inquiry.createdAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 760;

            final header = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.support_agent_outlined,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subject.isNotEmpty)
                        Text(
                          subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      if (subject.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        inquiry.customerName.isEmpty
                            ? '(No Customer Name)'
                            : inquiry.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (inquiry.contactName.isNotEmpty)
                            _buildMetaPill(
                              icon: Icons.person_outline,
                              text: inquiry.contactName,
                            ),
                          if (inquiry.contactPhone.isNotEmpty)
                            _buildMetaPill(
                              icon: Icons.phone_outlined,
                              text: inquiry.contactPhone,
                            ),
                          if (source.isNotEmpty)
                            _buildMetaPill(
                              icon: Icons.hub_outlined,
                              text: source,
                            ),
                          if (inquiryType.isNotEmpty)
                            _buildMetaPill(
                              icon: Icons.category_outlined,
                              text: inquiryType,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMetaPill(
                      icon: Icons.flag_outlined,
                      text: status,
                      color: _statusColor(status),
                    ),
                    const SizedBox(height: 8),
                    _buildMetaPill(
                      icon: Icons.local_fire_department_outlined,
                      text: priority,
                      color: _priorityColor(priority),
                    ),
                  ],
                ),
              ],
            );

            final details = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMetaPill(
                  icon: Icons.tag_outlined,
                  text: inquiryNumber,
                ),
                if (channelRef.isNotEmpty)
                  _buildMetaPill(
                    icon: Icons.link_outlined,
                    text: channelRef,
                  ),
                if (location.isNotEmpty)
                  _buildMetaPill(
                    icon: Icons.location_on_outlined,
                    text: location,
                  ),
                if (quantityScope.isNotEmpty)
                  _buildMetaPill(
                    icon: Icons.numbers_outlined,
                    text: quantityScope,
                  ),
                if (expectedValue.isNotEmpty)
                  _buildMetaPill(
                    icon: Icons.currency_rupee_outlined,
                    text: expectedValue,
                  ),
                if (inquiry.deliveryTimeline.isNotEmpty)
                  _buildMetaPill(
                    icon: Icons.local_shipping_outlined,
                    text: inquiry.deliveryTimeline,
                  ),
              ],
            );

            final footerLeft = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignedToUid.isEmpty
                      ? 'Unassigned'
                      : isAssignedToCurrentUser
                          ? 'Assigned to you'
                          : assignedToName.isNotEmpty
                              ? 'Assigned to $assignedToName'
                              : 'Assigned',
                  style: TextStyle(
                    fontSize: 12,
                    color: assignedToUid.isEmpty
                        ? Colors.red
                        : isAssignedToCurrentUser
                            ? Colors.green
                            : const Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isCreatedByCurrentUser && !isAssignedToCurrentUser) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Created by you',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Created: $createdAtText',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            );

            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditInquiry(
                    context: context,
                    doc: doc,
                    inquiry: inquiry,
                    currentUserUid: currentUserUid,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Open'),
                ),
                FilledButton.icon(
                  onPressed: () => _openQuotationFromInquiry(inquiry: inquiry),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Create Quotation'),
                ),
              ],
            );

            final footer = Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: isTight
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        footerLeft,
                        const SizedBox(height: 10),
                        _buildFooterRight(inquiry),
                        const SizedBox(height: 10),
                        actions,
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: footerLeft),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _buildFooterRight(inquiry),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: actions,
                        ),
                      ],
                    ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                if (inquiry.requiredProducts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    inquiry.requiredProducts,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                details,
                footer,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        runSpacing: 12,
        spacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Inquiries',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage leads, follow-ups, quotations and inquiry ownership in one place.',
                style: TextStyle(
                  color: Color(0xFFDCE7FF),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search customer, subject, contact, inquiry no...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchText = '';
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    const statuses = [
      'All',
      'Open',
      'Qualified',
      'Quotation Pending',
      'Quotation Sent',
      'Follow-up Pending',
      'Won',
      'Lost',
      'Not Qualified',
    ];

    const priorities = ['All', 'Hot', 'Warm', 'Cold'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses
                .map(
                  (e) => _buildFilterChip(
                    label: e,
                    selected: _statusFilter == e,
                    selectedColor:
                        e == 'All' ? const Color(0xFF2563EB) : _statusColor(e),
                    onTap: () {
                      setState(() => _statusFilter = e);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Priority',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: priorities
                .map(
                  (e) => _buildFilterChip(
                    label: e,
                    selected: _priorityFilter == e,
                    selectedColor: e == 'All'
                        ? const Color(0xFF2563EB)
                        : _priorityColor(e),
                    onTap: () {
                      setState(() => _priorityFilter = e);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int total = docs.length;
    int open = 0;
    int followUp = 0;
    int won = 0;
    int hot = 0;

    for (final doc in docs) {
      final inquiry = Inquiry.fromSnapshot(doc);
      final status = inquiry.status.toLowerCase();
      final priority = inquiry.priority.toLowerCase();

      if (status == 'open') open++;
      if (status == 'follow-up pending') followUp++;
      if (status == 'won') won++;
      if (priority == 'hot') hot++;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 760;

          final cards = [
            _buildSummaryCard(
              title: 'Total Inquiries',
              value: total.toString(),
              tone: const Color(0xFF2563EB),
              icon: Icons.inbox_outlined,
            ),
            _buildSummaryCard(
              title: 'Open',
              value: open.toString(),
              tone: const Color(0xFF2563EB),
              icon: Icons.folder_open_outlined,
            ),
            _buildSummaryCard(
              title: 'Follow-up Pending',
              value: followUp.toString(),
              tone: const Color(0xFFEA580C),
              icon: Icons.event_repeat_outlined,
            ),
            _buildSummaryCard(
              title: 'Won',
              value: won.toString(),
              tone: const Color(0xFF16A34A),
              icon: Icons.check_circle_outline,
            ),
            _buildSummaryCard(
              title: 'Hot Priority',
              value: hot.toString(),
              tone: const Color(0xFFDC2626),
              icon: Icons.local_fire_department_outlined,
            ),
          ];

          if (isMobile) {
            return Column(
              children: cards
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: e,
                    ),
                  )
                  .toList(),
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map(
                  (e) => SizedBox(
                    width: 220,
                    child: e,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 12),
            Text(
              'No inquiries found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try changing search or filters, or create a new inquiry using the + button.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadCurrentUserProfile(firebaseUser.uid),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inquiries')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading user profile:\n${userSnap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final userData = userSnap.data;
        if (userData == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inquiries')),
            body: const Center(
              child: Text('User profile not found'),
            ),
          );
        }

        final companyId = _safeString(userData['companyId']);
        final role = _safeString(userData['role']).isEmpty
            ? 'sales'
            : _safeString(userData['role']);

        if (companyId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inquiries')),
            body: const Center(
              child: Text('No company linked to this user'),
            ),
          );
        }

        // 1. Check if user can VIEW the page at all
        if (!_hasInquiryPermission(userData, action: 'view')) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inquiries')),
            body: const Center(
              child: Text('You do not have permission to view inquiries'),
            ),
          );
        }

        // 2. Check if user can CREATE new inquiries
        final bool canCreate = _hasInquiryPermission(userData, action: 'create');

        // 3. Check if user can EDIT existing inquiries
        final bool canEdit = _hasInquiryPermission(userData, action: 'edit');

        final inquiryRef = FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('inquiries');

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF111827),
            surfaceTintColor: Colors.white,
            title: const Text(
              'Inquiries',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),

          // 🔴 FIX 3: Conditionally render the Floating Action Button
          floatingActionButton: canCreate
              ? FloatingActionButton(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScreensAddInquiry(
                    companyId: companyId,
                    currentUserUid: firebaseUser.uid,
                    currentUserRole: role,
                  ),
                ),
              );

              if (result == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Inquiry added'),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {});
              }
            },
            child: const Icon(Icons.add),
          )
              : null, // Hides the button if they don't have 'create' permission

          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                inquiryRef.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error loading inquiries:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data?.docs.toList() ?? [];

              final docs = _applyLocalFilters(
                docs: allDocs,
                role: role,
                currentUserUid: firebaseUser.uid,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(),
                          _buildSummarySection(docs),
                          _buildFiltersRow(),
                          if (docs.isEmpty)
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.45,
                              child: _buildEmptyState(),
                            )
                          else
                            ListView.builder(
                              itemCount: docs.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final inquiry = Inquiry.fromSnapshot(doc);

                                return _buildInquiryCard(
                                  context: context,
                                  doc: doc,
                                  inquiry: inquiry,
                                  role: role,
                                  currentUserUid: firebaseUser.uid,
                                  canEdit: canEdit, // Pass 'edit' permission
                                );
                              },
                            ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}