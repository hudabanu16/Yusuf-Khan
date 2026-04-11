import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:QUIK/models/item_model.dart';

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF3B82F6);

class QuotationScreenLocal extends StatefulWidget {
  final int userId;

  const QuotationScreenLocal({super.key, required this.userId});

  @override
  State<QuotationScreenLocal> createState() => _QuotationScreenLocalState();
}

class _QuotationScreenLocalState extends State<QuotationScreenLocal> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _letterheadUrl;
  Uint8List? _letterheadBytes;
  bool _isUploadingLetterhead = false;

  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'sales';
  String _currentCompanyName = '';

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isAdminOrManager {
    final role = _currentUserRole.trim().toLowerCase();
    return role == 'admin' ||
        role == 'manager' ||
        role == 'director' ||
        role == 'md' ||
        role == 'ceo' ||
        role == 'super_admin';
  }

  bool get _canEditQuotationNumber {
    final role = _currentUserRole.trim().toLowerCase();
    return role == 'super_admin' ||
        role == 'ceo' ||
        role == 'md' ||
        role == 'director';
  }

  bool get _hasSavedLetterhead {
    return (_letterheadUrl != null && _letterheadUrl!.trim().isNotEmpty) ||
        (_letterheadBytes != null && _letterheadBytes!.isNotEmpty);
  }

  String? _selectedCustomerId;
  Map<String, dynamic>? _selectedCustomerSnapshot;

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _gstController = TextEditingController();

  final TextEditingController _quoteNumberController = TextEditingController();
  final TextEditingController _inquiryRefNoteController =
      TextEditingController();

  final List<String> _inquirySources = const [
    'Verbal',
    'Phone Call',
    'In Visit',
    'Email',
    'WhatsApp',
    'Other',
  ];
  String _selectedInquirySource = 'Verbal';

  DateTime _inquiryDate = DateTime.now();
  DateTime _quoteDate = DateTime.now();

  List<Item> _items = [];
  double _taxRate = 18.0;
  double _discount = 0.0;

  final TextEditingController _deliveryTimeController = TextEditingController();
  final TextEditingController _validityController = TextEditingController();
  final TextEditingController _priceBasisController = TextEditingController();
  final TextEditingController _paymentTermsController = TextEditingController();
  bool _packingChargesExtra = true;

  final TextEditingController _extraTermController = TextEditingController();
  final List<String> _extraTerms = [];

  final TextEditingController _signCompanyController = TextEditingController();
  final TextEditingController _signNameController = TextEditingController();
  final TextEditingController _signPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _deliveryTimeController.text = 'Within 4-6 weeks from PO and advance.';
    _validityController.text = '30 days from date of quotation.';
    _priceBasisController.text = 'Ex-works Mumbai, packing extra.';
    _paymentTermsController.text = '50% advance with PO, balance against PI.';
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadUserContext();
    await _loadUserSettings();
    await _initQuoteNumber();
  }

  Future<void> _initQuoteNumber() async {
    final number = await _generateQuoteNumber();
    if (!mounted) return;
    setState(() {
      _quoteNumberController.text = number;
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _contactPersonController.dispose();
    _gstController.dispose();
    _quoteNumberController.dispose();
    _inquiryRefNoteController.dispose();
    _deliveryTimeController.dispose();
    _validityController.dispose();
    _priceBasisController.dispose();
    _paymentTermsController.dispose();
    _extraTermController.dispose();
    _signCompanyController.dispose();
    _signNameController.dispose();
    _signPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _setError('No logged in user found.');
        return;
      }

      final rootUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = rootUserDoc.data() ?? <String, dynamic>{};

      _currentUserUid = user.uid;
      _companyId = (data['companyId'] ?? '').toString().trim();
      _currentUserRole = (data['role'] ?? 'sales').toString().trim();
      _currentCompanyName = (data['companyName'] ?? '').toString().trim();

      if (_signCompanyController.text.trim().isEmpty &&
          _currentCompanyName.isNotEmpty) {
        _signCompanyController.text = _currentCompanyName;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _setError('Failed to load user context: $e');
    }
  }

  Future<void> _loadUserSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('quotationSettings')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (_signCompanyController.text.trim().isEmpty &&
            _currentCompanyName.isNotEmpty) {
          _signCompanyController.text = _currentCompanyName;
        }
        return;
      }

      final data = doc.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        final url = (data['letterheadUrl'] ?? '').toString().trim();
        _letterheadUrl = url.isEmpty ? null : url;

        _taxRate = (data['taxRate'] as num?)?.toDouble() ?? _taxRate;
        _packingChargesExtra =
            data['packingChargesExtra'] as bool? ?? _packingChargesExtra;

        final delivery = (data['deliveryTime'] ?? '').toString();
        final validity = (data['validity'] ?? '').toString();
        final priceBasis = (data['priceBasis'] ?? '').toString();
        final payment = (data['paymentTerms'] ?? '').toString();

        if (delivery.isNotEmpty) _deliveryTimeController.text = delivery;
        if (validity.isNotEmpty) _validityController.text = validity;
        if (priceBasis.isNotEmpty) _priceBasisController.text = priceBasis;
        if (payment.isNotEmpty) _paymentTermsController.text = payment;

        final signCompany = (data['signatureCompany'] ?? '').toString();
        final signName = (data['signatureName'] ?? '').toString();
        final signPhone = (data['signaturePhone'] ?? '').toString();

        if (signCompany.isNotEmpty) {
          _signCompanyController.text = signCompany;
        } else if (_currentCompanyName.isNotEmpty &&
            _signCompanyController.text.trim().isEmpty) {
          _signCompanyController.text = _currentCompanyName;
        }

        _signNameController.text = signName;
        _signPhoneController.text = signPhone;
      });
    } catch (e) {
      _setError('Failed to load quotation settings: $e');
    }
  }

  Future<void> _saveUserSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('quotationSettings')
          .doc(user.uid)
          .set({
            'companyId': _companyId,
            'letterheadUrl': _letterheadUrl,
            'taxRate': _taxRate,
            'packingChargesExtra': _packingChargesExtra,
            'deliveryTime': _deliveryTimeController.text.trim(),
            'validity': _validityController.text.trim(),
            'priceBasis': _priceBasisController.text.trim(),
            'paymentTerms': _paymentTermsController.text.trim(),
            'signatureCompany': _signCompanyController.text.trim(),
            'signatureName': _signNameController.text.trim(),
            'signaturePhone': _signPhoneController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      _setError('Failed to save settings: $e');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
  }

  void _clearError() {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });
  }

  Future<String> _generateQuoteNumber() async {
    if (_companyId == null || _companyId!.isEmpty) {
      return 'MEM/0001/26-27';
    }

    final now = DateTime.now();
    final int startYear = now.month >= 4 ? now.year : now.year - 1;
    final int endYear = startYear + 1;
    final String fyShort =
        '${startYear.toString().substring(2)}-${endYear.toString().substring(2)}';

    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('quotations')
        .where('financialYear', isEqualTo: fyShort)
        .get();

    final int nextNumber = snapshot.docs.length + 1;
    final String number = nextNumber.toString().padLeft(4, '0');

    return 'MEM/$number/$fyShort';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));

  double get _discountAmount => _subtotal * (_discount / 100);
  double get _taxableAmount => _subtotal - _discountAmount;
  double get _taxAmount => _taxableAmount * (_taxRate / 100);
  double get _grandTotal => _taxableAmount + _taxAmount;

  Query<Map<String, dynamic>> _customerQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('customers');

    if (!_isAdminOrManager && _currentUserUid != null) {
      query = query.where('createdBy', isEqualTo: _currentUserUid);
    }

    return query;
  }

  Future<Map<String, dynamic>?> _selectCustomerDialog() async {
    if (_companyId == null || _companyId!.isEmpty) {
      _showSnack('Company not linked. Cannot load customers.', isError: true);
      return null;
    }

    final searchController = TextEditingController();
    String searchText = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Customer'),
              content: SizedBox(
                width: 550,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText:
                            'Search customer by company, person, phone, email',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchText = value.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _customerQuery().snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('Error loading customers'),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          final filtered = docs.where((doc) {
                            final data = doc.data();

                            final companyName =
                                (data['companyName'] ?? data['name'] ?? '')
                                    .toString()
                                    .toLowerCase();

                            final contactPerson =
                                (data['contactPerson'] ??
                                        data['contactName'] ??
                                        '')
                                    .toString()
                                    .toLowerCase();

                            final phone =
                                (data['mobile'] ?? data['phone'] ?? '')
                                    .toString()
                                    .toLowerCase();

                            final email = (data['email'] ?? '')
                                .toString()
                                .toLowerCase();

                            if (searchText.isEmpty) return true;

                            return companyName.contains(searchText) ||
                                contactPerson.contains(searchText) ||
                                phone.contains(searchText) ||
                                email.contains(searchText);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text('No customers found'),
                            );
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data = doc.data();

                              final companyName =
                                  (data['companyName'] ?? data['name'] ?? '')
                                      .toString();
                              final contactPerson =
                                  (data['contactPerson'] ??
                                          data['contactName'] ??
                                          '')
                                      .toString();
                              final mobile =
                                  (data['mobile'] ?? data['phone'] ?? '')
                                      .toString();
                              final email = (data['email'] ?? '').toString();
                              final gst = (data['gstNo'] ?? data['gst'] ?? '')
                                  .toString();

                              final subtitle = <String>[];
                              if (contactPerson.isNotEmpty) {
                                subtitle.add('Contact: $contactPerson');
                              }
                              if (mobile.isNotEmpty) {
                                subtitle.add('Mobile: $mobile');
                              }
                              if (email.isNotEmpty) {
                                subtitle.add('Email: $email');
                              }
                              if (gst.isNotEmpty) {
                                subtitle.add('GST: $gst');
                              }

                              return ListTile(
                                title: Text(
                                  companyName.isEmpty
                                      ? 'Unnamed Customer'
                                      : companyName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(subtitle.join(' | ')),
                                onTap: () {
                                  Navigator.pop<Map<String, dynamic>>(context, {
                                    'id': doc.id,
                                    ...data,
                                  });
                                },
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
            );
          },
        );
      },
    );
  }

  void _applyCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomerId = (customer['id'] ?? '').toString();
      _selectedCustomerSnapshot = Map<String, dynamic>.from(customer);

      _companyNameController.text =
          (customer['companyName'] ?? customer['name'] ?? '').toString();
      _addressController.text =
          (customer['address'] ?? customer['billingAddress'] ?? '').toString();
      _emailController.text = (customer['email'] ?? '').toString();
      _mobileController.text = (customer['mobile'] ?? customer['phone'] ?? '')
          .toString();
      _contactPersonController.text =
          (customer['contactPerson'] ?? customer['contactName'] ?? '')
              .toString();
      _gstController.text = (customer['gstNo'] ?? customer['gst'] ?? '')
          .toString();
    });
  }

  void _clearSelectedCustomer() {
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerSnapshot = null;
      _companyNameController.clear();
      _addressController.clear();
      _emailController.clear();
      _mobileController.clear();
      _contactPersonController.clear();
      _gstController.clear();
    });
  }

  Future<Map<String, dynamic>?> _selectProductDialog() async {
    if (_companyId == null || _companyId!.isEmpty) {
      _showSnack('Company not linked. Cannot load products.', isError: true);
      return null;
    }

    final searchController = TextEditingController();
    String searchText = '';

    Query<Map<String, dynamic>> productQuery = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products');

    if (!_isAdminOrManager && _currentUserUid != null) {
      productQuery = productQuery.where(
        'createdBy',
        isEqualTo: _currentUserUid,
      );
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Product'),
              content: SizedBox(
                width: 500,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search by name or code',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchText = value.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: productQuery.snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('Error loading products'),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];
                          final filtered = docs.where((doc) {
                            final data = doc.data();
                            final name = (data['name'] ?? '')
                                .toString()
                                .toLowerCase();
                            final itemCode = (data['itemCode'] ?? '')
                                .toString()
                                .toLowerCase();

                            if (searchText.isEmpty) return true;

                            return name.contains(searchText) ||
                                itemCode.contains(searchText);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text('No matching products found'),
                            );
                          }

                          return ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data = doc.data();

                              final name = (data['name'] ?? '').toString();
                              final hsnCode = (data['hsnCode'] ?? '')
                                  .toString();
                              final itemCode = (data['itemCode'] ?? '')
                                  .toString();
                              final uom = (data['uom'] ?? '').toString();
                              final unitPrice = (data['unitPrice'] ?? 0)
                                  .toString();
                              final gst = (data['gstPercentage'] ?? 0)
                                  .toString();

                              final subtitleLines = <String>[];
                              if (itemCode.isNotEmpty) {
                                subtitleLines.add('Code: $itemCode');
                              }
                              if (hsnCode.isNotEmpty) {
                                subtitleLines.add('HSN: $hsnCode');
                              }
                              if (uom.isNotEmpty) {
                                subtitleLines.add('UOM: $uom');
                              }
                              subtitleLines.add(
                                'Price: Rs $unitPrice | GST: $gst%',
                              );

                              return ListTile(
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(subtitleLines.join(' | ')),
                                onTap: () {
                                  Navigator.pop<Map<String, dynamic>>(context, {
                                    'id': doc.id,
                                    ...data,
                                  });
                                },
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
            );
          },
        );
      },
    );
  }

  void _showAddItemModal([Item? itemToEdit, int? index]) {
    final modalFormKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: itemToEdit?.name ?? '');
    final descriptionController = TextEditingController(
      text: itemToEdit?.description ?? '',
    );
    final quantityController = TextEditingController(
      text: itemToEdit != null ? itemToEdit.quantity.toString() : '',
    );
    final priceController = TextEditingController(
      text: itemToEdit != null ? itemToEdit.unitPrice.toString() : '',
    );

    String currentId =
        itemToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    String currentCompanyId = itemToEdit?.companyId ?? (_companyId ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
            key: modalFormKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        itemToEdit == null ? 'Add Line Item' : 'Edit Line Item',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final productData = await _selectProductDialog();
                          if (productData == null) return;

                          currentId = (productData['id'] ?? currentId)
                              .toString();

                          nameController.text = (productData['name'] ?? '')
                              .toString();
                          descriptionController.text =
                              (productData['description'] ?? '').toString();
                          priceController.text = (productData['unitPrice'] ?? 0)
                              .toString();
                          quantityController.text = '1';

                          final gst = productData['gstPercentage'];
                          if (gst != null) {
                            setState(() {
                              _taxRate = (gst as num).toDouble();
                            });
                          }
                        },
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('From Products'),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildItemTextField(
                    nameController,
                    'Item Name',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  _buildItemTextField(
                    descriptionController,
                    'Description (optional)',
                    maxLines: 3,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildItemTextField(
                          quantityController,
                          'Quantity',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Valid quantity required';
                            }
                            if (double.tryParse(v.trim()) == null) {
                              return 'Valid quantity required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildItemTextField(
                          priceController,
                          'Unit Price',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Valid price required';
                            }
                            if (double.tryParse(v.trim()) == null) {
                              return 'Valid price required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (!modalFormKey.currentState!.validate()) return;

                      final newItem = Item(
                        id: currentId,
                        companyId: currentCompanyId,
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim(),
                        quantity: double.parse(quantityController.text.trim()),
                        unitPrice: double.parse(priceController.text.trim()),
                        isActive: itemToEdit?.isActive ?? true,
                        isDeleted: itemToEdit?.isDeleted ?? false,
                        createdAt: itemToEdit?.createdAt ?? DateTime.now(),
                        createdBy:
                            itemToEdit?.createdBy ?? (_currentUserUid ?? ''),
                      );

                      setState(() {
                        if (index != null) {
                          _items[index] = newItem;
                        } else {
                          _items.add(newItem);
                        }
                      });

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      itemToEdit == null ? 'Add Item' : 'Save Changes',
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
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
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _openSettings() {
    final deliveryController = TextEditingController(
      text: _deliveryTimeController.text,
    );
    final validityController = TextEditingController(
      text: _validityController.text,
    );
    final priceBasisController = TextEditingController(
      text: _priceBasisController.text,
    );
    final paymentController = TextEditingController(
      text: _paymentTermsController.text,
    );

    final signCompanyController = TextEditingController(
      text: _signCompanyController.text,
    );
    final signNameController = TextEditingController(
      text: _signNameController.text,
    );
    final signPhoneController = TextEditingController(
      text: _signPhoneController.text,
    );

    double tempTaxRate = _taxRate;
    bool tempPackingExtra = _packingChargesExtra;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickLetterhead() async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  _showSnack(
                    'Please login before uploading letterhead',
                    isError: true,
                  );
                  return;
                }

                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                  withData: true,
                );

                if (result == null || result.files.isEmpty) return;

                final file = result.files.first;
                if (file.bytes == null) {
                  _showSnack('Unable to read file bytes', isError: true);
                  return;
                }

                if (!mounted) return;
                setState(() {
                  _letterheadBytes = file.bytes!;
                });
                setModalState(() {});

                setModalState(() {
                  _isUploadingLetterhead = true;
                });

                try {
                  final path =
                      'letterheads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
                  final ref = FirebaseStorage.instance.ref().child(path);

                  await ref.putData(
                    file.bytes!,
                    SettableMetadata(
                      contentType: file.extension == 'png'
                          ? 'image/png'
                          : 'image/jpeg',
                    ),
                  );

                  final url = await ref.getDownloadURL();

                  if (!mounted) return;
                  setState(() {
                    _letterheadUrl = url;
                  });

                  setModalState(() {});
                  await _saveUserSettings();
                  _showSnack('Letterhead uploaded successfully');
                } catch (e) {
                  _showSnack('Cloud upload failed: $e', isError: true);
                } finally {
                  setModalState(() {
                    _isUploadingLetterhead = false;
                  });
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: const [
                        Icon(Icons.settings, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Quotation Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.image_outlined,
                        color: primaryColor,
                      ),
                      title: Text(
                        !_hasSavedLetterhead
                            ? 'No letterhead selected'
                            : 'Letterhead ready for preview and print',
                      ),
                      subtitle: const Text(
                        'Upload a PNG or JPG letterhead image.',
                      ),
                      trailing: _isUploadingLetterhead
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : OutlinedButton(
                              onPressed: pickLetterhead,
                              child: const Text('Upload / Change'),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('Default GST (%)')),
                        SizedBox(
                          width: 180,
                          child: Slider(
                            value: tempTaxRate,
                            min: 0,
                            max: 28,
                            divisions: 28,
                            label: tempTaxRate.toStringAsFixed(1),
                            onChanged: (v) {
                              setModalState(() {
                                tempTaxRate = v;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: tempPackingExtra,
                      title: const Text(
                        'Packing and Forwarding charges EXTRA by default',
                      ),
                      onChanged: (v) {
                        setModalState(() {
                          tempPackingExtra = v;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deliveryController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Time',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: validityController,
                      decoration: const InputDecoration(
                        labelText: 'Quotation Validity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceBasisController,
                      decoration: const InputDecoration(
                        labelText: 'Price Basis',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: paymentController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Terms',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: signCompanyController,
                      decoration: const InputDecoration(
                        labelText: 'Company / Brand Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: signNameController,
                      decoration: const InputDecoration(
                        labelText: 'Signatory Name & Designation',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: signPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            _taxRate = tempTaxRate;
                            _packingChargesExtra = tempPackingExtra;
                            _deliveryTimeController.text = deliveryController
                                .text
                                .trim();
                            _validityController.text = validityController.text
                                .trim();
                            _priceBasisController.text = priceBasisController
                                .text
                                .trim();
                            _paymentTermsController.text = paymentController
                                .text
                                .trim();
                            _signCompanyController.text = signCompanyController
                                .text
                                .trim();
                            _signNameController.text = signNameController.text
                                .trim();
                            _signPhoneController.text = signPhoneController.text
                                .trim();
                          });

                          await _saveUserSettings();

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Save Settings'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Map<String, dynamic> _customerSnapshotForSave() {
    return {
      'customerId': _selectedCustomerId,
      'companyName': _companyNameController.text.trim(),
      'address': _addressController.text.trim(),
      'email': _emailController.text.trim(),
      'mobile': _mobileController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'gstNo': _gstController.text.trim(),
    };
  }

  Future<void> _saveQuotation() async {
    _clearError();

    if (!_formKey.currentState!.validate()) {
      _setError('Please complete the required fields.');
      return;
    }

    if (_items.isEmpty) {
      _setError('Please add at least one item to the quotation.');
      return;
    }

    if (_companyId == null || _companyId!.isEmpty || _currentUserUid == null) {
      _setError('User or company context not loaded properly.');
      return;
    }

    if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
      _setError('Please select an existing customer from customer master.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final itemsData = _items.map((item) => item.toFirestore()).toList();

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('quotations')
          .add({
            'companyId': _companyId,
            'userId': widget.userId,
            'firebaseUserId': user?.uid,
            'quoteNumber': _quoteNumberController.text.trim(),
            'financialYear': _quoteNumberController.text.split('/').last,
            'quoteDate': Timestamp.fromDate(_quoteDate),
            'customerId': _selectedCustomerId,
            'customerSnapshot': _customerSnapshotForSave(),
            'clientName': _companyNameController.text.trim(),
            'clientAddress': _addressController.text.trim(),
            'clientEmail': _emailController.text.trim(),
            'clientMobile': _mobileController.text.trim(),
            'contactPerson': _contactPersonController.text.trim(),
            'gstNo': _gstController.text.trim(),
            'inquirySource': _selectedInquirySource,
            'inquiryDate': Timestamp.fromDate(_inquiryDate),
            'inquiryReference': _inquiryRefNoteController.text.trim(),
            'taxRate': _taxRate,
            'discountPercentage': _discount,
            'subtotal': _subtotal,
            'discountAmount': _discountAmount,
            'taxableAmount': _taxableAmount,
            'taxAmount': _taxAmount,
            'grandTotal': _grandTotal,
            'deliveryTime': _deliveryTimeController.text.trim(),
            'validity': _validityController.text.trim(),
            'priceBasis': _priceBasisController.text.trim(),
            'paymentTerms': _paymentTermsController.text.trim(),
            'packingChargesExtra': _packingChargesExtra,
            'extraTerms': _extraTerms,
            'letterheadUrl': _letterheadUrl,
            'signatureCompany': _signCompanyController.text.trim(),
            'signatureName': _signNameController.text.trim(),
            'signaturePhone': _signPhoneController.text.trim(),
            'items': itemsData,
            'status': 'Draft',
            'assignedToUid': _currentUserUid,
            'assignedByUid': _currentUserUid,
            'createdBy': _currentUserUid,
            'createdByUid': _currentUserUid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedBy': _currentUserUid,
            'updatedByUid': _currentUserUid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      _showSnack('Quotation saved successfully');
    } catch (e) {
      _setError('Failed to save quotation: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPreviewPressed() {
    if (_items.isEmpty) {
      _showSnack('Add at least one item before preview.', isError: true);
      return;
    }

    final data = <String, dynamic>{
      'clientName': _companyNameController.text.trim(),
      'clientAddress': _addressController.text.trim(),
      'clientEmail': _emailController.text.trim(),
      'clientMobile': _mobileController.text.trim(),
      'contactPerson': _contactPersonController.text.trim(),
      'gstNo': _gstController.text.trim(),
      'quoteNumber': _quoteNumberController.text.trim(),
      'quoteDateStr': _formatDate(_quoteDate),
      'inquirySource': _selectedInquirySource,
      'inquiryDateStr': _formatDate(_inquiryDate),
      'inquiryReference': _inquiryRefNoteController.text.trim(),
      'taxRate': _taxRate,
      'discountPercentage': _discount,
      'subtotal': _subtotal,
      'discountAmount': _discountAmount,
      'taxableAmount': _taxableAmount,
      'taxAmount': _taxAmount,
      'grandTotal': _grandTotal,
      'deliveryTime': _deliveryTimeController.text.trim(),
      'validity': _validityController.text.trim(),
      'priceBasis': _priceBasisController.text.trim(),
      'paymentTerms': _paymentTermsController.text.trim(),
      'packingChargesExtra': _packingChargesExtra,
      'extraTerms': _extraTerms,
      'letterheadUrl': _letterheadUrl,
      'letterheadBytes': _letterheadBytes,
      'signatureCompany': _signCompanyController.text.trim(),
      'signatureName': _signNameController.text.trim(),
      'signaturePhone': _signPhoneController.text.trim(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationPreviewScreen(
          quotation: data,
          items: List<Item>.from(_items),
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Customer Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    final customer = await _selectCustomerDialog();
                    if (customer != null) {
                      _applyCustomer(customer);
                    }
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Select Customer'),
                ),
                const SizedBox(width: 8),
                if (_selectedCustomerId != null)
                  TextButton.icon(
                    onPressed: _clearSelectedCustomer,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const Divider(),
            if (_selectedCustomerId != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  'Linked customer ID: $_selectedCustomerId',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            _buildCustomTextField(
              _companyNameController,
              'Company Name *',
              Icons.business,
              required: true,
            ),
            _buildCustomTextField(
              _addressController,
              'Address',
              Icons.location_on_outlined,
              maxLines: 2,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildCustomTextField(
                    _emailController,
                    'Email',
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCustomTextField(
                    _mobileController,
                    'Mobile',
                    Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildCustomTextField(
                    _contactPersonController,
                    'Contact Person',
                    Icons.person_outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCustomTextField(
                    _gstController,
                    'GST No.',
                    Icons.request_quote_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationNumberField() {
    return TextFormField(
      controller: _quoteNumberController,
      readOnly: !_canEditQuotationNumber,
      enabled: true,
      decoration: InputDecoration(
        labelText: 'Quotation No.',
        prefixIcon: Icon(
          Icons.confirmation_number_outlined,
          color: primaryColor.withOpacity(0.7),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Quotation number required';
        }
        return null;
      },
    );
  }

  Widget _buildInquirySection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inquiry and Quotation Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: 'Inquiry Source',
                    value: _selectedInquirySource,
                    items: _inquirySources,
                    icon: Icons.record_voice_over_outlined,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedInquirySource = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDateField(
                    label: 'Inquiry Date',
                    icon: Icons.event_note_outlined,
                    date: _inquiryDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _inquiryDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _inquiryDate = picked;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildQuotationNumberField()),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDateField(
                    label: 'Quotation Date',
                    icon: Icons.today_outlined,
                    date: _quoteDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _quoteDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _quoteDate = picked;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCustomTextField(
              _inquiryRefNoteController,
              'Inquiry Reference / Notes',
              Icons.notes_outlined,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Line Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _showAddItemModal(),
                  icon: const Icon(Icons.add_circle, color: accentColor),
                ),
              ],
            ),
            const Divider(),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Click + to add a product or service.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                itemCount: _items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${item.quantity} x Rs ${item.unitPrice.toStringAsFixed(2)}',
                    ),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(
                          'Rs ${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showAddItemModal(item, index),
                          icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _items.removeAt(index);
                            });
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', _subtotal),
            const Divider(),
            Row(
              children: [
                Text(
                  'GST Rate (${_taxRate.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: Slider(
                    value: _taxRate,
                    min: 0,
                    max: 28,
                    divisions: 28,
                    label: _taxRate.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _taxRate = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            _buildSummaryRow('GST Amount', _taxAmount, isTax: true),
            Row(
              children: [
                Text(
                  'Discount (${_discount.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: Slider(
                    value: _discount,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: _discount.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _discount = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            _buildSummaryRow(
              'Discount Amount',
              _discountAmount,
              isNegative: true,
            ),
            const Divider(thickness: 2),
            _buildSummaryRow('GRAND TOTAL', _grandTotal, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms and Conditions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const Divider(),
            _buildCustomTextField(
              _deliveryTimeController,
              'Delivery Time',
              Icons.local_shipping_outlined,
            ),
            _buildCustomTextField(
              _validityController,
              'Quotation Validity',
              Icons.schedule_outlined,
            ),
            _buildCustomTextField(
              _priceBasisController,
              'Price Basis',
              Icons.place_outlined,
            ),
            _buildCustomTextField(
              _paymentTermsController,
              'Payment Terms',
              Icons.payments_outlined,
            ),
            SwitchListTile(
              value: _packingChargesExtra,
              title: const Text('Packing and Forwarding charges EXTRA'),
              onChanged: (v) {
                setState(() {
                  _packingChargesExtra = v;
                });
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _extraTermController,
                    decoration: InputDecoration(
                      labelText: 'Add additional term',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final t = _extraTermController.text.trim();
                    if (t.isEmpty) return;
                    setState(() {
                      _extraTerms.add(t);
                      _extraTermController.clear();
                    });
                  },
                  icon: const Icon(Icons.add_circle, color: accentColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_extraTerms.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _extraTerms.asMap().entries.map((entry) {
                  final index = entry.key;
                  final value = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text('${index + 1}.'),
                    title: Text(value),
                    trailing: IconButton(
                      onPressed: () {
                        setState(() {
                          _extraTerms.removeAt(index);
                        });
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isNegative = false,
    bool isTax = false,
  }) {
    final color = isNegative
        ? Colors.red.shade700
        : (isTotal ? primaryColor : Colors.black87);
    final weight = isTotal ? FontWeight.bold : FontWeight.normal;
    final fontSize = isTotal ? 20.0 : 16.0;

    String sign = '';
    if (isNegative) sign = '-';
    if (isTax) sign = '+';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            '$sign Rs ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.7)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'This field is required.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: items
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.7)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
        ),
        child: Text(_formatDate(date)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyContextMissing = _companyId == null || _companyId!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2A3D),
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'New Quotation',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: _onPreviewPressed,
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            tooltip: 'Preview / Print',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (companyContextMissing)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Company context is not loaded yet. Save and picker may not work correctly.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                _buildCustomerSection(),
                const SizedBox(height: 16),
                _buildInquirySection(),
                const SizedBox(height: 16),
                _buildItemsSection(),
                const SizedBox(height: 16),
                _buildSummarySection(),
                const SizedBox(height: 16),
                _buildTermsSection(),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _onPreviewPressed,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Preview on Letterhead and Print'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveQuotation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isLoading ? 'Saving...' : 'Save Quotation',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

class QuotationPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> quotation;
  final List<Item> items;

  const QuotationPreviewScreen({
    super.key,
    required this.quotation,
    required this.items,
  });

  String _currency(double value) => 'Rs ${value.toStringAsFixed(2)}';

  pw.Widget _metaRow(String label, String? value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(value ?? '', style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  pw.Widget _cellCenter(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Center(
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    ),
  );

  pw.Widget _cellLeft(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  pw.Widget _cellRight(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    ),
  );

  pw.Widget _buildItemsTable() {
    final headers = [
      'S.\nNo.',
      'Description',
      'Qty',
      'UOM',
      'Unit Price',
      'Amount',
    ];

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FixedColumnWidth(70),
        5: const pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1A3A52),
          ),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Center(
                    child: pw.Text(
                      h,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          final amount = item.quantity * item.unitPrice;
          final desc = item.description.isEmpty
              ? item.name
              : '${item.name}\n${item.description}';

          return pw.TableRow(
            children: [
              _cellCenter('${index + 1}'),
              _cellLeft(desc),
              _cellCenter(item.quantity.toStringAsFixed(2)),
              _cellCenter('Nos'),
              _cellRight(_currency(item.unitPrice)),
              _cellRight(_currency(amount)),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _summaryRow(String label, double value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          _currency(value),
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryBox() {
    final subtotal = (quotation['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discountPct =
        (quotation['discountPercentage'] as num?)?.toDouble() ?? 0.0;
    final discountAmt =
        (quotation['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final taxRate = (quotation['taxRate'] as num?)?.toDouble() ?? 0.0;
    final taxAmt = (quotation['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (quotation['grandTotal'] as num?)?.toDouble() ?? 0.0;

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _summaryRow('Subtotal', subtotal),
            _summaryRow(
              'Discount (${discountPct.toStringAsFixed(1)}%)',
              -discountAmt,
            ),
            _summaryRow('Tax (${taxRate.toStringAsFixed(1)}%)', taxAmt),
            pw.Divider(),
            _summaryRow('Grand Total', grandTotal, isBold: true),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTermsAndConditions() {
    final List<String> terms = [];

    final delivery = (quotation['deliveryTime'] ?? '').toString();
    final validity = (quotation['validity'] ?? '').toString();
    final priceBasis = (quotation['priceBasis'] ?? '').toString();
    final payment = (quotation['paymentTerms'] ?? '').toString();
    final packingExtra = quotation['packingChargesExtra'] as bool? ?? false;
    final extraTerms = (quotation['extraTerms'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    if (delivery.isNotEmpty) terms.add('Delivery: $delivery');
    if (validity.isNotEmpty) terms.add('Validity: $validity');
    if (priceBasis.isNotEmpty) terms.add('Price Basis: $priceBasis');
    if (payment.isNotEmpty) terms.add('Payment: $payment');
    if (packingExtra) {
      terms.add('Packing and Forwarding charges will be extra as applicable.');
    }
    terms.addAll(extraTerms);

    if (terms.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Terms and Conditions',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        ...terms.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final text = entry.value;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$idx. ', style: const pw.TextStyle(fontSize: 10)),
                pw.Expanded(
                  child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  pw.Widget _buildSignatureBlock() {
    final company = (quotation['signatureCompany'] ?? '').toString();
    final name = (quotation['signatureName'] ?? '').toString();
    final phone = (quotation['signaturePhone'] ?? '').toString();

    if (company.isEmpty && name.isEmpty && phone.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (company.isNotEmpty)
            pw.Text(
              'From $company',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          if (name.isNotEmpty)
            pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
          if (phone.isNotEmpty)
            pw.Text(phone, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Authorised Signatory',
            style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final doc = pw.Document();

    pw.ImageProvider? headerImage;
    final letterheadUrl = quotation['letterheadUrl'] as String?;
    final letterheadBytes = quotation['letterheadBytes'] as Uint8List?;

    if (letterheadUrl != null && letterheadUrl.isNotEmpty) {
      headerImage = await networkImage(letterheadUrl);
    } else if (letterheadBytes != null && letterheadBytes.isNotEmpty) {
      headerImage = pw.MemoryImage(letterheadBytes);
    }

    final pageTheme = pw.PageTheme(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(24),
      buildBackground: (context) {
        if (headerImage == null) return pw.SizedBox();
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(headerImage, fit: pw.BoxFit.cover),
        );
      },
    );

    const double topGap = 110;
    const double bottomGap = 60;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) {
          return [
            pw.SizedBox(height: topGap),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        (quotation['clientName'] ?? '').toString(),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if ((quotation['clientAddress'] ?? '')
                          .toString()
                          .isNotEmpty)
                        pw.Text(
                          quotation['clientAddress'].toString(),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if ((quotation['contactPerson'] ?? '')
                          .toString()
                          .isNotEmpty)
                        pw.Text(
                          'Attn: ${quotation['contactPerson']}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if ((quotation['clientEmail'] ?? '')
                          .toString()
                          .isNotEmpty)
                        pw.Text(
                          'Email: ${quotation['clientEmail']}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if ((quotation['clientMobile'] ?? '')
                          .toString()
                          .isNotEmpty)
                        pw.Text(
                          'Mobile: ${quotation['clientMobile']}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if ((quotation['gstNo'] ?? '').toString().isNotEmpty)
                        pw.Text(
                          'GST No: ${quotation['gstNo']}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Quotation',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _metaRow('No:', quotation['quoteNumber']?.toString()),
                      _metaRow('Date:', quotation['quoteDateStr']?.toString()),
                      _metaRow(
                        'Inquiry:',
                        quotation['inquirySource']?.toString(),
                      ),
                      _metaRow(
                        'Inquiry Date:',
                        quotation['inquiryDateStr']?.toString(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            _buildItemsTable(),
            pw.SizedBox(height: 16),
            _buildSummaryBox(),
            pw.SizedBox(height: 24),
            _buildTermsAndConditions(),
            pw.SizedBox(height: bottomGap),
            _buildSignatureBlock(),
          ];
        },
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Quotation Preview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: PdfPreview(
        build: _buildPdf,
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
