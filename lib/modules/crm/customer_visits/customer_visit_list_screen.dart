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
  String _searchQuery = '';
  String _statusFilter = 'All';

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  // Direct Firestore stream since getVisits is not in the service layer
  Stream<List<CustomerVisitModel>> _getVisitsStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('customer_visits')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CustomerVisitModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Direct soft-delete since deleteVisit is not in the service layer
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Customer Visits', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Log Visit'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerVisitScreen(
                    companyId: widget.companyId,
                    currentUserId: widget.currentUserId,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: StreamBuilder<List<CustomerVisitModel>>(
              stream: _getVisitsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                var visits = snapshot.data ?? [];

                // Client-side filtering
                if (_searchQuery.isNotEmpty) {
                  final sq = _searchQuery.toLowerCase();
                  visits = visits.where((v) =>
                  v.customerName.toLowerCase().contains(sq) ||
                      v.visitNumber.toLowerCase().contains(sq) ||
                      v.purpose.toLowerCase().contains(sq)
                  ).toList();
                }
                if (_statusFilter != 'All') {
                  visits = visits.where((v) => v.status == _statusFilter).toList();
                }

                if (visits.isEmpty) {
                  return const Center(child: Text('No visit records found.'));
                }

                return isDesktop ? _buildDesktopTable(visits) : _buildMobileList(visits);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer, visit no, or purpose...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              items: ['All', 'Draft', 'In Progress', 'Completed', 'Cancelled']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _statusFilter = val ?? 'All'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<CustomerVisitModel> visits) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.1)),
          columns: const [
            DataColumn(label: Text('Visit No', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Purpose', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Outcome', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Follow-up', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: visits.map((visit) {
            return DataRow(
              cells: [
                DataCell(Text(visit.visitNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(visit.visitDate != null ? _dateFormat.format(visit.visitDate!) : '-')),
                DataCell(Text(visit.customerName)),
                DataCell(Text(visit.contactPerson.isNotEmpty ? visit.contactPerson : '-')),
                DataCell(Text(visit.purpose)),
                DataCell(Text(visit.outcome.isNotEmpty ? visit.outcome : '-')),
                DataCell(Text(visit.followupDate != null ? _dateFormat.format(visit.followupDate!) : '-')),
                DataCell(_buildStatusBadge(visit.status)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                      tooltip: 'Edit Visit',
                      onPressed: () => _openVisitScreen(visit),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      tooltip: 'Delete Visit',
                      onPressed: () => _confirmDelete(visit),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<CustomerVisitModel> visits) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: visits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final visit = visits[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(visit.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('No: ${visit.visitNumber} | Date: ${visit.visitDate != null ? _dateFormat.format(visit.visitDate!) : '-'}'),
                const SizedBox(height: 4),
                Text('Purpose: ${visit.purpose}'),
                if (visit.outcome.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Outcome: ${visit.outcome}', style: TextStyle(color: Colors.grey.shade700)),
                ],
                const SizedBox(height: 8),
                _buildStatusBadge(visit.status),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openVisitScreen(visit),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Completed': color = Colors.green; break;
      case 'In Progress': color = Colors.orange; break;
      case 'Cancelled': color = Colors.red; break;
      default: color = Colors.blue; // Draft or other
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _openVisitScreen(CustomerVisitModel visit) {
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
        content: const Text('Are you sure you want to delete this customer visit record? This action will remove it from the timeline.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _deleteVisit(visit.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit deleted successfully'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}