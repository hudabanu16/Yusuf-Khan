import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'customer_visit_model.dart';
import 'customer_visit_screen.dart';

class CustomerVisitListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserId;
  final String currentUserRole;

  const CustomerVisitListScreen({
    Key? key,
    required this.companyId,
    required this.currentUserId,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  State<CustomerVisitListScreen> createState() => _CustomerVisitListScreenState();
}

class _CustomerVisitListScreenState extends State<CustomerVisitListScreen> {
  // --- STATE ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  // FIX 1: Stream must be held in state so it doesn't rebuild on every keystroke
  late Stream<List<CustomerVisitModel>> _visitsStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- BUSINESS LOGIC (FIXED FOR SAFETY & SCALABILITY) ---
  void _initStream() {
    _visitsStream = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('customer_visits')
    // FIX 2: Removed .where('isDeleted') to bypass missing index / missing field issues.
    // It is safely handled in local memory below.
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('--- VISIT LIST TRACE ---');
      debugPrint('1. Stream emitted. Docs received from Firestore: ${snapshot.docs.length}');

      final list = <CustomerVisitModel>[];
      for (var doc in snapshot.docs) {
        try {
          // FIX 3: Try-Catch prevents one corrupt record from crashing the entire list
          list.add(CustomerVisitModel.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('⚠️ Error parsing visit ${doc.id}: $e');
        }
      }
      debugPrint('2. Successfully parsed into models: ${list.length}');
      return list;
    });
  }

  Future<void> _deleteVisit(String visitId) async {
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('customer_visits')
        .doc(visitId)
        .update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': widget.currentUserId,
    });
  }

  // --- ACTIONS ---
  void _openVisitScreen(CustomerVisitModel? visit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerVisitScreen(
          companyId: widget.companyId,
          currentUserId: widget.currentUserId,
          visit: visit,
        ),
      ),
    );
  }

  void _confirmDelete(CustomerVisitModel visit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Visit Activity'),
        content: const Text(
            'Are you sure you want to delete this customer visit record? This action will remove it from the timeline.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _deleteVisit(visit.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Visit deleted successfully'),
                      backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- UI RENDERING ---
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6, // Match customer list shell header avoidance
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Log Visit',
        onPressed: () => _openVisitScreen(null),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // COMPACT HEADER MATCHING CUSTOMER LIST
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search customer, visit no, or purpose...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.trim().isEmpty
                            ? null
                            : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close, size: 17),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 38,
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _statusFilter,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: ['All', 'Draft', 'In Progress', 'Completed', 'Cancelled']
                        .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) => setState(() => _statusFilter = val ?? 'All'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // MAIN CONTENT
          Expanded(
            child: StreamBuilder<List<CustomerVisitModel>>(
              stream: _visitsStream, // Using the persistently stored stream
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSkeletonLoader();
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)));
                }

                var visits = snapshot.data ?? [];

                debugPrint('3. Processing ${visits.length} valid records in UI');

                // FIX 4: Safely exclude logically deleted documents
                visits = visits.where((v) => !v.isDeleted).toList();

                // Client-side filtering (Null-safe)
                if (_searchQuery.isNotEmpty) {
                  final sq = _searchQuery.toLowerCase();
                  visits = visits.where((v) {
                    final cName = (v.customerName).toLowerCase();
                    final vNum = (v.visitNumber).toLowerCase();
                    final purp = (v.purpose).toLowerCase();
                    return cName.contains(sq) || vNum.contains(sq) || purp.contains(sq);
                  }).toList();
                }

                if (_statusFilter != 'All') {
                  visits = visits.where((v) => v.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
                }

                debugPrint('4. Final rendered count after UI filters: ${visits.length}');

                if (visits.isEmpty) {
                  return _EmptyVisitsState(
                    hasSearch: _searchQuery.trim().isNotEmpty || _statusFilter != 'All',
                    onReset: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _statusFilter = 'All';
                      });
                    },
                    onLogVisit: () => _openVisitScreen(null),
                  );
                }

                return isDesktop ? _buildDesktopTable(visits) : _buildMobileList(visits);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutSine,
        tween: Tween(begin: 0.3, end: 0.7),
        builder: (context, opacity, child) {
          return Opacity(
            opacity: opacity,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(height: 40, width: 40, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(height: 14, width: 150, color: Colors.grey.shade200),
                        const SizedBox(height: 8),
                        Container(height: 12, width: 100, color: Colors.grey.shade200),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MOBILE LIST VIEW (ENTERPRISE STYLE) ---
  Widget _buildMobileList(List<CustomerVisitModel> visits) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), // Bottom padding for FAB
      itemCount: visits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final visit = visits[index];
        final initial = visit.customerName.isNotEmpty ? visit.customerName[0].toUpperCase() : '?';

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openVisitScreen(visit),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  visit.visitNumber,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  visit.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            visit.contactPerson.isNotEmpty ? visit.contactPerson : 'No Contact Info',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
                      onSelected: (value) {
                        if (value == 'edit') _openVisitScreen(visit);
                        if (value == 'delete') _confirmDelete(visit);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit / View Visit')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'delete', child: Text('Delete Visit', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      label: visit.status,
                      backgroundColor: _statusBg(visit.status),
                      textColor: _statusFg(visit.status),
                    ),
                    _InfoChip(
                      label: visit.purpose,
                      backgroundColor: Colors.purple.shade50,
                      textColor: Colors.purple.shade800,
                    ),
                    if (visit.outcome.isNotEmpty)
                      _InfoChip(
                        label: visit.outcome,
                        backgroundColor: Colors.teal.shade50,
                        textColor: Colors.teal.shade800,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _InlineInfo(
                      icon: Icons.calendar_today,
                      text: visit.visitDate != null ? _dateFormat.format(visit.visitDate!) : '-',
                    ),
                    if (visit.followupDate != null)
                      _InlineInfo(
                        icon: Icons.event_repeat_outlined,
                        text: 'Follow-up: ${_dateFormat.format(visit.followupDate!)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DESKTOP TABLE VIEW (ENTERPRISE STYLE) ---
  Widget _buildDesktopTable(List<CustomerVisitModel> visits) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    SizedBox(width: 120, child: Text('Visit No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 100, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 220, child: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 150, child: Text('Contact', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 150, child: Text('Purpose', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 150, child: Text('Outcome', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 100, child: Text('Follow-up', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 100, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 60, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                  ],
                ),
              ),
              ...visits.map((visit) {
                return InkWell(
                  onTap: () => _openVisitScreen(visit),
                  child: Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(visit.visitNumber, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade700)),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(visit.visitDate != null ? _dateFormat.format(visit.visitDate!) : '-', style: const TextStyle(fontSize: 13)),
                        ),
                        SizedBox(
                          width: 220,
                          child: Text(visit.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(visit.contactPerson.isNotEmpty ? visit.contactPerson : '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(visit.purpose, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(visit.outcome.isNotEmpty ? visit.outcome : '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(visit.followupDate != null ? _dateFormat.format(visit.followupDate!) : '-', style: const TextStyle(fontSize: 13)),
                        ),
                        SizedBox(
                          width: 100,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _InfoChip(
                              label: visit.status,
                              backgroundColor: _statusBg(visit.status),
                              textColor: _statusFg(visit.status),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 20),
                            tooltip: 'Actions',
                            onSelected: (val) {
                              if (val == 'edit') _openVisitScreen(visit);
                              if (val == 'delete') _confirmDelete(visit);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit / View Visit')),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: 'delete', child: Text('Delete Visit', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 90), // Bottom padding for FAB
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// REUSABLE UI COMPONENTS (MATCHING CRM STANDARD)
// ==========================================

class _InfoChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyVisitsState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;
  final VoidCallback onLogVisit;

  const _EmptyVisitsState({
    required this.hasSearch,
    required this.onReset,
    required this.onLogVisit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 40,
            ),
            child: IntrinsicHeight(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(
                        hasSearch ? Icons.search_off : Icons.assignment_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch
                          ? 'No matching visits found'
                          : 'No visit records found',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSearch
                          ? 'Try changing the search text or filter.'
                          : 'Click the button below to log your first customer visit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (hasSearch)
                      OutlinedButton(
                        onPressed: onReset,
                        child: const Text('Reset Filters'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: onLogVisit,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Log First Visit'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// STATUS COLOR SYSTEM
Color _statusBg(String status) {
  switch (status.toLowerCase()) {
    case 'completed': return Colors.green.shade50;
    case 'in progress': return Colors.orange.shade50;
    case 'cancelled': return Colors.red.shade50;
    default: return Colors.blue.shade50; // Draft
  }
}

Color _statusFg(String status) {
  switch (status.toLowerCase()) {
    case 'completed': return Colors.green.shade800;
    case 'in progress': return Colors.orange.shade800;
    case 'cancelled': return Colors.red.shade800;
    default: return Colors.blue.shade800; // Draft
  }
}