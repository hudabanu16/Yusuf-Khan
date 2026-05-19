import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/shell/quik_shell.dart';
import 'package:QUIK/auth/login/login_screen.dart';
import 'package:QUIK/modules/administration/company/screen_join_company.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, authSnap) {
        // 1. Await Firebase Auth resolution
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 3,
              ),
            ),
          );
        }

        // 2. User is logged out
        if (!authSnap.hasData || authSnap.data == null) {
          return const LoginScreen();
        }

        // 3. User is logged in.
        // 🚨 CRITICAL FIX: The ValueKey ensures that if a new user logs in,
        // the old state is completely destroyed and we fetch fresh data.
        // This stops the "Context Bleed" where Workspace B uses Workspace A's cache.
        return _WorkspaceGate(
          key: ValueKey(authSnap.data!.uid),
          firebaseUser: authSnap.data!,
        );
      },
    );
  }
}

class _WorkspaceGate extends StatefulWidget {
  final User firebaseUser;

  const _WorkspaceGate({super.key, required this.firebaseUser});

  @override
  State<_WorkspaceGate> createState() => _WorkspaceGateState();
}

class _WorkspaceGateState extends State<_WorkspaceGate> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadWorkspaceContextWithRetry();
  }

  // Fallback protection: If the widget updates with a new user while mounted
  @override
  void didUpdateWidget(covariant _WorkspaceGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.firebaseUser.uid != widget.firebaseUser.uid) {
      _loadWorkspaceContextWithRetry();
    }
  }

  Future<void> _loadWorkspaceContextWithRetry() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final uid = widget.firebaseUser.uid;

      // Retry logic for newly created accounts syncing to Firestore
      for (int i = 0; i < 8; i++) {
        final doc = await firestore.collection('users').doc(uid).get();

        if (doc.exists && doc.data() != null) {
          final userData = doc.data()!;

          if (!mounted) return;
          setState(() {
            _data = userData;
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
        _error = 'Workspace profile not found. Please contact your administrator.';
      });
    } catch (e) {
      debugPrint('[AUTH WRAPPER] Failed to load user profile: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load user context safely.\n$e';
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
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Securing Workspace...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_outlined, size: 54, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign Out & Switch Account'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data!;

    // 1. Check Active Status
    final isActive = data['isActive'] ?? true;
    if (isActive != true) {
      Future.microtask(() async {
        await FirebaseAuth.instance.signOut();
      });

      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Your account is inactive.\nPlease contact your workspace admin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    // 2. Dynamic Company ID Extraction
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

    // 3. Fallback Mapping
    final role = (data['role'] ?? 'sales').toString();
    final companyName = (data['companyName'] ?? widget.firebaseUser.email ?? 'Workspace').toString();
    final permissions = Map<String, dynamic>.from(data['permissions'] ?? {});
    final userDisplayName = (data['fullName'] ??
        data['name'] ??
        data['employeeName'] ??
        data['displayName'] ??
        'ERP User')
        .toString();

    // 4. Missing Workspace Handler
    if (companyId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(
                      Icons.domain_disabled_outlined,
                      size: 32,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Active Workspace',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account is valid, but it is not currently linked to any active company workspace.',
                    style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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
                        _loadWorkspaceContextWithRetry();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Join Existing Company',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600),
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

    // 5. Direct Routing to ERP Shell
    // 🚨 CRITICAL FIX: Adding a Key to ZohoShell using UID + CompanyID
    // forces the Shell and ALL its sub-modules to physically unmount and rebuild
    // entirely from scratch if the user switches accounts.
    return ZohoShell(
      key: ValueKey('${widget.firebaseUser.uid}_$companyId'),
      userEmail: widget.firebaseUser.email ?? 'user@workspace.com',
      userUid: widget.firebaseUser.uid,
      companyId: companyId,
      companyName: companyName,
      role: role,
      permissions: permissions,
      userDisplayName: userDisplayName,
    );
  }
}