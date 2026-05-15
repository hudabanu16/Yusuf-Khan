// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

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

  // INDUSTRIAL ERP FILTERS
  String _natureFilter = 'all';
  String _machineTypeFilter = 'all';
  String _familyFilter = 'all';
  String _brandFilter = 'all';
  String _accessoryGroupFilter = 'all';
  String _spareGroupFilter = 'all';
  String _compatibilityFilter = 'all';

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

  // ---------------------------------------------------------
  // HELPER METHODS: INDUSTRIAL ERP HIERARCHY & DISPLAY
  // ---------------------------------------------------------

  String _normalizedNature(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  String _natureLabel(dynamic value) {
    final nature = _normalizedNature(value);
    if (nature.isEmpty) return 'Standard';
    if (nature == 'raw material') return 'Raw Material';
    return nature[0].toUpperCase() + nature.substring(1);
  }

  Color _natureColor(dynamic value) {
    final nature = _normalizedNature(value);
    switch (nature) {
      case 'machine':
        return Colors.blue.shade700;
      case 'accessory':
        return Colors.purple.shade700;
      case 'spare':
        return Colors.orange.shade800;
      case 'service':
        return Colors.teal.shade700;
      case 'consumable':
        return Colors.green.shade700;
      case 'raw material':
        return Colors.brown.shade700;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  Widget _buildNatureBadge(String natureLabel) {
    final color = _natureColor(natureLabel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        natureLabel.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  String _machineHierarchy(Map<String, dynamic> data, int compatCount) {
    final nature = _normalizedNature(data['productNatureLower'] ?? data['productNature'] ?? data['nature']);

    if (nature == 'machine') {
      final cat = (data['category'] ?? '').toString().trim();
      final sub = (data['subcategory'] ?? '').toString().trim();
      final type = (data['machineType'] ?? data['type'] ?? '').toString().trim();
      final parts = [cat, sub, type].where((e) => e.isNotEmpty).toList();
      return parts.isEmpty ? '—' : parts.join('\n↳ ');
    } else if (nature == 'accessory') {
      final group = (data['accessoryGroupName'] ?? data['accessoryGroup'] ?? '').toString().trim();
      final main = group.isEmpty ? 'Accessory' : group;
      return compatCount > 0 ? '$main\n↳ Compatible: $compatCount Machines' : main;
    } else if (nature == 'spare') {
      final group = (data['spareGroupName'] ?? data['spareGroup'] ?? '').toString().trim();
      final main = group.isEmpty ? 'Spare Part' : group;
      return compatCount > 0 ? '$main\n↳ Compatible: $compatCount Machines' : main;
    }
    return '—';
  }

  List<String> _compatibleMachineNames(Map<String, dynamic> data) {
    final compat = data['compatibleProductNames'] ?? data['compatibleModels'];
    if (compat is! List) return [];
    return compat.map((e) {
      if (e is String) return e.trim();
      if (e is Map) return (e['name'] ?? e['id'] ?? '').toString().trim();
      return '';
    }).where((e) => e.isNotEmpty).toList();
  }

  String _compatiblePreview(List<Map<String, String>> models) {
    if (models.isEmpty) return '';
    if (models.length <= 2) return models.map((e) => e['name']).join(', ');
    return '${models[0]['name']}, ${models[1]['name']} +${models.length - 2} more';
  }

  List<Map<String, String>> _resolveCompatibleMachines(
      Map<String, dynamic> data,
      Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> productMapById,
      Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> productMapByName,
      ) {
    final List<Map<String, String>> result = [];

    final ids = data['compatibleProductIds'];
    final names = data['compatibleProductNames'] ?? data['compatibleModels'];

    List<String> parsedIds = [];
    if (ids is List) {
      parsedIds = ids.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    List<dynamic> parsedNamesOrMaps = [];
    if (names is List) {
      parsedNamesOrMaps = names;
    }

    // 1. Resolve by IDs if available (O(1) Hash Lookup)
    if (parsedIds.isNotEmpty) {
      for (int i = 0; i < parsedIds.length; i++) {
        final id = parsedIds[i];
        final doc = productMapById[id];

        if (doc != null) {
          final dData = doc.data();
          result.add({
            'name': (dData['name'] ?? '').toString(),
            'category': (dData['category'] ?? '').toString(),
            'subcategory': (dData['subcategory'] ?? '').toString(),
            'machineType': (dData['machineType'] ?? dData['type'] ?? '').toString(),
          });
        } else {
          // Safe Fallback using available legacy names if document is missing
          String fallbackName = 'Unknown Machine ($id)';
          if (i < parsedNamesOrMaps.length) {
            final fallbackItem = parsedNamesOrMaps[i];
            if (fallbackItem is String && fallbackItem.trim().isNotEmpty) {
              fallbackName = fallbackItem.trim();
            } else if (fallbackItem is Map) {
              fallbackName = (fallbackItem['name'] ?? fallbackItem['id'] ?? fallbackName).toString().trim();
            }
          }
          result.add({
            'name': fallbackName,
            'category': '',
            'subcategory': '',
            'machineType': ''
          });
        }
      }
      return result;
    }

    // 2. Fallback to Legacy Name/Map Structure (O(1) Hash Lookup)
    if (parsedNamesOrMaps.isNotEmpty) {
      for (final e in parsedNamesOrMaps) {
        if (e is String && e.trim().isNotEmpty) {
          final searchName = e.trim().toLowerCase();
          final doc = productMapByName[searchName];

          if (doc != null) {
            final dData = doc.data();
            result.add({
              'name': (dData['name'] ?? '').toString(),
              'category': (dData['category'] ?? '').toString(),
              'subcategory': (dData['subcategory'] ?? '').toString(),
              'machineType': (dData['machineType'] ?? dData['type'] ?? '').toString(),
            });
          } else {
            result.add({'name': e.trim(), 'category': '', 'subcategory': '', 'machineType': ''});
          }
        } else if (e is Map) {
          final nameStr = (e['name'] ?? e['id'] ?? '').toString().trim();
          final doc = productMapByName[nameStr.toLowerCase()];

          if (doc != null) {
            final dData = doc.data();
            result.add({
              'name': (dData['name'] ?? '').toString(),
              'category': (dData['category'] ?? '').toString(),
              'subcategory': (dData['subcategory'] ?? '').toString(),
              'machineType': (dData['machineType'] ?? dData['type'] ?? '').toString(),
            });
          } else {
            result.add({
              'name': nameStr,
              'category': (e['category'] ?? '').toString().trim(),
              'subcategory': (e['subcategory'] ?? '').toString().trim(),
              'machineType': (e['machineType'] ?? e['type'] ?? '').toString().trim(),
            });
          }
        }
      }
    }
    return result;
  }

  bool _matchesNature(Map<String, dynamic> data, String selectedNature) {
    if (selectedNature == 'all') return true;
    final docNature = _natureLabel(data['productNatureLower'] ?? data['productNature'] ?? data['nature']);
    return docNature.toLowerCase() == selectedNature.toLowerCase();
  }

  void _showCompatibleModelsDialog(String productName, List<Map<String, String>> models) {
    String dialogSearch = '';

    // Performance Optimization: Cache lowercase strings once
    final List<Map<String, dynamic>> cachedModels = models.map((m) {
      final combined = '${m['name']} ${m['category']} ${m['subcategory']} ${m['machineType']}'.toLowerCase();
      return {
        'data': m,
        'searchKey': combined,
      };
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = cachedModels.where((m) {
            if (dialogSearch.isEmpty) return true;
            return (m['searchKey'] as String).contains(dialogSearch);
          }).map((m) => m['data'] as Map<String, String>).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing_outlined, color: Colors.blueGrey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Compatible Machines (${models.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(productName, style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.normal)),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search machines...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE4E7EC))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue)),
                  ),
                  onChanged: (val) => setDialogState(() => dialogSearch = val.toLowerCase()),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              height: 400,
              child: filtered.isEmpty
                  ? const Center(child: Text('No compatible machines found', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final m = filtered[index];
                  final mName = m['name'] ?? 'Unknown';
                  final mCat = m['category'] ?? '';
                  final mSub = m['subcategory'] ?? '';
                  final mType = m['machineType'] ?? '';

                  final hierarchyParts = [mCat, mSub, mType].where((e) => e.isNotEmpty).toList();
                  final hierarchyStr = hierarchyParts.join(' → ');

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF1F5F9),
                      radius: 16,
                      child: Icon(Icons.precision_manufacturing, size: 16, color: Color(0xFF64748B)),
                    ),
                    title: Text(mName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: hierarchyStr.isNotEmpty ? Text(hierarchyStr, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)) : null,
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              )
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // CORE APP LOGIC
  // ---------------------------------------------------------

  void _sanitizeActiveFilters({
    required List<String> categoryOptions,
    required List<String> validSubOptions,
    required List<String> natureOptions,
    required List<String> machineTypeOptions,
    required List<String> familyOptions,
    required List<String> brandOptions,
    required List<String> accessoryGroupOptions,
    required List<String> spareGroupOptions,
  }) {
    bool needsUpdate = false;
    String newCat = _categoryFilter;
    String newSub = _subcategoryFilter;
    String newNature = _natureFilter;
    String newMachine = _machineTypeFilter;
    String newFamily = _familyFilter;
    String newBrand = _brandFilter;
    String newAcc = _accessoryGroupFilter;
    String newSpare = _spareGroupFilter;

    if (newCat != 'all' && !categoryOptions.contains(newCat)) { newCat = 'all'; newSub = 'all'; needsUpdate = true; }
    if (newSub != 'all' && !validSubOptions.contains(newSub)) { newSub = 'all'; needsUpdate = true; }
    if (newNature != 'all' && !natureOptions.contains(newNature)) { newNature = 'all'; needsUpdate = true; }
    if (newMachine != 'all' && !machineTypeOptions.contains(newMachine)) { newMachine = 'all'; needsUpdate = true; }
    if (newFamily != 'all' && !familyOptions.contains(newFamily)) { newFamily = 'all'; needsUpdate = true; }
    if (newBrand != 'all' && !brandOptions.contains(newBrand)) { newBrand = 'all'; needsUpdate = true; }
    if (newAcc != 'all' && !accessoryGroupOptions.contains(newAcc)) { newAcc = 'all'; needsUpdate = true; }
    if (newSpare != 'all' && !spareGroupOptions.contains(newSpare)) { newSpare = 'all'; needsUpdate = true; }

    if (needsUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _categoryFilter = newCat;
            _subcategoryFilter = newSub;
            _natureFilter = newNature;
            _machineTypeFilter = newMachine;
            _familyFilter = newFamily;
            _brandFilter = newBrand;
            _accessoryGroupFilter = newAcc;
            _spareGroupFilter = newSpare;
          });
        }
      });
    }
  }

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
    if (data.containsKey('reorderLevel')) return _toDouble(data['reorderLevel']);
    if (data.containsKey('minStockLevel')) return _toDouble(data['minStockLevel']);
    return 0;
  }

  double _minStockLevel(Map<String, dynamic> data) {
    if (data.containsKey('minStockLevel')) return _toDouble(data['minStockLevel']);
    return _reorderLevel(data);
  }

  String _categoryName(Map<String, dynamic> data) {
    return (data['category'] ?? '').toString().trim();
  }

  String _subcategoryName(Map<String, dynamic> data) {
    return (data['subcategory'] ?? '').toString().trim();
  }

  bool _matchesSearch(Map<String, dynamic> data, List<Map<String, String>> cachedCompatDetails, String cachedHierarchy, String cachedNatureLabel) {
    if (_searchText.isEmpty) return true;

    final fields = [
      data['name'],
      data['itemCode'],
      data['sku'],
      data['brand'],
      data['category'],
      data['subcategory'],
      cachedNatureLabel,
      cachedHierarchy,
      ...cachedCompatDetails.map((e) => e['name']!),
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
    return _subcategoryName(data).toLowerCase() == _subcategoryFilter.toLowerCase();
  }

  bool _matchesIndustrialFilters(Map<String, dynamic> data, int compatCount) {
    if (!_matchesNature(data, _natureFilter)) return false;

    if (_familyFilter != 'all' && (data['family'] ?? '').toString().trim() != _familyFilter) return false;
    if (_machineTypeFilter != 'all' && (data['machineType'] ?? data['type'] ?? '').toString().trim() != _machineTypeFilter) return false;
    if (_brandFilter != 'all' && (data['brand'] ?? '').toString().trim() != _brandFilter) return false;
    if (_accessoryGroupFilter != 'all' && (data['accessoryGroupName'] ?? data['accessoryGroup'] ?? '').toString().trim() != _accessoryGroupFilter) return false;
    if (_spareGroupFilter != 'all' && (data['spareGroupName'] ?? data['spareGroup'] ?? '').toString().trim() != _spareGroupFilter) return false;

    if (_compatibilityFilter == 'has_compatibility') return compatCount > 0;
    if (_compatibilityFilter == 'no_compatibility') return compatCount == 0;

    return true;
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
    required List<String> natureOptions,
    required List<String> familyOptions,
    required List<String> machineTypeOptions,
    required List<String> brandOptions,
    required List<String> accessoryGroupOptions,
    required List<String> spareGroupOptions,
  }) {
    String tempStatus = _statusFilter;
    String tempStock = _stockFilter;
    String tempCategory = _categoryFilter;
    String tempSubcategory = _subcategoryFilter;
    String tempNature = _natureFilter;
    String tempFamily = _familyFilter;
    String tempMachineType = _machineTypeFilter;
    String tempBrand = _brandFilter;
    String tempAccessoryGroup = _accessoryGroupFilter;
    String tempSpareGroup = _spareGroupFilter;
    String tempCompatibility = _compatibilityFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Advanced Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Basic Status', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempStatus,
                                    decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                                      DropdownMenuItem(value: 'active', child: Text('Active')),
                                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempStatus = value ?? 'all'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempStock,
                                    decoration: InputDecoration(labelText: 'Stock', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('All Stock')),
                                      DropdownMenuItem(value: 'in_stock', child: Text('In Stock')),
                                      DropdownMenuItem(value: 'low_stock', child: Text('Low Stock')),
                                      DropdownMenuItem(value: 'out_of_stock', child: Text('Out of Stock')),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempStock = value ?? 'all'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            const Text('ERP Hierarchy', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempNature,
                                    decoration: InputDecoration(labelText: 'Nature', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Natures')),
                                      ...natureOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempNature = value ?? 'all'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempFamily,
                                    decoration: InputDecoration(labelText: 'Product Family', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Families')),
                                      ...familyOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempFamily = value ?? 'all'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempMachineType,
                                    decoration: InputDecoration(labelText: 'Machine Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Types')),
                                      ...machineTypeOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempMachineType = value ?? 'all'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempBrand,
                                    decoration: InputDecoration(labelText: 'Brand', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Brands')),
                                      ...brandOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempBrand = value ?? 'all'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            const Text('Groups & Categorization', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempAccessoryGroup,
                                    decoration: InputDecoration(labelText: 'Accessory Group', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Acc. Groups')),
                                      ...accessoryGroupOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempAccessoryGroup = value ?? 'all'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempSpareGroup,
                                    decoration: InputDecoration(labelText: 'Spare Group', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Spare Groups')),
                                      ...spareGroupOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempSpareGroup = value ?? 'all'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempCategory,
                                    decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Categories')),
                                      ...categoryOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                    ],
                                    onChanged: (value) {
                                      modalSetState(() {
                                        tempCategory = value ?? 'all';
                                        tempSubcategory = 'all';
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempSubcategory,
                                    decoration: InputDecoration(labelText: 'Subcategory', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Subcategories')),
                                      ...availableSubs.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempSubcategory = value ?? 'all'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempCompatibility,
                                    decoration: InputDecoration(labelText: 'Compatibility', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('All')),
                                      DropdownMenuItem(value: 'has_compatibility', child: Text('Has Compatibility')),
                                      DropdownMenuItem(value: 'no_compatibility', child: Text('No Compatibility')),
                                    ],
                                    onChanged: (value) => modalSetState(() => tempCompatibility = value ?? 'all'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'all';
                                _stockFilter = 'all';
                                _categoryFilter = 'all';
                                _subcategoryFilter = 'all';
                                _natureFilter = 'all';
                                _familyFilter = 'all';
                                _machineTypeFilter = 'all';
                                _brandFilter = 'all';
                                _accessoryGroupFilter = 'all';
                                _spareGroupFilter = 'all';
                                _compatibilityFilter = 'all';
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Reset All'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: () {
                              setState(() {
                                _statusFilter = tempStatus;
                                _stockFilter = tempStock;
                                _categoryFilter = tempCategory;
                                _subcategoryFilter = tempSubcategory;
                                _natureFilter = tempNature;
                                _familyFilter = tempFamily;
                                _machineTypeFilter = tempMachineType;
                                _brandFilter = tempBrand;
                                _accessoryGroupFilter = tempAccessoryGroup;
                                _spareGroupFilter = tempSpareGroup;
                                _compatibilityFilter = tempCompatibility;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Apply Filters'),
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

    // INDUSTRIAL ERP FILTERS
    required List<String> natureOptions,
    required List<String> familyOptions,
    required List<String> machineTypeOptions,
    required List<String> brandOptions,
    required List<String> accessoryGroupOptions,
    required List<String> spareGroupOptions,

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
              // INDUSTRIAL ERP FILTERS
              natureOptions: natureOptions,
              familyOptions: familyOptions,
              machineTypeOptions: machineTypeOptions,
              brandOptions: brandOptions,
              accessoryGroupOptions: accessoryGroupOptions,
              spareGroupOptions: spareGroupOptions,
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
    if (_natureFilter != 'all') {
      chips.add(_filterChip('Nature: $_natureFilter', () {
        setState(() => _natureFilter = 'all');
      }));
    }
    if (_machineTypeFilter != 'all') {
      chips.add(_filterChip('Machine Type: $_machineTypeFilter', () {
        setState(() => _machineTypeFilter = 'all');
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
    if (_compatibilityFilter != 'all') {
      chips.add(_filterChip('Compatibility: ${_compatibilityFilter.replaceAll('_', ' ').toUpperCase()}', () {
        setState(() => _compatibilityFilter = 'all');
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
    required Map<String, List<Map<String, String>>> compatDetailsCache,
    required Map<String, String> hierarchyCache,
    required Map<String, String> natureLabelCache,
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
        child: Center(child: Text('No products found matching filters.')),
      )
          : showTable
          ? _buildTableView(
        docs: docs,
        compatDetailsCache: compatDetailsCache,
        hierarchyCache: hierarchyCache,
        natureLabelCache: natureLabelCache,
        canEdit: canEdit,
        canDelete: canDelete,
        companyId: companyId,
        firebaseUserUid: firebaseUserUid,
        role: role,
      )
          : _buildCardView(
        docs: docs,
        compatDetailsCache: compatDetailsCache,
        hierarchyCache: hierarchyCache,
        natureLabelCache: natureLabelCache,
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
    required Map<String, List<Map<String, String>>> compatDetailsCache,
    required Map<String, String> hierarchyCache,
    required Map<String, String> natureLabelCache,
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
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Nature')),
          DataColumn(label: Text('ERP Hierarchy')),
          DataColumn(label: Text('Brand')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Stock')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('')),
        ],
        rows: docs.map((doc) {
          final data = doc.data();
          final name = (data['name'] ?? '').toString();
          final description = (data['description'] ?? '').toString();
          final brand = (data['brand'] ?? '').toString();
          final sku = (data['sku'] ?? data['itemCode'] ?? '').toString();
          final price = data['unitPrice'];
          final isActive = _isProductActive(data);
          final stock = _stockOnHand(data);
          final imageUrl = data['imageUrl']?.toString();

          final natureName = natureLabelCache[doc.id] ?? 'Standard';
          final hierarchy = hierarchyCache[doc.id] ?? '—';

          final compatDetails = compatDetailsCache[doc.id] ?? [];
          final int compatCount = compatDetails.length;

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
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(_buildNatureBadge(natureName)),
              DataCell(
                SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hierarchy,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (compatCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: InkWell(
                            onTap: () => _showCompatibleModelsDialog(name, compatDetails),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link_outlined, size: 12, color: Colors.blue.shade700),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Compatible With: $compatCount Machines',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              DataCell(Text(brand.isEmpty ? '—' : brand)),
              DataCell(Text(sku.isEmpty ? '—' : sku)),
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
    required Map<String, List<Map<String, String>>> compatDetailsCache,
    required Map<String, String> hierarchyCache,
    required Map<String, String> natureLabelCache,
    required bool canEdit,
    required bool canDelete,
    required String companyId,
    required String firebaseUserUid,
    required String role,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        final description = (data['description'] ?? '').toString();
        final brand = (data['brand'] ?? '').toString();
        final sku = (data['sku'] ?? data['itemCode'] ?? '').toString();
        final price = data['unitPrice'];
        final isActive = _isProductActive(data);
        final stock = _stockOnHand(data);
        final stockStatus = _stockStatus(data);
        final imageUrl = data['imageUrl']?.toString();

        final natureName = natureLabelCache[doc.id] ?? 'Standard';
        final hierarchy = hierarchyCache[doc.id] ?? '—';
        final compatDetails = compatDetailsCache[doc.id] ?? [];
        final int compatCount = compatDetails.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EAF0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductAvatar(imageUrl, name, 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? '(No name)' : name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827)),
                          ),
                        ),
                        Text(
                          _formatCurrency(price),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF111827)),
                        ),
                        if (canEdit || canDelete) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
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
                                if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildNatureBadge(natureName),
                        _buildStatusChip(isActive ? 'Active' : 'Inactive'),
                        _buildStockChip(stockStatus),
                        if (stock > 0 || stockStatus == 'Low Stock')
                          Text('${_formatNumber(stock)} in stock', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475467))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.account_tree_outlined, size: 14, color: Colors.blueGrey),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  hierarchy,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _pill('Brand', brand.isEmpty ? '—' : brand),
                              _pill('SKU', sku.isEmpty ? '—' : sku),
                              if (compatCount > 0)
                                InkWell(
                                  onTap: () => _showCompatibleModelsDialog(name, compatDetails),
                                  child: _pill('Compatible With', '$compatCount Machines', isLink: true),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          fontSize: 11,
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
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _pill(String label, String value, {bool isLink = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLink ? Colors.blue.shade50 : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isLink ? Colors.blue.shade200 : const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLink ? Colors.blue.shade700 : const Color(0xFF344054),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
          // Safely using local filtering because Firestore .where('isDeleted', isEqualTo: false)
          // will drop legacy documents that do not have the 'isDeleted' field.
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
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              final totalCategories = categoryMasters.length;
              final totalSubcategories = categoryMasters.fold<int>(
                0,
                    (total, e) => total + e.subcategories.length,
              );

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

                  // ---------------------------------------------------------
                  // HIGH PERFORMANCE LOOKUP MAPS & LOCAL DATA CACHE
                  // ---------------------------------------------------------
                  final Map<String, Map<String, dynamic>> dataCache = {};
                  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> productMapById = {};
                  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> productMapByName = {};

                  for (final d in allDocs) {
                    final data = d.data();
                    dataCache[d.id] = data;
                    productMapById[d.id] = d;

                    final name = (data['name'] ?? '').toString().trim().toLowerCase();
                    if (name.isNotEmpty) {
                      productMapByName[name] = d;
                    }
                  }

                  // EXTRACT DYNAMIC OPTIONS FOR INDUSTRIAL FILTERS (Auto Sorted Case-Insensitive)
                  final natureOptions = allDocs.map((d) => _natureLabel(dataCache[d.id]!['productNatureLower'] ?? dataCache[d.id]!['productNature'] ?? dataCache[d.id]!['nature'])).where((e) => e.isNotEmpty && e != 'Standard').toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                  final familyOptions = allDocs.map((d) => (dataCache[d.id]!['family'] ?? '').toString().trim()).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                  final machineTypeOptions = allDocs.map((d) => (dataCache[d.id]!['machineType'] ?? dataCache[d.id]!['type'] ?? '').toString().trim()).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                  final brandOptions = allDocs.map((d) => (dataCache[d.id]!['brand'] ?? '').toString().trim()).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                  final accessoryGroupOptions = allDocs.map((d) => (dataCache[d.id]!['accessoryGroupName'] ?? dataCache[d.id]!['accessoryGroup'] ?? '').toString().trim()).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                  final spareGroupOptions = allDocs.map((d) => (dataCache[d.id]!['spareGroupName'] ?? dataCache[d.id]!['spareGroup'] ?? '').toString().trim()).where((e) => e.isNotEmpty).toSet().toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                  // ---------------------------------------------------------
                  // SANITIZE ACTIVE FILTERS (CENTRALIZED)
                  // ---------------------------------------------------------
                  final validSubOptions = _categoryFilter == 'all' ? subcategoryOptions : (subcategoryMap[_categoryFilter] ?? []);
                  _sanitizeActiveFilters(
                    categoryOptions: categoryOptions,
                    validSubOptions: validSubOptions,
                    natureOptions: natureOptions,
                    machineTypeOptions: machineTypeOptions,
                    familyOptions: familyOptions,
                    brandOptions: brandOptions,
                    accessoryGroupOptions: accessoryGroupOptions,
                    spareGroupOptions: spareGroupOptions,
                  );

                  // CACHED COLLECTIONS TO AVOID REPEATED PARSING
                  final Map<String, List<Map<String, String>>> compatDetailsCache = {};
                  final Map<String, String> hierarchyCache = {};
                  final Map<String, String> natureLabelCache = {};

                  final filteredDocs = allDocs.where((doc) {
                    final data = dataCache[doc.id]!;

                    final compatDetails = _resolveCompatibleMachines(data, productMapById, productMapByName);
                    final compatCount = compatDetails.length;

                    final hierarchy = _machineHierarchy(data, compatCount);
                    final natureLabel = _natureLabel(data['productNatureLower'] ?? data['productNature'] ?? data['nature']);

                    compatDetailsCache[doc.id] = compatDetails;
                    hierarchyCache[doc.id] = hierarchy;
                    natureLabelCache[doc.id] = natureLabel;

                    return _matchesSearch(data, compatDetails, hierarchy, natureLabel) &&
                        _matchesStatusFilter(data) &&
                        _matchesStockFilter(data) &&
                        _matchesCategoryFilter(data) &&
                        _matchesSubcategoryFilter(data) &&
                        _matchesIndustrialFilters(data, compatCount);
                  }).toList();

                  final totalProducts = allDocs.length;
                  final activeProducts =
                      allDocs.where((e) => _isProductActive(dataCache[e.id]!)).length;

                  final lowStockProducts = allDocs.where((e) {
                    final data = dataCache[e.id]!;
                    final stock = _stockOnHand(data);
                    final threshold = _minStockLevel(data) > 0 ? _minStockLevel(data) : _reorderLevel(data);
                    return stock > 0 && threshold > 0 && stock <= threshold;
                  }).length;

                  final outOfStockProducts =
                      allDocs.where((e) => _stockOnHand(dataCache[e.id]!) <= 0).length;

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
                              natureOptions: natureOptions,
                              familyOptions: familyOptions,
                              machineTypeOptions: machineTypeOptions,
                              brandOptions: brandOptions,
                              accessoryGroupOptions: accessoryGroupOptions,
                              spareGroupOptions: spareGroupOptions,
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
                              compatDetailsCache: compatDetailsCache,
                              hierarchyCache: hierarchyCache,
                              natureLabelCache: natureLabelCache,
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