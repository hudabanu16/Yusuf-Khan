import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import 'record_payment_screen.dart';
import 'payment_detail_screen.dart';

class PaymentsListScreen extends StatefulWidget {
  final String companyId;
  final String userUid;

  const PaymentsListScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  final NumberFormat formatter = NumberFormat('#,##0.00', 'en_IN');
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _minAmtController = TextEditingController();
  final TextEditingController _maxAmtController = TextEditingController();

  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedMode = 'All';
  String _selectedStatus = 'All';
  String _selectedMonth = 'All';
  String _selectedYear = 'All';
  String _selectedUser = 'All';
  double? _minAmount;
  double? _maxAmount;

  final Set<String> _deletingIds = {};
  final bool isAdmin = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _minAmtController.dispose();
    _maxAmtController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Pagination load more hook
    }
  }

  String _getPaymentStatus(PaymentModel payment) {
    double advance = payment.advanceAmount;
    double allocated = payment.allocatedAmount;
    double total = payment.totalAmount;

    if (advance > 0 && allocated == 0) return 'ADVANCE';
    if (allocated >= total) return 'ALLOCATED';
    if (allocated > 0) return 'PARTIAL';
    return 'UNALLOCATED';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ADVANCE': return Colors.purple.shade600;
      case 'ALLOCATED': return Colors.green.shade600;
      case 'PARTIAL': return Colors.orange.shade600;
      case 'UNALLOCATED': return Colors.red.shade600;
      default: return Colors.grey.shade600;
    }
  }

  Future<void> _deletePayment(String paymentId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment?'),
        content: const Text('Are you sure you want to delete this payment record? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _deletingIds.add(paymentId));

    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('payments')
          .doc(paymentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(paymentId));
    }
  }

  void _openFilterSheet(List<PaymentModel> allDocs) {
    // Extract unique users dynamically for the filter dropdown
    final uniqueUsers = allDocs.map((p) => p.createdBy).where((uid) => uid.isNotEmpty).toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown('Month', _selectedMonth, ['All', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'], (val) => setModalState(() => _selectedMonth = val!)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFilterDropdown('Year', _selectedYear, ['All', '2023', '2024', '2025', '2026'], (val) => setModalState(() => _selectedYear = val!)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown('Mode', _selectedMode, ['All', 'Cash', 'Bank Transfer', 'Wire Transfer (TT)', 'Cheque', 'Credit Card', 'Letter of Credit', 'UPI'], (val) => setModalState(() => _selectedMode = val!)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFilterDropdown('Status', _selectedStatus, ['All', 'ADVANCE', 'ALLOCATED', 'PARTIAL', 'UNALLOCATED'], (val) => setModalState(() => _selectedStatus = val!)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Created By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedUser,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Users')),
                        ...uniqueUsers.map((uid) => DropdownMenuItem(value: uid, child: Text(uid)))
                      ],
                      onChanged: (val) => setModalState(() => _selectedUser = val!),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minAmtController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Min Amount (INR)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            onChanged: (v) => _minAmount = double.tryParse(v),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxAmtController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Max Amount (INR)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            onChanged: (v) => _maxAmount = double.tryParse(v),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedMode = 'All';
                                _selectedStatus = 'All';
                                _selectedMonth = 'All';
                                _selectedYear = 'All';
                                _selectedUser = 'All';
                                _startDate = null;
                                _endDate = null;
                                _minAmount = null;
                                _maxAmount = null;
                                _minAmtController.clear();
                                _maxAmtController.clear();
                              });
                              setState(() {});
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {});
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: items.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordPaymentScreen(
                companyId: widget.companyId,
                userUid: widget.userUid,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('companies')
              .doc(widget.companyId)
              .collection('payments')
              .orderBy('paymentDate', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            final docs = snapshot.data?.docs ?? [];
            final payments = docs.map((doc) => PaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

            if (payments.isEmpty && _searchQuery.isEmpty) return _buildEmptyState(context);

            final filteredPayments = payments.where((p) {
              final sq = _searchQuery.toLowerCase();
              final matchesSearch = sq.isEmpty ||
                  p.customerName.toLowerCase().contains(sq) ||
                  p.receiptNumber.toLowerCase().contains(sq) ||
                  (p.referenceNo.toLowerCase().contains(sq));

              final matchesMode = _selectedMode == 'All' || p.paymentMode == _selectedMode;
              final matchesStatus = _selectedStatus == 'All' || _getPaymentStatus(p) == _selectedStatus;
              final matchesMonth = _selectedMonth == 'All' || p.paymentDate.month.toString() == _selectedMonth;
              final matchesYear = _selectedYear == 'All' || p.paymentDate.year.toString() == _selectedYear;
              final matchesUser = _selectedUser == 'All' || p.createdBy == _selectedUser;
              final matchesMin = _minAmount == null || p.amountInr >= _minAmount!;
              final matchesMax = _maxAmount == null || p.amountInr <= _maxAmount!;

              bool matchesDate = true;
              if (_startDate != null && _endDate != null) {
                matchesDate = p.paymentDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
                    p.paymentDate.isBefore(_endDate!.add(const Duration(days: 1)));
              }

              return matchesSearch && matchesMode && matchesStatus && matchesMonth && matchesYear && matchesUser && matchesMin && matchesMax && matchesDate;
            }).toList();

            double totalReceived = 0.0;
            double totalAdvance = 0.0;
            double totalAllocated = 0.0;

            for (var payment in filteredPayments) {
              totalReceived += payment.amountInr;
              totalAdvance += payment.currency == 'INR' ? payment.advanceAmount : payment.advanceAmount * payment.exchangeRate;
              totalAllocated += payment.currency == 'INR' ? payment.allocatedAmount : payment.allocatedAmount * payment.exchangeRate;
            }

            return Column(
              children: [
                _buildCompactSummaryCard(totalReceived, totalAllocated, totalAdvance),
                _buildSearchBar(payments),
                Expanded(
                  child: filteredPayments.isEmpty
                      ? const Center(child: Text('No matching payments found.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)))
                      : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                    itemCount: filteredPayments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildPaymentCard(filteredPayments[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactSummaryCard(double totalReceived, double totalAllocated, double totalAdvance) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL RECEIVED (INR)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '₹ ${formatter.format(totalReceived)}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Text('ALLOCATED: ', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                  Text('₹ ${formatter.format(totalAllocated)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('ADVANCE: ', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                  Text('₹ ${formatter.format(totalAdvance)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(List<PaymentModel> allDocs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search customer, receipt, or ref...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => _openFilterSheet(allDocs),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
              ),
              child: Stack(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF1E293B), size: 22),
                  if (_selectedMode != 'All' || _selectedStatus != 'All' || _selectedMonth != 'All' || _selectedYear != 'All' || _selectedUser != 'All' || _minAmount != null || _maxAmount != null)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    final status = _getPaymentStatus(payment);
    final statusColor = _getStatusColor(status);
    final isDeleting = _deletingIds.contains(payment.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentDetailScreen(
                companyId: widget.companyId,
                payment: payment,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.account_balance_wallet, color: Colors.green.shade600, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(payment.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(payment.receiptNumber, style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Text('•', style: TextStyle(color: Colors.grey.shade400)),
                                  const SizedBox(width: 6),
                                  Text(DateFormat('dd MMM yyyy').format(payment.paymentDate), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                              if (payment.referenceNo.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('Ref: ${payment.referenceNo}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${payment.currency} ${formatter.format(payment.totalAmount)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      if (payment.currency != 'INR')
                        Text(
                          '≈ ₹ ${formatter.format(payment.amountInr)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.indigo.shade500),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: isDeleting
                        ? const Padding(padding: EdgeInsets.all(4.0), child: CircularProgressIndicator(strokeWidth: 2))
                        : PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text('View Detail')])),
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                        if (isAdmin) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecordPaymentScreen(
                                companyId: widget.companyId,
                                userUid: widget.userUid,
                                existingPayment: payment,
                              ),
                            ),
                          );
                        } else if (value == 'delete') {
                          _deletePayment(payment.id);
                        } else if (value == 'view') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentDetailScreen(companyId: widget.companyId, payment: payment),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserNameWidget(companyId: widget.companyId, uid: payment.createdBy, prefix: 'Created by: ', fallbackName: payment.createdByName),
                        Text('Created on: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  if (payment.updatedBy != null && payment.updatedBy!.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          UserNameWidget(companyId: widget.companyId, uid: payment.updatedBy!, prefix: 'Updated by: ', fallbackName: payment.updatedByName),
                          Text('Updated on: ${payment.updatedAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(payment.updatedAt!) : 'N/A'}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.blue.shade400),
          ),
          const SizedBox(height: 24),
          const Text('No Payments Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text('Record your first payment to track incoming revenue.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordPaymentScreen(
                    companyId: widget.companyId,
                    userUid: widget.userUid,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Record First Payment', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          )
        ],
      ),
    );
  }
}

// 🔴 DYNAMIC USER NAME CACHING
class UserNameWidget extends StatefulWidget {
  final String companyId;
  final String uid;
  final String prefix;
  final String? fallbackName;

  const UserNameWidget({Key? key, required this.companyId, required this.uid, required this.prefix, this.fallbackName}) : super(key: key);

  static final Map<String, String> _cache = {};

  @override
  State<UserNameWidget> createState() => _UserNameWidgetState();
}

class _UserNameWidgetState extends State<UserNameWidget> {
  String _displayName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchName();
  }

  Future<void> _fetchName() async {
    if (widget.uid.isEmpty) {
      if (mounted) setState(() => _displayName = 'System / Unknown');
      return;
    }

    if (UserNameWidget._cache.containsKey(widget.uid)) {
      if (mounted) setState(() => _displayName = UserNameWidget._cache[widget.uid]!);
      return;
    }

    if (widget.fallbackName != null && widget.fallbackName!.isNotEmpty && widget.fallbackName != 'Unknown User') {
      _displayName = widget.fallbackName!;
      UserNameWidget._cache[widget.uid] = _displayName;
      if (mounted) setState(() {});
      return;
    }

    try {
      var doc = await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('users').doc(widget.uid).get();
      if (doc.exists && doc.data()!.containsKey('name')) {
        _displayName = doc.data()!['name'];
        UserNameWidget._cache[widget.uid] = _displayName;
      } else {
        _displayName = 'Unknown User';
      }
    } catch (e) {
      _displayName = 'Unknown User';
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Text('${widget.prefix}$_displayName', style: TextStyle(fontSize: 10, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}