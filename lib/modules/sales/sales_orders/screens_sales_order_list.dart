import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:QUIK/modules/sales/quotations/quotation_pdf_generator.dart';

// =========================================================
// CONSTANTS & THEME
// =========================================================
const Color _zBackground = Color(0xFFF8FAFC);
const Color _zCard = Colors.white;
const Color _zBorder = Color(0xFFE2E8F0);
const Color _zTextMain = Color(0xFF0F172A);
const Color _zTextMuted = Color(0xFF64748B);
const Color _zPrimary = Color(0xFF2563EB);
const Color _zPrimaryLight = Color(0xFFEFF6FF);
const Color _zDanger = Color(0xFFEF4444);
const Color _zSuccess = Color(0xFF10B981);
const Color _zWarning = Color(0xFFF59E0B);

// =========================================================
// HELPER METHODS
// =========================================================
double _parseSafeDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val.replaceAll(',', '')) ?? 0.0;
  return 0.0;
}

String _parseSafeString(dynamic val, {String fallback = '-'}) {
  if (val == null) return fallback;
  final str = val.toString().trim();
  return str.isEmpty ? fallback : str;
}

class SalesOrderListScreen extends StatefulWidget {
  final String companyId;

  const SalesOrderListScreen({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  @override
  State<SalesOrderListScreen> createState() => _SalesOrderListScreenState();
}

class _SalesOrderListScreenState extends State<SalesOrderListScreen> {
  // --- UI Controllers ---
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  // --- State Variables ---
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedSort = 'Latest';

  final List<String> _statusOptions = ['All', 'Draft', 'Confirmed', 'Completed', 'Cancelled'];
  final List<String> _sortOptions = ['Latest', 'Oldest', 'Highest Amount', 'Lowest Amount'];

  // --- Pagination & Data State ---
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _salesOrders = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  // --- User Name Cache ---
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================================
  // USER NAME RESOLUTION LOGIC
  // =========================================================

  Future<String> _getUserName(String uid) async {
    if (uid.isEmpty) return 'Unknown User';
    if (_userNameCache.containsKey(uid)) {
      return _userNameCache[uid]!;
    }

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data();
        final name = _parseSafeString(data?['name'], fallback: 'Unknown User');
        _userNameCache[uid] = name;
        return name;
      }
    } catch (e) {
      debugPrint('Error fetching user name for $uid: $e');
    }

    _userNameCache[uid] = 'Unknown User';
    return 'Unknown User';
  }

  // =========================================================
  // DATA FETCHING & PAGINATION LOGIC
  // =========================================================

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _fetchSalesOrders(refresh: true);
  }

  Future<void> _fetchSalesOrders({bool refresh = false}) async {
    if (refresh) {
      _lastDocument = null;
      _hasMore = true;
      _errorMessage = null;
    } else if (!_hasMore || _isFetchingMore) {
      return;
    }

    if (!mounted) return;
    setState(() => refresh ? _isLoading = true : _isFetchingMore = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('sales_orders');

      if (_selectedStatus != 'All') {
        query = query.where('status', isEqualTo: _selectedStatus.toLowerCase());
      }

      switch (_selectedSort) {
        case 'Latest':
          query = query.orderBy('createdAt', descending: true);
          break;
        case 'Oldest':
          query = query.orderBy('createdAt', descending: false);
          break;
        case 'Highest Amount':
          query = query.orderBy('grandTotal', descending: true);
          break;
        case 'Lowest Amount':
          query = query.orderBy('grandTotal', descending: false);
          break;
      }

      query = query.limit(20);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      if (!mounted) return;

      if (refresh) {
        _salesOrders.clear();
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newDocs = snapshot.docs.where((doc) {
          return !_salesOrders.any((existing) => existing.id == doc.id);
        }).toList();

        _salesOrders.addAll(newDocs);

        if (snapshot.docs.length < 20) {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        _errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.code == 'permission-denied') {
        _errorMessage = 'Access denied. You do not have permission to view these records.';
      } else {
        _errorMessage = 'Unable to load sales orders. Please contact support.';
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isFetchingMore && _hasMore && !_isLoading && _errorMessage == null) {
        _fetchSalesOrders();
      }
    }
  }

  // =========================================================
  // SEARCH & FILTER LOGIC
  // =========================================================

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _searchQuery != val) {
        setState(() => _searchQuery = val);
      }
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _getFilteredOrders() {
    if (_searchQuery.trim().isEmpty) return _salesOrders;

    final query = _searchQuery.trim().toLowerCase();
    return _salesOrders.where((doc) {
      final data = doc.data();
      final soNum = _parseSafeString(data['salesOrderNumber'] ?? data['soNumber'] ?? data['orderNumber'], fallback: '').toLowerCase();
      final custName = _parseSafeString(data['customerName'] ?? data['clientName'] ?? data['partyName'] ?? data['customer'], fallback: '').toLowerCase();
      return soNum.contains(query) || custName.contains(query);
    }).toList();
  }

  // =========================================================
  // PREVIEW & DATA MAPPING
  // =========================================================

  Map<String, dynamic> prepareSalesOrderForPdf(Map<String, dynamic> mergedData) {
    mergedData['documentType'] = 'Sales Order';

    DateTime? date;
    final dateRaw = mergedData['date'] ?? mergedData['createdAt'] ?? mergedData['soDate'];
    if (dateRaw != null && dateRaw is Timestamp) {
      date = dateRaw.toDate();
    } else if (dateRaw is String && dateRaw.isNotEmpty) {
      try {
        date = DateTime.parse(dateRaw);
      } catch (_) {
        date = DateTime.now();
      }
    } else {
      date = DateTime.now();
    }

    final soNumber = _parseSafeString(
        mergedData['salesOrderNumber'] ?? mergedData['soNumber'] ?? mergedData['orderNumber'],
        fallback: 'Draft SO'
    );
    final customerName = _parseSafeString(
        mergedData['customerName'] ?? mergedData['clientName'] ?? mergedData['partyName'] ?? mergedData['customer'],
        fallback: 'Unknown Customer'
    );

    mergedData['salesOrderNumberDisplay'] = soNumber;
    mergedData['quoteNumber'] = mergedData['quoteNumber'] ?? mergedData['quotationNumber'];
    mergedData['clientName'] = customerName;
    mergedData['quoteDateStr'] = DateFormat('dd/MM/yyyy').format(date);
    mergedData['grandTotal'] = _parseSafeDouble(mergedData['grandTotal'] ?? mergedData['totalAmount'] ?? mergedData['amount']);
    mergedData['totalTaxableAmount'] = _parseSafeDouble(mergedData['subtotal'] ?? mergedData['totalTaxableAmount']);
    mergedData['totalTaxAmount'] = _parseSafeDouble(mergedData['tax'] ?? mergedData['totalTaxAmount']);

    return mergedData;
  }

  Future<void> _openSalesOrderPreview(Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _zPrimary)),
    );

    try {
      Map<String, dynamic> mergedData = {};

      final quoteId = _parseSafeString(
          data['referenceQuotationId'] ??
              data['quotationId'] ??
              data['quoteId']
      );

      if (quoteId.isNotEmpty && widget.companyId.isNotEmpty) {
        final quoteDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('quotations')
            .doc(quoteId)
            .get();

        if (quoteDoc.exists) {
          final quoteData = quoteDoc.data() ?? {};
          mergedData.addAll(quoteData);
        }
      }

      final originalQuoteNumber = mergedData['quoteNumber'] ?? mergedData['quotationNumber'];

      mergedData.addAll(data);

      mergedData['quoteNumber'] = originalQuoteNumber;
      mergedData['quotationNumber'] = originalQuoteNumber;

      final preparedData = prepareSalesOrderForPdf(mergedData);

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (companyDoc.exists) {
        final companyData = companyDoc.data() ?? {};
        preparedData['companyName'] ??= companyData['companyName'] ?? companyData['name'] ?? '';
        preparedData['companyAddress'] ??= companyData['companyAddress'] ?? companyData['address'] ?? '';
        preparedData['companyPhone'] ??= companyData['companyPhone'] ?? companyData['phone'] ?? '';
        preparedData['companyEmail'] ??= companyData['companyEmail'] ?? companyData['email'] ?? '';
        preparedData['companyLogoUrl'] ??= companyData['companyLogoUrl'] ?? companyData['logoUrl'] ?? '';
        preparedData['companyGst'] ??= companyData['companyGst'] ?? companyData['gstin'] ?? companyData['gstNo'] ?? '';
        preparedData['companyPan'] ??= companyData['companyPan'] ?? companyData['pan'] ?? '';
        preparedData['companyIec'] ??= companyData['companyIec'] ?? companyData['iec'] ?? '';
        preparedData['companyWebsite'] ??= companyData['companyWebsite'] ?? companyData['website'] ?? '';
      }

      final bool isInterState = preparedData['isInterState'] == true;
      final itemsList = (preparedData['items'] is List) ? (preparedData['items'] as List) : [];

      final parsedItems = itemsList.map((e) {
        final itemMap = Map<String, dynamic>.from(e as Map);

        final double gstRate = _parseSafeDouble(itemMap['gstRate'] ?? itemMap['taxRate'] ?? itemMap['gst']);
        double cgst = 0.0;
        double sgst = 0.0;
        double igst = 0.0;

        if (isInterState) {
          igst = gstRate;
        } else {
          cgst = gstRate / 2;
          sgst = gstRate / 2;
        }

        return QuotationLineItem(
          id: itemMap['id']?.toString() ?? '',
          productId: itemMap['productId']?.toString() ?? '',
          name: itemMap['name']?.toString() ?? itemMap['itemName']?.toString() ?? 'Item',
          description: itemMap['description']?.toString() ?? '',
          hsnCode: itemMap['hsnCode']?.toString() ?? '',
          quantity: _parseSafeDouble(itemMap['quantity']),
          uom: itemMap['unit']?.toString() ?? itemMap['uom']?.toString() ?? 'Nos',
          unitPrice: _parseSafeDouble(itemMap['unitPrice'] ?? itemMap['price'] ?? itemMap['rate']),
          discountPercent: _parseSafeDouble(itemMap['discountPercent'] ?? itemMap['discount']),
          cgstPercent: cgst,
          sgstPercent: sgst,
          igstPercent: igst,
          availableStock: _parseSafeDouble(itemMap['availableStock'] ?? itemMap['stock']),
        );
      }).toList();

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuotationPreviewScreen(
            quotation: preparedData,
            items: parsedItems,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load preview: $e'),
          backgroundColor: _zDanger
      ));
    }
  }

  // =========================================================
  // PROFORMA INVOICE CREATION
  // =========================================================

  Future<void> _createProformaInvoice(Map<String, dynamic> soData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _zPrimary)),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated.');

      final currentUserName = await _getUserName(user.uid);

      final piCollection = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices');

      final newPiRef = piCollection.doc();
      final piNumber = 'PI-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      final piData = Map<String, dynamic>.from(soData);

      piData.remove('dispatchStatus');
      piData.remove('purchaseOrder');

      piData.addAll({
        'id': newPiRef.id,
        'sourceSalesOrderId': soData['id'] ?? newPiRef.id,
        'documentType': 'proforma_invoice',
        'status': 'draft',
        'proformaNumber': piNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByName': currentUserName,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
        'updatedByName': currentUserName,
        'activities': [
          {
            'type': 'Created',
            'note': 'Proforma Invoice automatically generated from Sales Order ${soData['salesOrderNumber'] ?? soData['id']}',
            'timestamp': Timestamp.now(),
            'byUid': user.uid,
          }
        ],
      });

      await newPiRef.set(piData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Proforma Invoice created successfully'),
          backgroundColor: _zSuccess,
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create Proforma Invoice: $e'),
          backgroundColor: _zDanger,
        ));
      }
    }
  }


  // =========================================================
  // PURCHASE ORDER UPLOAD LOGIC
  // =========================================================

  Future<void> _handlePOUpload(String docId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileSize = file.size;

      if (fileSize > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('File size exceeds 10MB limit.'),
            backgroundColor: _zDanger
        ));
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: _zPrimary)),
      );

      Uint8List fileBytes;
      String fileName = file.name;
      final extension = fileName.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png'].contains(extension);

      if (kIsWeb) {
        if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else {
          throw Exception('Cannot read file data on web.');
        }
      } else {
        if (isImage && file.path != null) {
          final compressed = await FlutterImageCompress.compressWithFile(
            file.path!,
            quality: 60,
          );
          if (compressed == null) throw Exception('Image compression failed');
          fileBytes = compressed;
        } else if (file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        } else if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else {
          throw Exception('Cannot read file data.');
        }
      }

      final String safeFileName = '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(RegExp(r'\s+'), '_')}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('companies/${widget.companyId}/sales_orders/$docId/purchase_order/$safeFileName');

      final uploadTask = storageRef.putData(fileBytes, SettableMetadata(
        contentType: isImage ? 'image/$extension' : 'application/pdf',
      ));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final docRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('sales_orders')
          .doc(docId);

      final user = FirebaseAuth.instance.currentUser;
      final currentUserName = user != null ? await _getUserName(user.uid) : 'System';

      await docRef.update({
        'purchaseOrder': {
          'url': downloadUrl,
          'fileName': fileName,
          'uploadedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user?.uid,
        'updatedByName': currentUserName,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'PO Upload',
            'note': 'Purchase Order ($fileName) uploaded',
            'timestamp': Timestamp.now(),
            'byUid': user?.uid ?? 'system',
          }
        ]),
      });

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Purchase Order uploaded successfully'),
          backgroundColor: _zSuccess
      ));

      _fetchInitialData();

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to upload PO: $e'),
          backgroundColor: _zDanger
      ));
    }
  }

  Future<void> _viewPO(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open file'),
            backgroundColor: _zDanger
        ));
      }
    }
  }

  // =========================================================
  // BUSINESS LOGIC ACTIONS (DISPATCH, APPROVE, CANCEL)
  // =========================================================

  Future<void> _updateOrderField(String docId, Map<String, dynamic> updates, String logType, String logNote) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('sales_orders')
          .doc(docId);

      final user = FirebaseAuth.instance.currentUser;
      final currentUserName = user != null ? await _getUserName(user.uid) : 'System';

      updates['activities'] = FieldValue.arrayUnion([
        {
          'type': logType,
          'note': logNote,
          'timestamp': Timestamp.now(),
          'byUid': user?.uid ?? 'system',
        }
      ]);
      updates['updatedAt'] = FieldValue.serverTimestamp();
      updates['updatedBy'] = user?.uid;
      updates['updatedByName'] = currentUserName;

      await docRef.update(updates);
      _fetchInitialData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e'), backgroundColor: _zDanger));
    }
  }

  void _showApprovalDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data['status'] == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completed orders cannot be modified.')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Sales Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text('Do you want to approve or reject this order? Approved orders will automatically be Confirmed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: _zTextMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _zDanger),
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderField(doc.id, {'approvalStatus': 'rejected', 'status': 'draft'}, 'Approval', 'Order Rejected by User');
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _zSuccess),
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderField(doc.id, {'approvalStatus': 'approved', 'status': 'confirmed'}, 'Approval', 'Order Approved and Confirmed');
            },
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDispatchDialog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String currentStatus = _parseSafeString(data['status']).toLowerCase();
    final String approvalStatus = _parseSafeString(data['approvalStatus']).toLowerCase();

    if (approvalStatus != 'approved' || currentStatus != 'confirmed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Approved and Confirmed orders can be dispatched.'), backgroundColor: _zWarning),
      );
      return;
    }

    String selectedDispatch = _parseSafeString(data['dispatchStatus'], fallback: 'pending');
    selectedDispatch = selectedDispatch.isEmpty ? 'Pending' : selectedDispatch[0].toUpperCase() + selectedDispatch.substring(1).toLowerCase();
    if (!['Pending', 'Packed', 'Shipped', 'Delivered'].contains(selectedDispatch)) selectedDispatch = 'Pending';

    final transCtrl = TextEditingController(text: _parseSafeString(data['transporterName'], fallback: ''));
    final vehCtrl = TextEditingController(text: _parseSafeString(data['vehicleNumber'], fallback: ''));
    final lrCtrl = TextEditingController(text: _parseSafeString(data['lrNumber'], fallback: ''));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Dispatch Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedDispatch,
                      decoration: const InputDecoration(labelText: 'Dispatch Status', border: OutlineInputBorder()),
                      items: ['Pending', 'Packed', 'Shipped', 'Delivered'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setDialogState(() => selectedDispatch = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: transCtrl, decoration: const InputDecoration(labelText: 'Transporter Name', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: vehCtrl, decoration: const InputDecoration(labelText: 'Vehicle Number', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: lrCtrl, decoration: const InputDecoration(labelText: 'LR Number', border: OutlineInputBorder())),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _zTextMuted))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _zPrimary),
                  onPressed: () {
                    final updates = <String, dynamic>{
                      'dispatchStatus': selectedDispatch.toLowerCase(),
                      'transporterName': transCtrl.text.trim(),
                      'vehicleNumber': vehCtrl.text.trim(),
                      'lrNumber': lrCtrl.text.trim(),
                    };

                    if (selectedDispatch.toLowerCase() == 'delivered') {
                      updates['status'] = 'completed';
                    }

                    Navigator.pop(ctx);
                    _updateOrderField(doc.id, updates, 'Dispatch', 'Dispatch updated to $selectedDispatch via ${transCtrl.text.trim()}');
                  },
                  child: const Text('Save Dispatch', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _cancelOrder(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final String status = _parseSafeString(data['status']).toLowerCase();
    final String dispatchStatus = _parseSafeString(data['dispatchStatus']).toLowerCase();

    if (status == 'completed' || dispatchStatus == 'shipped' || dispatchStatus == 'delivered') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot cancel orders that are shipped, delivered, or completed.'), backgroundColor: _zWarning),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order', style: TextStyle(color: _zDanger, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this Sales Order? This action cannot be fully undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, Keep It', style: TextStyle(color: _zTextMain))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _zDanger),
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderField(doc.id, {'status': 'cancelled'}, 'Status Update', 'Order manually cancelled');
            },
            child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // UI BUILDERS
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _zBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildToolbar(),
            _buildKpiDashboard(),
            Expanded(
              child: _buildListContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search order or customer...',
                    hintStyle: const TextStyle(color: _zTextMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: _zTextMuted, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: _zTextMuted, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: _zBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: _zBackground, borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    icon: const Icon(Icons.sort_rounded, color: _zTextMuted, size: 20),
                    style: const TextStyle(color: _zTextMain, fontSize: 14, fontWeight: FontWeight.w600),
                    items: _sortOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedSort) {
                        setState(() => _selectedSort = val);
                        _fetchInitialData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _statusOptions.map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? _zPrimary : _zTextMuted,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: _zPrimaryLight,
                    backgroundColor: _zBackground,
                    side: BorderSide(color: isSelected ? _zPrimary.withOpacity(0.3) : _zBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (selected) {
                      if (selected && _selectedStatus != status) {
                        setState(() => _selectedStatus = status);
                        _fetchInitialData();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiDashboard() {
    if (_isLoading && _salesOrders.isEmpty) return const SizedBox.shrink();

    final filteredDocs = _getFilteredOrders();
    double totalRevenue = 0;
    int confirmedCount = 0;
    int dispatchPendingCount = 0;
    int completedCount = 0;

    for (var doc in filteredDocs) {
      final data = doc.data();
      totalRevenue += _parseSafeDouble(data['grandTotal'] ?? data['totalAmount'] ?? data['amount']);
      final st = _parseSafeString(data['status']).toLowerCase();
      final dst = _parseSafeString(data['dispatchStatus']).toLowerCase();

      if (st == 'confirmed') confirmedCount++;
      if (st == 'completed') completedCount++;
      if (st == 'confirmed' && dst != 'delivered') dispatchPendingCount++;
    }

    final String formattedRevenue = NumberFormat.currency(
        symbol: '₹', locale: 'en_IN', decimalDigits: totalRevenue.truncateToDouble() == totalRevenue ? 0 : 2
    ).format(totalRevenue);

    return Container(
      width: double.infinity,
      color: _zBackground,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _KpiCard(title: 'Visible Revenue', value: formattedRevenue, icon: Icons.account_balance_wallet_rounded, color: _zPrimary),
            _KpiCard(title: 'Confirmed', value: '$confirmedCount', icon: Icons.check_circle_rounded, color: _zSuccess),
            _KpiCard(title: 'Dispatch Pending', value: '$dispatchPendingCount', icon: Icons.local_shipping_rounded, color: _zWarning),
            _KpiCard(title: 'Completed', value: '$completedCount', icon: Icons.done_all_rounded, color: _zTextMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent() {
    if (_isLoading && _salesOrders.isEmpty) {
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: 4, itemBuilder: (_, __) => const _SkeletonCard());
    }

    if (_errorMessage != null && _salesOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cloud_off_rounded, title: 'Connection Issue', subtitle: _errorMessage!,
        actionLabel: 'Retry', onAction: _fetchInitialData,
      );
    }

    final filteredDocs = _getFilteredOrders();

    if (filteredDocs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined, title: 'No Orders Found',
        subtitle: 'No sales orders match your current filters or search.',
        actionLabel: 'Clear Filters', onAction: () {
        _searchController.clear();
        setState(() { _searchQuery = ''; _selectedStatus = 'All'; });
        _fetchInitialData();
      },
      );
    }

    return RefreshIndicator(
      color: _zPrimary,
      onRefresh: _fetchInitialData,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
        itemCount: filteredDocs.length + 1,
        itemBuilder: (context, index) {
          if (index == filteredDocs.length) {
            if (_hasMore) {
              return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: _zPrimary)));
            } else {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 1, width: 40, color: _zBorder),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('No more records', style: TextStyle(color: _zTextMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                      Container(height: 1, width: 40, color: _zBorder),
                    ],
                  ),
                ),
              );
            }
          }

          final doc = filteredDocs[index];
          final data = doc.data();

          return _SalesOrderCard(
            key: ValueKey(doc.id),
            document: doc,
            nameResolver: _getUserName,
            onViewTap: () => _openSalesOrderPreview(data),
            onDispatchTap: () => _showDispatchDialog(doc),
            onApproveTap: () => _showApprovalDialog(doc),
            onCancelTap: () => _cancelOrder(doc),
            onUploadPOTap: () => _handlePOUpload(doc.id),
            onViewPOTap: () {
              final poData = data['purchaseOrder'];
              if (poData != null && poData['url'] != null) {
                _viewPO(poData['url']);
              }
            },
            onCreateProformaTap: () => _createProformaInvoice(data),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon, required String title, required String subtitle,
    String? actionLabel, VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Icon(icon, size: 40, color: _zTextMuted.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _zTextMain)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: _zTextMuted, height: 1.5)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onAction, icon: const Icon(Icons.refresh, size: 18), label: Text(actionLabel),
                style: OutlinedButton.styleFrom(foregroundColor: _zPrimary, side: const BorderSide(color: _zPrimary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// =========================================================
// WIDGETS
// =========================================================

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _zBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.withOpacity(0.8)),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _zTextMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _SalesOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final Future<String> Function(String) nameResolver;
  final VoidCallback onViewTap;
  final VoidCallback onDispatchTap;
  final VoidCallback onApproveTap;
  final VoidCallback onCancelTap;
  final VoidCallback onUploadPOTap;
  final VoidCallback onViewPOTap;
  final VoidCallback onCreateProformaTap;

  const _SalesOrderCard({
    Key? key,
    required this.document,
    required this.nameResolver,
    required this.onViewTap,
    required this.onDispatchTap,
    required this.onApproveTap,
    required this.onCancelTap,
    required this.onUploadPOTap,
    required this.onViewPOTap,
    required this.onCreateProformaTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = document.data();

    final String soNumber = _parseSafeString(
        data['salesOrderNumber'] ?? data['soNumber'] ?? data['orderNumber'],
        fallback: 'Draft SO'
    );
    final String customerName = _parseSafeString(
        data['customerName'] ?? data['clientName'] ?? data['partyName'] ?? data['customer'],
        fallback: 'Unknown Customer'
    );
    final String status = _parseSafeString(data['status'], fallback: 'draft').toLowerCase();
    final String approvalStatus = _parseSafeString(data['approvalStatus'], fallback: 'pending').toLowerCase();
    final String dispatchStatus = _parseSafeString(data['dispatchStatus'], fallback: 'pending').toLowerCase();
    final double grandTotal = _parseSafeDouble(data['grandTotal'] ?? data['totalAmount'] ?? data['amount']);

    DateTime? date;
    final dateRaw = data['date'] ?? data['createdAt'] ?? data['soDate'];
    if (dateRaw != null && dateRaw is Timestamp) {
      date = dateRaw.toDate();
    }

    final formattedDate = date != null ? DateFormat('dd MMM yyyy').format(date) : '--';
    final formattedAmount = NumberFormat.currency(
        symbol: '₹', locale: 'en_IN', decimalDigits: grandTotal.truncateToDouble() == grandTotal ? 0 : 2
    ).format(grandTotal);

    final bool canCancel = status != 'completed' && dispatchStatus != 'shipped' && dispatchStatus != 'delivered' && status != 'cancelled';
    final bool canDispatch = approvalStatus == 'approved' && status == 'confirmed';
    final bool canApprove = status != 'cancelled' && status != 'completed' && approvalStatus != 'approved' && approvalStatus != 'rejected';

    final Map<String, dynamic>? poData = data['purchaseOrder'];
    final bool hasPO = poData != null && _parseSafeString(poData['url']).isNotEmpty;

    // Audit Fields safely parsing
    final String createdByUid = _parseSafeString(data['createdBy']);
    final String? explicitlyStoredName = data['createdByName']?.toString().trim();

    String formattedCreatedAt = '--';
    final createdAtRaw = data['createdAt'];
    if (createdAtRaw != null && createdAtRaw is Timestamp) {
      formattedCreatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(createdAtRaw.toDate());
    }

    String formattedUpdatedAt = '--';
    final updatedAtRaw = data['updatedAt'];
    if (updatedAtRaw != null && updatedAtRaw is Timestamp) {
      formattedUpdatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(updatedAtRaw.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _zCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _zBorder, width: 0.8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), offset: const Offset(0, 2), blurRadius: 8)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onViewTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(soNumber, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _zTextMain)),
                        if (hasPO)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.attachment_rounded, size: 16, color: _zPrimary),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        _StatusBadge(status: status, type: 'Order'),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: _zTextMuted, size: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onSelected: (value) {
                            if (value == 'view') onViewTap();
                            if (value == 'dispatch') onDispatchTap();
                            if (value == 'approve') onApproveTap();
                            if (value == 'cancel') onCancelTap();
                            if (value == 'view_po') onViewPOTap();
                            if (value == 'upload_po') onUploadPOTap();
                            if (value == 'create_proforma') onCreateProformaTap();
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(value: 'view', child: Text('View Details')),
                            const PopupMenuDivider(),
                            if (hasPO)
                              const PopupMenuItem(value: 'view_po', child: Text('View PO', style: TextStyle(color: _zPrimary, fontWeight: FontWeight.w600))),
                            PopupMenuItem(
                                value: 'upload_po',
                                child: Text(hasPO ? 'Replace PO' : 'Upload PO', style: TextStyle(color: hasPO ? _zTextMuted : _zPrimary))
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                                value: 'create_proforma',
                                child: Text('Create Proforma Invoice')
                            ),
                            const PopupMenuDivider(),
                            if (canApprove) const PopupMenuItem(value: 'approve', child: Text('Approve / Reject')),
                            if (canDispatch) const PopupMenuItem(value: 'dispatch', child: Text('Update Dispatch')),
                            if (canCancel) const PopupMenuItem(value: 'cancel', child: Text('Cancel Order', style: TextStyle(color: _zDanger))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.business_center_rounded, size: 16, color: _zTextMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(customerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _zTextMain), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusBadge(status: approvalStatus, type: 'Approval'),
                    _StatusBadge(status: dispatchStatus, type: 'Dispatch'),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: _zBorder),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: _zTextMuted),
                        const SizedBox(width: 6),
                        Text(formattedDate, style: const TextStyle(fontSize: 13, color: _zTextMuted, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text(formattedAmount, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _zPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _zBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _zBorder.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: _zTextMuted),
                          const SizedBox(width: 6),
                          const Text('Created By: ', style: TextStyle(fontSize: 12, color: _zTextMuted, fontWeight: FontWeight.w600)),
                          Expanded(
                            child: (explicitlyStoredName != null && explicitlyStoredName.isNotEmpty)
                                ? Text(explicitlyStoredName, style: const TextStyle(fontSize: 12, color: _zTextMain, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)
                                : FutureBuilder<String>(
                                future: nameResolver(createdByUid),
                                builder: (context, snapshot) {
                                  return Text(snapshot.data ?? '...', style: const TextStyle(fontSize: 12, color: _zTextMain, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis);
                                }
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: _zTextMuted),
                          const SizedBox(width: 6),
                          const Text('Created At: ', style: TextStyle(fontSize: 12, color: _zTextMuted, fontWeight: FontWeight.w600)),
                          Text(formattedCreatedAt, style: const TextStyle(fontSize: 12, color: _zTextMain, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.update, size: 14, color: _zTextMuted),
                          const SizedBox(width: 6),
                          const Text('Last Updated: ', style: TextStyle(fontSize: 12, color: _zTextMuted, fontWeight: FontWeight.w600)),
                          Text(formattedUpdatedAt, style: const TextStyle(fontSize: 12, color: _zTextMain, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String type;

  const _StatusBadge({Key? key, required this.status, required this.type}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.grey.shade700;
    String displayStatus = status.toUpperCase();

    final s = status.toLowerCase();

    if (type == 'Approval') {
      if (s == 'approved') { bgColor = Colors.green.shade50; textColor = Colors.green.shade700; }
      else if (s == 'rejected') { bgColor = Colors.red.shade50; textColor = Colors.red.shade700; }
      else { bgColor = Colors.orange.shade50; textColor = Colors.orange.shade800; displayStatus = 'PENDING APPR'; }
    } else if (type == 'Dispatch') {
      if (s == 'delivered') { bgColor = Colors.green.shade50; textColor = Colors.green.shade700; }
      else if (s == 'shipped') { bgColor = Colors.blue.shade50; textColor = Colors.blue.shade700; }
      else if (s == 'packed') { bgColor = Colors.purple.shade50; textColor = Colors.purple.shade700; }
      else { bgColor = Colors.grey.shade100; textColor = Colors.grey.shade700; displayStatus = 'DISP PENDING'; }
    } else {
      // Order Status
      if (s == 'confirmed') { bgColor = Colors.blue.shade50; textColor = Colors.blue.shade700; }
      else if (s == 'completed') { bgColor = Colors.green.shade50; textColor = Colors.green.shade700; }
      else if (s == 'cancelled') { bgColor = Colors.red.shade50; textColor = Colors.red.shade700; }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: textColor.withOpacity(0.2))),
      child: Text(displayStatus, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}

// Lightweight static skeleton loader
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: _zCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _zBorder, width: 0.8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [_ShimmerBox(width: 120, height: 18), _ShimmerBox(width: 70, height: 22, borderRadius: 6)],
          ),
          const SizedBox(height: 16),
          Row(children: const [_ShimmerBox(width: 16, height: 16, borderRadius: 4), SizedBox(width: 8), _ShimmerBox(width: 180, height: 14)]),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _zBorder),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: const [_ShimmerBox(width: 14, height: 14, borderRadius: 4), SizedBox(width: 6), _ShimmerBox(width: 90, height: 12)]),
              const _ShimmerBox(width: 100, height: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const _ShimmerBox({Key? key, required this.width, required this.height, this.borderRadius = 8}) : super(key: key);
  @override State<_ShimmerBox> createState() => _ShimmerBoxState();
}
class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _animation, builder: (context, child) {
      return Container(width: widget.width, height: widget.height, decoration: BoxDecoration(color: Colors.grey.shade200.withOpacity(_animation.value), borderRadius: BorderRadius.circular(widget.borderRadius)));
    });
  }
}