import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_service_request_screen.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

String _safeString(dynamic val) {
  return (val ?? '').toString().trim();
}

DateTime? _extractDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _timeAgo(DateTime? d) {
  if (d == null) return '-';
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

String _formatAnyTimestamp(dynamic value) {
  final dt = _extractDate(value);
  if (dt == null) return '-';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/$year $hour:$minute $amPm';
}

// ==========================================
// MAIN SCREEN
// ==========================================

class ServiceRequestListScreen extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserName;

  const ServiceRequestListScreen({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserName,
  });

  @override
  State<ServiceRequestListScreen> createState() => _ServiceRequestListScreenState();
}

class _ServiceRequestListScreenState extends State<ServiceRequestListScreen> {
  // --- CORE UI STATE ---
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // --- FILTERS STATE ---
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedPriority = 'All';

  final List<String> _statuses = ['All', 'New', 'In Progress', 'Resolved', 'Closed'];
  final List<String> _priorities = ['All', 'Low', 'Medium', 'High', 'Critical'];

  // --- PREFERENCES & ENTERPRISE STATE ---
  bool _isTableView = false;
  final Set<String> _selectedRequestIds = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- PREFERENCES PERSISTENCE ---
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isTableView = prefs.getBool('erp_service_view_preference') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isTableView = !_isTableView);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('erp_service_view_preference', _isTableView);
    } catch (_) {}
  }

  // --- DATA FETCHING & FILTERING ---
  Stream<QuerySnapshot<Map<String, dynamic>>> _getRequestsStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('service_requests')
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {

    final filtered = docs.where((doc) {
      final data = doc.data();

      if (data['isDeleted'] == true) return false;

      final status = data['status'] ?? '';
      final priority = data['priority'] ?? '';

      final matchesStatus = _selectedStatus == 'All' || status == _selectedStatus;
      final matchesPriority = _selectedPriority == 'All' || priority == _selectedPriority;

      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final keywords = List<String>.from(data['searchKeywords'] ?? []);
        final searchTerms = _searchQuery.toLowerCase().trim().split(RegExp(r'\s+'));
        matchesSearch = searchTerms.every((term) => keywords.any((k) => k.contains(term)));
      }

      return matchesStatus && matchesPriority && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _extractDate(a.data()['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _extractDate(b.data()['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Map<String, int> _calculateStats(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int total = 0;
    int open = 0;
    int highPriority = 0;
    int resolved = 0;

    for (var doc in docs) {
      final data = doc.data();
      if (data['isDeleted'] == true) continue;

      total++;
      final status = data['status'] ?? '';
      final priority = data['priority'] ?? '';

      if (status != 'Resolved' && status != 'Closed') open++;
      if (priority == 'High' || priority == 'Critical') highPriority++;
      if (status == 'Resolved') resolved++;
    }

    return {
      'Total': total,
      'Open': open,
      'High Priority': highPriority,
      'Resolved': resolved,
    };
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedRequestIds.contains(id)) {
        _selectedRequestIds.remove(id);
      } else {
        _selectedRequestIds.add(id);
      }
    });
  }

  bool get _hasActiveFilters {
    return _selectedStatus != 'All' || _selectedPriority != 'All';
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = 'All';
      _selectedPriority = 'All';
    });
  }

  // --- ACTIONS ---
  Future<void> _deleteRequest(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request?'),
        content: const Text('Are you sure you want to delete this service request? This will safely hide it from all views.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('service_requests')
            .doc(docId)
            .update({
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedByUid': widget.currentUserUid,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showDetailsDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['requestNumber'] ?? 'Details', style: TextStyle(fontSize: 14, color: Colors.blue.shade700, fontWeight: FontWeight.w800)),
                Text(_safeString(data['customerName']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            _buildStatusChip(data['status'] ?? 'Unknown'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailSection('Customer Information', {
                  'Contact Person': data['contactPerson'],
                  'Mobile': data['mobileNumber'],
                  'Email': data['email'],
                }),
                const Divider(height: 24),
                _buildDetailSection('Machine Information', {
                  'Model': data['machineModel'],
                  'Serial': data['serialNumber'],
                  'Warranty': (data['isWarranty'] ?? false) ? 'Yes' : 'No',
                }),
                const Divider(height: 24),
                _buildDetailSection('Complaint Information', {
                  'Category': data['complaintCategory'],
                  'Priority': data['priority'],
                  'Source': data['source'],
                  'Description': data['complaintDescription'],
                  'Remarks': data['remarks'],
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, Map<String, dynamic> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 12),
        ...fields.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map(
                (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 140, child: Text('${e.key}:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500))),
                  Expanded(child: Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                ],
              ),
            )
        ),
      ],
    );
  }

  // --- FILTERS SHEET ---
  Future<void> _openFilterSheet() async {
    String tempStatus = _selectedStatus;
    String tempPriority = _selectedPriority;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: tempStatus,
                  decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                  items: _statuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (value) => tempStatus = value ?? 'All',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempPriority,
                  decoration: const InputDecoration(labelText: 'Priority', isDense: true, border: OutlineInputBorder()),
                  items: _priorities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (value) => tempPriority = value ?? 'All',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _resetFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatus = tempStatus;
                            _selectedPriority = tempPriority;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New Request',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
          companyId: widget.companyId,
          currentUserUid: widget.currentUserUid,
          currentUserName: widget.currentUserName,
        ))),
        child: const Icon(Icons.add),
      ),
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final isWaiting = snapshot.connectionState == ConnectionState.waiting;
          final allDocs = snapshot.data?.docs ?? [];
          final filteredDocs = _applyFilters(allDocs);
          final stats = _calculateStats(allDocs);

          return Column(
            children: [
              // ENTERPRISE HEADER
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
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search request, customer, machine...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.trim().isEmpty ? null : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      width: 38,
                      child: Material(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _openFilterSheet,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.tune_rounded, size: 18, color: Colors.grey.shade800),
                              if (_hasActiveFilters)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_rows_rounded, size: 20),
                      tooltip: _isTableView ? 'Switch to List View' : 'Switch to Table View',
                      onPressed: _toggleViewMode,
                      color: Colors.grey.shade700,
                    ),
                    const Spacer(),
                    if (!isWaiting) ...[
                      _MiniStatText(label: 'Total', value: stats['Total'].toString()),
                      const SizedBox(width: 10),
                      _MiniStatText(label: 'Open', value: stats['Open'].toString()),
                      const SizedBox(width: 10),
                      _MiniStatText(label: 'Resolved', value: stats['Resolved'].toString()),
                    ],
                  ],
                ),
              ),
              if (_hasActiveFilters)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('Filters applied', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500))),
                      TextButton(onPressed: _resetFilters, child: const Text('Clear')),
                    ],
                  ),
                ),
              const Divider(height: 1, thickness: 1),

              // MAIN CONTENT
              Expanded(
                child: isWaiting
                    ? _buildSkeletonLoader()
                    : filteredDocs.isEmpty
                    ? _EmptyRequestsState(
                  hasSearch: _searchQuery.trim().isNotEmpty || _hasActiveFilters,
                  onReset: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    _resetFilters();
                  },
                )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final forceCardView = constraints.maxWidth < 1100;
                    final effectiveTableView = forceCardView ? false : _isTableView;
                    return effectiveTableView ? _buildTableView(filteredDocs) : _buildListView(filteredDocs);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutSine,
        tween: Tween(begin: 0.3, end: 0.7),
        builder: (context, opacity, child) {
          return Opacity(
            opacity: opacity,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(height: 40, width: 40, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 16, width: 150, color: Colors.grey.shade200),
                          const SizedBox(height: 6),
                          Container(height: 12, width: 100, color: Colors.grey.shade200),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 250, color: Colors.grey.shade200),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildRequestCard(docs[index]);
      },
    );
  }

  Widget _buildTableView(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
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
                    SizedBox(width: 40),
                    SizedBox(width: 250, child: Text('Request No / Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 180, child: Text('Contact Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 160, child: Text('Category / Machine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 130, child: Text('Priority & Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 130, child: Text('Assigned To', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 100, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 60, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                  ],
                ),
              ),
              ...docs.map((doc) => _buildRequestTableRow(doc)),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final requestNo = _safeString(data['requestNumber']);
    final customerName = _safeString(data['customerName']);
    final machineModel = _safeString(data['machineModel']);
    final status = _safeString(data['status']);
    final priority = _safeString(data['priority']);
    final category = _safeString(data['complaintCategory']);
    final isWarranty = data['isWarranty'] == true;

    final mobile = _safeString(data['mobileNumber']);
    final email = _safeString(data['email']);
    final assignedToName = _safeString(data['assignedToName']);
    final createdAt = _extractDate(data['createdAt']);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showDetailsDialog(data),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _selectedRequestIds.contains(doc.id) ? Colors.blue.shade300 : Colors.grey.shade200,
            width: _selectedRequestIds.contains(doc.id) ? 1.5 : 0.8,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _selectedRequestIds.contains(doc.id),
                        onChanged: (v) => _toggleSelection(doc.id),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.indigo.shade50,
                    child: Text(
                      customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.indigo.shade800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (requestNo.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.indigo.shade100),
                                  ),
                                  child: Text(
                                    requestNo,
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.indigo.shade800, letterSpacing: 0.3),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                customerName.isNotEmpty ? customerName : '(Unknown Customer)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        if (machineModel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(machineModel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (val) {
                      if (val == 'view') _showDetailsDialog(data);
                      if (val == 'edit') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
                          companyId: widget.companyId,
                          currentUserUid: widget.currentUserUid,
                          currentUserName: widget.currentUserName,
                          existingDocId: doc.id,
                          existingData: data,
                        )));
                      }
                      if (val == 'delete') _deleteRequest(doc.id);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'view', child: Text('View Details')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit Request')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Request', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (status.isNotEmpty) _buildStatusChip(status),
                  if (priority.isNotEmpty) _buildPriorityChip(priority),
                  if (category.isNotEmpty) _InfoChip(label: category, backgroundColor: Colors.purple.shade50, textColor: Colors.purple.shade800),
                  if (isWarranty) _InfoChip(label: 'Under Warranty', backgroundColor: Colors.teal.shade50, textColor: Colors.teal.shade800),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _InlineInfo(icon: Icons.phone_outlined, text: mobile.isEmpty ? '-' : mobile),
                  if (email.isNotEmpty) _InlineInfo(icon: Icons.email_outlined, text: email),
                  _InlineInfo(icon: Icons.assignment_ind_outlined, text: assignedToName.isEmpty ? 'Unassigned' : assignedToName),
                  _InlineInfo(icon: Icons.calendar_today_outlined, text: _formatAnyTimestamp(createdAt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestTableRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final requestNo = _safeString(data['requestNumber']);
    final customerName = _safeString(data['customerName']);
    final contactPerson = _safeString(data['contactPerson']);
    final mobile = _safeString(data['mobileNumber']);
    final category = _safeString(data['complaintCategory']);
    final machineModel = _safeString(data['machineModel']);
    final status = _safeString(data['status']);
    final priority = _safeString(data['priority']);
    final assignedToName = _safeString(data['assignedToName']);
    final createdAt = _extractDate(data['createdAt']);

    return InkWell(
      onTap: () => _showDetailsDialog(data),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(value: _selectedRequestIds.contains(doc.id), onChanged: (v) => _toggleSelection(doc.id)),
            ),
            SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customerName.isNotEmpty ? customerName : '(Unknown)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (requestNo.isNotEmpty) Text(requestNo, style: TextStyle(fontSize: 11, color: Colors.indigo.shade700, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contactPerson.isNotEmpty ? contactPerson : '-', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(mobile, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.isNotEmpty ? category : '-', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(machineModel, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(status),
                  const SizedBox(height: 4),
                  _buildPriorityChip(priority),
                ],
              ),
            ),
            SizedBox(width: 130, child: Text(assignedToName.isNotEmpty ? assignedToName : 'Unassigned', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(width: 100, child: Text(_timeAgo(createdAt), style: const TextStyle(fontSize: 13))),
            SizedBox(
                width: 60,
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  tooltip: 'Actions',
                  onSelected: (val) {
                    if (val == 'view') _showDetailsDialog(data);
                    if (val == 'edit') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceRequestScreen(
                        companyId: widget.companyId,
                        currentUserUid: widget.currentUserUid,
                        currentUserName: widget.currentUserName,
                        existingDocId: doc.id,
                        existingData: data,
                      )));
                    }
                    if (val == 'delete') _deleteRequest(doc.id);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'view', child: Text('View Details')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit Request')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Request', style: TextStyle(color: Colors.red))),
                  ],
                )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg; Color fg;
    switch (status) {
      case 'New': bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'In Progress': bg = Colors.orange.shade50; fg = Colors.orange.shade800; break;
      case 'Resolved': bg = Colors.green.shade50; fg = Colors.green.shade800; break;
      case 'Closed': bg = Colors.grey.shade200; fg = Colors.grey.shade800; break;
      default: bg = Colors.blueGrey.shade50; fg = Colors.blueGrey.shade800;
    }
    return _InfoChip(label: status, backgroundColor: bg, textColor: fg);
  }

  Widget _buildPriorityChip(String priority) {
    Color bg; Color fg;
    switch (priority) {
      case 'Critical': bg = Colors.red.shade50; fg = Colors.red.shade800; break;
      case 'High': bg = Colors.orange.shade50; fg = Colors.orange.shade800; break;
      case 'Medium': bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'Low': bg = Colors.grey.shade100; fg = Colors.grey.shade800; break;
      default: bg = Colors.grey.shade100; fg = Colors.grey.shade800;
    }
    return _InfoChip(label: priority, backgroundColor: bg, textColor: fg);
  }
}

// ==========================================
// SHARED ENTERPRISE UI COMPONENTS
// ==========================================

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStatText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600));
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  const _InfoChip({required this.label, required this.backgroundColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}

class _EmptyRequestsState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;
  const _EmptyRequestsState({required this.hasSearch, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: IntrinsicHeight(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(
                        hasSearch ? Icons.search_off : Icons.support_agent_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch ? 'No matching service requests found' : 'No service requests found',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSearch ? 'Try changing the search text or filter.' : 'Click the button below to create your first service request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    if (hasSearch) OutlinedButton(onPressed: onReset, child: const Text('Reset Filters')),
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