import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();

  static const String _usersBoxName = 'genzprotech_users';
  static const String _quotationsBoxName = 'genzprotech_quotations';
  static const String _currentUserKey = 'currentUserId';

  bool _initialized = false;
  Box? _usersBox;
  Box? _quotationsBox;

  LocalDatabase._init();

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Hive for Flutter with proper path
      await Hive.initFlutter();

      // Open boxes
      _usersBox = await Hive.openBox(_usersBoxName);
      _quotationsBox = await Hive.openBox(_quotationsBoxName);

      _initialized = true;
      debugPrint('✅ LocalDatabase initialized successfully');
      debugPrint('📦 Users in database: ${_usersBox!.length}');
      debugPrint('📄 Quotations in database: ${_quotationsBox!.length}');
    } catch (e) {
      debugPrint('❌ Error initializing database: $e');
      rethrow;
    }
  }

  Box get _users {
    if (_usersBox == null || !_usersBox!.isOpen) {
      throw Exception('Users box not initialized. Call initialize() first.');
    }
    return _usersBox!;
  }

  Box get _quotations {
    if (_quotationsBox == null || !_quotationsBox!.isOpen) {
      throw Exception('Quotations box not initialized. Call initialize() first.');
    }
    return _quotationsBox!;
  }

  // USER OPERATIONS
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    await initialize();

    debugPrint('🔍 Attempting login for: $email');
    debugPrint('📦 Total users: ${_users.length}');

    // Search through all users
    for (var key in _users.keys) {
      try {
        final userData = Map<String, dynamic>.from(_users.get(key) as Map);
        debugPrint('👤 Checking user: ${userData['email']}');

        if (userData['email'] == email && userData['password'] == password) {
          debugPrint('✅ Login successful!');
          await _saveCurrentUserId(userData['id']);
          return userData;
        }
      } catch (e) {
        debugPrint('⚠️ Error reading user $key: $e');
        continue;
      }
    }

    debugPrint('❌ No matching user found');
    return null;
  }

  Future<int> registerUser({
    required String email,
    required String password,
    required String companyName,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    String? gstin,
    String? pan,
    String? website,
    String? logoUrl, // NEW: store company logo URL
  }) async {
    await initialize();

    debugPrint('📝 Attempting to register: $email');

    // Check if email exists
    for (var key in _users.keys) {
      try {
        final userData = Map<String, dynamic>.from(_users.get(key) as Map);
        if (userData['email'] == email) {
          debugPrint('❌ Email already registered');
          throw Exception('Email already registered');
        }
      } catch (e) {
        if (e.toString().contains('Email already registered')) rethrow;
        continue;
      }
    }

    // Generate new user ID as timestamp
    final userId = DateTime.now().millisecondsSinceEpoch;

    // Use String key for Hive (web compatibility)
    final userKey = 'user_$userId';

    final userData = {
      'id': userId,
      'email': email,
      'password': password,
      'companyName': companyName,
      'address': address ?? '',
      'city': city ?? '',
      'state': state ?? '',
      'pincode': pincode ?? '',
      'phone': phone ?? '',
      'gstin': gstin ?? '',
      'pan': pan ?? '',
      'website': website ?? '',
      'logoUrl': logoUrl ?? '', // NEW: saved logo url if available
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _users.put(userKey, userData);
    await _saveCurrentUserId(userId);

    debugPrint('✅ User registered successfully: $userKey');
    debugPrint('📦 Total users now: ${_users.length}');

    return userId;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    await initialize();

    final userId = await _getCurrentUserId();
    if (userId == null) {
      debugPrint('⚠️ No current user ID found');
      return null;
    }

    final userKey = 'user_$userId';
    debugPrint('🔍 Looking for user: $userKey');

    final userData = _users.get(userKey);
    if (userData != null) {
      debugPrint('✅ Current user found: ${(userData as Map)['email']}');
      return Map<String, dynamic>.from(userData);
    }

    debugPrint('❌ User not found in database');
    return null;
  }

  Future<void> updateUser(int userId, Map<String, dynamic> data) async {
    await initialize();

    final userKey = 'user_$userId';
    final currentUser = _users.get(userKey);
    if (currentUser != null) {
      final updatedUser = Map<String, dynamic>.from(currentUser as Map);
      updatedUser.addAll(data);
      updatedUser['updatedAt'] = DateTime.now().toIso8601String();
      await _users.put(userKey, updatedUser);
      debugPrint('✅ User updated: $userKey');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    debugPrint('👋 User logged out');
  }

  // QUOTATION OPERATIONS
  Future<int> createQuotation({
    required int userId,
    required String quoteNumber,
    required String clientName,
    required DateTime date,
    required String status,
    required double taxRate,
    required double discountPercentage,
    required double calculatedTotal,
    required List<Map<String, dynamic>> items,
  }) async {
    await initialize();

    final quotationId = DateTime.now().millisecondsSinceEpoch;

    // Use String key for Hive (web compatibility)
    final quotationKey = 'quote_$quotationId';

    final quotationData = {
      'id': quotationId,
      'userId': userId,
      'quoteNumber': quoteNumber,
      'clientName': clientName,
      'date': date.toIso8601String(),
      'status': status,
      'taxRate': taxRate,
      'discountPercentage': discountPercentage,
      'calculatedTotal': calculatedTotal,
      'items': jsonEncode(items),
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _quotations.put(quotationKey, quotationData);
    debugPrint('✅ Quotation created: $quotationKey');
    debugPrint('📄 Total quotations now: ${_quotations.length}');

    return quotationId;
  }

  Future<List<Map<String, dynamic>>> getQuotations(int userId) async {
    await initialize();

    final userQuotations = <Map<String, dynamic>>[];

    for (var key in _quotations.keys) {
      try {
        final quotationData =
        Map<String, dynamic>.from(_quotations.get(key) as Map);
        if (quotationData['userId'] == userId) {
          quotationData['items'] = jsonDecode(quotationData['items']);
          userQuotations.add(quotationData);
        }
      } catch (e) {
        debugPrint('⚠️ Error reading quotation $key: $e');
        continue;
      }
    }

    // Sort by date (newest first)
    userQuotations.sort((a, b) {
      final dateA = DateTime.parse(a['date']);
      final dateB = DateTime.parse(b['date']);
      return dateB.compareTo(dateA);
    });

    debugPrint('📄 Found ${userQuotations.length} quotations for user $userId');
    return userQuotations;
  }

  Future<void> deleteQuotation(int quotationId) async {
    await initialize();
    final quotationKey = 'quote_$quotationId';
    await _quotations.delete(quotationKey);
    debugPrint('🗑️ Quotation deleted: $quotationKey');
  }

  // HELPER METHODS
  Future<void> _saveCurrentUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentUserKey, userId);
    debugPrint('💾 Current user ID saved: $userId');
  }

  Future<int?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_currentUserKey);
    debugPrint('🔑 Current user ID: $userId');
    return userId;
  }

  Future<void> clearAllData() async {
    await initialize();
    await _users.clear();
    await _quotations.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    debugPrint('🗑️ All data cleared');
  }

  // DEBUG METHOD
  Future<void> printAllData() async {
    await initialize();
    debugPrint('\n📊 === DATABASE DEBUG INFO ===');
    debugPrint('Users Box: ${_users.length} entries');
    for (var key in _users.keys) {
      final user = _users.get(key);
      debugPrint('  $key: ${(user as Map)['email']}');
    }
    debugPrint('Quotations Box: ${_quotations.length} entries');
    debugPrint('=== END DEBUG INFO ===\n');
  }
}
