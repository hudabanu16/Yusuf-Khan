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
  final _formKey = GlobalKey<FormState>();

  // --- Customer / Company details ---
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _gstController = TextEditingController();

  // --- Inquiry & quotation details ---
  final _quoteNumberController = TextEditingController();
  final _inquiryRefNoteController = TextEditingController();

  final List<String> _inquirySources = [
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

  // --- Items / Pricing ---
  List<Item> _items = [];
  double _taxRate = 18.0;
  double _discount = 0.0;

  // --- Terms & Conditions ---
  final _deliveryTimeController = TextEditingController();
  final _validityController = TextEditingController();
  final _priceBasisController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  bool _packingChargesExtra = true;

  final _extraTermController = TextEditingController();
  final List<String> _extraTerms = [];

  // --- Letterhead ---
  String? _letterheadUrl;
  Uint8List? _letterheadBytes;
  bool _isUploadingLetterhead = false;

  // --- Signature block ---
  final _signCompanyController = TextEditingController();
  final _signNameController = TextEditingController();
  final _signPhoneController = TextEditingController();

  // --- User / company context ---
  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'sales';
  String _currentCompanyName = '';

  bool get _isAdminOrManager =>
      _currentUserRole == 'admin' || _currentUserRole == 'manager';

  // --- State flags ---
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _quoteNumberController.text = _generateQuoteNumber();

    _deliveryTimeController.text = 'Within 4–6 weeks from PO and advance.';
    _validityController.text = '30 days from date of quotation.';
    _priceBasisController.text = 'Ex-works Mumbai, packing extra.';
    _paymentTermsController.text = '50% advance with PO, balance against PI.';

    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadUserContext();
    await _loadUserSettings();
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
      if (user == null) return;

      final rootUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = rootUserDoc.data() ?? {};

      _currentUserUid = user.uid;
      _companyId = (data['companyId'] ?? '').toString();
      _currentUserRole = (data['role'] ?? 'sales').toString();
      _currentCompanyName = (data['companyName'] ?? '').toString();

      if (_signCompanyController.text.trim().isEmpty &&
          _currentCompanyName.isNotEmpty) {
        _signCompanyController.text = _currentCompanyName;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  // ========= SETTINGS LOAD / SAVE =========

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

      final data = doc.data() ?? {};

      setState(() {
        _letterheadUrl = (data['letterheadUrl'] ?? '') as String?;

        _taxRate = (data['taxRate'] as num?)?.toDouble() ?? _taxRate;
        _packingChargesExtra =
            data['packingChargesExtra'] as bool? ?? _packingChargesExtra;

        final delivery = data['deliveryTime']?.toString();
        final validity = data['validity']?.toString();
        final priceBasis = data['priceBasis']?.toString();
        final payment = data['paymentTerms']?.toString();

        if (delivery != null && delivery.isNotEmpty) {
          _deliveryTimeController.text = delivery;
        }
        if (validity != null && validity.isNotEmpty) {
          _validityController.text = validity;
        }
        if (priceBasis != null && priceBasis.isNotEmpty) {
          _priceBasisController.text = priceBasis;
        }
        if (payment != null && payment.isNotEmpty) {
          _paymentTermsController.text = payment;
        }

        final signCompany = data['signatureCompany']?.toString();
        final signName = data['signatureName']?.toString();
        final signPhone = data['signaturePhone']?.toString();

        if (signCompany != null && signCompany.isNotEmpty) {
          _signCompanyController.text = signCompany;
        } else if (_currentCompanyName.isNotEmpty &&
            _signCompanyController.text.trim().isEmpty) {
          _signCompanyController.text = _currentCompanyName;
        }

        if (signName != null) _signNameController.text = signName;
        if (signPhone != null) _signPhoneController.text = signPhone;
      });
    } catch (_) {}
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
    } catch (_) {}
  }

  // ========= BASIC HELPERS =========

  String _generateQuoteNumber() {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'QTE-$y$m$d-001';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  double get _discountAmount => _subtotal * (_discount / 100);
  double get _taxableAmount => _subtotal - _discountAmount;
  double get _taxAmount => _taxableAmount * (_taxRate / 100);
  double get _grandTotal => _taxableAmount + _taxAmount;

  // ================== PRODUCT PICKER ==================

  Future<Map<String, dynamic>?> _selectProductDialog() async {
    if (_companyId == null || _companyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company not linked. Cannot load products.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final TextEditingController searchController = TextEditingController();
    String searchText = '';

    Query<Map<String, dynamic>> productQuery = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .collection('products');

    if (!_isAdminOrManager && _currentUserUid != null) {
      productQuery = productQuery.where('createdBy', isEqualTo: _currentUserUid);
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                      ),
                      onChanged: (value) {
                        setStateDialog(() {
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
                            final name =
                            (data['name'] ?? '').toString().toLowerCase();
                            final itemCode = (data['itemCode'] ?? '')
                                .toString()
                                .toLowerCase();
                            if (searchText.isEmpty) return true;
                            return name.contains(searchText) ||
                                itemCode.contains(searchText);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text(
                                'No matching products found.\nTry a different search.',
                                textAlign: TextAlign.center,
                              ),
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
                              final hsnCode =
                              (data['hsnCode'] ?? '').toString();
                              final itemCode =
                              (data['itemCode'] ?? '').toString();
                              final uom = (data['uom'] ?? '').toString();
                              final unitPrice =
                              (data['unitPrice'] ?? 0).toString();
                              final gst =
                              (data['gstPercentage'] ?? 0).toString();

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
                              subtitleLines
                                  .add('Price: Rs $unitPrice | GST: $gst%');

                              return ListTile(
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(subtitleLines.join(' • ')),
                                onTap: () {
                                  Navigator.pop<Map<String, dynamic>>(
                                    context,
                                    {
                                      'id': doc.id,
                                      ...data,
                                    },
                                  );
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

  // ================== ADD / EDIT ITEM ==================

  void _showAddItemModal([Item? itemToEdit, int? index]) {
    String currentId = itemToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    String currentCompanyId = itemToEdit?.companyId ?? _companyId ?? '';

    final nameController = TextEditingController(text: itemToEdit?.name);
    final descriptionController =
    TextEditingController(text: itemToEdit?.description);
    final quantityController =
    TextEditingController(text: itemToEdit?.quantity.toString());
    final priceController =
    TextEditingController(text: itemToEdit?.unitPrice.toString());
    final modalFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        itemToEdit == null
                            ? 'Add Line Item'
                            : 'Edit Line Item',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final productData = await _selectProductDialog();
                          if (productData != null) {
                            currentId = (productData['id'] ?? currentId).toString();
                            nameController.text =
                                (productData['name'] ?? '').toString();
                            descriptionController.text =
                                (productData['description'] ?? '').toString();
                            priceController.text =
                                (productData['unitPrice'] ?? 0).toString();
                            quantityController.text = '1';

                            final gst = productData['gstPercentage'];
                            if (gst != null) {
                              setState(() {
                                _taxRate = (gst as num).toDouble();
                              });
                            }
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
                          validator: (v) => v == null ||
                              v.trim().isEmpty ||
                              double.tryParse(v) == null
                              ? 'Valid number required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildItemTextField(
                          priceController,
                          'Unit Price',
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null ||
                              v.trim().isEmpty ||
                              double.tryParse(v) == null
                              ? 'Valid price required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (modalFormKey.currentState!.validate()) {
                        final newItem = Item(
                          id: currentId,
                          companyId: currentCompanyId,
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          quantity: double.parse(quantityController.text),
                          unitPrice: double.parse(priceController.text),
                          isActive: itemToEdit?.isActive ?? true,
                          isDeleted: itemToEdit?.isDeleted ?? false,
                          createdAt: itemToEdit?.createdAt ?? DateTime.now(),
                          createdBy: itemToEdit?.createdBy ?? _currentUserUid ?? '',
                        );

                        setState(() {
                          if (index != null) {
                            _items[index] = newItem;
                          } else {
                            _items.add(newItem);
                          }
                        });
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
      padding: const EdgeInsets.only(bottom: 12.0),
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

  // ================== SETTINGS SHEET ==================

  void _openSettings() {
    final deliveryController =
    TextEditingController(text: _deliveryTimeController.text);
    final validityController =
    TextEditingController(text: _validityController.text);
    final priceBasisController =
    TextEditingController(text: _priceBasisController.text);
    final paymentController =
    TextEditingController(text: _paymentTermsController.text);

    final signCompanyController =
    TextEditingController(text: _signCompanyController.text);
    final signNameController =
    TextEditingController(text: _signNameController.text);
    final signPhoneController =
    TextEditingController(text: _signPhoneController.text);

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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please login before uploading letterhead'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                  withData: true,
                );

                if (result == null || result.files.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No file selected'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final file = result.files.first;
                if (file.bytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to read file bytes'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  _letterheadBytes = file.bytes!;
                });
                setModalState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Letterhead loaded. Uploading to cloud in background...'),
                    backgroundColor: Colors.green,
                  ),
                );

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

                  setState(() {
                    _letterheadUrl = url;
                  });
                  setModalState(() {});
                  await _saveUserSettings();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cloud upload failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Letterhead',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.image_outlined,
                          color: primaryColor),
                      title: Text(
                        _letterheadBytes == null && _letterheadUrl == null
                            ? 'No letterhead selected'
                            : 'Letterhead ready for preview & print',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Upload a PNG or JPG letterhead image (full page or header+footer).',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: _isUploadingLetterhead
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      )
                          : OutlinedButton(
                        onPressed: pickLetterhead,
                        child: const Text('Upload / Change'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quotation Defaults',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Default GST (%)',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
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
                          'Packing & Forwarding charges EXTRA by default'),
                      subtitle: const Text(
                          'Turn OFF if packing is usually included in quoted prices.'),
                      onChanged: (v) {
                        setModalState(() {
                          tempPackingExtra = v;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Default Terms & Conditions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deliveryController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Time',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: validityController,
                      decoration: const InputDecoration(
                        labelText: 'Quotation Validity',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceBasisController,
                      decoration: const InputDecoration(
                        labelText: 'Price Basis (Ex-Works / FOR etc.)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: paymentController,
                      decoration: const InputDecoration(
                        labelText:
                        'Payment Terms (Advance %, Against PI / PDC / Credit)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Signature Block',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: signCompanyController,
                      decoration: const InputDecoration(
                        labelText: 'Company / Brand Name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: signNameController,
                      decoration: const InputDecoration(
                        labelText: 'Signatory Name & Designation',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: signPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                        isDense: true,
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
                            _deliveryTimeController.text =
                                deliveryController.text.trim();
                            _validityController.text =
                                validityController.text.trim();
                            _priceBasisController.text =
                                priceBasisController.text.trim();
                            _paymentTermsController.text =
                                paymentController.text.trim();

                            _signCompanyController.text =
                                signCompanyController.text.trim();
                            _signNameController.text =
                                signNameController.text.trim();
                            _signPhoneController.text =
                                signPhoneController.text.trim();
                          });
                          await _saveUserSettings();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text(
                          'Save Settings',
                          style: TextStyle(fontSize: 16),
                        ),
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

  // ================== SAVE QUOTATION ==================

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one item to the quotation.';
      });
      return;
    }

    if (_companyId == null || _companyId!.isEmpty || _currentUserUid == null) {
      setState(() {
        _errorMessage = 'User/company context not loaded properly.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        'quoteDate': Timestamp.fromDate(_quoteDate),

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Quotation saved to cloud successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save quotation: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ================== PREVIEW & PRINT ==================

  void _onPreviewPressed() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item before preview.'),
          backgroundColor: Colors.red,
        ),
      );
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

  // ================== UI BUILD ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Quotation'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Quotation Settings',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Preview on Letterhead & Print',
            onPressed: _onPreviewPressed,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_companyId == null || _companyId!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Company context is not loaded yet. Quotation save and product picker may not work correctly.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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
                      'Error: $_errorMessage',
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
                    label: const Text('Preview on Letterhead & Print'),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== SECTIONS UI ==========

  Widget _buildCustomerSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const Divider(),
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

  Widget _buildInquirySection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inquiry & Quotation Details',
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
                        setState(() => _selectedInquirySource = value);
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
                        setState(() => _inquiryDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField(
                    controller: _quoteNumberController,
                    label: 'Quotation No.',
                    icon: Icons.confirmation_number_outlined,
                  ),
                ),
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
                        setState(() => _quoteDate = picked);
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Line Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: accentColor),
                  onPressed: () => _showAddItemModal(),
                ),
              ],
            ),
            const Divider(),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Text(
                    'Click "+" to add a product or service.\nYou can pick from Products master.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rs ${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.blueGrey,
                          ),
                          onPressed: () => _showAddItemModal(item, index),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() => _items.removeAt(index));
                          },
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryRow('Subtotal', _subtotal),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GST Rate (${_taxRate.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(
                  width: 170,
                  child: Slider(
                    value: _taxRate,
                    min: 0,
                    max: 28,
                    divisions: 28,
                    label: _taxRate.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() => _taxRate = value);
                    },
                  ),
                ),
              ],
            ),
            _buildSummaryRow('GST Amount', _taxAmount, isTax: true),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount (${_discount.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(
                  width: 170,
                  child: Slider(
                    value: _discount,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: _discount.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() => _discount = value);
                    },
                  ),
                ),
              ],
            ),
            _buildSummaryRow('Discount Amount', _discountAmount,
                isNegative: true),
            const Divider(thickness: 2, height: 20),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms & Conditions',
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
              'Price Basis (Ex-Works / FOR etc.)',
              Icons.place_outlined,
            ),
            _buildCustomTextField(
              _paymentTermsController,
              'Payment Terms (Advance %, Against PI / PDC / Credit)',
              Icons.payments_outlined,
            ),
            SwitchListTile(
              value: _packingChargesExtra,
              title: const Text('Packing & Forwarding charges EXTRA'),
              subtitle:
              const Text('Turn OFF if packing is included in quoted prices'),
              onChanged: (v) {
                setState(() {
                  _packingChargesExtra = v;
                });
              },
            ),
            const SizedBox(height: 8),
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
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: accentColor),
                  onPressed: () {
                    final t = _extraTermController.text.trim();
                    if (t.isNotEmpty) {
                      setState(() {
                        _extraTerms.add(t);
                        _extraTermController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_extraTerms.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _extraTerms.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final t = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text('${idx + 1}.'),
                    title: Text(t),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _extraTerms.removeAt(idx);
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ========== SMALL HELPERS ==========

  Widget _buildSummaryRow(
      String label,
      double amount, {
        bool isTotal = false,
        bool isNegative = false,
        bool isTax = false,
      }) {
    final Color color = isNegative
        ? Colors.red.shade700
        : (isTotal ? primaryColor : Colors.black87);
    final FontWeight weight = isTotal ? FontWeight.bold : FontWeight.normal;
    final double fontSize = isTotal ? 20 : 16;

    String sign = '';
    if (isNegative) sign = '-';
    if (isTax) sign = '+';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
            TextStyle(fontSize: fontSize, fontWeight: weight, color: color),
          ),
          Text(
            '$sign Rs ${amount.toStringAsFixed(2)}',
            style:
            TextStyle(fontSize: fontSize, fontWeight: weight, color: color),
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
              .map(
                (e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ),
          )
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
        ),
        child: Text(_formatDate(date)),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        isDense: true,
      ),
    );
  }
}

// ================== PREVIEW SCREEN ==================

class QuotationPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> quotation;
  final List<Item> items;

  const QuotationPreviewScreen({
    super.key,
    required this.quotation,
    required this.items,
  });

  String _currency(double v) => 'Rs ${v.toStringAsFixed(2)}';

  pw.Widget _metaRow(String label, String? value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Text(
            value ?? '',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  pw.Widget _cellCenter(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Center(
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    ),
  );

  pw.Widget _cellLeft(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 9),
    ),
  );

  pw.Widget _cellRight(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
      ),
    ),
  );

  pw.Widget _buildItemsTable() {
    final headers = [
      'S.\nNo.',
      'Description',
      'Qty',
      'UOM',
      'Unit Price',
      'Amount'
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

  pw.Widget _summaryRow(
      String label,
      double value, {
        bool isBold = false,
      }) {
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
      terms.add('Packing & Forwarding charges will be extra as applicable.');
    }
    terms.addAll(extraTerms);

    if (terms.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Terms & Conditions',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        ...terms.asMap().entries.map(
              (entry) {
            final idx = entry.key + 1;
            final text = entry.value;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$idx. ',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      text,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
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
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          if (name.isNotEmpty)
            pw.Text(
              name,
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (phone.isNotEmpty)
            pw.Text(
              phone,
              style: const pw.TextStyle(fontSize: 10),
            ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Authorised Signatory',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
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
          child: pw.Image(
            headerImage,
            fit: pw.BoxFit.cover,
          ),
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
                        quotation['clientName'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if ((quotation['clientAddress'] ?? '')
                          .toString()
                          .isNotEmpty)
                        pw.Text(
                          quotation['clientAddress'],
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
                      _metaRow('No:', quotation['quoteNumber']),
                      _metaRow('Date:', quotation['quoteDateStr']),
                      _metaRow('Inquiry:', quotation['inquirySource']),
                      _metaRow('Inquiry Date:', quotation['inquiryDateStr']),
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
        title: const Text('Quotation Preview'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
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