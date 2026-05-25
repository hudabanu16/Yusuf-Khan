import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:QUIK/models/customer.dart';
import 'package:QUIK/modules/crm/customers/screens_add_customer.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_timeline.dart';
import 'package:QUIK/modules/crm/contacts/screens_add_contact.dart';
import 'package:QUIK/modules/crm/contacts/screens_contact_list.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

bool _safeBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  if (value is int) return value == 1;
  return false;
}

String _safeString(dynamic value) {
  return (value ?? '').toString().trim();
}

List<dynamic> _safeList(dynamic value) {
  if (value is List) return value;
  return <dynamic>[];
}

Map<String, dynamic> _safeMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return <String, dynamic>{};
}

DateTime? _safeDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, dynamic>? _extractPrimaryAddress(List<dynamic>? addresses) {
  if (addresses == null || addresses.isEmpty) return null;
  for (var a in addresses) {
    if (a is Map && _safeBool(a['isPrimary'])) {
      return _safeMap(a);
    }
  }
  final first = addresses.first;
  return first is Map ? _safeMap(first) : null;
}

// ==========================================
// CUSTOMER 360 ENTERPRISE WORKSPACE
// ==========================================

class ScreensCustomer360 extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;
  final String companyId;
  final String? currentUserRole;
  final String? currentUserName;

  const ScreensCustomer360({
    super.key,
    required this.customerRef,
    required this.companyId,
    this.currentUserRole,
    this.currentUserName,
  });

  @override
  State<ScreensCustomer360> createState() => _ScreensCustomer360State();
}

class _ScreensCustomer360State extends State<ScreensCustomer360> {
  // CRITICAL ARCHITECTURE FIX: GlobalKey prevents NestedScrollView from
  // destroying the parent scroll state during StreamBuilder ticks.
  final GlobalKey<NestedScrollViewState> _nestedScrollKey = GlobalKey<NestedScrollViewState>();

  void _notImplemented(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature module coming in future update.'),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _editCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddCustomer(
          companyId: widget.companyId,
          existingDoc: widget.customerRef,
          currentUserUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          currentUserRole: widget.currentUserRole ?? 'user',
        ),
      ),
    );
  }

  void _addContact() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddContact(companyRef: widget.customerRef),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL ARCHITECTURE FIX: DefaultTabController OUTSIDE the stream guarantees
    // tab state is preserved regardless of real-time Firestore updates.
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Builder(
              builder: (context) {
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: widget.customerRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading customer: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                        child: Text(
                          'Customer record not found or deleted.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      );
                    }

                    final data = snapshot.data!.data() ?? {};
                    final rawCompanyName = _safeString(data['companyName']);
                    final rawName = _safeString(data['name']);
                    final companyName = rawCompanyName.isNotEmpty
                        ? rawCompanyName
                        : (rawName.isNotEmpty ? rawName : 'Unnamed Customer');

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: NestedScrollView(
                          key: _nestedScrollKey,
                          headerSliverBuilder: (context, innerBoxIsScrolled) => [
                            SliverToBoxAdapter(child: _buildEnterpriseHeader(companyName, data, context)),
                            SliverToBoxAdapter(child: _buildQuickActionBar(context)),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickyTabBarDelegate(
                                height: 52.0,
                                child: Container(
                                  color: Colors.white,
                                  child: const Column(
                                    children: [
                                      Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                                      Expanded(
                                        child: TabBar(
                                          isScrollable: true,
                                          labelColor: Color(0xFF2563EB),
                                          unselectedLabelColor: Color(0xFF64748B),
                                          indicatorColor: Color(0xFF2563EB),
                                          indicatorWeight: 3,
                                          labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                          tabs: [
                                            Tab(text: 'Overview'),
                                            Tab(text: 'Activity Timeline'),
                                            Tab(text: 'Contacts'),
                                            Tab(text: 'Locations & Sites'),
                                            Tab(text: 'Documents'),
                                            Tab(text: 'Analytics'),
                                          ],
                                        ),
                                      ),
                                      Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          body: TabBarView(
                            children: [
                              // PageStorageKeys preserve independent scroll positions perfectly without conflict
                              _OverviewTab(
                                key: const PageStorageKey('tab_overview'),
                                data: data,
                              ),
                              ScreensCustomerTimeline(
                                key: const PageStorageKey('tab_timeline'),
                                customerRef: widget.customerRef,
                                companyId: widget.companyId,
                                currentUserUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                                currentUserName: widget.currentUserName ?? 'System User',
                                customerName: companyName,
                              ),
                              ScreensContactList(
                                key: const PageStorageKey('tab_contacts'),
                                companyRef: widget.customerRef,
                                companyName: companyName,
                              ),
                              _AddressesTab(
                                key: const PageStorageKey('tab_addresses'),
                                data: data,
                              ),
                              _EmptyStatePanel(
                                key: const PageStorageKey('tab_documents'),
                                icon: Icons.folder_copy_outlined,
                                title: 'Document Store',
                                message: 'Upload and manage customer files, contracts, and attachments.',
                                ctaLabel: 'Upload Document',
                                onCta: () => _notImplemented('Documents'),
                              ),
                              _EmptyStatePanel(
                                key: const PageStorageKey('tab_analytics'),
                                icon: Icons.analytics_outlined,
                                title: 'Sales Analytics',
                                message: 'Conversion rates, quotation history, and revenue trends.',
                                ctaLabel: 'Configure Dashboards',
                                onCta: () => _notImplemented('Analytics'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
          ),
        ),
      ),
    );
  }

  // --- REGION: HEADER ---

  Widget _buildEnterpriseHeader(String companyName, Map<String, dynamic> data, BuildContext context) {
    final customerCode = _safeString(data['customerCode']);
    final status = _safeString(data['status']).isNotEmpty ? _safeString(data['status']) : 'Active';
    final priority = _safeString(data['priority']).isNotEmpty ? _safeString(data['priority']) : 'Medium';
    final stage = _safeString(data['customerStage']).isNotEmpty ? _safeString(data['customerStage']) : 'Lead';
    final assignedUser = _safeString(data['assignedToName']).isNotEmpty ? _safeString(data['assignedToName']) : 'Unassigned';

    final nextFollowUp = _safeDate(data['nextFollowUpDate']);
    final lastFollowUp = _safeDate(data['lastFollowUpAt']);
    final now = DateTime.now();

    String healthStatus = 'Healthy';
    Color healthColor = const Color(0xFF10B981);
    IconData healthIcon = Icons.check_circle_outline;

    if (nextFollowUp != null && nextFollowUp.isBefore(DateTime(now.year, now.month, now.day))) {
      healthStatus = 'At Risk (Overdue)';
      healthColor = const Color(0xFFEF4444);
      healthIcon = Icons.warning_amber_rounded;
    } else if (lastFollowUp != null && now.difference(lastFollowUp).inDays > 60) {
      healthStatus = 'Inactive / Stale';
      healthColor = const Color(0xFF64748B);
      healthIcon = Icons.snooze;
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 750;

          final headerTop = Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'Customer 360 Workspace',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

          final avatar = Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
            ),
            child: Center(
              child: Text(
                companyName.isNotEmpty ? companyName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
              ),
            ),
          );

          final titleAndBadges = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customerCode.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _MiniChip(label: customerCode, background: const Color(0xFFF1F5F9), foreground: const Color(0xFF475569)),
                ),
              Text(
                companyName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Badge(label: status, color: const Color(0xFFECFDF5), textColor: const Color(0xFF059669), icon: Icons.verified_outlined),
                  _Badge(label: stage, color: const Color(0xFFEFF6FF), textColor: const Color(0xFF1D4ED8), icon: Icons.trending_up),
                  _Badge(label: priority, color: const Color(0xFFFFF7ED), textColor: const Color(0xFFC2410C), icon: Icons.flag_outlined),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: healthColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: healthColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(healthIcon, size: 14, color: healthColor),
                        const SizedBox(width: 4),
                        Text(healthStatus, style: TextStyle(color: healthColor, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );

          final actionButtons = Column(
            crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _editCustomer,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              const SizedBox(height: 12),
              // CRITICAL FIX: Safe Flexible layout preventing RenderFlex Unbounded Width crashes
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_ind_outlined, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Assigned to: $assignedUser',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              headerTop,
              const SizedBox(height: 16),
              if (isMobile) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: 16),
                    Expanded(child: titleAndBadges),
                  ],
                ),
                const SizedBox(height: 20),
                actionButtons,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: 20),
                    Expanded(child: titleAndBadges),
                    const SizedBox(width: 20),
                    actionButtons,
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // --- REGION: QUICK ACTIONS ---

  Widget _buildQuickActionBar(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ElevatedButton.icon(
            onPressed: () => DefaultTabController.of(context).animateTo(1),
            icon: const Icon(Icons.add_task, size: 18),
            label: const Text('Log Activity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _addContact,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Add Contact'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _notImplemented('Quotations'),
            icon: const Icon(Icons.request_quote_outlined, size: 18),
            label: const Text('Create Quote'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _notImplemented('Inquiries'),
            icon: const Icon(Icons.support_agent_outlined, size: 18),
            label: const Text('New Inquiry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _notImplemented('Service'),
            icon: const Icon(Icons.build_outlined, size: 18),
            label: const Text('Service Visit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// OVERVIEW TAB (THE DASHBOARD)
// ==========================================

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OverviewTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Pure ListView matches the NestedScrollView body scroll mechanics without conflict
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSmartSummaryPanel(),
        const SizedBox(height: 24),
        _buildKPIGrid(context),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildBusinessDetailsCard()),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPrimaryContactCard(),
                        const SizedBox(height: 24),
                        _buildPrimaryLocationCard(),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBusinessDetailsCard(),
                const SizedBox(height: 24),
                _buildPrimaryContactCard(),
                const SizedBox(height: 24),
                _buildPrimaryLocationCard(),
              ],
            );
          },
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildSmartSummaryPanel() {
    final nextDate = _safeDate(data['nextFollowUpDate']);
    final nextAction = _safeString(data['nextFollowUpSummary']).isNotEmpty
        ? _safeString(data['nextFollowUpSummary'])
        : 'Scheduled Follow-up';
    final now = DateTime.now();

    if (nextDate == null) {
      return const _AlertPanel(
        color: Color(0xFFF1F5F9),
        icon: Icons.event_available,
        iconColor: Color(0xFF64748B),
        title: 'No Upcoming Actions',
        subtitle: 'No future activities are scheduled for this customer.',
      );
    }

    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(nextDate.year, nextDate.month, nextDate.day);

    if (target.isBefore(today)) {
      return _AlertPanel(
        color: const Color(0xFFFEF2F2),
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFDC2626),
        title: 'Overdue Action: $nextAction',
        subtitle: 'Was due on ${DateFormat('MMM dd, yyyy').format(nextDate)}. Requires immediate attention.',
      );
    } else if (target.isAtSameMomentAs(today)) {
      return _AlertPanel(
        color: const Color(0xFFFFFBEB),
        icon: Icons.bolt,
        iconColor: const Color(0xFFD97706),
        title: 'Due Today: $nextAction',
        subtitle: 'Scheduled for today.',
      );
    } else {
      return _AlertPanel(
        color: const Color(0xFFF0FDF4),
        icon: Icons.schedule,
        iconColor: const Color(0xFF059669),
        title: 'Upcoming: $nextAction',
        subtitle: 'Scheduled for ${DateFormat('MMM dd, yyyy').format(nextDate)}.',
      );
    }
  }

  Widget _buildKPIGrid(BuildContext context) {
    final followUpCount = data['followUpCount'] ?? 0;
    final contactsCount = data['contactsCount'] ?? 0;
    final openQuotes = data['openQuotationsCount'] ?? 0;
    final openInquiries = data['openInquiriesCount'] ?? 0;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final crossAxisCount = width > 1000 ? 4 : (width > 600 ? 2 : 1);
      final spacing = 16.0;
      final itemWidth = ((width - (spacing * (crossAxisCount - 1))) / crossAxisCount) - 1.0;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          SizedBox(
              width: itemWidth,
              child: _KPICard(title: 'Total Engagements', value: '$followUpCount', icon: Icons.timeline, color: const Color(0xFF2563EB))
          ),
          SizedBox(
              width: itemWidth,
              child: _KPICard(title: 'Total Contacts', value: '$contactsCount', icon: Icons.people_outline, color: const Color(0xFF8B5CF6))
          ),
          SizedBox(
              width: itemWidth,
              child: _KPICard(title: 'Open Quotations', value: '$openQuotes', icon: Icons.request_quote_outlined, color: const Color(0xFF10B981))
          ),
          SizedBox(
              width: itemWidth,
              child: _KPICard(title: 'Active Inquiries', value: '$openInquiries', icon: Icons.support_agent_outlined, color: const Color(0xFFF59E0B))
          ),
        ],
      );
    });
  }

  Widget _buildBusinessDetailsCard() {
    final industry = _safeString(data['industry']);
    final email = _safeString(data['businessEmail'].toString().isEmpty ? data['email'] : data['businessEmail']);
    final phone = _safeString(data['companyPhone'].toString().isEmpty ? data['phone'] : data['companyPhone']);
    final website = _safeString(data['website']);
    final taxId = _safeString(data['taxId']);

    return _SectionCard(
      title: 'Business Details',
      icon: Icons.domain,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DetailRow(label: 'Industry Sector', value: industry.isEmpty ? '-' : industry),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          _DetailRow(label: 'Corporate Phone', value: phone.isEmpty ? '-' : phone),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          _DetailRow(label: 'Corporate Email', value: email.isEmpty ? '-' : email),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          _DetailRow(label: 'Website', value: website.isEmpty ? '-' : website),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          _DetailRow(label: 'Tax / GST ID', value: taxId.isEmpty ? '-' : taxId),
        ],
      ),
    );
  }

  Widget _buildPrimaryContactCard() {
    final contactName = _safeString(data['primaryContactName']);
    final contactPhone = _safeString(data['primaryContactPhone']);
    final contactEmail = _safeString(data['primaryContactEmail']);

    if (contactName.isEmpty) {
      return const _SectionCard(
        title: 'Primary Contact',
        icon: Icons.person_pin_outlined,
        child: Text(
          'No primary contact assigned. Go to the Contacts tab to add one.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      );
    }

    return _SectionCard(
      title: 'Primary Contact',
      icon: Icons.person_pin_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEFF6FF),
            radius: 24,
            child: Text(
              contactName[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(contactName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)), softWrap: true),
                const SizedBox(height: 4),
                if (contactPhone.isNotEmpty) Text(contactPhone, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)), softWrap: true),
                if (contactEmail.isNotEmpty) Text(contactEmail, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)), softWrap: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryLocationCard() {
    final addresses = _safeList(data['addresses']);
    final primaryAddr = _extractPrimaryAddress(addresses);

    if (primaryAddr == null) {
      return const _SectionCard(
        title: 'Primary Location',
        icon: Icons.location_city_outlined,
        child: Text(
          'No primary address added. Go to Locations tab to add one.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      );
    }

    final street = _safeString(primaryAddr['street']);
    final city = _safeString(primaryAddr['city']);
    final state = _safeString(primaryAddr['state']);
    final zip = _safeString(primaryAddr['zip']);

    return _SectionCard(
      title: 'Primary Location',
      icon: Icons.location_city_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(street, style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500), softWrap: true),
                const SizedBox(height: 4),
                Text('$city, $state $zip', style: const TextStyle(fontSize: 13, color: Color(0xFF475569)), softWrap: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ADDRESSES TAB
// ==========================================

class _AddressesTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AddressesTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final addresses = _safeList(data['addresses']);

    if (addresses.isEmpty) {
      return _EmptyStatePanel(
        icon: Icons.add_location_alt_outlined,
        title: 'No Locations Configured',
        message: 'Add factories, corporate offices, and billing addresses for this customer.',
        ctaLabel: 'Add Address',
        onCta: () {},
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final a = _safeMap(addresses[index]);
        final type = _safeString(a['type']).isNotEmpty ? _safeString(a['type']) : 'Office';
        final isPrimary = _safeBool(a['isPrimary']);
        final street = _safeString(a['street']);
        final city = _safeString(a['city']);
        final state = _safeString(a['state']);
        final zip = _safeString(a['zip']);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isPrimary ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.business_outlined, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(type, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                        if (isPrimary)
                          const _MiniChip(label: 'Primary Address', background: Color(0xFFEFF6FF), foreground: Color(0xFF1D4ED8)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(street, style: const TextStyle(fontSize: 14, color: Color(0xFF334155)), softWrap: true),
                    const SizedBox(height: 4),
                    Text('$city, $state $zip', style: const TextStyle(fontSize: 14, color: Color(0xFF475569)), softWrap: true),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                onSelected: (_) {},
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit Address')),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// REUSABLE UI COMPONENTS
// ==========================================

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyTabBarDelegate({
    required this.child,
    this.height = 52.0,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  const _Badge({required this.label, required this.color, required this.textColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: textColor), const SizedBox(width: 6)],
          // CRITICAL FIX: Safe bounding box prevents Unbounded Width RenderFlex crashes inside Wraps
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  const _MiniChip({required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          label,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500), softWrap: true),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600), softWrap: true),
        ),
      ],
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KPICard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

class _AlertPanel extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _AlertPanel({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: iconColor), softWrap: true),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: iconColor.withOpacity(0.8), fontWeight: FontWeight.w500), softWrap: true),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _EmptyStatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onCta;

  const _EmptyStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            padding: const EdgeInsets.all(40),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 24),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), textAlign: TextAlign.center, softWrap: true),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5), softWrap: true),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(ctaLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}