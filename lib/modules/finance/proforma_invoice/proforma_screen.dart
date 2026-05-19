// ==========================================
// FILE 1: lib/modules/finance/proforma_invoice/proforma_screen.dart
// ==========================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'proforma_invoice_pdf_generator.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);
const String proformaSeriesPrefix = 'PI';

// ==========================================
// MODELS
// ==========================================
class ProformaLocalItem {
  String id;
  String productId;
  String name;
  String description;
  String hsnCode;
  double quantity;
  String uom;
  double unitPrice;
  double discountPercent;
  double cgstPercent;
  double sgstPercent;
  double igstPercent;
  double availableStock;

  ProformaLocalItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.description,
    required this.hsnCode,
    required this.quantity,
    required this.uom,
    required this.unitPrice,
    required this.discountPercent,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.igstPercent,
    required this.availableStock,
  });

  double get subtotal => quantity * unitPrice;
  double get discountAmount => subtotal * (discountPercent / 100);
  double get taxableAmount => subtotal - discountAmount;
  double get cgstAmount => taxableAmount * (cgstPercent / 100);
  double get sgstAmount => taxableAmount * (sgstPercent / 100);
  double get igstAmount => taxableAmount * (igstPercent / 100);
  double get taxAmount => cgstAmount + sgstAmount + igstAmount;
  double get totalAmount => taxableAmount + taxAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'description': description,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'uom': uom,
      'unitPrice': unitPrice,
      'discountPercent': discountPercent,
      'cgstPercent': cgstPercent,
      'sgstPercent': sgstPercent,
      'igstPercent': igstPercent,
      'availableStock': availableStock,
    };
  }

  factory ProformaLocalItem.fromMap(Map<String, dynamic> map) {
    return ProformaLocalItem(
      id: map['id']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      hsnCode: map['hsnCode']?.toString() ?? '',
      quantity: double.tryParse(map['quantity']?.toString() ?? '0') ?? 0.0,
      uom: map['uom']?.toString() ?? 'Nos',
      unitPrice: double.tryParse(map['unitPrice']?.toString() ?? '0') ?? 0.0,
      discountPercent:
          double.tryParse(map['discountPercent']?.toString() ?? '0') ?? 0.0,
      cgstPercent:
          double.tryParse(map['cgstPercent']?.toString() ?? '0') ?? 0.0,
      sgstPercent:
          double.tryParse(map['sgstPercent']?.toString() ?? '0') ?? 0.0,
      igstPercent:
          double.tryParse(map['igstPercent']?.toString() ?? '0') ?? 0.0,
      availableStock:
          double.tryParse(map['availableStock']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class ProformaTermRow {
  final TextEditingController titleCtrl;
  final TextEditingController valueCtrl;

  ProformaTermRow({String title = '', String value = ''})
    : titleCtrl = TextEditingController(text: title),
      valueCtrl = TextEditingController(text: value);

  void dispose() {
    titleCtrl.dispose();
    valueCtrl.dispose();
  }
}

// ==========================================
// SCREEN
// ==========================================
class ProformaScreen extends StatefulWidget {
  final String companyId;
  final String? proformaId;
  final Map<String, dynamic>? inquirySeed;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? existingProforma;
  final String? source;

  const ProformaScreen({
    super.key,
    required this.companyId,
    this.proformaId,
    this.inquirySeed,
    this.initialData,
    this.existingProforma,
    this.source,
  });

  @override
  State<ProformaScreen> createState() => _ProformaScreenState();
}

class _ProformaScreenState extends State<ProformaScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _currentUserUid;
  String _currentUserName = '';

  String _companyName = '';
  String _companyAddress = '';
  String _companyPhone = '';
  String _companyEmail = '';
  String _companyGst = '';
  String _companyCin = '';
  String _companyPan = '';
  String _companyWebsite = '';
  dynamic _companyBankDetails;
  String _companyLogoUrl = '';
  String _companyState = '';
  String _proformaPrefix = proformaSeriesPrefix;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isInterState = false;

  String? _selectedCustomerId;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _billingAddressController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _customerStateController =
      TextEditingController();
  Map<String, dynamic>? _customerInsights;

  bool _isSameAsBilling = false;
  final TextEditingController _shippingNameController = TextEditingController();
  final TextEditingController _shippingAddressController =
      TextEditingController();
  final TextEditingController _shippingEmailController =
      TextEditingController();
  final TextEditingController _shippingMobileController =
      TextEditingController();
  final TextEditingController _shippingContactPersonController =
      TextEditingController();
  final TextEditingController _shippingGstController = TextEditingController();
  final TextEditingController _shippingStateController =
      TextEditingController();

  final TextEditingController _proformaNumberController =
      TextEditingController();
  final TextEditingController _subjectController = TextEditingController();

  // Document Links Pipeline
  String? _linkedInquiryId;
  String? _linkedInquiryNumber;
  String? _linkedQuotationNumber;
  String? _linkedSalesOrderNumber;

  final TextEditingController _inquiryRefNoteController =
      TextEditingController();

  DateTime _inquiryDate = DateTime.now();
  DateTime _proformaDate = DateTime.now();
  DateTime? _nextFollowUpDate;
  final TextEditingController _followUpNotesController =
      TextEditingController();

  final List<String> _inquirySources = const [
    'Verbal',
    'Phone Call',
    'In Visit',
    'Email',
    'WhatsApp',
    'Website',
    'Other',
  ];
  String _selectedInquirySource = 'Verbal';

  List<ProformaLocalItem> _items = [];
  double _globalDiscountPercent = 0.0;

  double _cachedSubtotal = 0.0;
  double _cachedItemDiscount = 0.0;
  double _cachedGlobalDiscountAmount = 0.0;
  double _cachedTaxableAmount = 0.0;
  double _cachedCgst = 0.0;
  double _cachedSgst = 0.0;
  double _cachedIgst = 0.0;
  double _cachedTaxAmount = 0.0;
  double _cachedGrandTotal = 0.0;
  double _cachedRoundOff = 0.0;
  double _cachedFinalTotal = 0.0;

  double _advancePercent = 50.0;
  double _balancePercent = 50.0;
  double _advanceAmount = 0.0;
  double _balanceAmount = 0.0;

  final TextEditingController _advancePercentController = TextEditingController(
    text: '50.0',
  );
  final TextEditingController _balancePercentController = TextEditingController(
    text: '50.0',
  );

  List<ProformaTermRow> _dynamicTerms = [];
  bool _packingChargesExtra = true;

  final TextEditingController _accountHolderNameController =
      TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _branchAddressController =
      TextEditingController();
  final TextEditingController _branchCodeController = TextEditingController();
  final TextEditingController _micrController = TextEditingController();
  final TextEditingController _swiftController = TextEditingController();

  final TextEditingController _signNameController = TextEditingController();
  final TextEditingController _signDesignationController =
      TextEditingController();
  final TextEditingController _signPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupSyncListeners();
    _initializeScreen();
  }

  void _setupSyncListeners() {
    _customerNameController.addListener(() {
      if (_isSameAsBilling) {
        _shippingNameController.text = _customerNameController.text;
      }
    });
    _billingAddressController.addListener(() {
      if (_isSameAsBilling) {
        _shippingAddressController.text = _billingAddressController.text;
      }
    });
    _emailController.addListener(() {
      if (_isSameAsBilling) {
        _shippingEmailController.text = _emailController.text;
      }
    });
    _mobileController.addListener(() {
      if (_isSameAsBilling) {
        _shippingMobileController.text = _mobileController.text;
      }
    });
    _contactPersonController.addListener(() {
      if (_isSameAsBilling) {
        _shippingContactPersonController.text = _contactPersonController.text;
      }
    });
    _gstController.addListener(() {
      if (_isSameAsBilling) _shippingGstController.text = _gstController.text;
    });
    _customerStateController.addListener(() {
      if (_isSameAsBilling) {
        _shippingStateController.text = _customerStateController.text;
        _checkInterState();
      }
    });
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    await _loadUserContext();
    await _loadCompanyProfile();
    await _loadUserSettings();

    if (widget.existingProforma != null) {
      _loadExistingProforma(widget.existingProforma!);
    } else if (widget.proformaId != null) {
      await _fetchProformaById(widget.proformaId!);
    } else {
      await _applyInquirySeedIfNeeded();
      _proformaNumberController.text = 'Auto-generated on Save';
    }

    _calculateTotals();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchProformaById(String pid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .doc(pid)
          .get();
      if (doc.exists && doc.data() != null) {
        _loadExistingProforma(doc.data()!);
      }
    } catch (e) {
      _setError('Failed to load Proforma details.');
    }
  }

  void _copyBillingToShipping() {
    _shippingNameController.text = _customerNameController.text;
    _shippingAddressController.text = _billingAddressController.text;
    _shippingEmailController.text = _emailController.text;
    _shippingMobileController.text = _mobileController.text;
    _shippingContactPersonController.text = _contactPersonController.text;
    _shippingGstController.text = _gstController.text;
    _shippingStateController.text = _customerStateController.text;
  }

  void _applyBankDetails(dynamic bankData) {
    if (bankData is Map) {
      _accountHolderNameController.text =
          bankData['accountHolderName']?.toString() ?? '';
      _bankNameController.text = bankData['bankName']?.toString() ?? '';
      _accountNumberController.text =
          bankData['accountNumber']?.toString() ?? '';
      _ifscController.text = bankData['ifsc']?.toString() ?? '';
      _branchController.text = bankData['branch']?.toString() ?? '';
      _branchAddressController.text =
          bankData['branchAddress']?.toString() ?? '';
      _branchCodeController.text = bankData['branchCode']?.toString() ?? '';
      _micrController.text = bankData['micr']?.toString() ?? '';
      _swiftController.text = bankData['swift']?.toString() ?? '';
    } else if (bankData is String && bankData.isNotEmpty) {
      _accountHolderNameController.text = '';
      _bankNameController.text = bankData;
      _accountNumberController.text = '';
      _ifscController.text = '';
      _branchController.text = '';
      _branchAddressController.text = '';
      _branchCodeController.text = '';
      _micrController.text = '';
      _swiftController.text = '';
    }
  }

  void _loadExistingProforma(Map<String, dynamic> data) {
    _proformaNumberController.text = data['proformaNumber']?.toString() ?? '';
    _subjectController.text = data['subject']?.toString() ?? '';
    _proformaDate =
        (data['proformaDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    _selectedCustomerId = data['customerId']?.toString();
    _customerNameController.text =
        data['customerName']?.toString() ??
        data['clientName']?.toString() ??
        '';
    _billingAddressController.text =
        data['billingAddress']?.toString() ??
        data['clientAddress']?.toString() ??
        '';
    _emailController.text =
        data['email']?.toString() ?? data['clientEmail']?.toString() ?? '';
    _mobileController.text =
        data['mobile']?.toString() ?? data['clientMobile']?.toString() ?? '';
    _contactPersonController.text = data['contactPerson']?.toString() ?? '';
    _gstController.text = data['gstNo']?.toString() ?? '';
    _customerStateController.text = data['customerState']?.toString() ?? '';

    _isSameAsBilling = data['isSameAsBilling'] as bool? ?? false;
    _shippingNameController.text = data['shippingName']?.toString() ?? '';
    _shippingAddressController.text = data['shippingAddress']?.toString() ?? '';
    _shippingEmailController.text = data['shippingEmail']?.toString() ?? '';
    _shippingMobileController.text = data['shippingMobile']?.toString() ?? '';
    _shippingContactPersonController.text =
        data['shippingContactPerson']?.toString() ?? '';
    _shippingGstController.text = data['shippingGst']?.toString() ?? '';
    _shippingStateController.text = data['shippingState']?.toString() ?? '';

    _linkedInquiryId = data['inquiryId']?.toString();
    _linkedInquiryNumber = data['inquiryNumber']?.toString();
    _linkedQuotationNumber = data['quotationNumber']?.toString();
    _linkedSalesOrderNumber = data['salesOrderNumber']?.toString();

    _selectedInquirySource = data['inquirySource']?.toString() ?? 'Verbal';
    _inquiryDate =
        (data['inquiryDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    _inquiryRefNoteController.text = data['inquiryReference']?.toString() ?? '';

    _nextFollowUpDate = (data['nextFollowUpDate'] as Timestamp?)?.toDate();
    _followUpNotesController.text = data['followUpNotes']?.toString() ?? '';

    if (data['items'] != null) {
      _items = (data['items'] as List)
          .map((i) => ProformaLocalItem.fromMap(i as Map<String, dynamic>))
          .toList();
    }

    _globalDiscountPercent =
        double.tryParse(data['globalDiscountPercent']?.toString() ?? '0') ??
        0.0;

    _packingChargesExtra = data['packingChargesExtra'] as bool? ?? true;
    _advancePercent =
        double.tryParse(data['advancePercent']?.toString() ?? '50') ?? 50.0;
    _balancePercent =
        double.tryParse(data['balancePercent']?.toString() ?? '50') ?? 50.0;

    _advancePercentController.text = _advancePercent.toString();
    _balancePercentController.text = _balancePercent.toString();

    dynamic loadedBankDetails = data['bankDetails'];
    if (loadedBankDetails != null &&
        (loadedBankDetails is Map
            ? loadedBankDetails.isNotEmpty
            : loadedBankDetails.toString().isNotEmpty)) {
      _applyBankDetails(loadedBankDetails);
    } else {
      _applyBankDetails(_companyBankDetails);
    }

    _signNameController.text = data['signatureName']?.toString() ?? '';
    if (data.containsKey('signatureDesignation')) {
      _signDesignationController.text =
          data['signatureDesignation']?.toString() ?? '';
    }
    _signPhoneController.text = data['signaturePhone']?.toString() ?? '';

    for (var t in _dynamicTerms) {
      t.dispose();
    }
    _dynamicTerms.clear();

    if (data['dynamicTerms'] != null) {
      _dynamicTerms = (data['dynamicTerms'] as List)
          .map(
            (e) => ProformaTermRow(
              title: e['title']?.toString() ?? '',
              value: e['value']?.toString() ?? '',
            ),
          )
          .toList();
    } else {
      void addIfValid(String title, String? val) {
        if (val != null && val.trim().isNotEmpty) {
          _dynamicTerms.add(ProformaTermRow(title: title, value: val.trim()));
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

    _checkInterState();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _billingAddressController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _contactPersonController.dispose();
    _gstController.dispose();
    _customerStateController.dispose();

    _shippingNameController.dispose();
    _shippingAddressController.dispose();
    _shippingEmailController.dispose();
    _shippingMobileController.dispose();
    _shippingContactPersonController.dispose();
    _shippingGstController.dispose();
    _shippingStateController.dispose();

    _proformaNumberController.dispose();
    _subjectController.dispose();
    _inquiryRefNoteController.dispose();

    _advancePercentController.dispose();
    _balancePercentController.dispose();

    _accountHolderNameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _branchController.dispose();
    _branchAddressController.dispose();
    _branchCodeController.dispose();
    _micrController.dispose();
    _swiftController.dispose();

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

      final rootUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = rootUserDoc.data() ?? {};

      _currentUserUid = user.uid;
      _currentUserName = (data['name'] ?? data['fullName'] ?? '')
          .toString()
          .trim();

      String userDesignation =
          (data['designation'] ??
                  data['role'] ??
                  data['jobTitle'] ??
                  'Authorized Signatory')
              .toString()
              .trim();
      if (userDesignation.isEmpty) {
        userDesignation = 'Authorized Signatory';
      }

      if (_signNameController.text.isEmpty) {
        _signNameController.text = _currentUserName;
      }
      if (_signDesignationController.text.isEmpty) {
        _signDesignationController.text = userDesignation;
      }
    } catch (e) {
      _setError('Failed to load user context.');
    }
  }

  Future<void> _loadCompanyProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();
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
      _companyBankDetails = data['bankDetails'];
      _companyLogoUrl = (data['logoUrl'] ?? '').toString();
      _companyState = (data['state'] ?? '').toString().trim().toLowerCase();

      final configuredPrefix = (data['proformaPrefix'] ?? '').toString().trim();
      if (configuredPrefix.isNotEmpty) {
        _proformaPrefix = configuredPrefix.toUpperCase();
      }
    } catch (_) {}
  }

  Future<void> _loadCustomerFromFirestore(String customerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('customers')
          .doc(customerId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _selectedCustomerId = customerId;
        _customerNameController.text =
            (data['companyName'] ?? data['name'] ?? '').toString();
        _billingAddressController.text =
            (data['address'] ?? data['billingAddress'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _mobileController.text = (data['mobile'] ?? data['phone'] ?? '')
            .toString();
        _contactPersonController.text =
            (data['contactPerson'] ?? data['contactName'] ?? '').toString();
        _gstController.text = (data['gstNo'] ?? data['gst'] ?? '').toString();
        _customerStateController.text = (data['state'] ?? '').toString().trim();

        if (_isSameAsBilling) {
          _copyBillingToShipping();
        }

        _checkInterState();
        _fetchCustomerInsights(customerId);
      }
    } catch (_) {}
  }

  Future<ProformaLocalItem?> _hydrateProductItem(
    Map<String, dynamic> rawItem,
  ) async {
    final Map<String, dynamic> i = Map<String, dynamic>.from(rawItem);
    String productId = (i['productId'] ?? i['itemId'] ?? '').toString();
    String name = (i['name'] ?? i['productName'] ?? i['itemName'] ?? '')
        .toString();
    String desc = (i['description'] ?? i['details'] ?? '').toString();
    String hsn = (i['hsnCode'] ?? '').toString();
    double qty = double.tryParse(i['quantity']?.toString() ?? '1') ?? 1.0;
    String uom = (i['uom'] ?? i['unit'] ?? 'Nos').toString();
    double price =
        double.tryParse(
          i['unitPrice']?.toString() ??
              i['price']?.toString() ??
              i['rate']?.toString() ??
              '0',
        ) ??
        0.0;
    double disc =
        double.tryParse(
          i['discountPercent']?.toString() ?? i['discount']?.toString() ?? '0',
        ) ??
        0.0;

    double totalGst =
        double.tryParse(
          i['gstPercentage']?.toString() ?? i['tax']?.toString() ?? '0',
        ) ??
        0.0;
    if (totalGst == 0) {
      totalGst =
          (double.tryParse(i['cgstPercent']?.toString() ?? '0') ?? 0.0) +
          (double.tryParse(i['sgstPercent']?.toString() ?? '0') ?? 0.0) +
          (double.tryParse(i['igstPercent']?.toString() ?? '0') ?? 0.0);
    }

    double stock =
        double.tryParse(
          i['availableStock']?.toString() ?? i['stock']?.toString() ?? '0',
        ) ??
        0.0;

    if (productId.isNotEmpty) {
      try {
        final pDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('products')
            .doc(productId)
            .get();
        if (pDoc.exists && pDoc.data() != null) {
          final pData = pDoc.data()!;
          if (name.isEmpty) {
            name = (pData['name'] ?? '').toString();
          }
          if (desc.isEmpty) {
            desc = (pData['description'] ?? pData['details'] ?? '').toString();
          }
          if (hsn.isEmpty) {
            hsn = (pData['hsnCode'] ?? pData['hsn'] ?? '').toString();
          }
          if (totalGst == 0) {
            totalGst =
                double.tryParse(
                  pData['gstPercentage']?.toString() ??
                      pData['tax']?.toString() ??
                      '18',
                ) ??
                18.0;
          }
          if (price == 0) {
            price =
                double.tryParse(
                  pData['unitPrice']?.toString() ??
                      pData['price']?.toString() ??
                      '0',
                ) ??
                0.0;
          }
          if (uom == 'Nos' || uom.isEmpty) {
            uom = (pData['uom'] ?? 'Nos').toString();
          }
          stock =
              double.tryParse(
                pData['availableStock']?.toString() ??
                    pData['stockQuantity']?.toString() ??
                    stock.toString(),
              ) ??
              0.0;
        }
      } catch (_) {}
    }

    return ProformaLocalItem(
      id: (i['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
          .toString(),
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
    final seed = widget.inquirySeed ?? widget.initialData;
    if (seed == null || seed.isEmpty) return;

    _linkedInquiryId = seed['id']?.toString() ?? seed['inquiryId']?.toString();
    _linkedInquiryNumber =
        seed['inquiryNumber']?.toString() ?? seed['inquiryCode']?.toString();
    _linkedQuotationNumber =
        seed['quotationNumber']?.toString() ?? seed['quoteNumber']?.toString();
    _linkedSalesOrderNumber =
        seed['salesOrderNumber']?.toString() ?? seed['soNumber']?.toString();

    final seededCustomerId = (seed['customerId'] ?? '').toString().trim();
    if (seededCustomerId.isNotEmpty) {
      await _loadCustomerFromFirestore(seededCustomerId);
    } else {
      _customerNameController.text =
          (seed['customerName'] ??
                  seed['companyName'] ??
                  seed['clientName'] ??
                  '')
              .toString()
              .trim();
      _contactPersonController.text =
          (seed['contactPerson'] ?? seed['contactName'] ?? '')
              .toString()
              .trim();
      _emailController.text =
          (seed['email'] ?? seed['contactEmail'] ?? seed['clientEmail'] ?? '')
              .toString()
              .trim();
      _mobileController.text =
          (seed['mobile'] ??
                  seed['contactPhone'] ??
                  seed['contactMobile'] ??
                  seed['clientMobile'] ??
                  '')
              .toString()
              .trim();
      _billingAddressController.text =
          (seed['billingAddress'] ??
                  seed['address'] ??
                  seed['location'] ??
                  seed['customerAddress'] ??
                  seed['clientAddress'] ??
                  '')
              .toString()
              .trim();
      _gstController.text = (seed['gstNo'] ?? seed['gst'] ?? '')
          .toString()
          .trim();
      _customerStateController.text =
          (seed['state'] ?? seed['customerState'] ?? '').toString().trim();
    }

    _isSameAsBilling = false;
    _shippingNameController.text = '';
    _shippingAddressController.text = '';
    _shippingEmailController.text = '';
    _shippingMobileController.text = '';
    _shippingContactPersonController.text = '';
    _shippingGstController.text = '';
    _shippingStateController.text = '';
    _checkInterState();

    final subject = (seed['subject'] ?? seed['inquirySubject'] ?? '')
        .toString()
        .trim();
    if (subject.isNotEmpty) _subjectController.text = subject;

    final notes =
        (seed['notes'] ?? seed['description'] ?? seed['inquiryReference'] ?? '')
            .toString()
            .trim();
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
      List<Future<ProformaLocalItem?>> tasks = [];
      for (var rawItem in rawItems) {
        if (rawItem == null || rawItem is! Map) continue;
        tasks.add(_hydrateProductItem(rawItem as Map<String, dynamic>));
      }

      final results = await Future.wait(tasks);
      _items = results.whereType<ProformaLocalItem>().toList();
      _recalculateTaxes();
    }
  }

  Future<void> _fetchCustomerInsights(String custId) async {
    try {
      final snaps = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .where('customerId', isEqualTo: custId)
          .orderBy('createdAt', descending: true)
          .get();

      double totalVal = 0;
      double lastQuote = 0;
      if (snaps.docs.isNotEmpty) {
        lastQuote =
            double.tryParse(
              snaps.docs.first.data()['finalTotal']?.toString() ??
                  snaps.docs.first.data()['grandTotal']?.toString() ??
                  '0',
            ) ??
            0.0;
        for (var d in snaps.docs) {
          totalVal +=
              double.tryParse(
                d.data()['finalTotal']?.toString() ??
                    d.data()['grandTotal']?.toString() ??
                    '0',
              ) ??
              0.0;
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
      final doc = await FirebaseFirestore.instance
          .collection('proformaSettings')
          .doc(_currentUserUid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _packingChargesExtra =
            data['packingChargesExtra'] as bool? ?? _packingChargesExtra;
        _advancePercent =
            double.tryParse(data['advancePercent']?.toString() ?? '50') ?? 50.0;
        _balancePercent =
            double.tryParse(data['balancePercent']?.toString() ?? '50') ?? 50.0;

        _advancePercentController.text = _advancePercent.toString();
        _balancePercentController.text = _balancePercent.toString();

        if (widget.existingProforma == null && widget.proformaId == null) {
          dynamic savedBankDetails = data['bankDetails'];
          if (savedBankDetails != null &&
              (savedBankDetails is Map
                  ? savedBankDetails.isNotEmpty
                  : savedBankDetails.toString().isNotEmpty)) {
            _applyBankDetails(savedBankDetails);
          } else {
            _applyBankDetails(_companyBankDetails);
          }
        }

        if (_signNameController.text.isEmpty) {
          _signNameController.text =
              data['signatureName']?.toString() ?? _currentUserName;
        }
        if (data.containsKey('signatureDesignation')) {
          String savedSigDesig = data['signatureDesignation']?.toString() ?? '';
          if (savedSigDesig.isNotEmpty) {
            _signDesignationController.text = savedSigDesig;
          }
        }
        if (_signPhoneController.text.isEmpty) {
          _signPhoneController.text = data['signaturePhone']?.toString() ?? '';
        }

        if (widget.existingProforma == null) {
          if (data['dynamicTerms'] != null &&
              (data['dynamicTerms'] as List).isNotEmpty) {
            _dynamicTerms = (data['dynamicTerms'] as List)
                .map(
                  (e) => ProformaTermRow(
                    title: e['title']?.toString() ?? '',
                    value: e['value']?.toString() ?? '',
                  ),
                )
                .toList();
          } else {
            _dynamicTerms = [
              ProformaTermRow(
                title: 'Payment',
                value: 'Advance against PO, balance against PI.',
              ),
              ProformaTermRow(
                title: 'Delivery',
                value: 'Within 4-6 weeks from PO and advance.',
              ),
              ProformaTermRow(
                title: 'Validity',
                value: '30 days from date of Proforma.',
              ),
            ];
          }
        }
      } else if (widget.existingProforma == null && widget.proformaId == null) {
        _applyBankDetails(_companyBankDetails);
        _dynamicTerms = [
          ProformaTermRow(
            title: 'Payment',
            value: 'Advance against PO, balance against PI.',
          ),
          ProformaTermRow(
            title: 'Delivery',
            value: 'Within 4-6 weeks from PO and advance.',
          ),
          ProformaTermRow(
            title: 'Validity',
            value: '30 days from date of Proforma.',
          ),
        ];
      }
    } catch (_) {
      if (widget.existingProforma == null && widget.proformaId == null) {
        _applyBankDetails(_companyBankDetails);
      }
    }
  }

  void _checkInterState() {
    String effectiveShippingState = _isSameAsBilling
        ? _customerStateController.text
        : _shippingStateController.text;
    if (_companyState.isEmpty || effectiveShippingState.isEmpty) {
      _isInterState = false;
    } else {
      _isInterState =
          _companyState.toLowerCase().trim() !=
          effectiveShippingState.toLowerCase().trim();
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

    _cachedGlobalDiscountAmount =
        (_cachedSubtotal - _cachedItemDiscount) *
        (_globalDiscountPercent / 100);
    _cachedTaxableAmount =
        _cachedSubtotal - _cachedItemDiscount - _cachedGlobalDiscountAmount;
    _cachedTaxAmount = _cachedCgst + _cachedSgst + _cachedIgst;
    _cachedGrandTotal = _cachedTaxableAmount + _cachedTaxAmount;

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

  String _currentFinancialYearShort() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    return '$startYear-${(startYear + 1).toString().substring(2)}';
  }

  bool _isAutoQuoteNumberPlaceholder(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized.contains('auto-generated') ||
        normalized.contains('auto generated');
  }

  int? _extractSequence(String numberStr) {
    final match = RegExp(
      r'^[A-Z]+/(\d+)/\d{4}-\d{2}$',
    ).firstMatch(numberStr.trim().toUpperCase());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _normalizeManualNumber(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _registryId(String numberStr) {
    return numberStr
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
  }

  Future<void> _ensureUniqueNumber(String numberStr) async {
    final snap = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('proforma_invoices')
        .where('proformaNumber', isEqualTo: numberStr)
        .limit(2)
        .get();

    final duplicateExists = snap.docs.any((doc) => doc.id != widget.proformaId);
    if (duplicateExists) {
      throw Exception(
        'Proforma number $numberStr already exists. Use a unique number.',
      );
    }
  }

  Future<void> _saveProforma() async {
    if (!_formKey.currentState!.validate()) {
      _setError('Please fill required fields.');
      return;
    }
    if (_items.isEmpty) {
      _setError('Add at least one item.');
      return;
    }
    if (_currentUserUid == null) {
      _setError('System Error: Context missing.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final counterRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('counters')
          .doc('proforma_counter');

      final bool isUpdate = widget.proformaId != null;

      final docRef = isUpdate
          ? FirebaseFirestore.instance
                .collection('companies')
                .doc(widget.companyId)
                .collection('proforma_invoices')
                .doc(widget.proformaId)
          : FirebaseFirestore.instance
                .collection('companies')
                .doc(widget.companyId)
                .collection('proforma_invoices')
                .doc();

      String generatedNo = _normalizeManualNumber(
        _proformaNumberController.text,
      );
      final financialYear = _currentFinancialYearShort();
      int? manualSequence;

      if (_isAutoQuoteNumberPlaceholder(generatedNo)) {
        generatedNo = '';
      } else {
        final manualPattern = RegExp(r'^[A-Z]+/\d+/\d{4}-\d{2}$');
        if (!manualPattern.hasMatch(generatedNo)) {
          throw Exception('Use format $_proformaPrefix/119/$financialYear.');
        }
        manualSequence = _extractSequence(generatedNo);
        await _ensureUniqueNumber(generatedNo);
      }

      final mappedTerms = _dynamicTerms
          .map(
            (e) => {
              'title': e.titleCtrl.text.trim(),
              'value': e.valueCtrl.text.trim(),
            },
          )
          .toList();

      final mappedItems = _items.map((e) => e.toMap()).toList();

      final bankDetailsMap = {
        'accountHolderName': _accountHolderNameController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'ifsc': _ifscController.text.trim(),
        'micr': _micrController.text.trim(),
        'branch': _branchController.text.trim(),
        'branchCode': _branchCodeController.text.trim(),
        'branchAddress': _branchAddressController.text.trim(),
        'swift': _swiftController.text.trim(),
      };

      // STANDARDIZED PAYLOAD
      final payload = {
        'id': docRef.id,
        'companyId': widget.companyId,
        'subject': _subjectController.text.trim(),
        'proformaDate': Timestamp.fromDate(_proformaDate),
        'status': 'draft',

        'customerId': _selectedCustomerId,
        'customerName': _customerNameController.text.trim(),
        'billingAddress': _billingAddressController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'gstNo': _gstController.text.trim(),
        'customerState': _customerStateController.text.trim(),
        'isInterState': _isInterState,

        'isSameAsBilling': _isSameAsBilling,
        'shippingName': _shippingNameController.text.trim(),
        'shippingAddress': _shippingAddressController.text.trim(),
        'shippingEmail': _shippingEmailController.text.trim(),
        'shippingMobile': _shippingMobileController.text.trim(),
        'shippingContactPerson': _shippingContactPersonController.text.trim(),
        'shippingGst': _shippingGstController.text.trim(),
        'shippingState': _shippingStateController.text.trim(),

        'inquiryId': _linkedInquiryId ?? '',
        'inquiryNumber': _linkedInquiryNumber ?? '',
        'quotationNumber': _linkedQuotationNumber ?? '',
        'salesOrderNumber': _linkedSalesOrderNumber ?? '',

        'inquirySource': _selectedInquirySource,
        'inquiryDate': Timestamp.fromDate(_inquiryDate),
        'inquiryReference': _inquiryRefNoteController.text.trim(),

        'nextFollowUpDate': _nextFollowUpDate != null
            ? Timestamp.fromDate(_nextFollowUpDate!)
            : null,
        'followUpNotes': _followUpNotesController.text.trim(),

        'subTotal': _cachedSubtotal,
        'totalItemDiscount': _cachedItemDiscount,
        'globalDiscountPercent': _globalDiscountPercent,
        'globalDiscountAmount': _cachedGlobalDiscountAmount,
        'totalTaxableAmount': _cachedTaxableAmount,
        'totalCgst': _cachedCgst,
        'totalSgst': _cachedSgst,
        'totalIgst': _cachedIgst,
        'taxAmount': _cachedTaxAmount,
        'grandTotal': _cachedGrandTotal,
        'roundOff': _cachedRoundOff,
        'finalTotal': _cachedFinalTotal,

        'dynamicTerms': mappedTerms,

        'advancePercent': _advancePercent,
        'balancePercent': _balancePercent,
        'advanceAmount': _advanceAmount,
        'balanceAmount': _balanceAmount,
        'packingChargesExtra': _packingChargesExtra,

        'bankDetails': bankDetailsMap,

        'signatureName': _signNameController.text.trim(),
        'signatureDesignation': _signDesignationController.text.trim(),
        'signaturePhone': _signPhoneController.text.trim(),

        'items': mappedItems,

        'isActive': true,
        'isDeleted': false,
        'lastEditedBy': _currentUserUid,
        'lastEditedAt': FieldValue.serverTimestamp(),
      };

      if (!isUpdate) {
        payload['createdBy'] = _currentUserUid!;
        payload['createdByName'] = _currentUserName;
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .runTransaction((tx) async {
            String finalNumber = generatedNo;
            int? sequenceToSync;

            final counterDoc = await tx.get(counterRef);
            final currentSequence =
                ((counterDoc.data()?['sequence'] as num?)?.toInt() ?? 0);

            if (finalNumber.isEmpty) {
              final nextSequence = currentSequence + 1;
              finalNumber = '$_proformaPrefix/$nextSequence/$financialYear';
              sequenceToSync = nextSequence;
            } else if (manualSequence != null &&
                manualSequence > currentSequence) {
              sequenceToSync = manualSequence;
            }

            final numberRef = FirebaseFirestore.instance
                .collection('companies')
                .doc(widget.companyId)
                .collection('proforma_numbers')
                .doc(_registryId(finalNumber));

            final numberDoc = await tx.get(numberRef);
            final reservedFor = numberDoc.data()?['proformaId']?.toString();
            final allowedExistingReservations = {
              docRef.id,
              if (widget.proformaId != null) widget.proformaId!,
            };

            if (numberDoc.exists &&
                reservedFor != null &&
                reservedFor.isNotEmpty &&
                !allowedExistingReservations.contains(reservedFor)) {
              throw Exception(
                'Proforma number $finalNumber is already reserved.',
              );
            }

            final payloadWithNumber = {
              ...payload,
              'proformaNumber': finalNumber,
              'financialYear': finalNumber.split('/').last,
            };

            tx.set(numberRef, {
              'proformaNumber': finalNumber,
              'proformaId': docRef.id,
              'companyId': widget.companyId,
              'sequence': _extractSequence(finalNumber),
              'financialYear': finalNumber.split('/').last,
              'prefix': finalNumber.split('/').first,
              'updatedAt': FieldValue.serverTimestamp(),
              if (!numberDoc.exists) 'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (sequenceToSync != null) {
              tx.set(counterRef, {
                'sequence': sequenceToSync,
                'prefix': _proformaPrefix,
                'financialYear': financialYear,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }

            if (isUpdate) {
              tx.update(docRef, payloadWithNumber);
            } else {
              tx.set(docRef, payloadWithNumber);
            }
          })
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
              'Network timeout: Failed to save Proforma safely.',
            ),
          );

      await FirebaseFirestore.instance
          .collection('proformaSettings')
          .doc(_currentUserUid)
          .set({
            'dynamicTerms': mappedTerms,
            'advancePercent': _advancePercent,
            'balancePercent': _balancePercent,
            'bankDetails': bankDetailsMap,
            'signatureName': _signNameController.text.trim(),
            'signatureDesignation': _signDesignationController.text.trim(),
            'signaturePhone': _signPhoneController.text.trim(),
            'packingChargesExtra': _packingChargesExtra,
          }, SetOptions(merge: true));

      if (!mounted) return;
      _showSnack(isUpdate ? 'Proforma Updated!' : 'Proforma Created!');
      Navigator.pop(context, true);
    } catch (e) {
      _setError('Save Failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildProformaMap() {
    final tempNo = _isAutoQuoteNumberPlaceholder(_proformaNumberController.text)
        ? '$_proformaPrefix/Preview/${_currentFinancialYearShort()}'
        : _proformaNumberController.text;

    // MATCHES STANDARDIZED PAYLOAD EXACTLY
    return {
      'id': widget.proformaId ?? 'N/A',
      'proformaNumber': tempNo,
      'documentType': 'Proforma Invoice',
      'createdAt': _proformaDate, // Using DateTime for preview logic explicitly
      'proformaDate': _proformaDate,
      'subject': _subjectController.text.trim(),

      'customerName': _customerNameController.text.trim(),
      'billingAddress': _billingAddressController.text.trim(),
      'customerState': _customerStateController.text.trim(),
      'gstNo': _gstController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'email': _emailController.text.trim(),
      'isInterState': _isInterState,

      'shippingName': _isSameAsBilling
          ? _customerNameController.text.trim()
          : _shippingNameController.text.trim(),
      'shippingAddress': _isSameAsBilling
          ? _billingAddressController.text.trim()
          : _shippingAddressController.text.trim(),
      'shippingGst': _isSameAsBilling
          ? _gstController.text.trim()
          : _shippingGstController.text.trim(),
      'shippingContactPerson': _isSameAsBilling
          ? _contactPersonController.text.trim()
          : _shippingContactPersonController.text.trim(),
      'shippingMobile': _isSameAsBilling
          ? _mobileController.text.trim()
          : _shippingMobileController.text.trim(),
      'shippingState': _isSameAsBilling
          ? _customerStateController.text.trim()
          : _shippingStateController.text.trim(),

      'companyName': _companyName,
      'companyAddress': _companyAddress,
      'companyPhone': _companyPhone,
      'companyEmail': _companyEmail,
      'companyGst': _companyGst,
      'companyPan': _companyPan,
      'companyCin': _companyCin,
      'companyWebsite': _companyWebsite,
      'companyLogoUrl': _companyLogoUrl,

      'subTotal': _cachedSubtotal,
      'totalItemDiscount': _cachedItemDiscount,
      'globalDiscountPercent': _globalDiscountPercent,
      'globalDiscountAmount': _cachedGlobalDiscountAmount,
      'totalTaxableAmount': _cachedTaxableAmount,
      'totalCgst': _cachedCgst,
      'totalSgst': _cachedSgst,
      'totalIgst': _cachedIgst,
      'taxAmount': _cachedTaxAmount,
      'grandTotal': _cachedGrandTotal,
      'roundOff': _cachedRoundOff,
      'finalTotal': _cachedFinalTotal,

      'advancePercent': _advancePercent,
      'balancePercent': _balancePercent,
      'advanceAmount': _advanceAmount,
      'balanceAmount': _balanceAmount,
      'packingChargesExtra': _packingChargesExtra,

      'dynamicTerms': _dynamicTerms
          .map(
            (e) => {
              'title': e.titleCtrl.text.trim(),
              'value': e.valueCtrl.text.trim(),
            },
          )
          .toList(),

      'bankDetails': {
        'accountHolderName': _accountHolderNameController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'ifsc': _ifscController.text.trim(),
        'micr': _micrController.text.trim(),
        'branch': _branchController.text.trim(),
        'branchCode': _branchCodeController.text.trim(),
        'branchAddress': _branchAddressController.text.trim(),
        'swift': _swiftController.text.trim(),
      },

      'signatureName': _signNameController.text.trim(),
      'signatureDesignation': _signDesignationController.text.trim(),
      'signaturePhone': _signPhoneController.text.trim(),

      'inquiryNumber': _linkedInquiryNumber ?? '',
      'quotationNumber': _linkedQuotationNumber ?? '',
      'salesOrderNumber': _linkedSalesOrderNumber ?? '',

      'createdBy': _currentUserUid,
      'createdByName': _currentUserName,
    };
  }

  List<ProformaLocalItem> _buildProformaItems() {
    return _items;
  }

  void _onPreviewPressed() {
    if (_items.isEmpty) {
      _showSnack('Please add at least one item to preview.', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProformaPreviewScreen(
          data: _buildProformaMap(),
          items: _buildProformaItems(),
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isInfo = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : (isInfo ? Colors.blue : Colors.green),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.02),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _buildSectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          if (trailing != null) const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _selectCustomerDialog() async {
    final searchController = TextEditingController();
    String searchText = '';

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('customers');

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Select Customer',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => setDialogState(
                    () => searchText = value.trim().toLowerCase(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      final filtered = docs.where((doc) {
                        final data = doc.data();
                        final searchStr =
                            '${data['companyName']} ${data['contactPerson']} ${data['mobile']}'
                                .toLowerCase();
                        return searchText.isEmpty ||
                            searchStr.contains(searchText);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('No customers found.'));
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = filtered[index].data();
                          return ListTile(
                            title: Text(
                              data['companyName'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${data['contactPerson'] ?? ''} | ${data['mobile'] ?? ''}',
                            ),
                            onTap: () => Navigator.pop(context, {
                              'id': filtered[index].id,
                              ...data,
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
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

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('products')
        .where('isActive', isEqualTo: true);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Select Product from Inventory',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) => setDialogState(
                    () => searchText = value.trim().toLowerCase(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      final filtered = docs.where((doc) {
                        final data = doc.data();
                        final searchStr =
                            '${data['name']} ${data['sku']} ${data['description']}'
                                .toLowerCase();
                        return searchText.isEmpty ||
                            searchStr.contains(searchText);
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('No products found in inventory.'),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final data = filtered[index].data();
                          final stock =
                              double.tryParse(
                                data['availableStock']?.toString() ??
                                    data['stockQuantity']?.toString() ??
                                    '0',
                              ) ??
                              0;
                          return ListTile(
                            title: Text(
                              data['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Price: ₹${data['unitPrice'] ?? 0} | Tax: ${data['gstPercentage'] ?? 0}% | Stock: $stock ${data['uom'] ?? 'Nos'}',
                            ),
                            trailing: stock <= 0
                                ? const Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                  )
                                : const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                            onTap: () => Navigator.pop(context, {
                              'id': filtered[index].id,
                              'stock': stock,
                              ...data,
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemModal([ProformaLocalItem? itemToEdit, int? index]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: itemToEdit?.name ?? '');
    final descCtrl = TextEditingController(text: itemToEdit?.description ?? '');
    final hsnCtrl = TextEditingController(text: itemToEdit?.hsnCode ?? '');
    final qtyCtrl = TextEditingController(
      text: itemToEdit?.quantity.toString() ?? '1',
    );
    final priceCtrl = TextEditingController(
      text: itemToEdit?.unitPrice.toString() ?? '',
    );
    final uomCtrl = TextEditingController(text: itemToEdit?.uom ?? 'Nos');
    final discCtrl = TextEditingController(
      text: itemToEdit?.discountPercent.toString() ?? '0',
    );

    double totalGst =
        (itemToEdit?.cgstPercent ?? 0) +
        (itemToEdit?.sgstPercent ?? 0) +
        (itemToEdit?.igstPercent ?? 0);
    final gstCtrl = TextEditingController(
      text: itemToEdit != null
          ? (totalGst > 0 ? totalGst.toString() : '18')
          : '18',
    );

    String currentId =
        itemToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    String productId = itemToEdit?.productId ?? '';
    double currentStock = itemToEdit?.availableStock ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Form(
            key: formKey,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                double parsedQty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
                bool stockWarning =
                    productId.isNotEmpty && parsedQty > currentStock;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            itemToEdit == null
                                ? 'Add Product/Service'
                                : 'Edit Line Item',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.inventory_2),
                            label: const Text('Pick from Inventory'),
                            onPressed: () async {
                              final p = await _selectProductDialog();
                              if (p != null) {
                                setModalState(() {
                                  productId = p['id'];
                                  if (nameCtrl.text.trim().isEmpty) {
                                    nameCtrl.text = p['name'] ?? '';
                                  }
                                  if (descCtrl.text.trim().isEmpty) {
                                    descCtrl.text =
                                        p['description'] ?? p['details'] ?? '';
                                  }
                                  if (hsnCtrl.text.trim().isEmpty) {
                                    hsnCtrl.text =
                                        p['hsnCode'] ?? p['hsn'] ?? '';
                                  }

                                  if (priceCtrl.text.trim().isEmpty ||
                                      priceCtrl.text == '0' ||
                                      priceCtrl.text == '0.0') {
                                    priceCtrl.text =
                                        (p['unitPrice'] ??
                                                p['price'] ??
                                                p['rate'] ??
                                                0)
                                            .toString();
                                  }

                                  uomCtrl.text = p['uom'] ?? 'Nos';

                                  String currentGst = gstCtrl.text.trim();
                                  if (currentGst.isEmpty ||
                                      currentGst == '0' ||
                                      currentGst == '18' ||
                                      currentGst == '18.0') {
                                    double pGst =
                                        double.tryParse(
                                          p['gstPercentage']?.toString() ??
                                              p['tax']?.toString() ??
                                              '18',
                                        ) ??
                                        18;
                                    gstCtrl.text = pGst.toString();
                                  }
                                  currentStock = p['stock'] ?? 0;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      if (productId.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: stockWarning
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Available Stock: $currentStock ${uomCtrl.text}',
                            style: TextStyle(
                              color: stockWarning
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      _buildItemTextField(
                        nameCtrl,
                        'Item Name *',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      _buildItemTextField(hsnCtrl, 'HSN / SAC Code'),
                      _buildItemTextField(
                        descCtrl,
                        'Specification / Description',
                        maxLines: null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildItemTextField(
                              qtyCtrl,
                              'Quantity',
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildItemTextField(
                              uomCtrl,
                              'UOM (e.g., Nos, Kgs)',
                            ),
                          ),
                        ],
                      ),
                      if (stockWarning)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '⚠️ Warning: Quantity exceeds available inventory stock.',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildItemTextField(
                              priceCtrl,
                              'Unit Price *',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildItemTextField(
                              discCtrl,
                              'Discount (%)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      _buildItemTextField(
                        gstCtrl,
                        'GST (%)',
                        keyboardType: TextInputType.number,
                        hint: 'Default is 18%',
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;

                          double gstVal =
                              double.tryParse(gstCtrl.text.trim()) ?? 18.0;
                          double cgst = 0, sgst = 0, igst = 0;
                          if (_isInterState) {
                            igst = gstVal;
                          } else {
                            cgst = gstVal / 2;
                            sgst = gstVal / 2;
                          }

                          final newItem = ProformaLocalItem(
                            id: currentId,
                            productId: productId,
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            hsnCode: hsnCtrl.text.trim(),
                            quantity: double.tryParse(qtyCtrl.text.trim()) ?? 1,
                            uom: uomCtrl.text.trim().isEmpty
                                ? 'Nos'
                                : uomCtrl.text.trim(),
                            unitPrice:
                                double.tryParse(priceCtrl.text.trim()) ?? 0,
                            discountPercent:
                                double.tryParse(discCtrl.text.trim()) ?? 0,
                            cgstPercent: cgst,
                            sgstPercent: sgst,
                            igstPercent: igst,
                            availableStock: currentStock,
                          );

                          setState(() {
                            if (index != null) {
                              _items[index] = newItem;
                            } else {
                              _items.add(newItem);
                            }
                            _calculateTotals();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Save Item',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLines = 1,
    String? hint,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _calcRow(
    String label,
    double amount, {
    bool bold = false,
    double size = 14,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: size,
              color: color ?? Colors.grey.shade700,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: size,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
        title: Text(
          widget.proformaId != null
              ? 'Edit Proforma Invoice'
              : 'Create Proforma Invoice',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
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
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Customer Details',
                              Icons.business,
                              trailing: OutlinedButton.icon(
                                onPressed: () async {
                                  final c = await _selectCustomerDialog();
                                  if (c != null) _applyCustomer(c);
                                },
                                icon: const Icon(Icons.search, size: 18),
                                label: const Text('CRM Lookup'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accentColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            if (_customerInsights != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade100,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          'Total PI',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        Text(
                                          '${_customerInsights!['count']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          'Last PI',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        Text(
                                          '₹${_customerInsights!['lastQuoteAmount']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          'Lifetime Value',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        Text(
                                          '₹${_customerInsights!['totalValue']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            _buildItemTextField(
                              _customerNameController,
                              'Customer Name *',
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            _buildItemTextField(
                              _billingAddressController,
                              'Billing Address',
                              maxLines: 2,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _contactPersonController,
                                    'Contact Person',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _mobileController,
                                    'Mobile',
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _emailController,
                                    'Email ID',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _gstController,
                                    'GSTIN',
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _customerStateController,
                                    'State *',
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Spacer(),
                              ],
                            ),
                            const Divider(height: 30),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Shipping Details Same as Billing',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: _isSameAsBilling,
                              activeThumbColor: accentColor,
                              onChanged: (val) {
                                setState(() {
                                  _isSameAsBilling = val;
                                  if (val) {
                                    _copyBillingToShipping();
                                  } else {
                                    _shippingNameController.text = '';
                                    _shippingAddressController.text = '';
                                    _shippingEmailController.text = '';
                                    _shippingMobileController.text = '';
                                    _shippingContactPersonController.text = '';
                                    _shippingGstController.text = '';
                                    _shippingStateController.text = '';
                                  }
                                  _checkInterState();
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      if (!_isSameAsBilling)
                        Container(
                          decoration: _cardDecoration(),
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                'Shipping Details',
                                Icons.local_shipping_outlined,
                              ),
                              _buildItemTextField(
                                _shippingNameController,
                                'Shipping Company Name *',
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null,
                              ),
                              _buildItemTextField(
                                _shippingAddressController,
                                'Shipping Address',
                                maxLines: 2,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildItemTextField(
                                      _shippingContactPersonController,
                                      'Contact Person',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildItemTextField(
                                      _shippingMobileController,
                                      'Mobile',
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildItemTextField(
                                      _shippingEmailController,
                                      'Email ID',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildItemTextField(
                                      _shippingGstController,
                                      'GSTIN',
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildItemTextField(
                                      _shippingStateController,
                                      'Shipping State *',
                                      validator: (v) =>
                                          v!.isEmpty ? 'Required' : null,
                                      onChanged: (val) => _checkInterState(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Spacer(),
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
                            _buildSectionHeader(
                              'Proforma & Inquiry Link',
                              Icons.link,
                            ),
                            if (_linkedInquiryId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Linked Inquiry: $_linkedInquiryNumber.',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            _buildItemTextField(
                              _subjectController,
                              'Subject Line *',
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _proformaNumberController,
                                    'Proforma No.',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: _proformaDate,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (d != null) {
                                        setState(() => _proformaDate = d);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Proforma Date',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        isDense: true,
                                      ),
                                      child: Text(
                                        '${_proformaDate.day}/${_proformaDate.month}/${_proformaDate.year}',
                                      ),
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
                            _buildSectionHeader(
                              'Line Items',
                              Icons.inventory_2_outlined,
                              trailing: ElevatedButton.icon(
                                onPressed: _showAddItemModal,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Item'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            if (_items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'No items added yet.',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = _items[i];

                                  bool isOutOfStock = item.availableStock <= 0;
                                  bool isLowStock =
                                      item.availableStock < item.quantity &&
                                      !isOutOfStock;
                                  Color stockColor = isOutOfStock
                                      ? Colors.red
                                      : (isLowStock
                                            ? Colors.orange
                                            : Colors.green);
                                  String stockText = isOutOfStock
                                      ? 'Out of Stock'
                                      : (isLowStock ? 'Low Stock' : 'In Stock');

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (item.hsnCode.isNotEmpty)
                                          Text('HSN/SAC: ${item.hsnCode}'),
                                        Text(
                                          '${item.quantity} ${item.uom} x ₹${item.unitPrice.toStringAsFixed(2)}\nTax: ${item.cgstPercent + item.sgstPercent + item.igstPercent}% | Disc: ${item.discountPercent}%',
                                        ),
                                        if (item.productId.isNotEmpty)
                                          Text(
                                            'Inventory: $stockText (${item.availableStock} available)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: stockColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '₹${item.totalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blueGrey,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _showAddItemModal(item, i),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _items.removeAt(i);
                                              _calculateTotals();
                                            });
                                          },
                                        ),
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
                                    _calcRow(
                                      'Item Discounts',
                                      -_cachedItemDiscount,
                                      color: Colors.red,
                                    ),
                                    _calcRow(
                                      'Taxable Value',
                                      _cachedTaxableAmount,
                                      bold: true,
                                    ),
                                    if (!_isInterState) ...[
                                      _calcRow('CGST', _cachedCgst),
                                      _calcRow('SGST', _cachedSgst),
                                    ] else ...[
                                      _calcRow('IGST', _cachedIgst),
                                    ],
                                    if (_cachedRoundOff != 0)
                                      _calcRow('Round Off', _cachedRoundOff),
                                    const Divider(),
                                    _calcRow(
                                      'FINAL TOTAL',
                                      _cachedFinalTotal,
                                      bold: true,
                                      size: 18,
                                      color: primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                            _buildSectionHeader(
                              'Payment Structure',
                              Icons.account_balance_wallet_outlined,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _advancePercentController,
                                    'Advance %',
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) {
                                      double adv = double.tryParse(v) ?? 0;
                                      if (adv > 100) adv = 100;
                                      setState(() {
                                        _advancePercent = adv;
                                        _balancePercent = 100 - adv;
                                        _balancePercentController.text =
                                            _balancePercent.toString();
                                        _calculateTotals();
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _balancePercentController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: 'Balance %',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Packing & Forwarding Extra',
                                style: TextStyle(fontSize: 14),
                              ),
                              value: _packingChargesExtra,
                              onChanged: (v) =>
                                  setState(() => _packingChargesExtra = v),
                            ),

                            const Divider(height: 30),

                            _buildSectionHeader(
                              'Terms & Conditions',
                              Icons.gavel_outlined,
                              trailing: OutlinedButton.icon(
                                onPressed: () => setState(
                                  () => _dynamicTerms.add(ProformaTermRow()),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Term'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accentColor,
                                  side: const BorderSide(color: accentColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ),

                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _dynamicTerms.length,
                              itemBuilder: (ctx, i) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _buildItemTextField(
                                          _dynamicTerms[i].titleCtrl,
                                          'Title (e.g. Payment)',
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 7,
                                        child: _buildItemTextField(
                                          _dynamicTerms[i].valueCtrl,
                                          'Term Detail',
                                          maxLines: null,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => setState(
                                          () => _dynamicTerms.removeAt(i),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const Divider(height: 30),

                            _buildSectionHeader(
                              'Bank Details',
                              Icons.account_balance,
                            ),
                            _buildItemTextField(
                              _accountHolderNameController,
                              'Account Holder Name',
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _bankNameController,
                                    'Bank Name',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _accountNumberController,
                                    'Account Number',
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _ifscController,
                                    'IFSC Code',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _micrController,
                                    'MICR Code',
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _branchController,
                                    'Branch Name',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _branchCodeController,
                                    'Branch Code',
                                  ),
                                ),
                              ],
                            ),
                            _buildItemTextField(
                              _branchAddressController,
                              'Branch Address',
                              maxLines: 2,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _swiftController,
                                    'SWIFT Code',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Spacer(),
                              ],
                            ),

                            const Divider(height: 30),

                            _buildSectionHeader(
                              'Signature Details',
                              Icons.edit_document,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildItemTextField(
                                    _signNameController,
                                    'Signatory Name',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _signDesignationController,
                                    'Designation',
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 30),

                            const Text(
                              'Follow-up Schedule',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _nextFollowUpDate ??
                                            DateTime.now().add(
                                              const Duration(days: 3),
                                            ),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime(2100),
                                      );
                                      if (d != null) {
                                        setState(() => _nextFollowUpDate = d);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Next Follow-up',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.orange.shade50,
                                        isDense: true,
                                      ),
                                      child: Text(
                                        _nextFollowUpDate != null
                                            ? '${_nextFollowUpDate!.day}/${_nextFollowUpDate!.month}/${_nextFollowUpDate!.year}'
                                            : 'Select Date',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildItemTextField(
                                    _followUpNotesController,
                                    'Follow-up Notes',
                                  ),
                                ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Final Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '₹ ${_cachedFinalTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProforma,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save Proforma'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
