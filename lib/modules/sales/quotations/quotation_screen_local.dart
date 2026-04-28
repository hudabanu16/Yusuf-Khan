import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import 'quotation_pdf_generator.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);

class QuotationScreenLocal extends StatefulWidget {
  final int? userId;
  final String? currentUserUid;
  final String? companyId;
  final String? quotationId;
  final Map<String, dynamic>? inquirySeed;
  final Map<String, dynamic>? existingQuotation;

  const QuotationScreenLocal({
    super.key,
    this.userId,
    this.currentUserUid,
    this.companyId,
    this.quotationId,
    this.inquirySeed,
    this.existingQuotation,
  });

  @override
  State<QuotationScreenLocal> createState() => _QuotationScreenLocalState();
}

class _QuotationScreenLocalState extends State<QuotationScreenLocal> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'sales';
  String _currentUserName = '';

  String _companyName = '';
  String _companyAddress = '';
  String _companyPhone = '';
  String _companyEmail = '';
  String _companyGst = '';
  String _companyCin = '';
  String _companyPan = '';
  String _companyWebsite = '';
  String _companyBankDetails = '';
  String _companyLogoUrl = '';
  String _companyState = '';

  bool _isLoading = false;
  String? _errorMessage;
  bool _isInterState = false;
  bool _isReadOnly = false;
  int _currentVersion = 1;

  bool get _isAdminOrManager => ['admin', 'manager', 'director', 'md', 'ceo', 'super_admin'].contains(_currentUserRole.toLowerCase());

  String _approvalStatus = 'Pending';
  String _quotationStatus = 'Sent';
  String _paymentStatus = 'Pending';

  String? _selectedCustomerId;
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  String _customerState = '';
  Map<String, dynamic>? _customerInsights;

  final TextEditingController _quoteNumberController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  String? _linkedInquiryId;
  String? _linkedInquiryNumber;
  final TextEditingController _inquiryRefNoteController = TextEditingController();

  DateTime _inquiryDate = DateTime.now();
  DateTime _quoteDate = DateTime.now();
  DateTime? _nextFollowUpDate;
  final TextEditingController _followUpNotesController = TextEditingController();

  final List<String> _inquirySources = const ['Verbal', 'Phone Call', 'In Visit', 'Email', 'WhatsApp', 'Website', 'Other'];
  String _selectedInquirySource = 'Verbal';

  List<QuotationLineItem> _items = [];
  double _globalDiscountPercent = 0.0;

  double _cachedSubtotal = 0.0;
  double _cachedItemDiscount = 0.0;
  double _cachedGlobalDiscountAmount = 0.0;
  double _cachedTaxableAmount = 0.0;
  double _cachedCgst = 0.0;
  double _cachedSgst = 0.0;
  double _cachedIgst = 0.0;
  double _cachedGrandTotal = 0.0;
  double _cachedRoundOff = 0.0;
  double _cachedFinalTotal = 0.0;
  double _advanceAmount = 0.0;
  double _balanceAmount = 0.0;

  List<TermRow> _dynamicTerms = [];
  bool _packingChargesExtra = true;
  double _advancePercent = 50.0;
  double _balancePercent = 50.0;

  final TextEditingController _signNameController = TextEditingController();
  final TextEditingController _signDesignationController = TextEditingController();
  final TextEditingController _signPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    await _loadUserContext();
    await _loadCompanyProfile();
    await _loadUserSettings();

    if (widget.existingQuotation != null) {
      _loadExistingQuotation(widget.existingQuotation!);
    } else {
      await _applyInquirySeedIfNeeded();
      _quoteNumberController.text = 'Auto-generated on Save';
    }

    _calculateTotals();
    if (mounted) setState(() => _isLoading = false);
  }

  void _loadExistingQuotation(Map<String, dynamic> data) {
    _approvalStatus = data['approvalStatus']?.toString() ?? 'Pending';
    _quotationStatus = data['status']?.toString() ?? 'Sent';
    _paymentStatus = data['paymentStatus']?.toString() ?? 'Pending';
    _currentVersion = data['version'] ?? 1;

    if ((_approvalStatus == 'Approved' || _quotationStatus == 'Converted') && !_isAdminOrManager) {
      _isReadOnly = true;
    }

    _quoteNumberController.text = data['quoteNumber']?.toString() ?? '';
    _subjectController.text = data['subject']?.toString() ?? '';
    _quoteDate = (data['quoteDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    _selectedCustomerId = data['customerId']?.toString();
    _clientNameController.text = data['clientName']?.toString() ?? '';
    _addressController.text = data['clientAddress']?.toString() ?? '';
    _emailController.text = data['clientEmail']?.toString() ?? '';
    _mobileController.text = data['clientMobile']?.toString() ?? '';
    _contactPersonController.text = data['contactPerson']?.toString() ?? '';
    _gstController.text = data['gstNo']?.toString() ?? '';
    _isInterState = data['isInterState'] as bool? ?? false;
    _customerState = data['customerState']?.toString() ?? '';

    _linkedInquiryId = data['inquiryId']?.toString();
    _linkedInquiryNumber = data['inquiryNumber']?.toString();
    _selectedInquirySource = data['inquirySource']?.toString() ?? 'Verbal';
    _inquiryDate = (data['inquiryDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    _inquiryRefNoteController.text = data['inquiryReference']?.toString() ?? '';

    _nextFollowUpDate = (data['nextFollowUpDate'] as Timestamp?)?.toDate();
    _followUpNotesController.text = data['followUpNotes']?.toString() ?? '';

    if (data['items'] != null) {
      _items = (data['items'] as List).map((i) => QuotationLineItem.fromMap(i as Map<String, dynamic>)).toList();
    }

    _globalDiscountPercent = double.tryParse(data['globalDiscountPercent']?.toString() ?? '0') ?? 0.0;

    _packingChargesExtra = data['packingChargesExtra'] as bool? ?? true;
    _advancePercent = double.tryParse(data['advancePercent']?.toString() ?? '50') ?? 50.0;
    _balancePercent = double.tryParse(data['balancePercent']?.toString() ?? '50') ?? 50.0;

    _signNameController.text = data['signatureName']?.toString() ?? '';
    _signDesignationController.text = data['signatureDesignation']?.toString() ?? '';
    _signPhoneController.text = data['signaturePhone']?.toString() ?? '';

    for (var t in _dynamicTerms) {
      t.dispose();
    }
    _dynamicTerms.clear();

    if (data['dynamicTerms'] != null) {
      _dynamicTerms = (data['dynamicTerms'] as List).map((e) => TermRow(
          title: e['title']?.toString() ?? '',
          value: e['value']?.toString() ?? ''
      )).toList();
    } else {
      void addIfValid(String title, String? val) {
        if (val != null && val.trim().isNotEmpty) {
          _dynamicTerms.add(TermRow(title: title, value: val.trim()));
        }
      }
      addIfValid('Payment', data['paymentTerms']);
      addIfValid('Delivery Time', data['deliveryTime']);
      addIfValid('Validity', data['validity']);
      addIfValid('Warranty', data['warranty']);
      addIfValid('Price Basis', data['priceBasis']);
      addIfValid('Freight', data['freight']);
      addIfValid('Installation', data['installation']);

      if (data['extraTerms'] != null) {
        for (var t in data['extraTerms']) {
          addIfValid('Term', t.toString());
        }
      }
    }

    if (_selectedCustomerId != null) {
      _fetchCustomerInsights(_selectedCustomerId!);
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _contactPersonController.dispose();
    _gstController.dispose();
    _quoteNumberController.dispose();
    _subjectController.dispose();
    _inquiryRefNoteController.dispose();
    _signNameController.dispose();
    _signDesignationController.dispose();
    _signPhoneController.dispose();
    _followUpNotesController.dispose();
    for (var t in _dynamicTerms) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No logged-in user.');

      final rootUserDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = rootUserDoc.data() ?? {};

      _currentUserUid = user.uid;
      _companyId = widget.companyId?.trim().isNotEmpty == true ? widget.companyId!.trim() : (data['companyId'] ?? '').toString().trim();
      _currentUserRole = (data['role'] ?? 'sales').toString().trim();
      _currentUserName = (data['name'] ?? data['fullName'] ?? '').toString().trim();

      if (_signNameController.text.isEmpty) _signNameController.text = _currentUserName;
      if (_signDesignationController.text.isEmpty) _signDesignationController.text = _currentUserRole.toUpperCase();
    } catch (e) {
      _setError('Failed to load user context.');
    }
  }

  Future<void> _loadCompanyProfile() async {
    if (_companyId == null || _companyId!.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};

      _companyName = (data['companyName'] ?? data['name'] ?? '').toString();
      _companyAddress = (data['address'] ?? '').toString();
      _companyPhone = (data['phone'] ?? data['mobile'] ?? '').toString();
      _companyEmail = (data['email'] ?? '').toString();
      _companyWebsite = (data['website'] ?? '').toString();
      _companyGst = (data['gstNo'] ?? data['gst'] ?? '').toString();
      _companyCin = (data['cin'] ?? '').toString();
      _companyPan = (data['pan'] ?? '').toString();
      _companyBankDetails = (data['bankDetails'] ?? '').toString();
      _companyLogoUrl = (data['logoUrl'] ?? '').toString();
      _companyState = (data['state'] ?? '').toString().trim().toLowerCase();
    } catch (_) {}
  }

  Future<void> _loadCustomerFromFirestore(String customerId) async {
    if (_companyId == null || _companyId!.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('customers').doc(customerId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _selectedCustomerId = customerId;
        _clientNameController.text = (data['companyName'] ?? data['name'] ?? '').toString();
        _addressController.text = (data['address'] ?? data['billingAddress'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _mobileController.text = (data['mobile'] ?? data['phone'] ?? '').toString();
        _contactPersonController.text = (data['contactPerson'] ?? data['contactName'] ?? '').toString();
        _gstController.text = (data['gstNo'] ?? data['gst'] ?? '').toString();
        _customerState = (data['state'] ?? '').toString().trim().toLowerCase();

        _checkInterState();
        _fetchCustomerInsights(customerId);
      }
    } catch (_) {}
  }

  Future<QuotationLineItem?> _hydrateProductItem(Map<String, dynamic> rawItem) async {
    final Map<String, dynamic> i = Map<String, dynamic>.from(rawItem);
    String productId = (i['productId'] ?? i['itemId'] ?? '').toString();
    String name = (i['name'] ?? i['productName'] ?? i['itemName'] ?? '').toString();
    String desc = (i['description'] ?? i['details'] ?? '').toString();
    String hsn = (i['hsnCode'] ?? '').toString();
    double qty = double.tryParse(i['quantity']?.toString() ?? '1') ?? 1.0;
    String uom = (i['uom'] ?? i['unit'] ?? 'Nos').toString();
    double price = double.tryParse(i['unitPrice']?.toString() ?? i['price']?.toString() ?? i['rate']?.toString() ?? '0') ?? 0.0;
    double disc = double.tryParse(i['discountPercent']?.toString() ?? i['discount']?.toString() ?? '0') ?? 0.0;

    double totalGst = double.tryParse(i['gstPercentage']?.toString() ?? i['tax']?.toString() ?? '0') ?? 0.0;
    if (totalGst == 0) {
      totalGst = (double.tryParse(i['cgstPercent']?.toString() ?? '0') ?? 0.0) +
          (double.tryParse(i['sgstPercent']?.toString() ?? '0') ?? 0.0) +
          (double.tryParse(i['igstPercent']?.toString() ?? '0') ?? 0.0);
    }

    double stock = double.tryParse(i['availableStock']?.toString() ?? i['stock']?.toString() ?? '0') ?? 0.0;

    if (productId.isNotEmpty && _companyId != null && _companyId!.isNotEmpty) {
      try {
        final pDoc = await FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('products').doc(productId).get();
        if (pDoc.exists && pDoc.data() != null) {
          final pData = pDoc.data()!;
          if (name.isEmpty) name = (pData['name'] ?? '').toString();
          if (desc.isEmpty) desc = (pData['description'] ?? pData['details'] ?? '').toString();
          if (hsn.isEmpty) hsn = (pData['hsnCode'] ?? pData['hsn'] ?? '').toString();
          if (totalGst == 0) totalGst = double.tryParse(pData['gstPercentage']?.toString() ?? pData['tax']?.toString() ?? '18') ?? 18.0;
          if (price == 0) price = double.tryParse(pData['unitPrice']?.toString() ?? pData['price']?.toString() ?? '0') ?? 0.0;
          if (uom == 'Nos' || uom.isEmpty) uom = (pData['uom'] ?? 'Nos').toString();
          stock = double.tryParse(pData['availableStock']?.toString() ?? pData['stockQuantity']?.toString() ?? stock.toString()) ?? 0.0;
        }
      } catch (_) {}
    }

    return QuotationLineItem(
      id: (i['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      productId: productId,
      name: name,
      description: desc,
      hsnCode: hsn,
      quantity: qty,
      uom: uom,
      unitPrice: price,
      discountPercent: disc,
      cgstPercent: 0.0,
      sgstPercent: 0.0,
      igstPercent: totalGst > 0 ? totalGst : 18.0,
      availableStock: stock,
    );
  }

  Future<void> _applyInquirySeedIfNeeded() async {
    final seed = widget.inquirySeed;
    if (seed == null || seed.isEmpty) return;

    _linkedInquiryId = seed['id']?.toString() ?? seed['inquiryId']?.toString();
    _linkedInquiryNumber = seed['inquiryNumber']?.toString() ?? seed['inquiryCode']?.toString();

    final seededCustomerId = (seed['customerId'] ?? '').toString().trim();
    if (seededCustomerId.isNotEmpty) {
      await _loadCustomerFromFirestore(seededCustomerId);
    } else {
      _clientNameController.text = (seed['customerName'] ?? seed['companyName'] ?? seed['clientName'] ?? '').toString().trim();
      _contactPersonController.text = (seed['contactPerson'] ?? seed['contactName'] ?? '').toString().trim();
      _emailController.text = (seed['email'] ?? seed['contactEmail'] ?? seed['clientEmail'] ?? '').toString().trim();
      _mobileController.text = (seed['mobile'] ?? seed['contactPhone'] ?? seed['contactMobile'] ?? seed['clientMobile'] ?? '').toString().trim();
      _addressController.text = (seed['address'] ?? seed['location'] ?? seed['customerAddress'] ?? seed['clientAddress'] ?? '').toString().trim();
      _gstController.text = (seed['gstNo'] ?? seed['gst'] ?? '').toString().trim();
      _customerState = (seed['state'] ?? seed['customerState'] ?? '').toString().trim().toLowerCase();
      _checkInterState();
    }

    final subject = (seed['subject'] ?? seed['inquirySubject'] ?? '').toString().trim();
    if (subject.isNotEmpty) _subjectController.text = subject;

    final notes = (seed['notes'] ?? seed['description'] ?? seed['inquiryReference'] ?? '').toString().trim();
    final loc = (seed['location'] ?? '').toString().trim();

    List<String> combinedNotes = [];
    if (loc.isNotEmpty) combinedNotes.add("Location: $loc");
    if (notes.isNotEmpty) combinedNotes.add("Notes: $notes");

    if (combinedNotes.isNotEmpty) {
      _inquiryRefNoteController.text = combinedNotes.join('\n');
    }

    final source = (seed['source'] ?? '').toString().trim();
    if (source.isNotEmpty && _inquirySources.contains(source)) {
      _selectedInquirySource = source;
    }

    final rawItems = seed['items'] ?? seed['products'];
    if (rawItems != null && rawItems is List && rawItems.isNotEmpty) {
      List<Future<QuotationLineItem?>> tasks = [];
      for (var rawItem in rawItems) {
        if (rawItem == null || rawItem is! Map) continue;
        tasks.add(_hydrateProductItem(rawItem as Map<String, dynamic>));
      }

      final results = await Future.wait(tasks);
      _items = results.whereType<QuotationLineItem>().toList();
      _recalculateTaxes();
    }
  }

  Future<void> _fetchCustomerInsights(String custId) async {
    if (_companyId == null) return;
    try {
      final snaps = await FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('quotations')
          .where('customerId', isEqualTo: custId)
          .orderBy('createdAt', descending: true)
          .get();

      double totalVal = 0;
      double lastQuote = 0;
      if (snaps.docs.isNotEmpty) {
        lastQuote = double.tryParse(snaps.docs.first.data()['finalTotal']?.toString() ?? snaps.docs.first.data()['grandTotal']?.toString() ?? '0') ?? 0.0;
        for (var d in snaps.docs) {
          totalVal += double.tryParse(d.data()['finalTotal']?.toString() ?? d.data()['grandTotal']?.toString() ?? '0') ?? 0.0;
        }
      }

      if (mounted) {
        setState(() {
          _customerInsights = {
            'count': snaps.docs.length,
            'totalValue': totalVal,
            'lastQuoteAmount': lastQuote,
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserSettings() async {
    if (_currentUserUid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('quotationSettings').doc(_currentUserUid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _packingChargesExtra = data['packingChargesExtra'] as bool? ?? _packingChargesExtra;
        _advancePercent = double.tryParse(data['advancePercent']?.toString() ?? '50') ?? 50.0;
        _balancePercent = double.tryParse(data['balancePercent']?.toString() ?? '50') ?? 50.0;

        if (_signNameController.text.isEmpty) _signNameController.text = data['signatureName']?.toString() ?? _currentUserName;
        if (_signDesignationController.text.isEmpty) _signDesignationController.text = data['signatureDesignation']?.toString() ?? _currentUserRole.toUpperCase();
        if (_signPhoneController.text.isEmpty) _signPhoneController.text = data['signaturePhone']?.toString() ?? '';

        if (widget.existingQuotation == null) {
          if (data['dynamicTerms'] != null && (data['dynamicTerms'] as List).isNotEmpty) {
            _dynamicTerms = (data['dynamicTerms'] as List).map((e) => TermRow(
                title: e['title']?.toString() ?? '',
                value: e['value']?.toString() ?? ''
            )).toList();
          } else {
            _dynamicTerms = [
              TermRow(title: 'Payment', value: 'Advance against PO, balance against PI.'),
              TermRow(title: 'Delivery', value: 'Within 4-6 weeks from PO and advance.'),
              TermRow(title: 'Validity', value: '30 days from date of quotation.'),
              TermRow(title: 'Warranty', value: '12 months from the date of dispatch.'),
            ];
          }
        }
      } else if (widget.existingQuotation == null) {
        _dynamicTerms = [
          TermRow(title: 'Payment', value: 'Advance against PO, balance against PI.'),
          TermRow(title: 'Delivery', value: 'Within 4-6 weeks from PO and advance.'),
          TermRow(title: 'Validity', value: '30 days from date of quotation.'),
          TermRow(title: 'Warranty', value: '12 months from the date of dispatch.'),
        ];
      }
    } catch (_) {}
  }

  void _checkInterState() {
    if (_companyState.isEmpty || _customerState.isEmpty) {
      _isInterState = false;
    } else {
      _isInterState = _companyState.toLowerCase().trim() != _customerState.toLowerCase().trim();
    }
    _recalculateTaxes();
  }

  void _recalculateTaxes() {
    for (var item in _items) {
      double totalGst = item.cgstPercent + item.sgstPercent + item.igstPercent;
      if (totalGst > 0) {
        if (_isInterState) {
          item.igstPercent = totalGst;
          item.cgstPercent = 0.0;
          item.sgstPercent = 0.0;
        } else {
          item.cgstPercent = totalGst / 2;
          item.sgstPercent = totalGst / 2;
          item.igstPercent = 0.0;
        }
      }
    }
    _calculateTotals();
  }

  void _calculateTotals() {
    _cachedSubtotal = 0.0;
    _cachedItemDiscount = 0.0;
    _cachedCgst = 0.0;
    _cachedSgst = 0.0;
    _cachedIgst = 0.0;

    for (var item in _items) {
      _cachedSubtotal += item.subtotal;
      _cachedItemDiscount += item.discountAmount;
      _cachedCgst += item.cgstAmount;
      _cachedSgst += item.sgstAmount;
      _cachedIgst += item.igstAmount;
    }

    _cachedGlobalDiscountAmount = (_cachedSubtotal - _cachedItemDiscount) * (_globalDiscountPercent / 100);
    _cachedTaxableAmount = _cachedSubtotal - _cachedItemDiscount - _cachedGlobalDiscountAmount;
    _cachedGrandTotal = _cachedTaxableAmount + _cachedCgst + _cachedSgst + _cachedIgst;

    _cachedFinalTotal = _cachedGrandTotal.roundToDouble();
    _cachedRoundOff = _cachedFinalTotal - _cachedGrandTotal;

    _advanceAmount = _cachedFinalTotal * (_advancePercent / 100);
    _balanceAmount = _cachedFinalTotal - _advanceAmount;

    if (mounted) setState(() {});
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  String _extractLegacyTerm(String searchTitle) {
    return _dynamicTerms.firstWhere((t) => t.titleCtrl.text.toLowerCase().contains(searchTitle.toLowerCase()), orElse: () => TermRow(title: '', value: '')).valueCtrl.text.trim();
  }

  Future<void> _saveQuotation() async {
    if (_isReadOnly) {
      _showSnack('Document is locked for editing.', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _setError('Please fill required fields.');
      return;
    }
    if (_items.isEmpty) {
      _setError('Add at least one item.');
      return;
    }
    if (_companyId == null || _currentUserUid == null) {
      _setError('System Error: Context missing.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final counterRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('counters').doc('quotation_counter');
      final bool isUpdate = widget.quotationId != null;
      bool isRevision = isUpdate;

      final quoteRef = (isUpdate && !isRevision)
          ? FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('quotations').doc(widget.quotationId)
          : FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('quotations').doc();

      String generatedQuoteNo = _quoteNumberController.text.trim();
      String fyShort = '';

      if (!isUpdate || (isUpdate && _quoteNumberController.text.isEmpty)) {
        final now = DateTime.now();
        final startYear = now.month >= 4 ? now.year : now.year - 1;
        fyShort = '${startYear.toString().substring(2)}-${(startYear + 1).toString().substring(2)}';

        int newSequence = await FirebaseFirestore.instance.runTransaction<int>((tx) async {
          final counterDoc = await tx.get(counterRef);
          int seq = 1;
          if (counterDoc.exists) {
            seq = ((counterDoc.data()?['sequence'] as num?)?.toInt() ?? 0) + 1;
          }
          tx.set(counterRef, {'sequence': seq}, SetOptions(merge: true));
          return seq;
        }).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Network timeout: Failed to generate quotation number.')
        );

        generatedQuoteNo = 'QT/${newSequence.toString().padLeft(4, '0')}/$fyShort';
      }

      final activityLog = {
        'type': isRevision ? 'Revision Created' : (isUpdate ? 'Updated' : 'Created'),
        'status': _quotationStatus,
        'timestamp': Timestamp.now(),
        'byUid': _currentUserUid,
        'byName': _currentUserName,
        'note': isRevision ? 'Revision created from ${widget.quotationId}' : 'Quotation saved.'
      };

      final mappedTerms = _dynamicTerms.map((e) => {'title': e.titleCtrl.text.trim(), 'value': e.valueCtrl.text.trim()}).toList();
      final mappedItems = _items.map((e) => e.toMap()).toList();

      final payload = {
        'id': quoteRef.id,
        'companyId': _companyId,
        'quoteNumber': generatedQuoteNo,
        'subject': _subjectController.text.trim(),
        if (!isUpdate || fyShort.isNotEmpty) 'financialYear': fyShort,
        'quoteDate': Timestamp.fromDate(_quoteDate),
        'status': _quotationStatus,
        'approvalStatus': _approvalStatus,
        'paymentStatus': _paymentStatus,

        'customerId': _selectedCustomerId,
        'clientName': _clientNameController.text.trim(),
        'clientAddress': _addressController.text.trim(),
        'clientEmail': _emailController.text.trim(),
        'clientMobile': _mobileController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'gstNo': _gstController.text.trim(),
        'isInterState': _isInterState,
        'customerState': _customerState,

        'inquiryId': _linkedInquiryId ?? '',
        'inquiryNumber': _linkedInquiryNumber ?? '',
        'inquiryRefNo': _linkedInquiryNumber ?? '',
        'inquirySource': _selectedInquirySource,
        'inquiryDate': Timestamp.fromDate(_inquiryDate),
        'inquiryReference': _inquiryRefNoteController.text.trim(),

        'nextFollowUpDate': _nextFollowUpDate != null ? Timestamp.fromDate(_nextFollowUpDate!) : null,
        'followUpNotes': _followUpNotesController.text.trim(),

        'totalSubtotal': _cachedSubtotal,
        'totalItemDiscount': _cachedItemDiscount,
        'globalDiscountPercent': _globalDiscountPercent,
        'globalDiscountAmount': _cachedGlobalDiscountAmount,
        'totalTaxableAmount': _cachedTaxableAmount,
        'totalCgst': _cachedCgst,
        'totalSgst': _cachedSgst,
        'totalIgst': _cachedIgst,
        'grandTotal': _cachedGrandTotal,
        'roundOff': _cachedRoundOff,
        'finalTotal': _cachedFinalTotal,

        'deliveryTime': _extractLegacyTerm('delivery'),
        'validity': _extractLegacyTerm('validity'),
        'priceBasis': _extractLegacyTerm('price basis'),
        'paymentTerms': _extractLegacyTerm('payment'),
        'warranty': _extractLegacyTerm('warranty'),
        'freight': _extractLegacyTerm('freight'),
        'installation': _extractLegacyTerm('installation'),

        'dynamicTerms': mappedTerms,

        'advancePercent': _advancePercent,
        'balancePercent': _balancePercent,
        'advanceAmount': _advanceAmount,
        'balanceAmount': _balanceAmount,
        'packingChargesExtra': _packingChargesExtra,

        'signatureName': _signNameController.text.trim(),
        'signatureDesignation': _signDesignationController.text.trim(),
        'signaturePhone': _signPhoneController.text.trim(),

        'items': mappedItems,
        'activities': FieldValue.arrayUnion([activityLog]),

        'isActive': true,
        'isDeleted': false,
        'lastEditedBy': _currentUserUid,
        'lastEditedAt': FieldValue.serverTimestamp(),
      };

      if (!isUpdate || isRevision) {
        payload['createdBy'] = _currentUserUid!;
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['version'] = isRevision ? _currentVersion + 1 : 1;
        payload['isLatest'] = true;
        payload['parentQuotationId'] = isRevision ? widget.quotationId : null;
      }

      final batch = FirebaseFirestore.instance.batch();

      if (isRevision) {
        final oldRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('quotations').doc(widget.quotationId);
        batch.update(oldRef, {'isLatest': false, 'updatedAt': FieldValue.serverTimestamp()});
      }

      if (isUpdate && !isRevision) {
        batch.update(quoteRef, payload);
      } else {
        batch.set(quoteRef, payload);
      }

      if (_linkedInquiryId != null && _linkedInquiryId!.isNotEmpty) {
        final inqRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('inquiries').doc(_linkedInquiryId);
        batch.update(inqRef, {
          'status': 'Quoted',
          'quotationId': quoteRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': _currentUserUid,
        });
      }

      await batch.commit().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Network timeout: Failed to commit batch write.')
      );

      if (!_isReadOnly) {
        await FirebaseFirestore.instance.collection('quotationSettings').doc(_currentUserUid).set({
          'dynamicTerms': mappedTerms,
          'advancePercent': _advancePercent,
          'balancePercent': _balancePercent,
          'signatureName': _signNameController.text.trim(),
          'signatureDesignation': _signDesignationController.text.trim(),
          'signaturePhone': _signPhoneController.text.trim(),
          'packingChargesExtra': _packingChargesExtra,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      _showSnack(isRevision ? 'Revision Created Successfully!' : (isUpdate ? 'Quotation Updated!' : 'Quotation Created!'));
      Navigator.pop(context, true);

    } catch (e) {
      _setError('Save Failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _convertToInvoice() async {
    if (!_isAdminOrManager) {
      _showSnack('Only managers or admins can convert to invoice directly.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      final invoiceRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('tax_invoices').doc();
      final quoteRef = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('quotations').doc(widget.quotationId);

      final invoicePayload = {
        'id': invoiceRef.id,
        'companyId': _companyId,
        'referenceQuotationId': widget.quotationId,
        'referenceQuotationNo': _quoteNumberController.text,
        'customerId': _selectedCustomerId,
        'clientName': _clientNameController.text.trim(),
        'items': _items.map((e) => e.toMap()).toList(),
        'totalSubtotal': _cachedSubtotal,
        'totalTaxableAmount': _cachedTaxableAmount,
        'totalCgst': _cachedCgst,
        'totalSgst': _cachedSgst,
        'totalIgst': _cachedIgst,
        'grandTotal': _cachedGrandTotal,
        'roundOff': _cachedRoundOff,
        'finalTotal': _cachedFinalTotal,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _currentUserUid,
      };

      batch.set(invoiceRef, invoicePayload);

      batch.update(quoteRef, {
        'status': 'Converted',
        'convertedToInvoiceId': invoiceRef.id,
        'lastEditedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': _currentUserUid,
        'activities': FieldValue.arrayUnion([{
          'type': 'Converted',
          'status': 'Converted',
          'timestamp': Timestamp.now(),
          'byUid': _currentUserUid,
          'byName': _currentUserName,
          'note': 'Converted to Invoice'
        }])
      });

      await batch.commit().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Network timeout: Failed to convert.')
      );

      if (!mounted) return;
      _showSnack('Successfully converted to Invoice!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnack('Error converting: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _triggerFollowUpReminderLogic() {
    if (_nextFollowUpDate != null) {
      debugPrint("Reminder scheduled for $_nextFollowUpDate");
    }
  }

  Map<String, dynamic> _buildPreviewData() {
    return {
      'quoteNumber': _quoteNumberController.text.contains('Auto') ? 'PREVIEW MODE' : _quoteNumberController.text,
      'quoteDateStr': '${_quoteDate.day.toString().padLeft(2, '0')}/${_quoteDate.month.toString().padLeft(2, '0')}/${_quoteDate.year}',
      'revisionNo': _currentVersion.toString(),
      'inquiryRefNo': _linkedInquiryNumber ?? '',
      'subject': _subjectController.text.trim(),
      'clientName': _clientNameController.text.trim(),
      'clientAddress': _addressController.text.trim(),
      'clientEmail': _emailController.text.trim(),
      'clientMobile': _mobileController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'gstNo': _gstController.text.trim(),
      'customerState': _customerState,
      'isInterState': _isInterState,
      'totalSubtotal': _cachedSubtotal,
      'totalItemDiscount': _cachedItemDiscount,
      'totalTaxableAmount': _cachedTaxableAmount,
      'totalCgst': _cachedCgst,
      'totalSgst': _cachedSgst,
      'totalIgst': _cachedIgst,
      'grandTotal': _cachedGrandTotal,
      'roundOff': _cachedRoundOff,
      'finalTotal': _cachedFinalTotal,
      'advancePercent': _advancePercent,
      'balancePercent': _balancePercent,
      'advanceAmount': _advanceAmount,
      'balanceAmount': _balanceAmount,

      'dynamicTerms': _dynamicTerms.map((e) => {'title': e.titleCtrl.text.trim(), 'value': e.valueCtrl.text.trim()}).toList(),

      'packingChargesExtra': _packingChargesExtra,
      'companyName': _companyName,
      'companyAddress': _companyAddress,
      'companyPhone': _companyPhone,
      'companyEmail': _companyEmail,
      'companyWebsite': _companyWebsite,
      'companyGst': _companyGst,
      'companyCin': _companyCin,
      'companyPan': _companyPan,
      'companyBankDetails': _companyBankDetails,
      'companyLogoUrl': _companyLogoUrl,
      'signatureName': _signNameController.text.trim(),
      'signatureDesignation': _signDesignationController.text.trim(),
    };
  }

  void _onPreviewPressed() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add items before previewing.'), backgroundColor: Colors.red));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuotationPreviewScreen(quotation: _buildPreviewData(), items: _items)),
    );
  }

  void _showSnack(String message, {bool isInfo = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : (isInfo ? Colors.blue : Colors.green),
        )
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
  );

  Widget _buildSectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          if (trailing != null) const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _selectCustomerDialog() async {
    final searchController = TextEditingController();
    String searchText = '';

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('customers');
    if (!_isAdminOrManager && _currentUserUid != null) {
      query = query.where('createdBy', isEqualTo: _currentUserUid);
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Customer', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by company, person, or phone...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => setDialogState(() => searchText = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data?.docs ?? [];
                      final filtered = docs.where((doc) {
                        final data = doc.data();
                        final searchStr = '${data['companyName']} ${data['contactPerson']} ${data['mobile']}'.toLowerCase();
                        return searchText.isEmpty || searchStr.contains(searchText);
                      }).toList();

                      if (filtered.isEmpty) return const Center(child: Text('No customers found.'));

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = filtered[index].data();
                          return ListTile(
                            title: Text(data['companyName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${data['contactPerson'] ?? ''} | ${data['mobile'] ?? ''}'),
                            onTap: () => Navigator.pop(context, {'id': filtered[index].id, ...data}),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }

  void _applyCustomer(Map<String, dynamic> customer) {
    if (customer['id'] != null) {
      _loadCustomerFromFirestore(customer['id']);
    }
  }

  Future<Map<String, dynamic>?> _selectProductDialog() async {
    final searchController = TextEditingController();
    String searchText = '';

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('products').where('isActive', isEqualTo: true);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Product from Inventory', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by product name or SKU...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => setDialogState(() => searchText = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final docs = snapshot.data?.docs ?? [];
                      final filtered = docs.where((doc) {
                        final data = doc.data();
                        final searchStr = '${data['name']} ${data['sku']} ${data['description']}'.toLowerCase();
                        return searchText.isEmpty || searchStr.contains(searchText);
                      }).toList();

                      if (filtered.isEmpty) return const Center(child: Text('No products found in inventory.'));

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = filtered[index].data();
                          final stock = double.tryParse(data['availableStock']?.toString() ?? data['stockQuantity']?.toString() ?? '0') ?? 0;
                          return ListTile(
                            title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Price: ₹${data['unitPrice'] ?? 0} | Tax: ${data['gstPercentage'] ?? 0}% | Stock: $stock ${data['uom'] ?? 'Nos'}'),
                            trailing: stock <= 0 ? const Icon(Icons.warning, color: Colors.orange) : const Icon(Icons.check_circle, color: Colors.green),
                            onTap: () => Navigator.pop(context, {'id': filtered[index].id, 'stock': stock, ...data}),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      ),
    );
  }

  void _showAddItemModal([QuotationLineItem? itemToEdit, int? index]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: itemToEdit?.name ?? '');
    final descCtrl = TextEditingController(text: itemToEdit?.description ?? '');
    final hsnCtrl = TextEditingController(text: itemToEdit?.hsnCode ?? '');
    final qtyCtrl = TextEditingController(text: itemToEdit?.quantity.toString() ?? '1');
    final priceCtrl = TextEditingController(text: itemToEdit?.unitPrice.toString() ?? '');
    final uomCtrl = TextEditingController(text: itemToEdit?.uom ?? 'Nos');
    final discCtrl = TextEditingController(text: itemToEdit?.discountPercent.toString() ?? '0');

    double totalGst = (itemToEdit?.cgstPercent ?? 0) + (itemToEdit?.sgstPercent ?? 0) + (itemToEdit?.igstPercent ?? 0);
    final gstCtrl = TextEditingController(text: itemToEdit != null ? (totalGst > 0 ? totalGst.toString() : '18') : '18');

    String currentId = itemToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    String productId = itemToEdit?.productId ?? '';
    double currentStock = itemToEdit?.availableStock ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: Form(
            key: formKey,
            child: StatefulBuilder(
                builder: (context, setModalState) {
                  double parsedQty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
                  bool stockWarning = productId.isNotEmpty && parsedQty > currentStock;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(itemToEdit == null ? 'Add Product/Service' : 'Edit Line Item',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                            TextButton.icon(
                              icon: const Icon(Icons.inventory_2),
                              label: const Text('Pick from Inventory'),
                              onPressed: () async {
                                final p = await _selectProductDialog();
                                if (p != null) {
                                  setModalState(() {
                                    productId = p['id'];

                                    if (nameCtrl.text.trim().isEmpty) nameCtrl.text = p['name'] ?? '';
                                    if (descCtrl.text.trim().isEmpty) descCtrl.text = p['description'] ?? p['details'] ?? '';
                                    if (hsnCtrl.text.trim().isEmpty) hsnCtrl.text = p['hsnCode'] ?? p['hsn'] ?? '';

                                    if (priceCtrl.text.trim().isEmpty || priceCtrl.text == '0' || priceCtrl.text == '0.0') {
                                      priceCtrl.text = (p['unitPrice'] ?? p['price'] ?? p['rate'] ?? 0).toString();
                                    }

                                    uomCtrl.text = p['uom'] ?? 'Nos';

                                    String currentGst = gstCtrl.text.trim();
                                    if (currentGst.isEmpty || currentGst == '0' || currentGst == '18' || currentGst == '18.0') {
                                      double pGst = double.tryParse(p['gstPercentage']?.toString() ?? p['tax']?.toString() ?? '18') ?? 18;
                                      gstCtrl.text = pGst.toString();
                                    }

                                    currentStock = p['stock'] ?? 0;
                                  });
                                }
                              },
                            )
                          ],
                        ),
                        const Divider(),
                        if (productId.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: stockWarning ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                'Available Stock: $currentStock ${uomCtrl.text}',
                                style: TextStyle(color: stockWarning ? Colors.orange.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12)
                            ),
                          ),
                        _buildItemTextField(nameCtrl, 'Item Name *', validator: (v) => v!.isEmpty ? 'Required' : null),
                        _buildItemTextField(hsnCtrl, 'HSN / SAC Code'),
                        _buildItemTextField(descCtrl, 'Specification / Description', maxLines: null, hint: 'Enter features line by line for bullet points in PDF'),
                        Row(
                          children: [
                            Expanded(child: _buildItemTextField(qtyCtrl, 'Quantity', keyboardType: TextInputType.number, onChanged: (v) => setModalState((){}))),
                            const SizedBox(width: 10),
                            Expanded(child: _buildItemTextField(uomCtrl, 'UOM (e.g., Nos, Kgs)')),
                          ],
                        ),
                        if (stockWarning)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('⚠️ Warning: Quantity exceeds available inventory stock.', style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        Row(
                          children: [
                            Expanded(child: _buildItemTextField(priceCtrl, 'Unit Price *', keyboardType: TextInputType.number)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildItemTextField(discCtrl, 'Discount (%)', keyboardType: TextInputType.number)),
                          ],
                        ),
                        _buildItemTextField(gstCtrl, 'GST (%)', keyboardType: TextInputType.number, hint: 'Default is 18%'),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;

                            double gstVal = double.tryParse(gstCtrl.text.trim()) ?? 18.0;
                            double cgst = 0, sgst = 0, igst = 0;
                            if (_isInterState) {
                              igst = gstVal;
                            } else {
                              cgst = gstVal / 2;
                              sgst = gstVal / 2;
                            }

                            final newItem = QuotationLineItem(
                              id: currentId,
                              productId: productId,
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              hsnCode: hsnCtrl.text.trim(),
                              quantity: double.tryParse(qtyCtrl.text.trim()) ?? 1,
                              uom: uomCtrl.text.trim().isEmpty ? 'Nos' : uomCtrl.text.trim(),
                              unitPrice: double.tryParse(priceCtrl.text.trim()) ?? 0,
                              discountPercent: double.tryParse(discCtrl.text.trim()) ?? 0,
                              cgstPercent: cgst,
                              sgstPercent: sgst,
                              igstPercent: igst,
                              availableStock: currentStock,
                            );

                            setState(() {
                              if (index != null) _items[index] = newItem;
                              else _items.add(newItem);
                              _calculateTotals();
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Save Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                }
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemTextField(TextEditingController controller, String label, {TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator, int? maxLines = 1, String? hint, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        onChanged: onChanged,
        readOnly: _isReadOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          filled: true,
          fillColor: _isReadOnly ? Colors.grey.shade100 : Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _calcRow(String label, double amount, {bool bold = false, double size = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: size, color: color ?? Colors.grey.shade700)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: size, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
        title: Text(widget.quotationId != null ? 'Edit Quotation' : 'Create Quotation', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _onPreviewPressed,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Preview'),
            style: TextButton.styleFrom(foregroundColor: accentColor),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isReadOnly)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(Icons.lock, color: Colors.green.shade800, size: 20),
                              const SizedBox(width: 8),
                              Text('This document is $_approvalStatus and locked for editing.', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, border: Border.all(color: Colors.red.shade200), borderRadius: BorderRadius.circular(8)),
                          child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600)),
                        ),

                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Customer Details', Icons.business,
                                trailing: _isReadOnly ? null : OutlinedButton.icon(
                                  onPressed: () async {
                                    final c = await _selectCustomerDialog();
                                    if (c != null) _applyCustomer(c);
                                  },
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text('CRM Lookup'),
                                  style: OutlinedButton.styleFrom(foregroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                )
                            ),
                            if (_customerInsights != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(children: [Text('Total Quotes', style: TextStyle(fontSize: 10, color: Colors.blue.shade800)), Text('${_customerInsights!['count']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                                    Column(children: [Text('Last Quote', style: TextStyle(fontSize: 10, color: Colors.blue.shade800)), Text('₹${_customerInsights!['lastQuoteAmount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                                    Column(children: [Text('Lifetime Value', style: TextStyle(fontSize: 10, color: Colors.blue.shade800)), Text('₹${_customerInsights!['totalValue']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                                  ],
                                ),
                              ),
                            _buildItemTextField(_clientNameController, 'Company Name *', validator: (v) => v!.isEmpty ? 'Required' : null),
                            _buildItemTextField(_addressController, 'Billing Address', maxLines: 2),
                            Row(
                              children: [
                                Expanded(child: _buildItemTextField(_contactPersonController, 'Contact Person')),
                                const SizedBox(width: 10),
                                Expanded(child: _buildItemTextField(_mobileController, 'Mobile')),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: _buildItemTextField(_emailController, 'Email ID')),
                                const SizedBox(width: 10),
                                Expanded(child: _buildItemTextField(_gstController, 'GSTIN')),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Quotation & Inquiry Link', Icons.link),
                            if (_linkedInquiryId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text('Linked Inquiry: $_linkedInquiryNumber. Status will auto-update to "Quoted".', style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            _buildItemTextField(_subjectController, 'Subject Line *', validator: (v) => v!.isEmpty ? 'Required' : null),
                            Row(
                              children: [
                                Expanded(child: _buildItemTextField(_quoteNumberController, 'Quotation No.')),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: _isReadOnly ? null : () async {
                                      final d = await showDatePicker(context: context, initialDate: _quoteDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                      if (d != null) setState(() => _quoteDate = d);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(labelText: 'Quote Date', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: _isReadOnly ? Colors.grey.shade100 : Colors.grey.shade50, isDense: true),
                                      child: Text('${_quoteDate.day}/${_quoteDate.month}/${_quoteDate.year}'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Line Items', Icons.inventory_2_outlined,
                                trailing: _isReadOnly ? null : ElevatedButton.icon(
                                  onPressed: _showAddItemModal,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Item'),
                                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                )
                            ),
                            if (_items.isEmpty)
                              Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('No items added yet.', style: TextStyle(color: Colors.grey.shade500))))
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = _items[i];

                                  bool isOutOfStock = item.availableStock <= 0;
                                  bool isLowStock = item.availableStock < item.quantity && !isOutOfStock;
                                  Color stockColor = isOutOfStock ? Colors.red : (isLowStock ? Colors.orange : Colors.green);
                                  String stockText = isOutOfStock ? 'Out of Stock' : (isLowStock ? 'Low Stock' : 'In Stock');

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (item.hsnCode.isNotEmpty) Text('HSN/SAC: ${item.hsnCode}'),
                                        Text('${item.quantity} ${item.uom} x ₹${item.unitPrice.toStringAsFixed(2)}\nTax: ${item.cgstPercent+item.sgstPercent+item.igstPercent}% | Disc: ${item.discountPercent}%'),
                                        if (item.productId.isNotEmpty)
                                          Text('Inventory: $stockText (${item.availableStock} available)', style: TextStyle(fontSize: 10, color: stockColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('₹${item.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        if (!_isReadOnly) IconButton(icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20), onPressed: () => _showAddItemModal(item, i)),
                                        if (!_isReadOnly) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () {
                                          setState(() {
                                            _items.removeAt(i);
                                            _calculateTotals();
                                          });
                                        }),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            const Divider(height: 32, thickness: 1.5),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 300,
                                child: Column(
                                  children: [
                                    _calcRow('Subtotal', _cachedSubtotal),
                                    _calcRow('Item Discounts', -_cachedItemDiscount, color: Colors.red),
                                    _calcRow('Taxable Value', _cachedTaxableAmount, bold: true),
                                    if (!_isInterState) ...[
                                      _calcRow('CGST', _cachedCgst),
                                      _calcRow('SGST', _cachedSgst),
                                    ] else ...[
                                      _calcRow('IGST', _cachedIgst),
                                    ],
                                    if (_cachedRoundOff != 0)
                                      _calcRow('Round Off', _cachedRoundOff),
                                    const Divider(),
                                    _calcRow('FINAL TOTAL', _cachedFinalTotal, bold: true, size: 18, color: primaryColor),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),

                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('Payment Structure', Icons.account_balance_wallet_outlined),
                            Row(
                              children: [
                                Expanded(
                                    child: TextFormField(
                                      initialValue: _advancePercent.toString(),
                                      keyboardType: TextInputType.number,
                                      readOnly: _isReadOnly,
                                      decoration: InputDecoration(labelText: 'Advance %', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
                                      onChanged: (v) {
                                        double adv = double.tryParse(v) ?? 0;
                                        if (adv > 100) adv = 100;
                                        setState(() {
                                          _advancePercent = adv;
                                          _balancePercent = 100 - adv;
                                          _calculateTotals();
                                        });
                                      },
                                    )
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: TextFormField(
                                      controller: TextEditingController(text: _balancePercent.toString()),
                                      readOnly: true,
                                      decoration: InputDecoration(labelText: 'Balance %', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true, filled: true, fillColor: Colors.grey.shade100),
                                    )
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (!_isReadOnly)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Packing & Forwarding Extra', style: TextStyle(fontSize: 14)),
                                value: _packingChargesExtra,
                                onChanged: (v) => setState(() => _packingChargesExtra = v),
                              ),

                            const Divider(height: 30),

                            _buildSectionHeader('Terms & Conditions', Icons.gavel_outlined,
                                trailing: _isReadOnly ? null : OutlinedButton.icon(
                                  onPressed: () => setState(() => _dynamicTerms.add(TermRow())),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Term'),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: accentColor,
                                      side: const BorderSide(color: accentColor),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: Size.zero
                                  ),
                                )
                            ),

                            ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _dynamicTerms.length,
                                itemBuilder: (ctx, i) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 3, child: _buildItemTextField(_dynamicTerms[i].titleCtrl, 'Title (e.g. Payment)', maxLines: 1)),
                                        const SizedBox(width: 10),
                                        Expanded(flex: 7, child: _buildItemTextField(_dynamicTerms[i].valueCtrl, 'Term Detail', maxLines: null)),
                                        if (!_isReadOnly)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => setState(() => _dynamicTerms.removeAt(i)),
                                          )
                                      ],
                                    ),
                                  );
                                }
                            ),

                            const Divider(height: 30),

                            _buildSectionHeader('Signature Details', Icons.edit_document),
                            Row(
                              children: [
                                Expanded(child: _buildItemTextField(_signNameController, 'Signatory Name')),
                                const SizedBox(width: 10),
                                Expanded(child: _buildItemTextField(_signDesignationController, 'Designation')),
                              ],
                            ),
                            const Divider(height: 30),

                            const Text('Follow-up Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _isReadOnly ? null : () async {
                                      final d = await showDatePicker(context: context, initialDate: _nextFollowUpDate ?? DateTime.now().add(const Duration(days: 3)), firstDate: DateTime.now(), lastDate: DateTime(2100));
                                      if (d != null) setState(() => _nextFollowUpDate = d);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(labelText: 'Next Follow-up', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: _isReadOnly ? Colors.grey.shade100 : Colors.orange.shade50, isDense: true),
                                      child: Text(_nextFollowUpDate != null ? '${_nextFollowUpDate!.day}/${_nextFollowUpDate!.month}/${_nextFollowUpDate!.year}' : 'Select Date'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: _buildItemTextField(_followUpNotesController, 'Follow-up Notes')),
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

            Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
                ),
                child: SafeArea(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Final Total', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                Text('₹ ${_cachedFinalTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                              ]
                          ),
                          Row(
                              children: [
                                if (_quotationStatus != 'Converted' && (_approvalStatus == 'Approved' || _isAdminOrManager) && widget.quotationId != null)
                                  OutlinedButton(
                                      onPressed: _convertToInvoice,
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: primaryColor), foregroundColor: primaryColor),
                                      child: const Text('Convert to SO')
                                  ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                    onPressed: _isReadOnly || _isLoading ? null : _saveQuotation,
                                    icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                                    label: const Text('Save Quotation'),
                                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white)
                                )
                              ]
                          )
                        ]
                    )
                )
            )
          ],
        ),
      ),
    );
  }
}