import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:QUIK/modules/finance/proforma_invoice/proforma_screen.dart';
import 'package:QUIK/modules/finance/proforma_invoice/proforma_invoice_pdf_generator.dart';

class ProformaListScreen extends StatefulWidget {
  final String companyId;

  const ProformaListScreen({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  @override
  State<ProformaListScreen> createState() => _ProformaListScreenState();
}

class _ProformaListScreenState extends State<ProformaListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _statusFilter = 'All';
  String _sortOption = 'Date: Newest';
  bool _isLoading = false;

  final Map<String, String> _userNamesCache = {};

  final List<String> _statuses = [
    'All',
    'Draft',
    'Sent',
    'Approved',
    'Converted',
    'Cancelled',
    'Rejected',
  ];

  final List<String> _sortOptions = [
    'Date: Newest',
    'Date: Oldest',
    'Amount: High to Low',
    'Amount: Low to High',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // HELPER FUNCTIONS & FORMATTING
  // ==========================================

  String _formatCompactDate(DateTime? date) {
    if (date == null) return '-';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'All' || _sortOption != 'Date: Newest';

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _sortOption = 'Date: Newest';
    });
  }

  void _showLoading(bool show) {
    if (mounted) {
      setState(() => _isLoading = show);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmAction(String title, String content,
      {String confirmText = 'Confirm', bool isDestructive = false}) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ??
        false;
  }

  // ==========================================
  // USER NAME CACHING LOGIC
  // ==========================================

  String _getCreatorName(Map<String, dynamic> data) {
    final String createdByName = (data['createdByName'] ?? '').toString().trim();
    if (createdByName.isNotEmpty) return createdByName;

    final String uid = (data['createdBy'] ?? '').toString().trim();
    if (uid.isEmpty) return 'Unknown';

    if (_userNamesCache.containsKey(uid)) {
      return _userNamesCache[uid]!;
    }

    _fetchAndCacheUserName(uid);
    return 'Fetching...';
  }

  Future<void> _fetchAndCacheUserName(String uid) async {
    _userNamesCache[uid] = 'Fetching...';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final name = (doc.data()!['name'] ?? doc.data()!['fullName'] ?? 'Unknown').toString().trim();
        if (mounted) {
          setState(() {
            _userNamesCache[uid] = name.isNotEmpty ? name : 'Unknown';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userNamesCache[uid] = 'Unknown';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userNamesCache[uid] = 'Unknown';
        });
      }
    }
  }

  // ==========================================
  // PROFORMA ACTION LOGIC (ENTERPRISE GRADE)
  // ==========================================

  Future<void> _updateStatus(String docId, String newStatus,
      {bool setApprovedAt = false}) async {
    try {
      _showLoading(true);
      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (setApprovedAt) {
        updates['approvedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .doc(docId)
          .update(updates);

      _showSnack('Proforma marked as $newStatus');
    } catch (e) {
      _showSnack('Error updating status: $e', isError: true);
    } finally {
      _showLoading(false);
    }
  }

  Future<void> _deleteProforma(String docId) async {
    try {
      _showLoading(true);
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .doc(docId)
          .update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnack('Proforma invoice deleted');
    } catch (e) {
      _showSnack('Error deleting: $e', isError: true);
    } finally {
      _showLoading(false);
    }
  }

  Future<void> _createRevision(String docId, Map<String, dynamic> data) async {
    try {
      _showLoading(true);
      final oldNumber = (data['proformaNumber'] ?? '').toString();

      String newNumber = oldNumber;
      if (oldNumber.contains('-R')) {
        final parts = oldNumber.split('-R');
        final base = parts[0];
        final revStr = parts[1];
        final revNum = int.tryParse(revStr) ?? 0;
        newNumber = '$base-R${revNum + 1}';
      } else if (oldNumber.isNotEmpty && oldNumber != 'Draft') {
        newNumber = '$oldNumber-R1';
      }

      final newData = Map<String, dynamic>.from(data);
      newData.remove('id');
      newData['proformaNumber'] = newNumber;
      newData['status'] = 'Draft';
      newData['referenceProformaId'] = docId;
      newData['createdAt'] = FieldValue.serverTimestamp();
      newData['updatedAt'] = FieldValue.serverTimestamp();
      newData.remove('approvedAt');
      newData.remove('invoiceId');

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .add(newData);

      _showSnack('Revision $newNumber created successfully');
    } catch (e) {
      _showSnack('Error creating revision: $e', isError: true);
    } finally {
      _showLoading(false);
    }
  }

  Future<void> _convertToInvoice(String docId, Map<String, dynamic> data) async {
    try {
      _showLoading(true);

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final invoiceRef = db
          .collection('companies')
          .doc(widget.companyId)
          .collection('invoices')
          .doc();

      final invoiceData = {
        'customerId': data['customerId'],
        'customerName': data['customerName'] ?? data['clientName'],
        'items': data['items'] ?? [],
        'grandTotal': data['grandTotal'] ?? data['totalAmount'] ?? 0,
        'taxAmount': data['taxAmount'] ?? 0,
        'subTotal': data['subTotal'] ?? 0,
        'status': 'Draft',
        'proformaId': docId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': data['createdBy'],
        'createdByName': data['createdByName'],
        'isDeleted': false,
      };

      batch.set(invoiceRef, invoiceData);

      final proformaRef = db
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .doc(docId);

      batch.update(proformaRef, {
        'status': 'Converted',
        'invoiceId': invoiceRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _showSnack('Successfully converted to Invoice');
    } catch (e) {
      _showSnack('Error converting to invoice: $e', isError: true);
    } finally {
      _showLoading(false);
    }
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  Future<void> _openFilterSheet() async {
    String tempStatus = _statusFilter;
    String tempSort = _sortOption;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters & Sort',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: tempStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _statuses
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempStatus = value ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: tempSort,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _sortOptions
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempSort = value ?? 'Date: Newest';
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'All';
                                _sortOption = 'Date: Newest';
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = tempStatus;
                                _sortOption = tempSort;
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
      },
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final search = _searchText.trim().toLowerCase();

    var filtered = docs.where((doc) {
      final data = doc.data();

      final piNumber = (data['proformaNumber'] ?? '').toString().toLowerCase();
      final customer = (data['customerName'] ?? data['clientName'] ?? '')
          .toString()
          .toLowerCase();
      final status = (data['status'] ?? 'Draft').toString();
      final isDeleted = data['isDeleted'] == true;

      final matchesSearch = search.isEmpty ||
          piNumber.contains(search) ||
          customer.contains(search);
      final matchesStatus = _statusFilter == 'All' ||
          status.toLowerCase() == _statusFilter.toLowerCase();

      return !isDeleted && matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      if (_sortOption.startsWith('Amount')) {
        final amtA = double.tryParse(
            (dataA['grandTotal'] ?? dataA['totalAmount'] ?? 0).toString()) ??
            0;
        final amtB = double.tryParse(
            (dataB['grandTotal'] ?? dataB['totalAmount'] ?? 0).toString()) ??
            0;
        return _sortOption.contains('High')
            ? amtB.compareTo(amtA)
            : amtA.compareTo(amtB);
      } else {
        final dateA = (dataA['createdAt'] as Timestamp?)?.toDate() ??
            DateTime(2000);
        final dateB = (dataB['createdAt'] as Timestamp?)?.toDate() ??
            DateTime(2000);
        return _sortOption.contains('Newest')
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            toolbarHeight: 6,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Create Proforma Invoice',
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProformaScreen(companyId: widget.companyId),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('companies')
                .doc(widget.companyId)
                .collection('proforma_invoices')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading proforma invoices:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data?.docs.toList() ?? [];
              final filteredDocs = _applyLocalFilters(allDocs);

              int total = filteredDocs.length;
              int draft = 0;
              int sent = 0;
              int approved = 0;

              for (final doc in filteredDocs) {
                final status =
                (doc.data()['status'] ?? '').toString().toLowerCase();
                if (status == 'draft') draft++;
                if (status == 'sent') sent++;
                if (status == 'approved') approved++;
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchText = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search customer, number...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: _searchText.trim().isEmpty
                                    ? null
                                    : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close, size: 17),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchText = '';
                                    });
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
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: Colors.grey.shade800,
                                  ),
                                  if (_hasActiveFilters)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade700,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        _MiniStatText(label: 'Total', value: total.toString()),
                        const SizedBox(width: 10),
                        _MiniStatText(label: 'Draft', value: draft.toString()),
                        const SizedBox(width: 10),
                        _MiniStatText(label: 'Sent', value: sent.toString()),
                        const SizedBox(width: 10),
                        _MiniStatText(
                            label: 'Approved', value: approved.toString()),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filters applied',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _resetFilters,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? _EmptyProformaState(
                      hasSearch: _searchText.trim().isNotEmpty ||
                          _hasActiveFilters,
                      onReset: () {
                        _searchController.clear();
                        setState(() {
                          _searchText = '';
                        });
                        _resetFilters();
                      },
                    )
                        : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();

                        final rawPINo =
                        (data['proformaNumber'] ?? '').toString().trim();
                        final proformaNo =
                        rawPINo.isEmpty ? 'Draft' : rawPINo;

                        final status =
                        (data['status'] ?? 'Draft').toString();
                        final customerName = (data['customerName'] ??
                            data['clientName'] ??
                            'Unknown Customer')
                            .toString();

                        final createdByName = _getCreatorName(data);

                        String referenceRef = '';
                        final refNumber = (data['referenceNumber'] ?? '').toString().trim();
                        final qtNumber = (data['quotationNumber'] ?? '').toString().trim();
                        final inqNumber = (data['inquiryNumber'] ?? '').toString().trim();

                        if (refNumber.isNotEmpty) {
                          referenceRef = refNumber;
                        } else if (qtNumber.isNotEmpty) {
                          referenceRef = qtNumber;
                        } else if (inqNumber.isNotEmpty) {
                          referenceRef = inqNumber;
                        }

                        final displayReference = referenceRef.isNotEmpty ? '# $referenceRef' : '';

                        final grandTotal = double.tryParse(
                            (data['grandTotal'] ??
                                data['totalAmount'] ??
                                0)
                                .toString()) ??
                            0.0;
                        final amountStr =
                            '₹ ${grandTotal.toStringAsFixed(2)}';

                        DateTime? createdAt;
                        if (data['createdAt'] is Timestamp) {
                          createdAt =
                              (data['createdAt'] as Timestamp).toDate();
                        }

                        DateTime? nextFollowUp;
                        if (data['nextFollowUpDate'] is Timestamp) {
                          nextFollowUp =
                              (data['nextFollowUpDate'] as Timestamp)
                                  .toDate();
                        }

                        final statLw = status.toLowerCase();

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 0.8,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.blue.shade50,
                                      child: Text(
                                        customerName.isNotEmpty
                                            ? customerName[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            proformaNo,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            customerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Actions',
                                        icon: Icon(Icons.more_vert,
                                            size: 20,
                                            color: Colors.grey.shade600),
                                        onSelected: (value) async {
                                          switch (value) {
                                            case 'edit':
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ProformaScreen(
                                                    companyId: widget.companyId,
                                                    proformaId: doc.id,
                                                  ),
                                                ),
                                              );
                                              break;
                                            case 'view_pdf':
                                              final previewData = Map<String, dynamic>.from(data);
                                              previewData['id'] = doc.id;

                                              // Safely parse the dynamic items into the strictly typed List<ProformaLocalItem> required by the preview screen
                                              List<ProformaLocalItem> parsedItems = [];
                                              if (previewData['items'] != null && previewData['items'] is List) {
                                                try {
                                                  parsedItems = (previewData['items'] as List).map((e) {
                                                    return ProformaLocalItem.fromMap(Map<String, dynamic>.from(e as Map));
                                                  }).toList();
                                                } catch (_) {
                                                  // Silent catch to prevent crash if mapping fails
                                                }
                                              }

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ProformaPreviewScreen(
                                                    data: previewData,
                                                    items: parsedItems,
                                                  ),
                                                ),
                                              );
                                              break;
                                            case 'approve':
                                              final confirm = await _confirmAction('Approve Proforma', 'Are you sure you want to approve this proforma invoice?');
                                              if (confirm) await _updateStatus(doc.id, 'Approved', setApprovedAt: true);
                                              break;
                                            case 'reject':
                                              final confirm = await _confirmAction('Reject Proforma', 'Are you sure you want to reject this proforma invoice?');
                                              if (confirm) await _updateStatus(doc.id, 'Rejected');
                                              break;
                                            case 'cancel':
                                              final confirm = await _confirmAction('Cancel Proforma', 'Are you sure you want to cancel this proforma invoice?');
                                              if (confirm) await _updateStatus(doc.id, 'Cancelled');
                                              break;
                                            case 'revise':
                                              final confirm = await _confirmAction('Create Revision', 'Are you sure you want to create a new revision from this proforma?');
                                              if (confirm) await _createRevision(doc.id, data);
                                              break;
                                            case 'convert':
                                              final confirm = await _confirmAction('Convert to Invoice', 'Are you sure you want to convert this Proforma into a final Tax Invoice?');
                                              if (confirm) await _convertToInvoice(doc.id, data);
                                              break;
                                            case 'delete':
                                              final confirm = await _confirmAction('Delete Proforma', 'Are you sure you want to delete this proforma invoice?', confirmText: 'Delete', isDestructive: true);
                                              if (confirm) await _deleteProforma(doc.id);
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) {
                                          final List<PopupMenuEntry<String>> menuItems = [];

                                          // Dynamic View / Edit Option
                                          if (statLw == 'draft' || statLw == 'rejected') {
                                            menuItems.add(const PopupMenuItem(value: 'edit', child: Text('Edit')));
                                          } else if (statLw == 'sent') {
                                            menuItems.add(const PopupMenuItem(value: 'edit', child: Text('View / Edit')));
                                          } else if (statLw == 'approved' || statLw == 'converted' || statLw == 'cancelled') {
                                            menuItems.add(const PopupMenuItem(value: 'view_pdf', child: Text('View')));
                                          } else {
                                            menuItems.add(const PopupMenuItem(value: 'edit', child: Text('View / Edit')));
                                          }

                                          // Action Options
                                          if (statLw == 'draft' || statLw == 'sent') {
                                            menuItems.add(const PopupMenuItem(value: 'approve', child: Text('Approve')));
                                            menuItems.add(const PopupMenuItem(value: 'reject', child: Text('Reject')));
                                          }

                                          if (statLw != 'cancelled' && statLw != 'converted') {
                                            menuItems.add(const PopupMenuItem(value: 'cancel', child: Text('Cancel')));
                                          }

                                          menuItems.add(const PopupMenuItem(value: 'revise', child: Text('Create Revision')));

                                          if (statLw != 'converted' && statLw != 'cancelled' && statLw != 'rejected') {
                                            menuItems.add(const PopupMenuItem(value: 'convert', child: Text('Convert to Invoice')));
                                          }

                                          // Delete Option
                                          menuItems.add(const PopupMenuDivider());
                                          menuItems.add(const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete', style: TextStyle(color: Colors.red))));

                                          return menuItems;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _InfoChip(
                                      label: status,
                                      backgroundColor: _statusBg(status),
                                      textColor: _statusFg(status),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  crossAxisAlignment:
                                  WrapCrossAlignment.center,
                                  children: [
                                    if (displayReference.isNotEmpty)
                                      _InlineInfo(
                                        icon: Icons.tag_outlined,
                                        text: displayReference,
                                      ),
                                    _InlineInfo(
                                      icon: Icons.person_outline,
                                      text: createdByName,
                                    ),
                                    _InlineInfo(
                                      icon: Icons.currency_rupee_outlined,
                                      text: amountStr,
                                    ),
                                    _InlineInfo(
                                      icon: Icons.add_circle_outline,
                                      text:
                                      'Created: ${_formatCompactDate(createdAt)}',
                                    ),
                                    if (nextFollowUp != null)
                                      _InlineInfo(
                                        icon: Icons.event_repeat_outlined,
                                        text:
                                        'Next: ${_formatCompactDate(nextFollowUp)}',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // GLOBAL LOADING OVERLAY
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            ),
          ),
      ],
    );
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
    );
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
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
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
        borderRadius: BorderRadius.circular(999),
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

class _EmptyProformaState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyProformaState({required this.hasSearch, required this.onReset});

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
                        hasSearch
                            ? Icons.search_off
                            : Icons.request_quote_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch
                          ? 'No matching proforma invoices found'
                          : 'No proforma invoices found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSearch
                          ? 'Try changing the search text or filter.'
                          : 'Click the button above to create your first proforma invoice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (hasSearch)
                      OutlinedButton(
                        onPressed: onReset,
                        child: const Text('Reset Filters'),
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

Color _statusBg(String status) {
  switch (status.toLowerCase()) {
    case 'draft':
      return Colors.orange.shade50;
    case 'sent':
    case 'viewed':
      return Colors.blue.shade50;
    case 'approved':
    case 'converted':
      return Colors.green.shade50;
    case 'rejected':
    case 'cancelled':
      return Colors.red.shade50;
    default:
      return Colors.grey.shade100;
  }
}

Color _statusFg(String status) {
  switch (status.toLowerCase()) {
    case 'draft':
      return Colors.orange.shade800;
    case 'sent':
    case 'viewed':
      return Colors.blue.shade800;
    case 'approved':
    case 'converted':
      return Colors.green.shade800;
    case 'rejected':
    case 'cancelled':
      return Colors.red.shade800;
    default:
      return Colors.grey.shade800;
  }
}