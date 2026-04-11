import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/inventory/products/screens_add_product.dart';

class ScreensProductList extends StatefulWidget {
  const ScreensProductList({super.key});

  @override
  State<ScreensProductList> createState() => _ScreensProductListState();
}

class _ScreensProductListState extends State<ScreensProductList> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _fabKey = GlobalKey();

  String _searchText = '';
  String _statusFilter = 'all';
  String _stockFilter = 'all';
  String _categoryFilter = 'all';
  String _subcategoryFilter = 'all';
  bool _showTableView = true;

  // Cached Futures & Streams to prevent rebuilds
  Future<Map<String, dynamic>?>? _userProfileFuture;
  Future<List<_CategoryMaster>>? _categoryMasterFuture;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _productsStream;
  String? _currentCompanyId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userProfileFuture = _loadCurrentUserProfile(user.uid);
    }

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Reloads Category Master Data for the main UI
  void _refreshCategoryMaster() {
    if (!mounted || _currentCompanyId == null || _currentCompanyId!.isEmpty) return;
    setState(() {
      _categoryMasterFuture = _loadCategoryMaster(_currentCompanyId!);
    });
  }

  Widget _buildProductAvatar(String? imageUrl, String name, double size) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => _buildInitialsFallback(name, size),
          ),
        ),
      );
    }
    return _buildInitialsFallback(name, size);
  }

  Widget _buildInitialsFallback(String name, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFEAF2FF),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF3167E3),
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadCurrentUserProfile(String uid) async {
    final firestore = FirebaseFirestore.instance;

    final globalDoc = await firestore.collection('users').doc(uid).get();
    final globalData = globalDoc.data() ?? <String, dynamic>{};

    String companyId = (globalData['companyId'] ?? '').toString();
    if (companyId.isEmpty) {
      final companyIds = globalData['companyIds'];
      if (companyIds is List && companyIds.isNotEmpty) {
        companyId = companyIds.first.toString();
      } else {
        final memberships = globalData['memberships'];
        if (memberships is Map && memberships.isNotEmpty) {
          companyId = memberships.keys.first.toString();
        }
      }
    }

    if (companyId.isEmpty) return globalData;

    final companyUserDoc = await firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid)
        .get();

    final companyData = companyUserDoc.data() ?? <String, dynamic>{};

    return {
      ...globalData,
      ...companyData,
      'companyId': companyId,
    };
  }

  bool _isAdminOrManager(String role) {
    final r = role.toLowerCase().trim();
    return r == 'owner' ||
        r == 'founder' ||
        r == 'ceo' ||
        r == 'superadmin' ||
        r == 'admin' ||
        r == 'manager';
  }

  bool _hasProductPermission(Map<String, dynamic> userData, {String action = 'view'}) {
    final role = (userData['role'] ?? '').toString();
    if (_isAdminOrManager(role)) return true;

    final permissions = userData['permissions'];
    if (permissions is! Map) return false;

    final inventory = permissions['inventory'];
    if (inventory is Map) {
      final products = inventory['products'];
      if (products is Map && products[action] == true) {
        return true;
      }
    }

    if (permissions['products'] == true && action == 'view') return true;
    if (permissions['products'] is Map && permissions['products'][action] == true) return true;

    return false;
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '—';
    final num? number = value is num ? value : num.tryParse(value.toString());
    if (number == null) return '—';
    if (number == number.toInt()) return '₹ ${number.toInt()}';
    return '₹ ${number.toStringAsFixed(2)}';
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num? number = value is num ? value : num.tryParse(value.toString());
    if (number == null) return '0';
    if (number == number.toInt()) return number.toInt().toString();
    return number.toStringAsFixed(2);
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  bool _isProductActive(Map<String, dynamic> data) {
    if (data.containsKey('isActive')) return data['isActive'] == true;
    return true;
  }

  double _stockOnHand(Map<String, dynamic> data) {
    if (data.containsKey('stockOnHand')) return _toDouble(data['stockOnHand']);
    if (data.containsKey('qty')) return _toDouble(data['qty']);
    return 0;
  }

  double _reorderLevel(Map<String, dynamic> data) {
    if (data.containsKey('reorderLevel')) {
      return _toDouble(data['reorderLevel']);
    }
    if (data.containsKey('minStockLevel')) {
      return _toDouble(data['minStockLevel']);
    }
    return 0;
  }

  double _minStockLevel(Map<String, dynamic> data) {
    if (data.containsKey('minStockLevel')) {
      return _toDouble(data['minStockLevel']);
    }
    return _reorderLevel(data);
  }

  String _categoryName(Map<String, dynamic> data) {
    return (data['category'] ?? '').toString().trim();
  }

  String _subcategoryName(Map<String, dynamic> data) {
    return (data['subcategory'] ?? '').toString().trim();
  }

  String _productTypeName(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim();
    switch (type) {
      case 'stock':
        return 'Stock';
      case 'non_stock':
        return 'Non-Stock';
      case 'service':
        return 'Service';
      case 'raw_material':
        return 'Raw Material';
      case 'finished_good':
        return 'Finished Good';
      default:
        return type.isEmpty ? '—' : type;
    }
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchText.isEmpty) return true;

    final fields = [
      data['name'],
      data['itemCode'],
      data['hsnCode'],
      data['description'],
      data['uom'],
      data['sku'],
      data['barcode'],
      data['category'],
      data['subcategory'],
      data['brand'],
      data['type'],
    ];

    return fields.any(
          (e) => (e ?? '').toString().toLowerCase().contains(_searchText),
    );
  }

  bool _matchesStatusFilter(Map<String, dynamic> data) {
    final isActive = _isProductActive(data);
    switch (_statusFilter) {
      case 'active':
        return isActive;
      case 'inactive':
        return !isActive;
      default:
        return true;
    }
  }

  bool _matchesStockFilter(Map<String, dynamic> data) {
    final stock = _stockOnHand(data);
    final threshold = _minStockLevel(data) > 0 ? _minStockLevel(data) : _reorderLevel(data);

    switch (_stockFilter) {
      case 'in_stock':
        return stock > 0;
      case 'low_stock':
        return stock > 0 && threshold > 0 && stock <= threshold;
      case 'out_of_stock':
        return stock <= 0;
      default:
        return true;
    }
  }

  bool _matchesCategoryFilter(Map<String, dynamic> data) {
    if (_categoryFilter == 'all') return true;
    return _categoryName(data).toLowerCase() == _categoryFilter.toLowerCase();
  }

  bool _matchesSubcategoryFilter(Map<String, dynamic> data) {
    if (_subcategoryFilter == 'all') return true;
    return _subcategoryName(data).toLowerCase() ==
        _subcategoryFilter.toLowerCase();
  }

  String _stockStatus(Map<String, dynamic> data) {
    final stock = _stockOnHand(data);
    final threshold = _minStockLevel(data) > 0 ? _minStockLevel(data) : _reorderLevel(data);

    if (stock <= 0) return 'Out of Stock';
    if (threshold > 0 && stock <= threshold) return 'Low Stock';
    return 'In Stock';
  }

  Color _stockStatusColor(String status) {
    switch (status) {
      case 'In Stock':
        return Colors.green;
      case 'Low Stock':
        return Colors.orange;
      case 'Out of Stock':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  CollectionReference<Map<String, dynamic>> _categoriesRef(String companyId) {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('inventory_categories');
  }

  Future<List<_CategoryMaster>> _loadCategoryMaster(String companyId) async {
    final categorySnap =
    await _categoriesRef(companyId).orderBy('nameLower').get();

    final List<_CategoryMaster> result = [];

    for (final catDoc in categorySnap.docs) {
      final catData = catDoc.data();
      final catName = (catData['name'] ?? '').toString();

      final subSnap = await _categoriesRef(companyId)
          .doc(catDoc.id)
          .collection('subcategories')
          .orderBy('nameLower')
          .get();

      final subs = subSnap.docs.map((s) {
        final d = s.data();
        return _SubcategoryMaster(
          id: s.id,
          name: (d['name'] ?? '').toString(),
        );
      }).toList();

      result.add(
        _CategoryMaster(
          id: catDoc.id,
          name: catName,
          isActive: catData['isActive'] != false,
          subcategories: subs,
        ),
      );
    }

    return result;
  }

  void _openAddProduct({
    required String companyId,
    required String currentUserUid,
    required String currentUserRole,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddProduct(
          companyId: companyId,
          currentUserUid: currentUserUid,
          currentUserRole: currentUserRole,
        ),
      ),
    );
  }

  void _openEditProduct({
    required String productId,
    required Map<String, dynamic> initialData,
    required String companyId,
    required String currentUserUid,
    required String currentUserRole,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddProduct(
          companyId: companyId,
          currentUserUid: currentUserUid,
          currentUserRole: currentUserRole,
          productId: productId,
          initialData: initialData,
        ),
      ),
    );
  }

  Future<void> _deleteProduct({
    required String companyId,
    required String productId,
    required String productName,
    required String currentUserUid,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "$productName"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('products')
          .doc(productId)
          .update({
        'isDeleted': true,
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': currentUserUid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFabMenu({
    required String companyId,
    required String currentUserUid,
    required String currentUserRole,
  }) async {
    final ctx = _fabKey.currentContext;
    if (ctx == null) return;

    final RenderBox button = ctx.findRenderObject() as RenderBox;
    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy - 120,
        overlay.size.width - bottomRight.dx,
        overlay.size.height - topLeft.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const [
        PopupMenuItem<String>(
          value: 'add',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_box_outlined),
            title: Text('Add Product'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'import',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.file_upload_outlined),
            title: Text('Import Product'),
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    if (selected == 'add') {
      _openAddProduct(
        companyId: companyId,
        currentUserUid: currentUserUid,
        currentUserRole: currentUserRole,
      );
    } else if (selected == 'import') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import product coming soon')),
      );
    }
  }

  void _showFilterSheet({
    required List<String> categoryOptions,
    required List<String> subcategoryOptions,
    required Map<String, List<String>> subcategoryMap,
  }) {
    String tempStatus = _statusFilter;
    String tempStock = _stockFilter;
    String tempCategory = _categoryFilter;
    String tempSubcategory = _subcategoryFilter;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final availableSubs = tempCategory == 'all'
                ? subcategoryOptions
                : (subcategoryMap[tempCategory] ?? []);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: tempStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Status'),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          modalSetState(() => tempStatus = value ?? 'all');
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tempStock,
                        decoration: InputDecoration(
                          labelText: 'Stock',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Stock'),
                          ),
                          DropdownMenuItem(
                            value: 'in_stock',
                            child: Text('In Stock'),
                          ),
                          DropdownMenuItem(
                            value: 'low_stock',
                            child: Text('Low Stock'),
                          ),
                          DropdownMenuItem(
                            value: 'out_of_stock',
                            child: Text('Out of Stock'),
                          ),
                        ],
                        onChanged: (value) {
                          modalSetState(() => tempStock = value ?? 'all');
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tempCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Categories'),
                          ),
                          ...categoryOptions.map(
                                (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          modalSetState(() {
                            tempCategory = value ?? 'all';
                            tempSubcategory = 'all';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tempSubcategory,
                        decoration: InputDecoration(
                          labelText: 'Subcategory',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Subcategories'),
                          ),
                          ...availableSubs.map(
                                (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          modalSetState(
                                () => tempSubcategory = value ?? 'all',
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _statusFilter = 'all';
                                  _stockFilter = 'all';
                                  _categoryFilter = 'all';
                                  _subcategoryFilter = 'all';
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _statusFilter = tempStatus;
                                  _stockFilter = tempStock;
                                  _categoryFilter = tempCategory;
                                  _subcategoryFilter = tempSubcategory;
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createCategoryDialog({
    required String companyId,
    required String currentUserUid,
    String? categoryId,
    String? categoryName,
  }) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            categoryId == null ? 'Create Category' : 'Create Subcategory',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText:
              categoryId == null ? 'Category Name' : 'Subcategory Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                try {
                  if (categoryId == null) {
                    await _categoriesRef(companyId).add({
                      'name': name,
                      'nameLower': name.toLowerCase(),
                      'isActive': true,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                      'createdBy': currentUserUid,
                      'updatedBy': currentUserUid,
                    });
                  } else {
                    await _categoriesRef(companyId)
                        .doc(categoryId)
                        .collection('subcategories')
                        .add({
                      'name': name,
                      'nameLower': name.toLowerCase(),
                      'categoryId': categoryId,
                      'categoryName': categoryName,
                      'isActive': true,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                      'createdBy': currentUserUid,
                      'updatedBy': currentUserUid,
                    });
                  }

                  if (!mounted) return;
                  _refreshCategoryMaster();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        categoryId == null
                            ? 'Category created successfully'
                            : 'Subcategory created successfully',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameCategory({
    required String companyId,
    required String categoryId,
    required String currentName,
    required String currentUserUid,
  }) async {
    final controller = TextEditingController(text: currentName);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty || name == currentName) return;

                try {
                  final batch = FirebaseFirestore.instance.batch();
                  final catRef = _categoriesRef(companyId).doc(categoryId);

                  batch.update(catRef, {
                    'name': name,
                    'nameLower': name.toLowerCase(),
                    'updatedAt': FieldValue.serverTimestamp(),
                    'updatedBy': currentUserUid,
                  });

                  // Update subcategories' reference to categoryName
                  final subsSnap = await catRef.collection('subcategories').get();
                  for (final subDoc in subsSnap.docs) {
                    batch.update(subDoc.reference, {
                      'categoryName': name,
                    });
                  }

                  await batch.commit();

                  // Cascade to products to prevent orphaned filters
                  final productsSnap = await FirebaseFirestore.instance
                      .collection('companies')
                      .doc(companyId)
                      .collection('products')
                      .where('category', isEqualTo: currentName)
                      .get();

                  if (productsSnap.docs.isNotEmpty) {
                    final pBatch = FirebaseFirestore.instance.batch();
                    int count = 0;
                    for (final pDoc in productsSnap.docs) {
                      pBatch.update(pDoc.reference, {'category': name});
                      count++;
                      if (count >= 490) break; // Firestore batch limit safety
                    }
                    await pBatch.commit();
                  }

                  if (!mounted) return;
                  _refreshCategoryMaster();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category updated')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Update failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameSubcategory({
    required String companyId,
    required String categoryId,
    required String subcategoryId,
    required String currentName,
    required String currentUserUid,
  }) async {
    final controller = TextEditingController(text: currentName);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Subcategory'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Subcategory Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty || name == currentName) return;

                try {
                  await _categoriesRef(companyId)
                      .doc(categoryId)
                      .collection('subcategories')
                      .doc(subcategoryId)
                      .update({
                    'name': name,
                    'nameLower': name.toLowerCase(),
                    'updatedAt': FieldValue.serverTimestamp(),
                    'updatedBy': currentUserUid,
                  });

                  // Cascade to products
                  final productsSnap = await FirebaseFirestore.instance
                      .collection('companies')
                      .doc(companyId)
                      .collection('products')
                      .where('subcategory', isEqualTo: currentName)
                      .get();

                  if (productsSnap.docs.isNotEmpty) {
                    final pBatch = FirebaseFirestore.instance.batch();
                    int count = 0;
                    for (final pDoc in productsSnap.docs) {
                      pBatch.update(pDoc.reference, {'subcategory': name});
                      count++;
                      if (count >= 490) break;
                    }
                    await pBatch.commit();
                  }

                  if (!mounted) return;
                  _refreshCategoryMaster();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subcategory updated')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Update failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteDialog({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ??
        false;

    if (ok) {
      await onConfirm();
    }
  }

  Future<bool> _categoryHasLinkedProducts({
    required String companyId,
    required String categoryId,
    required String categoryName,
  }) async {
    final productsRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('products');

    // Filtering isDeleted locally prevents silent crashes caused by missing composite indexes
    final byId = await productsRef.where('categoryId', isEqualTo: categoryId).get();
    if (byId.docs.any((d) => d.data()['isDeleted'] != true)) return true;

    final byName = await productsRef.where('category', isEqualTo: categoryName).get();
    if (byName.docs.any((d) => d.data()['isDeleted'] != true)) return true;

    return false;
  }

  Future<bool> _subcategoryHasLinkedProducts({
    required String companyId,
    required String subcategoryId,
    required String subcategoryName,
  }) async {
    final productsRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('products');

    final byId = await productsRef.where('subcategoryId', isEqualTo: subcategoryId).get();
    if (byId.docs.any((d) => d.data()['isDeleted'] != true)) return true;

    final byName = await productsRef.where('subcategory', isEqualTo: subcategoryName).get();
    if (byName.docs.any((d) => d.data()['isDeleted'] != true)) return true;

    return false;
  }

  Future<void> _deleteCategory({
    required String companyId,
    required String categoryId,
    required String categoryName,
  }) async {
    try {
      final linked = await _categoryHasLinkedProducts(
        companyId: companyId,
        categoryId: categoryId,
        categoryName: categoryName,
      );

      if (linked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot delete category. It is linked to existing products.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final subsSnap = await _categoriesRef(companyId)
          .doc(categoryId)
          .collection('subcategories')
          .get();

      for (final subDoc in subsSnap.docs) {
        final subName = (subDoc.data()['name'] ?? '').toString();

        final subLinked = await _subcategoryHasLinkedProducts(
          companyId: companyId,
          subcategoryId: subDoc.id,
          subcategoryName: subName,
        );

        if (subLinked) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cannot delete category. One or more subcategories are linked to existing products.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      for (final subDoc in subsSnap.docs) {
        await subDoc.reference.delete();
      }

      await _categoriesRef(companyId).doc(categoryId).delete();

      if (!mounted) return;
      _refreshCategoryMaster();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSubcategory({
    required String companyId,
    required String categoryId,
    required String subcategoryId,
    required String subcategoryName,
  }) async {
    try {
      final linked = await _subcategoryHasLinkedProducts(
        companyId: companyId,
        subcategoryId: subcategoryId,
        subcategoryName: subcategoryName,
      );

      if (linked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot delete subcategory. It is linked to existing products.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await _categoriesRef(companyId)
          .doc(categoryId)
          .collection('subcategories')
          .doc(subcategoryId)
          .delete();

      if (!mounted) return;
      _refreshCategoryMaster();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subcategory deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCategoryManager({
    required String companyId,
    required String currentUserUid,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 820,
            constraints: const BoxConstraints(maxHeight: 620),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Category Manager',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _createCategoryDialog(
                          companyId: companyId,
                          currentUserUid: currentUserUid,
                        );
                      },
                      icon: const Icon(
                        Icons.create_new_folder_outlined,
                        size: 18,
                      ),
                      label: const Text('New Category'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                    _categoriesRef(companyId).orderBy('nameLower').snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            'Error loading categories: ${snap.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('No categories yet'));
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final categoryName = (data['name'] ?? '').toString();

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FBFD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE6EAF0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.folder_outlined,
                                      color: Color(0xFF3167E3),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        categoryName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        _createCategoryDialog(
                                          companyId: companyId,
                                          currentUserUid: currentUserUid,
                                          categoryId: doc.id,
                                          categoryName: categoryName,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 16,
                                      ),
                                      label: const Text('Add Subcategory'),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'rename') {
                                          await _renameCategory(
                                            companyId: companyId,
                                            categoryId: doc.id,
                                            currentName: categoryName,
                                            currentUserUid: currentUserUid,
                                          );
                                        } else if (value == 'delete') {
                                          await _confirmDeleteDialog(
                                            title: 'Delete Category',
                                            message:
                                            'Delete "$categoryName"? This will remove the category only if it is not linked to any product.',
                                            onConfirm: () => _deleteCategory(
                                              companyId: companyId,
                                              categoryId: doc.id,
                                              categoryName: categoryName,
                                            ),
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'rename',
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(Icons.edit_outlined),
                                            title: Text('Rename'),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            title: Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: _categoriesRef(companyId)
                                      .doc(doc.id)
                                      .collection('subcategories')
                                      .orderBy('nameLower')
                                      .snapshots(),
                                  builder: (context, subSnap) {
                                    if (subSnap.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 32),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final subs = subSnap.data?.docs ?? [];
                                    if (subs.isEmpty) {
                                      return const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 32),
                                          child: Text(
                                            'No subcategories',
                                            style: TextStyle(
                                              color: Color(0xFF667085),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 32),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: subs.map((s) {
                                            final subData = s.data();
                                            final subName =
                                            (subData['name'] ?? '').toString();

                                            return Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                BorderRadius.circular(20),
                                                border: Border.all(
                                                  color:
                                                  const Color(0xFFE4E7EC),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .subdirectory_arrow_right,
                                                    size: 14,
                                                    color: Color(0xFF667085),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    subName,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                      FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  PopupMenuButton<String>(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                    const BoxConstraints(),
                                                    onSelected: (value) async {
                                                      if (value == 'rename') {
                                                        await _renameSubcategory(
                                                          companyId: companyId,
                                                          categoryId: doc.id,
                                                          subcategoryId: s.id,
                                                          currentName: subName,
                                                          currentUserUid:
                                                          currentUserUid,
                                                        );
                                                      } else if (value ==
                                                          'delete') {
                                                        await _confirmDeleteDialog(
                                                          title:
                                                          'Delete Subcategory',
                                                          message:
                                                          'Delete "$subName"? This will remove the subcategory only if it is not linked to any product.',
                                                          onConfirm: () =>
                                                              _deleteSubcategory(
                                                                companyId: companyId,
                                                                categoryId: doc.id,
                                                                subcategoryId: s.id,
                                                                subcategoryName:
                                                                subName,
                                                              ),
                                                        );
                                                      }
                                                    },
                                                    itemBuilder: (context) =>
                                                    const [
                                                      PopupMenuItem(
                                                        value: 'rename',
                                                        child: ListTile(
                                                          dense: true,
                                                          contentPadding:
                                                          EdgeInsets.zero,
                                                          leading: Icon(
                                                            Icons.edit_outlined,
                                                          ),
                                                          title: Text('Rename'),
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'delete',
                                                        child: ListTile(
                                                          dense: true,
                                                          contentPadding:
                                                          EdgeInsets.zero,
                                                          leading: Icon(
                                                            Icons.delete_outline,
                                                            color: Colors.red,
                                                          ),
                                                          title: Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _iconBoxButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Icon(icon, size: 20),
    );
  }

  Widget _buildHeaderRow({
    required String companyId,
    required String currentUserUid,
    required bool isWide,
    required bool canCreate,
    required List<String> categoryOptions,
    required List<String> subcategoryOptions,
    required Map<String, List<String>> subcategoryMap,
    required int totalProducts,
    required int activeProducts,
    required int lowStockProducts,
    required int outOfStockProducts,
    required int totalCategories,
    required int totalSubcategories,
  }) {
    const double rowHeight = 42;

    final categoryButton = canCreate
        ? SizedBox(
      height: rowHeight,
      child: OutlinedButton.icon(
        onPressed: () => _showCategoryManager(
          companyId: companyId,
          currentUserUid: currentUserUid,
        ),
        icon: const Icon(Icons.create_new_folder_outlined, size: 16),
        label: const Text('Category Manager'),
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFFE4E7EC)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    )
        : const SizedBox.shrink();

    final statsText = Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Color(0xFF475467),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        children: [
          const TextSpan(text: 'Products: '),
          TextSpan(
            text: '$totalProducts',
            style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '   Active: '),
          TextSpan(
            text: '$activeProducts',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '   Low Stock: '),
          TextSpan(
            text: '$lowStockProducts',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '   Out of Stock: '),
          TextSpan(
            text: '$outOfStockProducts',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '   Categories: '),
          TextSpan(
            text: '$totalCategories',
            style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '   Subcategories: '),
          TextSpan(
            text: '$totalSubcategories',
            style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final innerContent = Row(
      children: [
        SizedBox(
          width: 260,
          height: rowHeight,
          child: _searchField(),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          height: rowHeight,
          child: _iconBoxButton(
            icon: Icons.filter_alt_outlined,
            onTap: () => _showFilterSheet(
              categoryOptions: categoryOptions,
              subcategoryOptions: subcategoryOptions,
              subcategoryMap: subcategoryMap,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (canCreate) ...[
          categoryButton,
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 42,
          height: rowHeight,
          child: _iconBoxButton(
            icon: _showTableView
                ? Icons.grid_view_outlined
                : Icons.table_rows_outlined,
            onTap: () {
              setState(() => _showTableView = !_showTableView);
            },
          ),
        ),
        if (isWide) const Spacer() else const SizedBox(width: 16),
        statsText,
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: isWide
          ? innerContent
          : SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: innerContent,
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search product...',
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _searchText.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () {
            _searchController.clear();
            setState(() {
              _searchText = '';
            });
          },
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    final chips = <Widget>[];

    if (_statusFilter != 'all') {
      chips.add(_filterChip('Status: $_statusFilter', () {
        setState(() => _statusFilter = 'all');
      }));
    }
    if (_stockFilter != 'all') {
      chips.add(_filterChip('Stock: $_stockFilter', () {
        setState(() => _stockFilter = 'all');
      }));
    }
    if (_categoryFilter != 'all') {
      chips.add(_filterChip('Category: $_categoryFilter', () {
        setState(() {
          _categoryFilter = 'all';
          _subcategoryFilter = 'all';
        });
      }));
    }
    if (_subcategoryFilter != 'all') {
      chips.add(_filterChip('Subcategory: $_subcategoryFilter', () {
        setState(() => _subcategoryFilter = 'all');
      }));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _filterChip(String text, VoidCallback onDeleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDeleted,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF1D4ED8)),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool canEdit,
    required bool canDelete,
    required String companyId,
    required String firebaseUserUid,
    required String role,
    required bool showTable,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: docs.isEmpty
          ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: Text('No products found')),
      )
          : showTable
          ? _buildTableView(
        docs: docs,
        canEdit: canEdit,
        canDelete: canDelete,
        companyId: companyId,
        firebaseUserUid: firebaseUserUid,
        role: role,
      )
          : _buildCardView(
        docs: docs,
        canEdit: canEdit,
        canDelete: canDelete,
        companyId: companyId,
        firebaseUserUid: firebaseUserUid,
        role: role,
      ),
    );
  }

  Widget _buildTableView({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool canEdit,
    required bool canDelete,
    required String companyId,
    required String firebaseUserUid,
    required String role,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 10,
        columnSpacing: 18,
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Stock')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('')),
        ],
        rows: docs.map((doc) {
          final data = doc.data();
          final name = (data['name'] ?? '').toString();
          final description = (data['description'] ?? '').toString();
          final category = _categoryName(data);
          final subcategory = _subcategoryName(data);
          final itemCode = (data['itemCode'] ?? '').toString();
          final price = data['unitPrice'];
          final isActive = _isProductActive(data);
          final stock = _stockOnHand(data);
          final productType = _productTypeName(data);
          final imageUrl = data['imageUrl']?.toString();

          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 250,
                  child: Row(
                    children: [
                      _buildProductAvatar(imageUrl, name, 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? '(No name)' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667085),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                Text(
                  category.isEmpty
                      ? '—'
                      : subcategory.isEmpty
                      ? category
                      : '$category / $subcategory',
                ),
              ),
              DataCell(Text(productType)),
              DataCell(Text(itemCode.isEmpty ? '—' : itemCode)),
              DataCell(Text(_formatCurrency(price))),
              DataCell(Text(_formatNumber(stock))),
              DataCell(_buildStatusChip(isActive ? 'Active' : 'Inactive')),
              DataCell(
                (canEdit || canDelete)
                    ? PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (value) async {
                    if (value == 'edit' && canEdit) {
                      _openEditProduct(
                        productId: doc.id,
                        initialData: data,
                        companyId: companyId,
                        currentUserUid: firebaseUserUid,
                        currentUserRole: role,
                      );
                    } else if (value == 'delete' && canDelete) {
                      await _deleteProduct(
                        companyId: companyId,
                        productId: doc.id,
                        productName: name.isEmpty ? 'Product' : name,
                        currentUserUid: firebaseUserUid,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    if (canEdit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                    if (canDelete) const PopupMenuDivider(),
                    if (canDelete)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardView({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool canEdit,
    required bool canDelete,
    required String companyId,
    required String firebaseUserUid,
    required String role,
  }) {
    return Column(
      children: docs.map((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final category = _categoryName(data);
        final subcategory = _subcategoryName(data);
        final itemCode = (data['itemCode'] ?? '').toString();
        final price = data['unitPrice'];
        final isActive = _isProductActive(data);
        final stock = _stockOnHand(data);
        final stockStatus = _stockStatus(data);
        final productType = _productTypeName(data);
        final imageUrl = data['imageUrl']?.toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EAF0)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: _buildProductAvatar(imageUrl, name, 44),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? '(No name)' : name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _buildStatusChip(isActive ? 'Active' : 'Inactive'),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill('Type', productType),
                      _pill('Category', category.isEmpty ? '—' : category),
                      _pill(
                        'Subcategory',
                        subcategory.isEmpty ? '—' : subcategory,
                      ),
                      _pill('Code', itemCode.isEmpty ? '—' : itemCode),
                      _pill('Price', _formatCurrency(price)),
                      _pill('Stock', _formatNumber(stock)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildStockChip(stockStatus),
                ],
              ),
            ),
            trailing: (canEdit || canDelete)
                ? PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (value) async {
                if (value == 'edit' && canEdit) {
                  _openEditProduct(
                    productId: doc.id,
                    initialData: data,
                    companyId: companyId,
                    currentUserUid: firebaseUserUid,
                    currentUserRole: role,
                  );
                } else if (value == 'delete' && canDelete) {
                  await _deleteProduct(
                    companyId: companyId,
                    productId: doc.id,
                    productName: name.isEmpty ? 'Product' : name,
                    currentUserUid: firebaseUserUid,
                  );
                }
              },
              itemBuilder: (context) => [
                if (canEdit)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                if (canDelete) const PopupMenuDivider(),
                if (canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
              ],
            )
                : null,
            onTap: () {
              if (!canEdit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You do not have permission to edit this product.')),
                );
                return;
              }
              _openEditProduct(
                productId: doc.id,
                initialData: data,
                companyId: companyId,
                currentUserUid: firebaseUserUid,
                currentUserRole: role,
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusChip(String label) {
    final isActive = label == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.10)
            : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.green[800] : Colors.grey[700],
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStockChip(String label) {
    final color = _stockStatusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in again. No user found.')),
      );
    }

    _userProfileFuture ??= _loadCurrentUserProfile(firebaseUser.uid);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _userProfileFuture,
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error loading user profile: ${userSnap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final userData = userSnap.data;
        if (userData == null) {
          return const Scaffold(
            body: Center(child: Text('User profile not found')),
          );
        }

        final companyId = (userData['companyId'] ?? '').toString();
        final role = (userData['role'] ?? 'sales').toString();

        if (companyId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No company linked to this user')),
          );
        }

        if (!_hasProductPermission(userData, action: 'view')) {
          return const Scaffold(
            body: Center(
              child: Text('You do not have permission to view products'),
            ),
          );
        }

        if (_currentCompanyId != companyId && companyId.isNotEmpty) {
          _currentCompanyId = companyId;
          _categoryMasterFuture = _loadCategoryMaster(companyId);
          _productsStream = FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('products')
              .snapshots();
        }

        final bool canCreate = _hasProductPermission(userData, action: 'create');
        final bool canEdit = _hasProductPermission(userData, action: 'edit');
        final bool canDelete = _hasProductPermission(userData, action: 'delete');

        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FB),

          floatingActionButton: canCreate
              ? FloatingActionButton(
            key: _fabKey,
            onPressed: () {
              _showFabMenu(
                companyId: companyId,
                currentUserUid: firebaseUser.uid,
                currentUserRole: role,
              );
            },
            child: const Icon(Icons.add),
          )
              : null,

          body: FutureBuilder<List<_CategoryMaster>>(
            future: _categoryMasterFuture,
            builder: (context, masterSnap) {
              if (masterSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (masterSnap.hasError) {
                return Center(
                  child: Text(
                    'Error loading categories: ${masterSnap.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final categoryMasters = masterSnap.data ?? [];

              final categoryOptions = categoryMasters
                  .where((e) => e.name.trim().isNotEmpty)
                  .map((e) => e.name)
                  .toList()
                ..sort();

              final Map<String, List<String>> subcategoryMap = {
                for (final cat in categoryMasters)
                  cat.name: (cat.subcategories
                    ..sort(
                          (a, b) => a.name.toLowerCase().compareTo(
                        b.name.toLowerCase(),
                      ),
                    ))
                      .where((s) => s.name.trim().isNotEmpty)
                      .map((s) => s.name)
                      .toList(),
              };

              final subcategoryOptions = categoryMasters
                  .expand((e) => e.subcategories)
                  .map((e) => e.name)
                  .where((e) => e.trim().isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

              final totalCategories = categoryMasters.length;
              final totalSubcategories = categoryMasters.fold<int>(
                0,
                    (sum, e) => sum + e.subcategories.length,
              );

              if (_categoryFilter != 'all' &&
                  !categoryOptions.contains(_categoryFilter)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _categoryFilter = 'all';
                    _subcategoryFilter = 'all';
                  });
                });
              }

              final validSubOptions = _categoryFilter == 'all'
                  ? subcategoryOptions
                  : (subcategoryMap[_categoryFilter] ?? []);

              if (_subcategoryFilter != 'all' &&
                  !validSubOptions.contains(_subcategoryFilter)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _subcategoryFilter = 'all';
                  });
                });
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _productsStream,
                builder: (context, productSnap) {
                  if (productSnap.hasError) {
                    return Center(
                      child: Text(
                        'Error loading products: ${productSnap.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (productSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = productSnap.data?.docs.where((doc) {
                    final data = doc.data();
                    return data['isDeleted'] != true;
                  }).toList() ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  allDocs.sort((a, b) {
                    final aTs = a.data()['createdAt'] as Timestamp?;
                    final bTs = b.data()['createdAt'] as Timestamp?;
                    final aDate =
                        aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bDate =
                        bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bDate.compareTo(aDate);
                  });

                  final filteredDocs = allDocs.where((doc) {
                    final data = doc.data();
                    return _matchesSearch(data) &&
                        _matchesStatusFilter(data) &&
                        _matchesStockFilter(data) &&
                        _matchesCategoryFilter(data) &&
                        _matchesSubcategoryFilter(data);
                  }).toList();

                  final totalProducts = allDocs.length;
                  final activeProducts =
                      allDocs.where((e) => _isProductActive(e.data())).length;

                  final lowStockProducts = allDocs.where((e) {
                    final data = e.data();
                    final stock = _stockOnHand(data);
                    final threshold = _minStockLevel(data) > 0 ? _minStockLevel(data) : _reorderLevel(data);
                    return stock > 0 && threshold > 0 && stock <= threshold;
                  }).length;

                  final outOfStockProducts =
                      allDocs.where((e) => _stockOnHand(e.data()) <= 0).length;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1280;
                      final activeFiltersBar = _buildActiveFiltersBar();
                      final hasFilters = activeFiltersBar is! SizedBox;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderRow(
                              companyId: companyId,
                              currentUserUid: firebaseUser.uid,
                              isWide: isWide,
                              canCreate: canCreate,
                              categoryOptions: categoryOptions,
                              subcategoryOptions: subcategoryOptions,
                              subcategoryMap: subcategoryMap,
                              totalProducts: totalProducts,
                              activeProducts: activeProducts,
                              lowStockProducts: lowStockProducts,
                              outOfStockProducts: outOfStockProducts,
                              totalCategories: totalCategories,
                              totalSubcategories: totalSubcategories,
                            ),
                            if (hasFilters) ...[
                              const SizedBox(height: 10),
                              activeFiltersBar,
                            ],
                            const SizedBox(height: 10),
                            _buildContentCard(
                              docs: filteredDocs,
                              canEdit: canEdit,
                              canDelete: canDelete,
                              companyId: companyId,
                              firebaseUserUid: firebaseUser.uid,
                              role: role,
                              showTable: isWide ? _showTableView : false,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _CategoryMaster {
  final String id;
  final String name;
  final bool isActive;
  final List<_SubcategoryMaster> subcategories;

  _CategoryMaster({
    required this.id,
    required this.name,
    required this.isActive,
    required this.subcategories,
  });
}

class _SubcategoryMaster {
  final String id;
  final String name;

  _SubcategoryMaster({
    required this.id,
    required this.name,
  });
}