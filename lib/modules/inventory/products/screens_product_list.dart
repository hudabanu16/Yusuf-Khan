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
  String _makeFilter = 'all';
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

  bool _isMachine(dynamic nature) => _normalizedNature(nature) == 'machine';
  bool _isAccessory(dynamic nature) => _normalizedNature(nature) == 'accessory';
  bool _isSpare(dynamic nature) => _normalizedNature(nature) == 'spare';

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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
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

  String _formatSupportedCategories(List<String> items) {
    if (items.isEmpty) return 'None';
    if (items.length <= 2) return items.join(', ');
    return '${items[0]}, ${items[1]} +${items.length - 2} more';
  }

  String _machineCountLabel(int count, {bool usedIn = false}) {
    final word = count == 1 ? 'Equipment' : 'Equipment';
    return usedIn ? 'Used In: $count $word' : 'Compatible: $count $word';
  }

  String _formatFilterLabel(String value) {
    switch (value) {
      case 'low_stock':
        return 'Low Stock';
      case 'out_of_stock':
        return 'Out of Stock';
      case 'in_stock':
        return 'In Stock';
      case 'has_compatibility':
        return 'Compatible';
      case 'no_compatibility':
        return 'No Compatibility';
      case 'all':
        return 'All';
      default:
        return value
            .split('_')
            .map(
              (e) =>
                  e.isNotEmpty ? '${e[0].toUpperCase()}${e.substring(1)}' : '',
            )
            .join(' ');
    }
  }

  String _machineHierarchy(
    Map<String, dynamic> data,
    int compatCount,
    Map<String, String> subcategoryNameCache,
  ) {
    final nature = _normalizedNature(
      data['productNatureLower'] ?? data['productNature'] ?? data['nature'],
    );

    if (_isMachine(nature)) {
      final cat = (data['category'] ?? '').toString().trim();
      final sub = (data['subcategory'] ?? '').toString().trim();
      final type = (data['machineType'] ?? data['type'] ?? '')
          .toString()
          .trim();
      final parts = [cat, sub, type].where((e) => e.isNotEmpty).toList();
      return parts.isEmpty ? '—' : parts.join(' → ');
    } else if (_isAccessory(nature)) {
      final group = (data['accessoryGroupName'] ?? data['accessoryGroup'] ?? '')
          .toString()
          .trim();
      final main = group.isEmpty ? 'Accessory' : group;

      List<String> supportedSubs = [];
      if (data['compatibleSubcategoryNames'] is List &&
          (data['compatibleSubcategoryNames'] as List).isNotEmpty) {
        supportedSubs = List<String>.from(data['compatibleSubcategoryNames']);
      } else if (data['compatibleSubcategories'] is List) {
        supportedSubs = (data['compatibleSubcategories'] as List).map((id) {
          return subcategoryNameCache[id.toString()] ?? id.toString();
        }).toList();
      }

      String supportsText = supportedSubs.isNotEmpty
          ? '\n• Supports: ${_formatSupportedCategories(supportedSubs)}'
          : '';
      String compatText = compatCount > 0
          ? '\n• ${_machineCountLabel(compatCount, usedIn: true)}'
          : '';

      return '$main$supportsText$compatText';
    } else if (_isSpare(nature)) {
      final group = (data['spareGroupName'] ?? data['spareGroup'] ?? '')
          .toString()
          .trim();
      final main = group.isEmpty ? 'Spare Part' : group;
      final type = (data['compatibleMachineType'] ?? '').toString().trim();

      String typeText = type.isNotEmpty ? '\n• Type: $type' : '';
      String compatText = compatCount > 0
          ? '\n• ${_machineCountLabel(compatCount, usedIn: false)}'
          : '';

      return '$main$typeText$compatText';
    }
    return '—';
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
      parsedIds = ids
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
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
            'machineType': (dData['machineType'] ?? dData['type'] ?? '')
                .toString(),
          });
        } else {
          // Safe Fallback using available legacy names if document is missing
          String fallbackName = 'Unknown Equipment ($id)';
          if (i < parsedNamesOrMaps.length) {
            final fallbackItem = parsedNamesOrMaps[i];
            if (fallbackItem is String && fallbackItem.trim().isNotEmpty) {
              fallbackName = fallbackItem.trim();
            } else if (fallbackItem is Map) {
              fallbackName =
                  (fallbackItem['name'] ?? fallbackItem['id'] ?? fallbackName)
                      .toString()
                      .trim();
            }
          }
          result.add({
            'name': fallbackName,
            'category': '',
            'subcategory': '',
            'machineType': '',
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
              'machineType': (dData['machineType'] ?? dData['type'] ?? '')
                  .toString(),
            });
          } else {
            result.add({
              'name': e.trim(),
              'category': '',
              'subcategory': '',
              'machineType': '',
            });
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
              'machineType': (dData['machineType'] ?? dData['type'] ?? '')
                  .toString(),
            });
          } else {
            result.add({
              'name': nameStr,
              'category': (e['category'] ?? '').toString().trim(),
              'subcategory': (e['subcategory'] ?? '').toString().trim(),
              'machineType': (e['machineType'] ?? e['type'] ?? '')
                  .toString()
                  .trim(),
            });
          }
        }
      }
    }
    return result;
  }

  bool _matchesNature(Map<String, dynamic> data, String selectedNature) {
    if (selectedNature == 'all') return true;
    final docNature = _natureLabel(
      data['productNatureLower'] ?? data['productNature'] ?? data['nature'],
    );
    return docNature.toLowerCase() == selectedNature.toLowerCase();
  }

  void _showCompatibleModelsDialog(
    String productName,
    List<Map<String, String>> models, {
    required bool isAccessory,
  }) {
    String dialogSearch = '';

    // Performance Optimization: Cache lowercase strings once
    final List<Map<String, dynamic>> cachedModels = models.map((m) {
      final combined =
          '${m['name']} ${m['category']} ${m['subcategory']} ${m['machineType']}'
              .toLowerCase();
      return {'data': m, 'searchKey': combined};
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = cachedModels
              .where((m) {
                if (dialogSearch.isEmpty) return true;
                return (m['searchKey'] as String).contains(dialogSearch);
              })
              .map((m) => m['data'] as Map<String, String>)
              .toList();

          final titlePrefix = isAccessory
              ? 'Used In Equipment'
              : 'Compatible Equipment';

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.precision_manufacturing_outlined,
                      color: Colors.blueGrey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$titlePrefix (${models.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 36,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search equipment...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                    ),
                    onChanged: (val) =>
                        setDialogState(() => dialogSearch = val.toLowerCase()),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width > 600
                  ? 480
                  : MediaQuery.of(ctx).size.width * 0.92,
              height: 400,
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No compatible equipment found',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, index) {
                        final m = filtered[index];
                        final mName = m['name'] ?? 'Unknown';
                        final mCat = m['category'] ?? '';
                        final mSub = m['subcategory'] ?? '';
                        final mType = m['machineType'] ?? '';

                        final hierarchyParts = [
                          mCat,
                          mSub,
                          mType,
                        ].where((e) => e.isNotEmpty).toList();
                        final hierarchyStr = hierarchyParts.join(' → ');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.precision_manufacturing,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (hierarchyStr.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        hierarchyStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(fontSize: 13)),
              ),
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
    required List<String> makeOptions,
    required List<String> accessoryGroupOptions,
    required List<String> spareGroupOptions,
  }) {
    bool needsUpdate = false;
    String newCat = _categoryFilter;
    String newSub = _subcategoryFilter;
    String newNature = _natureFilter;
    String newMachine = _machineTypeFilter;
    String newFamily = _familyFilter;
    String newMake = _makeFilter;
    String newAcc = _accessoryGroupFilter;
    String newSpare = _spareGroupFilter;

    if (newCat != 'all' && !categoryOptions.contains(newCat)) {
      newCat = 'all';
      newSub = 'all';
      needsUpdate = true;
    }
    if (newSub != 'all' && !validSubOptions.contains(newSub)) {
      newSub = 'all';
      needsUpdate = true;
    }
    if (newNature != 'all' && !natureOptions.contains(newNature)) {
      newNature = 'all';
      needsUpdate = true;
    }
    if (newMachine != 'all' && !machineTypeOptions.contains(newMachine)) {
      newMachine = 'all';
      needsUpdate = true;
    }
    if (newFamily != 'all' && !familyOptions.contains(newFamily)) {
      newFamily = 'all';
      needsUpdate = true;
    }
    if (newMake != 'all' && !makeOptions.contains(newMake)) {
      newMake = 'all';
      needsUpdate = true;
    }
    if (newAcc != 'all' && !accessoryGroupOptions.contains(newAcc)) {
      newAcc = 'all';
      needsUpdate = true;
    }
    if (newSpare != 'all' && !spareGroupOptions.contains(newSpare)) {
      newSpare = 'all';
      needsUpdate = true;
    }

    if (needsUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _categoryFilter = newCat;
            _subcategoryFilter = newSub;
            _natureFilter = newNature;
            _machineTypeFilter = newMachine;
            _familyFilter = newFamily;
            _makeFilter = newMake;
            _accessoryGroupFilter = newAcc;
            _spareGroupFilter = newSpare;
          });
        }
      });
    }
  }

  void _refreshCategoryMaster() {
    if (!mounted || _currentCompanyId == null || _currentCompanyId!.isEmpty) {
      return;
    }
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
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                _buildInitialsFallback(name, size),
          ),
        ),
      );
    }
    return _buildInitialsFallback(name, size);
  }

  Widget _buildInitialsFallback(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
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

    return {...globalData, ...companyData, 'companyId': companyId};
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

  bool _hasProductPermission(
    Map<String, dynamic> userData, {
    String action = 'view',
  }) {
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
    if (permissions['products'] is Map &&
        permissions['products'][action] == true) {
      return true;
    }

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

  bool _matchesSearch(
    Map<String, dynamic> data,
    List<Map<String, String>> cachedCompatDetails,
    String cachedHierarchy,
    String cachedNatureLabel,
  ) {
    if (_searchText.isEmpty) return true;

    final subNames = data['compatibleSubcategoryNames'];
    final mType = data['compatibleMachineType'];
    final make = data['make'] ?? data['brand'];

    final fields = [
      data['name'],
      data['itemCode'],
      data['sku'],
      make,
      data['category'],
      data['subcategory'],
      cachedNatureLabel,
      cachedHierarchy,
      if (subNames is List) ...subNames.map((e) => e.toString()),
      if (mType != null) mType.toString(),
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
    final threshold = _minStockLevel(data) > 0
        ? _minStockLevel(data)
        : _reorderLevel(data);

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

    final filter = _subcategoryFilter.toLowerCase();
    final nature = _normalizedNature(
      data['productNatureLower'] ?? data['productNature'] ?? data['nature'],
    );

    if (_isAccessory(nature)) {
      final subNames = data['compatibleSubcategoryNames'];
      if (subNames is List &&
          subNames.any((e) => e.toString().toLowerCase() == filter)) {
        return true;
      }
      return false;
    }

    return _subcategoryName(data).toLowerCase() == filter;
  }

  bool _matchesIndustrialFilters(Map<String, dynamic> data, int compatCount) {
    if (!_matchesNature(data, _natureFilter)) return false;

    if (_familyFilter != 'all' &&
        (data['family'] ?? '').toString().trim() != _familyFilter) {
      return false;
    }
    if (_machineTypeFilter != 'all' &&
        (data['machineType'] ?? data['type'] ?? '').toString().trim() !=
            _machineTypeFilter) {
      return false;
    }

    final make = (data['make'] ?? data['brand'] ?? '').toString().trim();
    if (_makeFilter != 'all' && make != _makeFilter) return false;

    if (_accessoryGroupFilter != 'all' &&
        (data['accessoryGroupName'] ?? data['accessoryGroup'] ?? '')
                .toString()
                .trim() !=
            _accessoryGroupFilter) {
      return false;
    }
    if (_spareGroupFilter != 'all' &&
        (data['spareGroupName'] ?? data['spareGroup'] ?? '')
                .toString()
                .trim() !=
            _spareGroupFilter) {
      return false;
    }

    if (_compatibilityFilter == 'has_compatibility') return compatCount > 0;
    if (_compatibilityFilter == 'no_compatibility') return compatCount == 0;

    return true;
  }

  String _stockStatus(Map<String, dynamic> data) {
    final stock = _stockOnHand(data);
    final threshold = _minStockLevel(data) > 0
        ? _minStockLevel(data)
        : _reorderLevel(data);

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
        return Colors.blueGrey;
    }
  }

  CollectionReference<Map<String, dynamic>> _categoriesRef(String companyId) {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('inventory_categories');
  }

  Future<List<_CategoryMaster>> _loadCategoryMaster(String companyId) async {
    final categorySnap = await _categoriesRef(
      companyId,
    ).orderBy('nameLower').get();

    final List<_CategoryMaster> result = [];

    for (final catDoc in categorySnap.docs) {
      final catData = catDoc.data();
      final catName = (catData['name'] ?? '').toString();

      final subSnap = await _categoriesRef(
        companyId,
      ).doc(catDoc.id).collection('subcategories').orderBy('nameLower').get();

      final subs = subSnap.docs.map((s) {
        final d = s.data();
        return _SubcategoryMaster(id: s.id, name: (d['name'] ?? '').toString());
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
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Product', style: TextStyle(fontSize: 16)),
            content: Text(
              'Are you sure you want to delete "$productName"?\n\nThis action cannot be undone.',
              style: const TextStyle(fontSize: 14),
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

  void _showFilterSheet({
    required List<String> categoryOptions,
    required List<String> subcategoryOptions,
    required Map<String, List<String>> subcategoryMap,
    required List<String> natureOptions,
    required List<String> familyOptions,
    required List<String> machineTypeOptions,
    required List<String> makeOptions,
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
    String tempMake = _makeFilter;
    String tempAccessoryGroup = _accessoryGroupFilter;
    String tempSpareGroup = _spareGroupFilter;
    String tempCompatibility = _compatibilityFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final availableSubs = tempCategory == 'all'
                ? subcategoryOptions
                : (subcategoryMap[tempCategory] ?? []);

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Advanced Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'A. Product Classification',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempNature,
                                    decoration: InputDecoration(
                                      labelText: 'Product Nature',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Natures',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...natureOptions.map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempNature = value ?? 'all',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempFamily,
                                    decoration: InputDecoration(
                                      labelText: 'Product Family',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Families',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...familyOptions.map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempFamily = value ?? 'all',
                                    ),
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
                                    decoration: InputDecoration(
                                      labelText: 'Category',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Categories',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...categoryOptions.map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
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
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempSubcategory,
                                    decoration: InputDecoration(
                                      labelText: 'Subcategory',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Subcategories',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...availableSubs.map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempSubcategory = value ?? 'all',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              'B. Machine Structure',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempMachineType,
                                    decoration: InputDecoration(
                                      labelText: 'Machine Series',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Series',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...machineTypeOptions.map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempMachineType = value ?? 'all',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempMake,
                                    decoration: InputDecoration(
                                      labelText: 'Manufacturer',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Manufacturers',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...makeOptions.map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempMake = value ?? 'all',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              'C. Compatibility Mapping',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempAccessoryGroup,
                                    decoration: InputDecoration(
                                      labelText: 'Accessory Group',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Acc. Groups',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...accessoryGroupOptions.map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempAccessoryGroup = value ?? 'all',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempSpareGroup,
                                    decoration: InputDecoration(
                                      labelText: 'Spare Group',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Spare Groups',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...spareGroupOptions.map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempSpareGroup = value ?? 'all',
                                    ),
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
                                    decoration: InputDecoration(
                                      labelText: 'Compatibility Status',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'has_compatibility',
                                        child: Text(
                                          'Compatible',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'no_compatibility',
                                        child: Text(
                                          'No Compatibility',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempCompatibility = value ?? 'all',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              'D. Inventory Controls',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempStatus,
                                    decoration: InputDecoration(
                                      labelText: 'Product Status',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Status',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'active',
                                        child: Text(
                                          'Active',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'inactive',
                                        child: Text(
                                          'Inactive',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempStatus = value ?? 'all',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: tempStock,
                                    decoration: InputDecoration(
                                      labelText: 'Inventory Status',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'all',
                                        child: Text(
                                          'All Stock',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'in_stock',
                                        child: Text(
                                          'In Stock',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'low_stock',
                                        child: Text(
                                          'Low Stock',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'out_of_stock',
                                        child: Text(
                                          'Out of Stock',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) => modalSetState(
                                      () => tempStock = value ?? 'all',
                                    ),
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
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'all';
                                _stockFilter = 'all';
                                _categoryFilter = 'all';
                                _subcategoryFilter = 'all';
                                _natureFilter = 'all';
                                _familyFilter = 'all';
                                _machineTypeFilter = 'all';
                                _makeFilter = 'all';
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
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _statusFilter = tempStatus;
                                _stockFilter = tempStock;
                                _categoryFilter = tempCategory;
                                _subcategoryFilter = tempSubcategory;
                                _natureFilter = tempNature;
                                _familyFilter = tempFamily;
                                _machineTypeFilter = tempMachineType;
                                _makeFilter = tempMake;
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
            style: const TextStyle(fontSize: 16),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: categoryId == null
                  ? 'Category Name'
                  : 'Subcategory Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
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
                    await _categoriesRef(
                      companyId,
                    ).doc(categoryId).collection('subcategories').add({
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
          title: const Text('Rename Category', style: TextStyle(fontSize: 16)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
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
                  final subsSnap = await catRef
                      .collection('subcategories')
                      .get();
                  for (final subDoc in subsSnap.docs) {
                    batch.update(subDoc.reference, {'categoryName': name});
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
          title: const Text(
            'Rename Subcategory',
            style: TextStyle(fontSize: 16),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Subcategory Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
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
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(title, style: const TextStyle(fontSize: 16)),
              content: Text(message, style: const TextStyle(fontSize: 14)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    final byId = await productsRef
        .where('categoryId', isEqualTo: categoryId)
        .get();
    if (byId.docs.any((d) => d.data()['isDeleted'] != true)) return true;

    final byName = await productsRef
        .where('category', isEqualTo: categoryName)
        .get();
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

    final byId = await productsRef
        .where('subcategoryId', isEqualTo: subcategoryId)
        .get();
    if (byId.docs.any((d) => d.data()['isDeleted'] != true)) return true;

    final byName = await productsRef
        .where('subcategory', isEqualTo: subcategoryName)
        .get();
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

      final subsSnap = await _categoriesRef(
        companyId,
      ).doc(categoryId).collection('subcategories').get();

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

      await _categoriesRef(
        companyId,
      ).doc(categoryId).collection('subcategories').doc(subcategoryId).delete();

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
        final dialogWidth = MediaQuery.of(context).size.width > 900
            ? 820.0
            : MediaQuery.of(context).size.width * 0.95;

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: dialogWidth,
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
                          fontSize: 16,
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
                        size: 16,
                      ),
                      label: const Text(
                        'New Category',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _categoriesRef(
                      companyId,
                    ).orderBy('nameLower').snapshots(),
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
                        return const Center(
                          child: Text(
                            'No categories yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final categoryName = (data['name'] ?? '').toString();

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FBFD),
                              borderRadius: BorderRadius.circular(8),
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
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        categoryName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
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
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Add Subcategory',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      iconSize: 18,
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
                                          height: 32,
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                            ),
                                            title: Text(
                                              'Rename',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          height: 32,
                                          child: ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                              size: 16,
                                            ),
                                            title: Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
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
                                          padding: EdgeInsets.only(left: 26),
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
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
                                          padding: EdgeInsets.only(left: 26),
                                          child: Text(
                                            'No subcategories',
                                            style: TextStyle(
                                              color: Color(0xFF667085),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 26,
                                        ),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: subs.map((s) {
                                            final subData = s.data();
                                            final subName =
                                                (subData['name'] ?? '')
                                                    .toString();

                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE4E7EC,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .subdirectory_arrow_right,
                                                    size: 12,
                                                    color: Color(0xFF667085),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    subName,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  PopupMenuButton<String>(
                                                    padding: EdgeInsets.zero,
                                                    iconSize: 14,
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
                                                                companyId:
                                                                    companyId,
                                                                categoryId:
                                                                    doc.id,
                                                                subcategoryId:
                                                                    s.id,
                                                                subcategoryName:
                                                                    subName,
                                                              ),
                                                        );
                                                      }
                                                    },
                                                    itemBuilder: (context) => const [
                                                      PopupMenuItem(
                                                        value: 'rename',
                                                        height: 32,
                                                        child: ListTile(
                                                          dense: true,
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          leading: Icon(
                                                            Icons.edit_outlined,
                                                            size: 14,
                                                          ),
                                                          title: Text(
                                                            'Rename',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'delete',
                                                        height: 32,
                                                        child: ListTile(
                                                          dense: true,
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          leading: Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: Colors.red,
                                                            size: 14,
                                                          ),
                                                          title: Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                              fontSize: 12,
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

  Widget _iconBoxButton({required IconData icon, required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Icon(icon, size: 18),
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
    required List<String> makeOptions,
    required List<String> accessoryGroupOptions,
    required List<String> spareGroupOptions,

    required int totalProducts,
    required int activeProducts,
    required int lowStockProducts,
    required int outOfStockProducts,
  }) {
    const double rowHeight = 36;

    final categoryButton = canCreate
        ? SizedBox(
            height: rowHeight,
            child: OutlinedButton.icon(
              onPressed: () => _showCategoryManager(
                companyId: companyId,
                currentUserUid: currentUserUid,
              ),
              icon: const Icon(Icons.create_new_folder_outlined, size: 14),
              label: const Text('Categories', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF111827),
                side: const BorderSide(color: Color(0xFFE4E7EC)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final statsText = Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Color(0xFF475467),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        children: [
          const TextSpan(text: 'Products: '),
          TextSpan(
            text: '$totalProducts  |  ',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(text: 'Active: '),
          TextSpan(
            text: '$activeProducts  |  ',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(text: 'Low Stock: '),
          TextSpan(
            text: '$lowStockProducts  |  ',
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const TextSpan(text: 'OOS: '),
          TextSpan(
            text: '$outOfStockProducts',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final innerContent = Row(
      children: [
        SizedBox(width: 260, height: rowHeight, child: _searchField()),
        const SizedBox(width: 8),
        SizedBox(
          width: rowHeight,
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
              makeOptions: makeOptions,
              accessoryGroupOptions: accessoryGroupOptions,
              spareGroupOptions: spareGroupOptions,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (canCreate) ...[categoryButton, const SizedBox(width: 8)],
        SizedBox(
          width: rowHeight,
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
        if (isWide) const Spacer() else const SizedBox(width: 12),
        statsText,
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search products, SKU, machine series...',
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: const Icon(Icons.search, size: 16),
        suffixIcon: _searchText.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchText = '';
                  });
                },
              ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2563EB)),
        ),
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    final chips = <Widget>[];

    if (_statusFilter != 'all') {
      chips.add(
        _filterChip('Product Status: ${_formatFilterLabel(_statusFilter)}', () {
          setState(() => _statusFilter = 'all');
        }),
      );
    }
    if (_stockFilter != 'all') {
      chips.add(
        _filterChip('Inventory: ${_formatFilterLabel(_stockFilter)}', () {
          setState(() => _stockFilter = 'all');
        }),
      );
    }
    if (_natureFilter != 'all') {
      chips.add(
        _filterChip('Nature: $_natureFilter', () {
          setState(() => _natureFilter = 'all');
        }),
      );
    }
    if (_machineTypeFilter != 'all') {
      chips.add(
        _filterChip('Series: $_machineTypeFilter', () {
          setState(() => _machineTypeFilter = 'all');
        }),
      );
    }
    if (_makeFilter != 'all') {
      chips.add(
        _filterChip('Manufacturer: $_makeFilter', () {
          setState(() => _makeFilter = 'all');
        }),
      );
    }
    if (_categoryFilter != 'all') {
      chips.add(
        _filterChip('Category: $_categoryFilter', () {
          setState(() {
            _categoryFilter = 'all';
            _subcategoryFilter = 'all';
          });
        }),
      );
    }
    if (_subcategoryFilter != 'all') {
      chips.add(
        _filterChip('Subcategory: $_subcategoryFilter', () {
          setState(() => _subcategoryFilter = 'all');
        }),
      );
    }
    if (_compatibilityFilter != 'all') {
      chips.add(
        _filterChip(
          'Compatibility: ${_formatFilterLabel(_compatibilityFilter)}',
          () {
            setState(() => _compatibilityFilter = 'all');
          },
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _filterChip(String text, VoidCallback onDeleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF1D4ED8)),
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
    required Map<String, String> subcategoryNameCache,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: docs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'No products found for the selected filters.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Try:\n• Changing filter criteria\n• Clearing filters\n• Searching different keywords',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
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
              subcategoryNameCache: subcategoryNameCache,
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
              subcategoryNameCache: subcategoryNameCache,
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
    required Map<String, String> subcategoryNameCache,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1200),
        child: DataTable(
          dataRowMinHeight: 72,
          dataRowMaxHeight: 110,
          horizontalMargin: 12,
          columnSpacing: 16,
          headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(
              label: Text(
                'Product',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Nature',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Machine / Compatibility Structure',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Manufacturer',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'SKU',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Price',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Stock',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                '',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: docs.map((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString();
            final description = (data['description'] ?? '').toString();
            final make = (data['make'] ?? data['brand'] ?? '').toString();
            final sku = (data['sku'] ?? data['itemCode'] ?? '').toString();
            final price = data['unitPrice'];
            final isActive = _isProductActive(data);
            final stock = _stockOnHand(data);
            final imageUrl = data['imageUrl']?.toString();

            final natureName = natureLabelCache[doc.id] ?? 'Standard';
            final hierarchy = hierarchyCache[doc.id] ?? '—';

            final compatDetails = compatDetailsCache[doc.id] ?? [];
            final int compatCount = compatDetails.length;

            final isAccessory = _isAccessory(
              data['productNatureLower'] ??
                  data['productNature'] ??
                  data['nature'],
            );

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Row(
                      children: [
                        _buildProductAvatar(imageUrl, name, 36),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? '(No name)' : name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
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
                  SizedBox(
                    width: 90,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildNatureBadge(natureName),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hierarchy,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          softWrap: true,
                        ),
                        if (compatCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: () => _showCompatibleModelsDialog(
                                name,
                                compatDetails,
                                isAccessory: isAccessory,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.link_outlined,
                                      size: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        _machineCountLabel(
                                          compatCount,
                                          usedIn: isAccessory,
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
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
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(
                      make.isEmpty ? '—' : make,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 120,
                    child: Text(
                      sku.isEmpty ? '—' : sku,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 100,
                    child: Text(
                      _formatCurrency(price),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Text(
                      _formatNumber(stock),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 90,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildStatusChip(isActive ? 'Active' : 'Inactive'),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 60,
                    child: (canEdit || canDelete)
                        ? PopupMenuButton<String>(
                            tooltip: 'Actions',
                            iconSize: 18,
                            padding: EdgeInsets.zero,
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
                                  height: 32,
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                    title: Text(
                                      'Edit',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              if (canDelete) const PopupMenuDivider(),
                              if (canDelete)
                                const PopupMenuItem(
                                  value: 'delete',
                                  height: 32,
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                    title: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
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
    required Map<String, String> subcategoryNameCache,
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
        final make = (data['make'] ?? data['brand'] ?? '').toString();
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

        final isAccessory = _isAccessory(
          data['productNatureLower'] ?? data['productNature'] ?? data['nature'],
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE6EAF0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductAvatar(imageUrl, name, 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? '(No name)' : name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatCurrency(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (canEdit || canDelete) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
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
                                    productName: name.isEmpty
                                        ? 'Product'
                                        : name,
                                    currentUserUid: firebaseUserUid,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                if (canEdit)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    height: 32,
                                    child: Text(
                                      'Edit',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                if (canDelete)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    height: 32,
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildNatureBadge(natureName),
                        _buildStatusChip(isActive ? 'Active' : 'Inactive'),
                        _buildStockChip(stockStatus),
                        if (stock > 0 || stockStatus == 'Low Stock')
                          Text(
                            '${_formatNumber(stock)} in stock',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475467),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
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
                                child: Icon(
                                  Icons.account_tree_outlined,
                                  size: 12,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  hierarchy,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF344054),
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _pill('Manufacturer', make.isEmpty ? '—' : make),
                              _pill('SKU', sku.isEmpty ? '—' : sku),
                              if (compatCount > 0)
                                InkWell(
                                  onTap: () => _showCompatibleModelsDialog(
                                    name,
                                    compatDetails,
                                    isAccessory: isAccessory,
                                  ),
                                  child: _pill(
                                    isAccessory ? 'Used In' : 'Compatible',
                                    '$compatCount ${compatCount == 1 ? 'Equipment' : 'Equipment'}',
                                    isLink: true,
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String label) {
    final isActive = label == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.10)
            : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.green[800] : Colors.grey[700],
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildStockChip(String label) {
    final color = _stockStatusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _pill(String label, String value, {bool isLink = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLink ? Colors.blue.shade50 : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isLink ? Colors.blue.shade200 : const Color(0xFFE4E7EC),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 10, color: Color(0xFF667085)),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
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
          _productsStream = FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('products')
              .snapshots();
        }

        final bool canCreate = _hasProductPermission(
          userData,
          action: 'create',
        );
        final bool canEdit = _hasProductPermission(userData, action: 'edit');
        final bool canDelete = _hasProductPermission(
          userData,
          action: 'delete',
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FB),

          floatingActionButton: canCreate
              ? FloatingActionButton(
                  key: _fabKey,
                  onPressed: () {
                    _openAddProduct(
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

              final categoryOptions =
                  categoryMasters
                      .where((e) => e.name.trim().isNotEmpty)
                      .map((e) => e.name)
                      .toList()
                    ..sort(
                      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                    );

              final Map<String, List<String>> subcategoryMap = {
                for (final cat in categoryMasters)
                  cat.name:
                      (cat.subcategories..sort(
                            (a, b) => a.name.toLowerCase().compareTo(
                              b.name.toLowerCase(),
                            ),
                          ))
                          .where((s) => s.name.trim().isNotEmpty)
                          .map((s) => s.name)
                          .toList(),
              };

              final subcategoryOptions =
                  categoryMasters
                      .expand((e) => e.subcategories)
                      .map((e) => e.name)
                      .where((e) => e.trim().isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort(
                      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                    );

              final Map<String, String> subcategoryNameCache = {};
              for (final cat in categoryMasters) {
                for (final sub in cat.subcategories) {
                  subcategoryNameCache[sub.id] = sub.name;
                }
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

                  final allDocs =
                      productSnap.data?.docs.where((doc) {
                        final data = doc.data();
                        return data['isDeleted'] != true;
                      }).toList() ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

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
                  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
                  productMapById = {};
                  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
                  productMapByName = {};

                  for (final d in allDocs) {
                    final data = d.data();
                    dataCache[d.id] = data;
                    productMapById[d.id] = d;

                    final name = (data['name'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                    if (name.isNotEmpty) {
                      productMapByName[name] = d;
                    }
                  }

                  // EXTRACT DYNAMIC OPTIONS FOR INDUSTRIAL FILTERS (Auto Sorted Case-Insensitive)
                  final natureOptions =
                      allDocs
                          .map(
                            (d) => _natureLabel(
                              dataCache[d.id]!['productNatureLower'] ??
                                  dataCache[d.id]!['productNature'] ??
                                  dataCache[d.id]!['nature'],
                            ),
                          )
                          .where((e) => e.isNotEmpty && e != 'Standard')
                          .toSet()
                          .toList()
                        ..sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );
                  final familyOptions =
                      allDocs
                          .map(
                            (d) => (dataCache[d.id]!['family'] ?? '')
                                .toString()
                                .trim(),
                          )
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );
                  final machineTypeOptions =
                      allDocs
                          .map(
                            (d) =>
                                (dataCache[d.id]!['machineType'] ??
                                        dataCache[d.id]!['type'] ??
                                        '')
                                    .toString()
                                    .trim(),
                          )
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );
                  final makeOptions =
                      allDocs
                          .map(
                            (d) =>
                                (dataCache[d.id]!['make'] ??
                                        dataCache[d.id]!['brand'] ??
                                        '')
                                    .toString()
                                    .trim(),
                          )
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );
                  final accessoryGroupOptions =
                      allDocs
                          .map(
                            (d) =>
                                (dataCache[d.id]!['accessoryGroupName'] ??
                                        dataCache[d.id]!['accessoryGroup'] ??
                                        '')
                                    .toString()
                                    .trim(),
                          )
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );
                  final spareGroupOptions =
                      allDocs
                          .map(
                            (d) =>
                                (dataCache[d.id]!['spareGroupName'] ??
                                        dataCache[d.id]!['spareGroup'] ??
                                        '')
                                    .toString()
                                    .trim(),
                          )
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(
                          (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                        );

                  // ---------------------------------------------------------
                  // SANITIZE ACTIVE FILTERS (CENTRALIZED)
                  // ---------------------------------------------------------
                  final validSubOptions = _categoryFilter == 'all'
                      ? subcategoryOptions
                      : (subcategoryMap[_categoryFilter] ?? []);
                  _sanitizeActiveFilters(
                    categoryOptions: categoryOptions,
                    validSubOptions: validSubOptions,
                    natureOptions: natureOptions,
                    machineTypeOptions: machineTypeOptions,
                    familyOptions: familyOptions,
                    makeOptions: makeOptions,
                    accessoryGroupOptions: accessoryGroupOptions,
                    spareGroupOptions: spareGroupOptions,
                  );

                  // CACHED COLLECTIONS TO AVOID REPEATED PARSING
                  final Map<String, List<Map<String, String>>>
                  compatDetailsCache = {};
                  final Map<String, String> hierarchyCache = {};
                  final Map<String, String> natureLabelCache = {};

                  final filteredDocs = allDocs.where((doc) {
                    final data = dataCache[doc.id]!;

                    final compatDetails = _resolveCompatibleMachines(
                      data,
                      productMapById,
                      productMapByName,
                    );
                    final compatCount = compatDetails.length;

                    final hierarchy = _machineHierarchy(
                      data,
                      compatCount,
                      subcategoryNameCache,
                    );
                    final natureLabel = _natureLabel(
                      data['productNatureLower'] ??
                          data['productNature'] ??
                          data['nature'],
                    );

                    compatDetailsCache[doc.id] = compatDetails;
                    hierarchyCache[doc.id] = hierarchy;
                    natureLabelCache[doc.id] = natureLabel;

                    return _matchesSearch(
                          data,
                          compatDetails,
                          hierarchy,
                          natureLabel,
                        ) &&
                        _matchesStatusFilter(data) &&
                        _matchesStockFilter(data) &&
                        _matchesCategoryFilter(data) &&
                        _matchesSubcategoryFilter(data) &&
                        _matchesIndustrialFilters(data, compatCount);
                  }).toList();

                  final totalProducts = allDocs.length;
                  final activeProducts = allDocs
                      .where((e) => _isProductActive(dataCache[e.id]!))
                      .length;

                  final lowStockProducts = allDocs.where((e) {
                    final data = dataCache[e.id]!;
                    final stock = _stockOnHand(data);
                    final threshold = _minStockLevel(data) > 0
                        ? _minStockLevel(data)
                        : _reorderLevel(data);
                    return stock > 0 && threshold > 0 && stock <= threshold;
                  }).length;

                  final outOfStockProducts = allDocs
                      .where((e) => _stockOnHand(dataCache[e.id]!) <= 0)
                      .length;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 768;
                      final allowTableView = constraints.maxWidth >= 1100;
                      final effectiveTableView = allowTableView
                          ? _showTableView
                          : false;
                      final activeFiltersBar = _buildActiveFiltersBar();
                      final hasFilters = activeFiltersBar is! SizedBox;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
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
                              makeOptions: makeOptions,
                              accessoryGroupOptions: accessoryGroupOptions,
                              spareGroupOptions: spareGroupOptions,
                              totalProducts: totalProducts,
                              activeProducts: activeProducts,
                              lowStockProducts: lowStockProducts,
                              outOfStockProducts: outOfStockProducts,
                            ),
                            if (hasFilters) ...[
                              const SizedBox(height: 8),
                              activeFiltersBar,
                            ],
                            const SizedBox(height: 8),
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
                              showTable: effectiveTableView,
                              subcategoryNameCache: subcategoryNameCache,
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

  _SubcategoryMaster({required this.id, required this.name});
}
