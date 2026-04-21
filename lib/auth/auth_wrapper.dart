import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:QUIK/shell/zoho_shell.dart';
import 'package:QUIK/core/modules/providers/module_access_provider.dart';
import 'package:QUIK/auth/login/login_screen.dart';
import 'package:QUIK/modules/administration/company/screen_join_company.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnap.data == null) {
          // 🔴 FIX: Removed the 'const' keyword here.
          // Note: Standard Dart convention uses PascalCase for classes (LoginScreen).
          // If your class is strictly named login_Screen, change this to: return login_Screen();
          return LoginScreen();
        }

        return _UserProfileGate(firebaseUser: authSnap.data!);
      },
    );
  }
}

class _UserProfileGate extends StatefulWidget {
  final User firebaseUser;

  const _UserProfileGate({required this.firebaseUser});

  @override
  State<_UserProfileGate> createState() => _UserProfileGateState();
}

class _UserProfileGateState extends State<_UserProfileGate> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadUserProfileWithRetry();
  }

  Future<void> _loadUserProfileWithRetry() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final uid = widget.firebaseUser.uid;

      for (int i = 0; i < 8; i++) {
        final doc = await firestore.collection('users').doc(uid).get();

        if (doc.exists && doc.data() != null) {
          if (!mounted) return;
          setState(() {
            _data = doc.data();
            _loading = false;
            _error = null;
          });
          return;
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'User profile not found in database.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load user profile: $e';
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _logout,
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data!;

    final isActive = data['isActive'] ?? true;
    if (isActive != true) {
      Future.microtask(() async {
        await FirebaseAuth.instance.signOut();
      });

      return const Scaffold(
        body: Center(
          child: Text('Your account is inactive. Please contact admin.'),
        ),
      );
    }

    // Dynamic companyId extraction
    String companyId = (data['companyId'] ?? '').toString();
    if (companyId.isEmpty) {
      final companyIds = data['companyIds'];
      if (companyIds is List && companyIds.isNotEmpty) {
        companyId = companyIds.first.toString();
      } else {
        final memberships = data['memberships'];
        if (memberships is Map && memberships.isNotEmpty) {
          companyId = memberships.keys.first.toString();
        }
      }
    }

    final role = (data['role'] ?? 'sales').toString();
    final companyName =
    (data['companyName'] ?? widget.firebaseUser.email ?? 'Workspace').toString();

    final permissions = Map<String, dynamic>.from(data['permissions'] ?? {});

    final userDisplayName = (
        data['fullName'] ??
            data['name'] ??
            data['employeeName'] ??
            data['displayName'] ??
            ''
    ).toString();

    if (companyId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(
                      Icons.group_add_outlined,
                      size: 28,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You are not linked to any company yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join your company using an invite code to access your workspace.',
                    style: TextStyle(color: Colors.grey, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScreenJoinCompany(),
                          ),
                        );

                        if (!mounted) return;
                        setState(() {
                          _loading = true;
                          _error = null;
                          _data = null;
                        });
                        _loadUserProfileWithRetry();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Join Existing Company',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ModuleAccessProvider(
      tenantId: companyId,
      child: ZohoShell(
        userEmail: widget.firebaseUser.email ?? 'user@workspace.com',
        userUid: widget.firebaseUser.uid,
        companyId: companyId,
        companyName: companyName,
        role: role,
        permissions: permissions,
        userDisplayName: userDisplayName,
      ),
    );
  }
}
