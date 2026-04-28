import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';
import 'quotation_pdf_generator.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);

class ScreensQuotationList extends StatefulWidget {
  final int userId;

  const ScreensQuotationList({
    super.key,
    required this.userId,
  });

  @override
  State<ScreensQuotationList> createState() => _ScreensQuotationListState();
}

class _ScreensQuotationListState extends State<ScreensQuotationList> {
  final TextEditingController _searchController = TextEditingController();

  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'sales';
  String _currentUserName = '';
  bool _isLoadingContext = true;
  String? _errorMessage;

  String _searchText = '';
  String _statusFilter = 'All';
  String _sortOption = 'Date: Newest';

  final List<String> _statuses = [
    'All',
    'Draft',
    'Sent',
    'Viewed',
    'Follow-up',
    'Negotiation',
    'Approved',
    'Rejected',
    'Converted',
    'Cancelled'
  ];

  final List<String> _sortOptions = [
    'Date: Newest',
    'Date: Oldest',
    'Amount: High to Low',
    'Amount: Low to High'
  ];

  Query<Map<String, dynamic>>? _primaryQuery;
  CollectionReference<Map<String, dynamic>>? _quotationCollection;

  bool get _isAdminOrManager {
    final role = _currentUserRole.trim().toLowerCase().replaceAll('_', '');
    return ['admin', 'manager', 'owner', 'founder', 'ceo', 'superadmin', 'director', 'md'].contains(role);
  }

  bool _hasQuotationPermission(Map<String, dynamic> userData) {
    if (_isAdminOrManager) return true;
    final permissions = userData['permissions'];
    if (permissions is Map) {
      final salesPerms = permissions['sales'];
      if (salesPerms is Map && salesPerms['quotations'] is Map) {
        if (salesPerms['quotations']['view'] == true) return true;
      }
      if (permissions['quotations'] == true) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User authentication required. Please log in again.';
          _isLoadingContext = false;
        });
        return;
      }

      _currentUserUid = user.uid;
      final rootUserDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      Map<String, dynamic> userData = rootUserDoc.data() ?? {};

      String resolvedCompanyId = _safeString(userData['activeCompanyId']);
      if (resolvedCompanyId.isEmpty) resolvedCompanyId = _safeString(userData['companyId']);
      if (resolvedCompanyId.isEmpty && userData['companyIds'] is List && (userData['companyIds'] as List).isNotEmpty) {
        resolvedCompanyId = _safeString((userData['companyIds'] as List).first);
      }
      if (resolvedCompanyId.isEmpty && userData['memberships'] is Map && (userData['memberships'] as Map).isNotEmpty) {
        resolvedCompanyId = _safeString((userData['memberships'] as Map).keys.first);
      }

      if (resolvedCompanyId.isEmpty) {
        setState(() {
          _errorMessage = 'No active workspace linked. Please join a company first.';
          _isLoadingContext = false;
        });
        return;
      }

      _companyId = resolvedCompanyId;
      _currentUserName = (userData['name'] ?? userData['fullName'] ?? '').toString();

      final companyUserDoc = await FirebaseFirestore.instance.collection('companies').doc(resolvedCompanyId).collection('users').doc(user.uid).get();
      if (companyUserDoc.exists && companyUserDoc.data() != null) {
        userData.addAll(companyUserDoc.data()!);
      }

      _currentUserRole = (userData['role'] ?? 'sales').toString().trim();

      if (!_hasQuotationPermission(userData)) {
        setState(() {
          _errorMessage = 'Access Denied: You lack permissions to view quotations.';
          _isLoadingContext = false;
        });
        return;
      }

      _setupQueries(resolvedCompanyId);

      setState(() {
        _isLoadingContext = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user context safely. Please try again.';
        _isLoadingContext = false;
      });
    }
  }

  void _setupQueries(String companyId) {
    _quotationCollection = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('quotations');
    Query<Map<String, dynamic>> query = _quotationCollection!;

    // ✅ UPDATED: Removed Filter.or for better scalability and composite index avoidance.
    // 💡 SUGGESTION FOR FUTURE: If multiple users need access, maintain a 'visibleTo': [uid1, uid2] array in Firestore.
    if (!_isAdminOrManager && _currentUserUid != null) {
      query = query.where('createdBy', isEqualTo: _currentUserUid);
    }

    // ✅ ENSURE PROPER QUERY STRUCTURE
    query = query.where('isDeleted', isEqualTo: false).orderBy('createdAt', descending: true);
    _primaryQuery = query;
  }

  String _safeString(dynamic value) => (value ?? '').toString().trim();

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    return '-';
  }

  String _money(dynamic value) {
    // ✅ SAFE PARSING
    final parsed = double.tryParse(value?.toString() ?? '0') ?? 0.0;
    return '₹ ${parsed.toStringAsFixed(2)}';
  }

  int _getFollowUpPriority(Map<String, dynamic> data) {
    final dateVal = data['nextFollowUpDate'];
    if (dateVal == null || dateVal is! Timestamp) return 3;

    final followUp = dateVal.toDate();
    final today = DateTime.now();

    if (followUp.year == today.year && followUp.month == today.month && followUp.day == today.day) {
      return 1;
    }
    if (followUp.isBefore(today)) {
      return 2;
    }

    return 3;
  }

  Future<void> _openCreateQuotation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => QuotationScreenLocal(userId: widget.userId, companyId: _companyId)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openQuotationForEdit(String docId, Map<String, dynamic> data) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => QuotationScreenLocal(
          userId: widget.userId,
          companyId: _companyId,
          quotationId: docId,
          existingQuotation: data
      )),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openQuotationPreview(Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );

    try {
      final safeData = Map<String, dynamic>.from(data);

      final quoteDate = (safeData['quoteDate'] as Timestamp?)?.toDate() ?? DateTime.now();
      safeData['quoteDateStr'] = '${quoteDate.day.toString().padLeft(2, '0')}/${quoteDate.month.toString().padLeft(2, '0')}/${quoteDate.year}';

      if (safeData['companyName'] == null && _companyId != null) {
        final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).get();
        if (companyDoc.exists) {
          final companyData = companyDoc.data() ?? {};

          safeData['companyName'] ??= companyData['companyName'] ?? companyData['name'] ?? '';
          safeData['companyAddress'] ??= companyData['companyAddress'] ?? companyData['address'] ?? '';
          safeData['companyPhone'] ??= companyData['companyPhone'] ?? companyData['phone'] ?? '';
          safeData['companyEmail'] ??= companyData['companyEmail'] ?? companyData['email'] ?? '';
          safeData['companyLogoUrl'] ??= companyData['companyLogoUrl'] ?? companyData['logoUrl'] ?? '';
          safeData['companyGst'] ??= companyData['companyGst'] ?? companyData['gstin'] ?? companyData['gstNo'] ?? '';
          safeData['companyPan'] ??= companyData['companyPan'] ?? companyData['pan'] ?? '';
          safeData['companyIec'] ??= companyData['companyIec'] ?? companyData['iec'] ?? '';
          safeData['companyWebsite'] ??= companyData['companyWebsite'] ?? companyData['website'] ?? '';
        }
      }

      final itemsList = (safeData['items'] is List) ? (safeData['items'] as List) : [];
      final parsedItems = itemsList.map((e) => QuotationLineItem.fromMap(Map<String, dynamic>.from(e as Map))).toList();

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuotationPreviewScreen(
            quotation: safeData,
            items: parsedItems,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showSnack('Failed to load preview: $e', isError: true);
    }
  }

  Future<void> _convertToSalesOrder(String docId, Map<String, dynamic> data) async {
    if (!_isAdminOrManager) {
      _showSnack('Only administrators or managers can convert quotations to Sales Orders.', isError: true);
      return;
    }
    if ((data['status'] ?? '').toString().toLowerCase() == 'converted') {
      _showSnack('Already converted to Sales Order.', isError: true);
      return;
    }
    if ((data['approvalStatus'] ?? '').toString() != 'Approved') {
      _showSnack('Quotation must be Approved before converting to SO.', isError: true);
      return;
    }

    final confirm = await _showConfirmDialog('Convert to Sales Order', 'Convert quotation ${data['quoteNumber']} to a Sales Order?');
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final counterRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('counters').doc('sales_order_counter');
      int seq = 1;
      final counterDoc = await counterRef.get();
      if (counterDoc.exists) seq = (counterDoc.data()?['sequence'] ?? 0) + 1;

      final now = DateTime.now();
      final startYear = now.month >= 4 ? now.year : now.year - 1;
      final fyShort = '${startYear.toString().substring(2)}-${(startYear + 1).toString().substring(2)}';
      final generatedSoNo = 'SO/${seq.toString().padLeft(4, '0')}/$fyShort';

      final soRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('sales_orders').doc();
      batch.set(soRef, {
        'id': soRef.id,
        'companyId': _companyId,
        'soNumber': generatedSoNo,
        'referenceQuotationId': docId,
        'referenceQuotationNo': data['quoteNumber'],
        'soDate': FieldValue.serverTimestamp(),
        'customerId': data['customerId'],
        'clientName': data['clientName'],
        'items': data['items'],
        'grandTotal': data['grandTotal'],
        'totalTaxableAmount': data['totalTaxableAmount'],
        'status': 'Draft',
        'createdBy': _currentUserUid,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isDeleted': false,
      });
      batch.set(counterRef, {'sequence': seq}, SetOptions(merge: true));

      final quoteRef = _quotationCollection!.doc(docId);
      batch.update(quoteRef, {
        'status': 'Converted',
        'convertedToSalesOrder': true,
        'convertedSoId': soRef.id,
        'convertedAt': FieldValue.serverTimestamp(),
        'convertedByUid': _currentUserUid,
        // ✅ STRONG AUDIT TRAIL LOGGING
        'activities': FieldValue.arrayUnion([{
          'type': 'Converted',
          'status': 'Converted',
          'timestamp': Timestamp.now(),
          'byUid': _currentUserUid,
          'byName': _currentUserName,
          'note': 'Converted to Sales Order $generatedSoNo'
        }])
      });

      final inquiryId = data['inquiryId'];
      if (inquiryId != null && inquiryId.toString().isNotEmpty) {
        final inquiryRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('inquiries').doc(inquiryId);
        batch.update(inquiryRef, {
          'status': 'Converted',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': _currentUserUid,
        });
      }

      await batch.commit();
      _showSnack('Successfully converted to Sales Order $generatedSoNo!');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to convert: $e', isError: true);
    }
  }

  Future<void> _createRevision(String docId, Map<String, dynamic> data) async {
    // ✅ ENFORCE INQUIRY-BASED QUOTATIONS
    final inquiryId = data['inquiryId'] ?? data['inquiryRefNo'];
    if (inquiryId == null || inquiryId.toString().trim().isEmpty) {
      _showSnack('Warning: Cannot revise a quotation that is not linked to an Inquiry.', isError: true);
      return;
    }

    final confirm = await _showConfirmDialog('Create Revision', 'Create a new version of quotation ${data['quoteNumber']}?');
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final oldRef = _quotationCollection!.doc(docId);
      batch.update(oldRef, {
        'isLatest': false,
        'status': 'Revised',
        'lastEditedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': _currentUserUid,
      });

      final newRef = _quotationCollection!.doc();
      final currentVersion = (data['version'] as int?) ?? 1;

      // ✅ REVISION OVERRIDING INSTEAD OF DUPLICATING
      final newData = Map<String, dynamic>.from(data)
        ..['id'] = newRef.id
        ..['version'] = currentVersion + 1
        ..['parentQuotationId'] = docId
        ..['isLatest'] = true
        ..['status'] = 'Draft'
        ..['approvalStatus'] = 'Pending'
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['createdBy'] = _currentUserUid
        ..['lastEditedAt'] = FieldValue.serverTimestamp()
        ..['lastEditedBy'] = _currentUserUid
      // ✅ STRONG AUDIT TRAIL LOGGING
        ..['activities'] = [{
          'type': 'Revised',
          'status': 'Draft',
          'timestamp': Timestamp.now(),
          'byUid': _currentUserUid,
          'byName': _currentUserName,
          'note': 'Revision ${currentVersion + 1} created from $docId'
        }];

      batch.set(newRef, newData);
      await batch.commit();

      _showSnack('Revision ${currentVersion + 1} created successfully.');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to create revision: $e', isError: true);
    }
  }

  // ❌ REMOVED _duplicateQuotation ENTIRELY TO ENFORCE CLEAN BUSINESS LOGIC

  Future<void> _updateApproval(String docId, String status) async {
    if (!_isAdminOrManager) {
      _showSnack('Only administrators or managers can approve quotations.', isError: true);
      return;
    }
    try {
      await _quotationCollection!.doc(docId).update({
        'approvalStatus': status,
        if (status == 'Approved') 'status': 'Approved',
        'approvedBy': status == 'Approved' ? _currentUserUid : null,
        'lastEditedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': _currentUserUid,
        // ✅ STRONG AUDIT TRAIL LOGGING
        'activities': FieldValue.arrayUnion([{
          'type': 'Approval Update',
          'status': status,
          'timestamp': Timestamp.now(),
          'byUid': _currentUserUid,
          'byName': _currentUserName,
          'note': 'Approval set to $status'
        }])
      });
      _showSnack('Quotation $status');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to update approval: $e', isError: true);
    }
  }

  Future<void> _cancelQuotation(String docId) async {
    final confirm = await _showConfirmDialog('Cancel Quotation', 'Are you sure you want to cancel this quotation?');
    if (confirm != true) return;

    try {
      await _quotationCollection!.doc(docId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _currentUserUid,
        // ✅ STRONG AUDIT TRAIL LOGGING
        'activities': FieldValue.arrayUnion([{
          'type': 'Cancelled',
          'status': 'Cancelled',
          'timestamp': Timestamp.now(),
          'byUid': _currentUserUid,
          'byName': _currentUserName,
          'note': 'Quotation cancelled'
        }])
      });

      _showSnack('Quotation Cancelled');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to cancel: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white), child: const Text('Confirm')),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final search = _searchText.trim().toLowerCase();

    var filtered = docs.where((doc) {
      final data = doc.data();
      final quoteNumber = (data['quoteNumber'] ?? '').toString().toLowerCase();
      final customer = (data['clientName'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? 'Draft').toString();

      final matchesSearch = search.isEmpty || quoteNumber.contains(search) || customer.contains(search);
      final matchesStatus = _statusFilter == 'All' || status.toLowerCase() == _statusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      int prioA = _getFollowUpPriority(dataA);
      int prioB = _getFollowUpPriority(dataB);
      if (prioA != prioB) {
        return prioA.compareTo(prioB);
      }

      if (_sortOption.startsWith('Amount')) {
        final amtA = double.tryParse(dataA['grandTotal']?.toString() ?? '0') ?? 0;
        final amtB = double.tryParse(dataB['grandTotal']?.toString() ?? '0') ?? 0;
        return _sortOption.contains('High') ? amtB.compareTo(amtA) : amtA.compareTo(amtB);
      } else {
        final dateA = (dataA['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final dateB = (dataB['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return _sortOption.contains('Newest') ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
      }
    });

    return filtered;
  }

  void _openFilterSheet() {
    String tempStatus = _statusFilter;
    String tempSort = _sortOption;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sort & Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 20),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _statuses.map((s) => ChoiceChip(
                  label: Text(s),
                  selected: tempStatus == s,
                  onSelected: (v) => setModalState(() => tempStatus = s),
                  selectedColor: primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: tempStatus == s ? primaryColor : Colors.black87, fontWeight: tempStatus == s ? FontWeight.bold : FontWeight.normal),
                )).toList(),
              ),
              const SizedBox(height: 20),
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tempSort,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
                items: _sortOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setModalState(() => tempSort = v!),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    setState(() {
                      _statusFilter = tempStatus;
                      _sortOption = tempSort;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply Options', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingContext) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) return Scaffold(body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))));
    if (_primaryQuery == null) return const Scaffold(body: Center(child: Text('System initialization failed')));

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('Quotations', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.grey), onPressed: () => setState((){})),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Quote', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openCreateQuotation,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _primaryQuery!.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = _applyLocalFilters(docs);

          int totalQuotes = filteredDocs.length;
          double totalValue = 0;
          double approvedValue = 0;
          int converted = 0;

          for (var doc in filteredDocs) {
            final data = doc.data();
            final st = (data['status'] ?? '').toString().toLowerCase();
            final ap = (data['approvalStatus'] ?? '').toString().toLowerCase();
            final val = double.tryParse(data['grandTotal']?.toString() ?? '0') ?? 0;

            if (st != 'cancelled') {
              totalValue += val;
              if (ap == 'approved') approvedValue += val;
              if (st == 'converted') converted++;
            }
          }

          double avgValue = totalQuotes > 0 ? totalValue / totalQuotes : 0;
          double convRate = totalQuotes > 0 ? (converted / totalQuotes) * 100 : 0;

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildKpiCard('Total Value', '₹${(totalValue/100000).toStringAsFixed(2)}L', Icons.account_balance_wallet, Colors.blue),
                      _buildKpiCard('Approved Val', '₹${(approvedValue/100000).toStringAsFixed(2)}L', Icons.verified, Colors.green),
                      _buildKpiCard('Conv. Rate', '${convRate.toStringAsFixed(1)}%', Icons.insights, Colors.purple),
                      _buildKpiCard('Avg Value', '₹${(avgValue/1000).toStringAsFixed(1)}K', Icons.bar_chart, Colors.orange),
                    ],
                  ),
                ),
              ),

              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchText = v),
                        decoration: InputDecoration(
                          hintText: 'Search quotation, customer...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchText.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _searchController.clear(); _searchText = ''; })) : null,
                          filled: true, fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _openFilterSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.tune, color: _statusFilter != 'All' ? primaryColor : Colors.grey.shade700, size: 22),
                      ),
                    )
                  ],
                ),
              ),

              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.insert_drive_file_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No Quotations Found', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ]))
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredDocs.length,
                  itemBuilder: (ctx, i) {
                    final doc = filteredDocs[i];
                    final data = doc.data();

                    // ✅ DATA FIX: FIX DRAFT DISPLAY BUG
                    final rawQNo = data['quoteNumber']?.toString().trim() ?? '';
                    final qNo = rawQNo.isEmpty ? 'Draft' : rawQNo;

                    final version = data['version']?.toString() ?? '1';
                    final customer = data['clientName']?.toString() ?? 'Unknown Customer';
                    final date = _formatTimestamp(data['quoteDate']);
                    final amt = _money(data['grandTotal']);

                    final status = data['status']?.toString() ?? 'Draft';
                    final approval = data['approvalStatus']?.toString() ?? 'Pending';
                    final paymentStat = data['paymentStatus']?.toString() ?? 'Pending';
                    final inqRef = (data['inquiryRefNo'] ?? data['inquiryNumber'] ?? data['inquiryId'] ?? '').toString();

                    final priority = _getFollowUpPriority(data);

                    // ✅ DISABLE INVALID ACTIONS
                    bool isCancelled = status == 'Cancelled';
                    bool isApproved = approval == 'Approved';
                    bool isSent = status == 'Sent';
                    bool isConverted = status == 'Converted';

                    // Strict edit lock rules
                    bool canEdit = !isCancelled && !isApproved && !isSent && !isConverted;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0,2))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('$qNo (v$version)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryColor)),
                                    if (inqRef.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text('INQ: $inqRef', style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold))),
                                    ]
                                  ],
                                ),
                                Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(customer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                                Text(amt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildStatusChip(status),
                                const SizedBox(width: 8),
                                if (approval != 'Pending') _buildStatusChip(approval, isApproval: true),
                                const SizedBox(width: 8),
                                if (status == 'Converted') _buildStatusChip(paymentStat, isPayment: true),

                                const Spacer(),

                                if (!isCancelled) ...[
                                  if (priority == 1)
                                    _buildFollowUpChip('Follow-up Today', Colors.orange)
                                  else if (priority == 2)
                                    _buildFollowUpChip('Overdue', Colors.red),
                                ],

                                const SizedBox(width: 8),

                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (val) {
                                    switch (val) {
                                      case 'view': _openQuotationPreview(data); break;
                                      case 'edit': _openQuotationForEdit(doc.id, data); break;
                                      case 'approve': _updateApproval(doc.id, 'Approved'); break;
                                      case 'reject': _updateApproval(doc.id, 'Rejected'); break;
                                      case 'convert': _convertToSalesOrder(doc.id, data); break;
                                      case 'revision': _createRevision(doc.id, data); break;
                                      case 'cancel': _cancelQuotation(doc.id); break;
                                    }
                                  },
                                  itemBuilder: (ctx) {
                                    // ✅ KEEP MENU CLEAN
                                    List<PopupMenuEntry<String>> items = [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text('View')]),
                                      ),
                                    ];

                                    if (canEdit) {
                                      items.add(
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
                                        ),
                                      );
                                    }

                                    if (!isCancelled) {
                                      items.add(const PopupMenuDivider());

                                      if (approval == 'Pending' && _isAdminOrManager) {
                                        items.add(const PopupMenuItem(value: 'approve', child: Row(children: [Icon(Icons.thumb_up, size: 18, color: Colors.green), SizedBox(width: 8), Text('Approve')])));
                                        items.add(const PopupMenuItem(value: 'reject', child: Row(children: [Icon(Icons.thumb_down, size: 18, color: Colors.red), SizedBox(width: 8), Text('Reject')])));
                                      }

                                      if (!isConverted && isApproved && _isAdminOrManager) {
                                        items.add(const PopupMenuItem(value: 'convert', child: Row(children: [Icon(Icons.swap_horiz, size: 18, color: Colors.teal), SizedBox(width: 8), Text('Convert to SO')])));
                                      }

                                      // Allow revisions if they are not approved (or if admin is handling changes)
                                      items.add(const PopupMenuItem(value: 'revision', child: Row(children: [Icon(Icons.history, size: 18, color: Colors.indigo), SizedBox(width: 8), Text('Create Revision')])));

                                      items.add(const PopupMenuDivider());
                                      items.add(const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel, size: 18, color: Colors.red), SizedBox(width: 8), Text('Cancel', style: TextStyle(color: Colors.red))])));
                                    }

                                    return items;
                                  },
                                )
                              ],
                            ),

                            // ✅ UX: SHOW CLEAR NEXT STEP (Prominent Convert Button)
                            if (isApproved && !isConverted && !isCancelled)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.swap_horiz, size: 20),
                                    label: const Text('Convert to Sales Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    onPressed: () => _convertToSalesOrder(doc.id, data),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              Text(value, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFollowUpChip(String label, MaterialColor color) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: color.shade200)),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 12, color: color.shade800),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.shade800)),
          ],
        )
    );
  }

  Widget _buildStatusChip(String status, {bool isApproval = false, bool isPayment = false}) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;

    String s = status.toLowerCase();

    if (isPayment) {
      if (s == 'paid') { bg = Colors.green.shade50; fg = Colors.green.shade800; }
      else if (s == 'partial') { bg = Colors.orange.shade50; fg = Colors.orange.shade800; }
      else { bg = Colors.red.shade50; fg = Colors.red.shade800; }
    } else {
      if (s == 'draft') { bg = Colors.orange.shade50; fg = Colors.orange.shade800; }
      else if (s == 'sent' || s == 'viewed') { bg = Colors.blue.shade50; fg = Colors.blue.shade800; }
      else if (s == 'approved' || s == 'converted') { bg = Colors.green.shade50; fg = Colors.green.shade800; }
      else if (s == 'rejected') { bg = Colors.red.shade50; fg = Colors.red.shade800; }
      else if (s == 'follow-up' || s == 'negotiation') { bg = Colors.purple.shade50; fg = Colors.purple.shade800; }
      else if (s == 'cancelled') { bg = Colors.red.shade100; fg = Colors.red.shade900; }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}