import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ScreensAddProduct extends StatefulWidget {
  final String companyId;
  final String currentUserUid;
  final String currentUserRole;
  final String? productId;
  final Map<String, dynamic>? initialData;

  const ScreensAddProduct({
    super.key,
    required this.companyId,
    required this.currentUserUid,
    required this.currentUserRole,
    this.productId,
    this.initialData,
  });

  @override
  State<ScreensAddProduct> createState() => _ScreensAddProductState();
}

class _ScreensAddProductState extends State<ScreensAddProduct> {
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isUploadingCatalog = false;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hsnController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _uomController = TextEditingController(text: 'Nos');

  final _openingStockController = TextEditingController(text: '0');
  final _reorderLevelController = TextEditingController(text: '0');
  final _minStockLevelController = TextEditingController(text: '0');
  final _maxStockLevelController = TextEditingController(text: '0');

  final _costPriceController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _gstController = TextEditingController(text: '18');

  final _brandController = TextEditingController();
  final _notesController = TextEditingController();

  String? _assignedToUid;

  String _productType = 'stock';
  bool _isActive = true;
  bool _trackInventory = true;
  bool _isSaleable = true;
  bool _isPurchasable = true;

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedSubcategoryId;
  String? _selectedSubcategoryName;

  String? _imageUrl;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;

  String? _catalogUrl;
  String? _catalogName;
  String? _catalogContentType;

  double _existingStockOnHand = 0;
  double _existingQty = 0;

  bool get isEditMode => widget.productId != null;

  bool get _canAssignOthers =>
      widget.currentUserRole == 'admin' || widget.currentUserRole == 'manager';

  bool get _isServiceLike =>
      _productType == 'service' || _productType == 'non_stock';

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('products');

  CollectionReference<Map<String, dynamic>> get _companyUsersRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users');

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('inventory_categories');

  CollectionReference<Map<String, dynamic>> _subcategoriesRef(
      String categoryId,
      ) =>
      _categoriesRef.doc(categoryId).collection('subcategories');

  @override
  void initState() {
    super.initState();

    _assignedToUid = widget.currentUserUid;

    final data = widget.initialData;
    if (data != null) {
      _nameController.text = (data['name'] ?? '').toString();
      _descriptionController.text = (data['description'] ?? '').toString();
      _hsnController.text = (data['hsnCode'] ?? '').toString();
      _itemCodeController.text = (data['itemCode'] ?? '').toString();
      _skuController.text = (data['sku'] ?? '').toString();
      _barcodeController.text = (data['barcode'] ?? '').toString();
      _uomController.text = (data['uom'] ?? 'Nos').toString();

      _brandController.text = (data['brand'] ?? '').toString();
      _notesController.text = (data['notes'] ?? '').toString();

      _imageUrl = (data['imageUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (data['imageUrl'] ?? '').toString().trim();

      _catalogUrl = (data['catalogUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (data['catalogUrl'] ?? '').toString().trim();
      _catalogName = (data['catalogName'] ?? '').toString().trim().isEmpty
          ? null
          : (data['catalogName'] ?? '').toString().trim();
      _catalogContentType =
      (data['catalogContentType'] ?? '').toString().trim().isEmpty
          ? null
          : (data['catalogContentType'] ?? '').toString().trim();

      final categoryId = (data['categoryId'] ?? '').toString().trim();
      final categoryName = (data['category'] ?? '').toString().trim();
      final subcategoryId = (data['subcategoryId'] ?? '').toString().trim();
      final subcategoryName = (data['subcategory'] ?? '').toString().trim();

      _selectedCategoryId = categoryId.isEmpty ? null : categoryId;
      _selectedCategoryName = categoryName.isEmpty ? null : categoryName;
      _selectedSubcategoryId = subcategoryId.isEmpty ? null : subcategoryId;
      _selectedSubcategoryName =
      subcategoryName.isEmpty ? null : subcategoryName;

      _productType = (data['type'] ?? 'stock').toString();
      _isActive = data['isActive'] == null ? true : data['isActive'] == true;
      _trackInventory = data['trackInventory'] == null
          ? true
          : data['trackInventory'] == true;
      _isSaleable =
      data['isSaleable'] == null ? true : data['isSaleable'] == true;
      _isPurchasable =
      data['isPurchasable'] == null ? true : data['isPurchasable'] == true;

      final openingStock =
          data['openingStock'] ?? data['stockOnHand'] ?? data['qty'];
      if (openingStock != null) {
        _openingStockController.text = openingStock.toString();
      }

      _existingStockOnHand = _toDouble(data['stockOnHand']);
      _existingQty = _toDouble(data['qty']);

      final reorderLevel = data['reorderLevel'] ?? data['minStockLevel'];
      if (reorderLevel != null) {
        _reorderLevelController.text = reorderLevel.toString();
      }

      final minStockLevel = data['minStockLevel'];
      if (minStockLevel != null) {
        _minStockLevelController.text = minStockLevel.toString();
      }

      final maxStockLevel = data['maxStockLevel'];
      if (maxStockLevel != null) {
        _maxStockLevelController.text = maxStockLevel.toString();
      }

      final costPrice = data['costPrice'];
      if (costPrice != null) {
        _costPriceController.text = costPrice.toString();
      }

      final unitPrice = data['unitPrice'];
      if (unitPrice != null) {
        _unitPriceController.text = unitPrice.toString();
      }

      final mrp = data['mrp'];
      if (mrp != null) {
        _mrpController.text = mrp.toString();
      }

      final gst = data['gstPercentage'];
      if (gst != null) {
        _gstController.text = gst.toString();
      }

      final assigned = (data['assignedToUid'] ?? '').toString();
      if (assigned.isNotEmpty) {
        _assignedToUid = assigned;
      }
    }

    _applyProductTypeRules(silent: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _hsnController.dispose();
    _itemCodeController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _uomController.dispose();
    _openingStockController.dispose();
    _reorderLevelController.dispose();
    _minStockLevelController.dispose();
    _maxStockLevelController.dispose();
    _costPriceController.dispose();
    _unitPriceController.dispose();
    _mrpController.dispose();
    _gstController.dispose();
    _brandController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyProductTypeRules({bool silent = false}) {
    if (_isServiceLike) {
      _trackInventory = false;
      _openingStockController.text = '0';
      _reorderLevelController.text = '0';
      _minStockLevelController.text = '0';
      _maxStockLevelController.text = '0';
    }
    if (!silent && mounted) {
      setState(() {});
    }
  }

  double _parseDouble(String value, {double fallback = 0}) {
    return double.tryParse(value.trim()) ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  String _formatCurrencyPreview(String value) {
    final number = double.tryParse(value.trim());
    if (number == null) return '₹ 0';
    if (number == number.toInt()) return '₹ ${number.toInt()}';
    return '₹ ${number.toStringAsFixed(2)}';
  }

  String? _requiredValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _numberValidator(String? v, {bool required = false}) {
    if ((v == null || v.trim().isEmpty) && !required) return null;
    if ((v == null || v.trim().isEmpty) && required) return 'Required';
    if (double.tryParse(v!.trim()) == null) return 'Enter valid number';
    return null;
  }

  String? _categoryValidator(String? _) {
    if (_selectedCategoryId == null || _selectedCategoryId!.trim().isEmpty) {
      return 'Please select category';
    }
    return null;
  }

  String _safeExt(String? ext, {String fallback = 'bin'}) {
    final value = (ext ?? '').trim().toLowerCase();
    if (value.isEmpty) return fallback;
    return value.replaceAll('.', '');
  }

  String _detectContentTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  IconData _catalogIcon(String? contentType, String? name) {
    final lowerName = (name ?? '').toLowerCase();
    final lowerType = (contentType ?? '').toLowerCase();

    if (lowerType.contains('pdf') || lowerName.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (lowerType.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.attach_file_outlined;
  }

  // 🔴 FIXED: Upload spinner logic with preview state update and failsafe
  Future<void> _pickAndUploadImage() async {
    try {
      if (mounted) {
        setState(() => _isUploadingImage = true);
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Unable to read selected image bytes');
      }

      final ext = _safeExt(file.extension, fallback: 'jpg');
      final contentType = _detectContentTypeFromExtension(ext);

      final fileName =
          'product_photo_${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserUid}.$ext';

      final ref = FirebaseStorage.instance
          .ref()
          .child('companies/${widget.companyId}/products/images/$fileName');

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'companyId': widget.companyId,
          'uploadedBy': widget.currentUserUid,
          'originalName': file.name,
          'module': 'products',
          'type': 'image',
        },
      );

      final task = await ref.putData(bytes, metadata).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Upload timed out after 30 seconds'),
      );

      if (task.state != TaskState.success) {
        throw Exception('Image upload did not complete successfully');
      }

      final downloadUrl = await ref.getDownloadURL();

      if (!mounted) return;
      setState(() {
        _imageUrl = downloadUrl;
        _pickedImageBytes = bytes;
        _pickedImageName = file.name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product photo uploaded successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  // 🔴 FIXED: Catalog upload preview logic and failsafe
  Future<void> _pickAndUploadCatalog() async {
    try {
      if (mounted) {
        setState(() => _isUploadingCatalog = true);
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Unable to read selected catalog file');
      }

      final ext = _safeExt(file.extension, fallback: 'bin');
      final contentType = _detectContentTypeFromExtension(ext);

      final fileName =
          'product_catalog_${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserUid}.$ext';

      final ref = FirebaseStorage.instance
          .ref()
          .child('companies/${widget.companyId}/products/catalogs/$fileName');

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'companyId': widget.companyId,
          'uploadedBy': widget.currentUserUid,
          'originalName': file.name,
          'module': 'products',
          'type': 'catalog',
        },
      );

      final task = await ref.putData(bytes, metadata).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Upload timed out after 30 seconds'),
      );

      if (task.state != TaskState.success) {
        throw Exception('Catalog upload did not complete successfully');
      }

      final downloadUrl = await ref.getDownloadURL();

      if (!mounted) return;
      setState(() {
        _catalogUrl = downloadUrl;
        _catalogName = file.name;
        _catalogContentType = contentType;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catalog uploaded successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catalog upload failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingCatalog = false);
      }
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _imageUrl = null;
      _pickedImageBytes = null;
      _pickedImageName = null;
    });
  }

  void _removeCatalog() {
    setState(() {
      _catalogUrl = null;
      _catalogName = null;
      _catalogContentType = null;
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_assignedToUid == null || _assignedToUid!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select assigned user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final openingStock = _trackInventory && !_isServiceLike
          ? _parseDouble(_openingStockController.text)
          : 0.0;

      final reorderLevel = _trackInventory && !_isServiceLike
          ? _parseDouble(_reorderLevelController.text)
          : 0.0;

      final minStockLevel = _trackInventory && !_isServiceLike
          ? _parseDouble(_minStockLevelController.text)
          : 0.0;

      final maxStockLevel = _trackInventory && !_isServiceLike
          ? _parseDouble(_maxStockLevelController.text)
          : 0.0;

      final costPrice = _parseDouble(_costPriceController.text);
      final unitPrice = _parseDouble(_unitPriceController.text);
      final mrp = _parseDouble(_mrpController.text);
      final gst = _parseDouble(_gstController.text);

      final cleanName = _nameController.text.trim();
      final cleanDescription = _descriptionController.text.trim();
      final cleanHsn = _hsnController.text.trim();
      final cleanItemCode = _itemCodeController.text.trim();
      final cleanSku = _skuController.text.trim();
      final cleanBarcode = _barcodeController.text.trim();
      final cleanUom = _uomController.text.trim();
      final cleanBrand = _brandController.text.trim();
      final cleanNotes = _notesController.text.trim();

      final data = <String, dynamic>{
        'companyId': widget.companyId,
        'name': cleanName,
        'nameLower': cleanName.toLowerCase(),
        'description': cleanDescription,
        'type': _productType,
        'categoryId': _selectedCategoryId,
        'category': _selectedCategoryName ?? '',
        'subcategoryId': _selectedSubcategoryId,
        'subcategory': _selectedSubcategoryName ?? '',
        'brand': cleanBrand,
        'hsnCode': cleanHsn,
        'itemCode': cleanItemCode,
        'sku': cleanSku,
        'barcode': cleanBarcode,
        'uom': cleanUom,
        'openingStock': openingStock,
        'reorderLevel': reorderLevel,
        'minStockLevel': minStockLevel,
        'maxStockLevel': maxStockLevel,
        'trackInventory': _trackInventory,
        'costPrice': costPrice,
        'unitPrice': unitPrice,
        'sellingPrice': unitPrice,
        'mrp': mrp,
        'gstPercentage': gst,
        'imageUrl': _imageUrl ?? '',
        'catalogUrl': _catalogUrl ?? '',
        'catalogName': _catalogName ?? '',
        'catalogContentType': _catalogContentType ?? '',
        'notes': cleanNotes,
        'isActive': _isActive,
        'isSaleable': _isSaleable,
        'isPurchasable': _isPurchasable,
        'assignedToUid': _assignedToUid,
        'assignedByUid': widget.currentUserUid,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.currentUserUid,
        'updatedByUid': widget.currentUserUid,
      };

      if (isEditMode) {
        await _productsRef.doc(widget.productId).update({
          ...data,
          'stockOnHand':
          _trackInventory && !_isServiceLike ? _existingStockOnHand : 0.0,
          'qty': _trackInventory && !_isServiceLike
              ? (_existingQty == 0 ? _existingStockOnHand : _existingQty)
              : 0.0,
        });
      } else {
        await _productsRef.add({
          ...data,
          'stockOnHand': _trackInventory && !_isServiceLike ? openingStock : 0.0,
          'qty': _trackInventory && !_isServiceLike ? openingStock : 0.0,
          'isDeleted': false,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': widget.currentUserUid,
          'createdByUid': widget.currentUserUid,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Product updated successfully'
                : 'Product saved successfully',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    void Function(String)? onChanged,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label: label, icon: icon, hint: hint),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label: label, icon: icon),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildAssignUserDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companyUsersRef.where('isActive', isEqualTo: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }

        if (snap.hasError) {
          return Text(
            'Failed to load users: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        final docs = snap.data?.docs.toList() ?? [];
        docs.sort((a, b) {
          final an = (a.data()['name'] ?? '').toString().toLowerCase();
          final bn = (b.data()['name'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

        if (docs.isEmpty) {
          return const Text('No active users found');
        }

        final values = docs.map((e) => e.id).toSet();
        if (_assignedToUid == null || !values.contains(_assignedToUid)) {
          _assignedToUid = docs.first.id;
        }

        return DropdownButtonFormField<String>(
          value: _assignedToUid,
          decoration: _inputDecoration(
            label: 'Assign To',
            icon: Icons.person_outline,
          ),
          items: docs.map((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final role = (data['role'] ?? '').toString();

            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(name.isEmpty ? doc.id : '$name ($role)'),
            );
          }).toList(),
          onChanged: _canAssignOthers
              ? (value) => setState(() => _assignedToUid = value)
              : null,
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: child,
    );
  }

  Widget _buildStatusToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _categoriesRef.orderBy('nameLower').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const LinearProgressIndicator();
        }

        if (snap.hasError) {
          return Text(
            'Failed to load categories: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        var docs = snap.data?.docs ?? [];

        docs = docs.where((doc) {
          final data = doc.data();
          final isActive = data['isActive'] != false;
          final isCurrentSelected = doc.id == _selectedCategoryId;
          return isActive || isCurrentSelected;
        }).toList();

        if (_selectedCategoryId != null &&
            !docs.any((e) => e.id == _selectedCategoryId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedCategoryId = null;
              _selectedCategoryName = null;
              _selectedSubcategoryId = null;
              _selectedSubcategoryName = null;
            });
          });
        }

        return DropdownButtonFormField<String?>(
          value: _selectedCategoryId,
          decoration: _inputDecoration(
            label: 'Category *',
            icon: Icons.folder_outlined,
          ),
          validator: _categoryValidator,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Select Category'),
            ),
            ...docs.map((doc) {
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final active = data['isActive'] != false;
              return DropdownMenuItem<String?>(
                value: doc.id,
                child: Text(active ? name : '$name (Inactive)'),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null || value.isEmpty) {
              setState(() {
                _selectedCategoryId = null;
                _selectedCategoryName = null;
                _selectedSubcategoryId = null;
                _selectedSubcategoryName = null;
              });
              return;
            }

            final selectedDoc = docs.firstWhere((e) => e.id == value);
            setState(() {
              _selectedCategoryId = value;
              _selectedCategoryName =
                  (selectedDoc.data()['name'] ?? '').toString();
              _selectedSubcategoryId = null;
              _selectedSubcategoryName = null;
            });
          },
        );
      },
    );
  }

  Widget _buildSubcategoryDropdown() {
    if (_selectedCategoryId == null) {
      return DropdownButtonFormField<String?>(
        value: null,
        decoration: _inputDecoration(
          label: 'Subcategory',
          icon: Icons.folder_open_outlined,
        ),
        items: const [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('Select Category First'),
          ),
        ],
        onChanged: null,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _subcategoriesRef(_selectedCategoryId!)
          .orderBy('nameLower').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const LinearProgressIndicator();
        }

        if (snap.hasError) {
          return Text(
            'Failed to load subcategories: ${snap.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        var docs = snap.data?.docs ?? [];

        docs = docs.where((doc) {
          final data = doc.data();
          final isActive = data['isActive'] != false;
          final isCurrentSelected = doc.id == _selectedSubcategoryId;
          return isActive || isCurrentSelected;
        }).toList();

        if (_selectedSubcategoryId != null &&
            !docs.any((e) => e.id == _selectedSubcategoryId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedSubcategoryId = null;
              _selectedSubcategoryName = null;
            });
          });
        }

        return DropdownButtonFormField<String?>(
          value: _selectedSubcategoryId,
          decoration: _inputDecoration(
            label: 'Subcategory',
            icon: Icons.folder_open_outlined,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Select Subcategory'),
            ),
            ...docs.map((doc) {
              final data = doc.data();
              final name = (data['name'] ?? '').toString();
              final active = data['isActive'] != false;
              return DropdownMenuItem<String?>(
                value: doc.id,
                child: Text(active ? name : '$name (Inactive)'),
              );
            }),
          ],
          onChanged: (value) {
            if (value == null || value.isEmpty) {
              setState(() {
                _selectedSubcategoryId = null;
                _selectedSubcategoryName = null;
              });
              return;
            }

            final selectedDoc = docs.firstWhere((e) => e.id == value);
            setState(() {
              _selectedSubcategoryId = value;
              _selectedSubcategoryName =
                  (selectedDoc.data()['name'] ?? '').toString();
            });
          },
        );
      },
    );
  }

  Widget _buildImageAndCatalogCard() {
    Widget preview;

    if (_pickedImageBytes != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _pickedImageBytes!,
          width: 110,
          height: 110,
          fit: BoxFit.cover,
        ),
      );
    } else if ((_imageUrl ?? '').isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _imageUrl!,
          width: 110,
          height: 110,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    } else {
      preview = Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: const Icon(
          Icons.image_outlined,
          size: 34,
          color: Color(0xFF667085),
        ),
      );
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Product Media & Notes'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              preview,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.icon(
                      onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                      icon: _isUploadingImage
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(
                        _isUploadingImage
                            ? 'Uploading...'
                            : 'Upload Product Photo',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((_pickedImageName ?? '').isNotEmpty)
                      Text(
                        _pickedImageName!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      )
                    else if ((_imageUrl ?? '').isNotEmpty)
                      const Text(
                        'Photo uploaded',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      )
                    else
                      const Text(
                        'Select image from your device and upload to cloud storage.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if ((_imageUrl ?? '').isNotEmpty || _pickedImageBytes != null)
                      TextButton.icon(
                        onPressed: _isUploadingImage ? null : _removeSelectedImage,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text(
                          'Remove Photo',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E7EC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Catalog / Attachment',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload product catalog, brochure, spec sheet, image, or PDF.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Icon(
                        _catalogIcon(_catalogContentType, _catalogName),
                        color: const Color(0xFF475467),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.icon(
                            onPressed:
                            _isUploadingCatalog ? null : _pickAndUploadCatalog,
                            icon: _isUploadingCatalog
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                              CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(Icons.attach_file_outlined),
                            label: Text(
                              _isUploadingCatalog
                                  ? 'Uploading...'
                                  : 'Upload Catalog',
                            ),
                          ),
                          const SizedBox(height: 8),
                          if ((_catalogName ?? '').isNotEmpty)
                            Text(
                              _catalogName!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            )
                          else if ((_catalogUrl ?? '').isNotEmpty)
                            const Text(
                              'Catalog uploaded',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            )
                          else
                            const Text(
                              'Allowed formats: PDF, JPG, JPEG, PNG, WEBP',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            ),
                          if ((_catalogUrl ?? '').isNotEmpty)
                            TextButton.icon(
                              onPressed:
                              _isUploadingCatalog ? null : _removeCatalog,
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              label: const Text(
                                'Remove Catalog',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _notesController,
            label: 'Internal Notes',
            icon: Icons.sticky_note_2_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // 🔴 REMOVED: _buildSummaryPanel (Strip logic requested)

  @override
  Widget build(BuildContext context) {
    final isEditText = isEditMode ? 'Edit Product' : 'Add Product';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(isEditText),
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1100;
          final isTablet = constraints.maxWidth >= 760;

          final mainForm = Form(
            key: _formKey,
            child: Column(
              children: [
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Basic Information'),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _nameController,
                                label: 'Product Name *',
                                icon: Icons.label_outline,
                                validator: _requiredValidator,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Product Type',
                                icon: Icons.category_outlined,
                                value: _productType,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'stock',
                                    child: Text('Stock Item'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'non_stock',
                                    child: Text('Non-Stock Item'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'service',
                                    child: Text('Service'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'raw_material',
                                    child: Text('Raw Material'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'finished_good',
                                    child: Text('Finished Good'),
                                  ),
                                ],
                                onChanged: (value) {
                                  _productType = value ?? 'stock';
                                  _applyProductTypeRules();
                                },
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _nameController,
                          label: 'Product Name *',
                          icon: Icons.label_outline,
                          validator: _requiredValidator,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownField(
                          label: 'Product Type',
                          icon: Icons.category_outlined,
                          value: _productType,
                          items: const [
                            DropdownMenuItem(
                              value: 'stock',
                              child: Text('Stock Item'),
                            ),
                            DropdownMenuItem(
                              value: 'non_stock',
                              child: Text('Non-Stock Item'),
                            ),
                            DropdownMenuItem(
                              value: 'service',
                              child: Text('Service'),
                            ),
                            DropdownMenuItem(
                              value: 'raw_material',
                              child: Text('Raw Material'),
                            ),
                            DropdownMenuItem(
                              value: 'finished_good',
                              child: Text('Finished Good'),
                            ),
                          ],
                          onChanged: (value) {
                            _productType = value ?? 'stock';
                            _applyProductTypeRules();
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(child: _buildCategoryDropdown()),
                            const SizedBox(width: 10),
                            Expanded(child: _buildSubcategoryDropdown()),
                          ],
                        )
                      else ...[
                        _buildCategoryDropdown(),
                        const SizedBox(height: 10),
                        _buildSubcategoryDropdown(),
                      ],
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _brandController,
                        label: 'Brand',
                        icon: Icons.workspace_premium_outlined,
                        hint: 'e.g. MEMCO',
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Codes & Classification'),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _hsnController,
                                label: 'HSN / SAC Code *',
                                icon: Icons.confirmation_number_outlined,
                                validator: _requiredValidator,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _itemCodeController,
                                label: 'Item Code',
                                icon: Icons.code_outlined,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _hsnController,
                          label: 'HSN / SAC Code *',
                          icon: Icons.confirmation_number_outlined,
                          validator: _requiredValidator,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _itemCodeController,
                          label: 'Item Code',
                          icon: Icons.code_outlined,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _skuController,
                                label: 'SKU',
                                icon: Icons.tag_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _barcodeController,
                                label: 'Barcode',
                                icon: Icons.qr_code_scanner_outlined,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _skuController,
                          label: 'SKU',
                          icon: Icons.tag_outlined,
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _barcodeController,
                          label: 'Barcode',
                          icon: Icons.qr_code_scanner_outlined,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _uomController,
                        label: 'UOM *',
                        icon: Icons.straighten_outlined,
                        hint: 'e.g. Nos, Kg, Meter',
                        validator: _requiredValidator,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Inventory Controls'),
                      _buildStatusToggleTile(
                        title: 'Track Inventory',
                        subtitle:
                        'Enable quantity and stock-related control for this item.',
                        value: _trackInventory,
                        onChanged: _isServiceLike
                            ? (_) {}
                            : (value) {
                          setState(() {
                            _trackInventory = value;
                            if (!value) {
                              _openingStockController.text = '0';
                              _reorderLevelController.text = '0';
                              _minStockLevelController.text = '0';
                              _maxStockLevelController.text = '0';
                            }
                          });
                        },
                      ),
                      if (_isServiceLike)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Inventory tracking is disabled automatically for service and non-stock items.',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _openingStockController,
                                label: 'Opening Stock',
                                icon: Icons.production_quantity_limits_outlined,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) =>
                                _trackInventory && !_isServiceLike
                                    ? _numberValidator(v)
                                    : null,
                                onChanged: (_) => setState(() {}),
                                enabled: _trackInventory && !_isServiceLike,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _reorderLevelController,
                                label: 'Reorder Level',
                                icon: Icons.warning_amber_outlined,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) =>
                                _trackInventory && !_isServiceLike
                                    ? _numberValidator(v)
                                    : null,
                                onChanged: (_) => setState(() {}),
                                enabled: _trackInventory && !_isServiceLike,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _openingStockController,
                          label: 'Opening Stock',
                          icon: Icons.production_quantity_limits_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _trackInventory && !_isServiceLike
                              ? _numberValidator(v)
                              : null,
                          onChanged: (_) => setState(() {}),
                          enabled: _trackInventory && !_isServiceLike,
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _reorderLevelController,
                          label: 'Reorder Level',
                          icon: Icons.warning_amber_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _trackInventory && !_isServiceLike
                              ? _numberValidator(v)
                              : null,
                          onChanged: (_) => setState(() {}),
                          enabled: _trackInventory && !_isServiceLike,
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _minStockLevelController,
                                label: 'Minimum Stock',
                                icon: Icons.vertical_align_bottom_outlined,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) =>
                                _trackInventory && !_isServiceLike
                                    ? _numberValidator(v)
                                    : null,
                                enabled: _trackInventory && !_isServiceLike,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _maxStockLevelController,
                                label: 'Maximum Stock',
                                icon: Icons.vertical_align_top_outlined,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) =>
                                _trackInventory && !_isServiceLike
                                    ? _numberValidator(v)
                                    : null,
                                enabled: _trackInventory && !_isServiceLike,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _minStockLevelController,
                          label: 'Minimum Stock',
                          icon: Icons.vertical_align_bottom_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _trackInventory && !_isServiceLike
                              ? _numberValidator(v)
                              : null,
                          enabled: _trackInventory && !_isServiceLike,
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _maxStockLevelController,
                          label: 'Maximum Stock',
                          icon: Icons.vertical_align_top_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _trackInventory && !_isServiceLike
                              ? _numberValidator(v)
                              : null,
                          enabled: _trackInventory && !_isServiceLike,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Pricing & Tax'),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _costPriceController,
                                label: 'Cost Price',
                                icon: Icons.payments_outlined,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) => _numberValidator(v),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _unitPriceController,
                                label: 'Selling Price *',
                                icon: Icons.currency_rupee,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) =>
                                    _numberValidator(v, required: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _costPriceController,
                          label: 'Cost Price',
                          icon: Icons.payments_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _numberValidator(v),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _unitPriceController,
                          label: 'Selling Price *',
                          icon: Icons.currency_rupee,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _numberValidator(v, required: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (isTablet)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _mrpController,
                                label: 'MRP',
                                icon: Icons.sell_outlined,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) => _numberValidator(v),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTextField(
                                controller: _gstController,
                                label: 'GST % *',
                                icon: Icons.percent,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) =>
                                    _numberValidator(v, required: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildTextField(
                          controller: _mrpController,
                          label: 'MRP',
                          icon: Icons.sell_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _numberValidator(v),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _gstController,
                          label: 'GST % *',
                          icon: Icons.percent,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) => _numberValidator(v, required: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Assignment & Control'),
                      _buildAssignUserDropdown(),
                      if (!_canAssignOthers) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'You can create product only for yourself.',
                          style: TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _buildStatusToggleTile(
                        title: 'Active Product',
                        subtitle:
                        'Inactive products can be hidden from normal use.',
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                      ),
                      _buildStatusToggleTile(
                        title: 'Saleable',
                        subtitle:
                        'Allow this product to be used in sales and quotations.',
                        value: _isSaleable,
                        onChanged: (value) {
                          setState(() {
                            _isSaleable = value;
                          });
                        },
                      ),
                      _buildStatusToggleTile(
                        title: 'Purchasable',
                        subtitle:
                        'Allow this product to be used in purchase workflows.',
                        value: _isPurchasable,
                        onChanged: (value) {
                          setState(() {
                            _isPurchasable = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildImageAndCatalogCard(),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6EAF0)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveProduct,
                        icon: _isSaving
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                          CircularProgressIndicator(strokeWidth: 2.5),
                        )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : (isEditMode ? 'Update Product' : 'Save Product'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: isDesktop
                    ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: mainForm),
                    const SizedBox(width: 14),
                    // 🔴 REMOVED: Summary panel widget call
                  ],
                )
                    : Column(
                  children: [
                    mainForm,
                    const SizedBox(height: 12),
                    // 🔴 REMOVED: Summary panel widget call
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}