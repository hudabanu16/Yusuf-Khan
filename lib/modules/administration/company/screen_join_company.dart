import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF2563EB);
const Color pageBgColor = Color(0xFFF5F7FB);
const Color borderColor = Color(0xFFE5E7EB);
const Color mutedTextColor = Color(0xFF6B7280);
const Color successColor = Color(0xFF16A34A);

class ScreenJoinCompany extends StatefulWidget {
  const ScreenJoinCompany({super.key});

  @override
  State<ScreenJoinCompany> createState() => _ScreenJoinCompanyState();
}

class _ScreenJoinCompanyState extends State<ScreenJoinCompany> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController inviteCodeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>> _getInviteDoc(
      FirebaseFirestore firestore,
      String code,
      ) async {
    final inviteQuery = await firestore
        .collectionGroup('invites')
        .where('code', isEqualTo: code)
        .where('status', isEqualTo: 'pending')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (inviteQuery.docs.isEmpty) {
      throw Exception('Invalid, inactive, or already used invite code');
    }

    return inviteQuery.docs.first;
  }

  Future<User> _ensureAuthenticatedUser() async {
    final existingUser = FirebaseAuth.instance.currentUser;
    if (existingUser != null) return existingUser;

    final enteredEmail = emailController.text.trim().toLowerCase();
    final enteredPassword = passwordController.text.trim();
    final enteredConfirmPassword = confirmPasswordController.text.trim();

    if (enteredEmail.isEmpty) {
      throw Exception('Email is required');
    }
    if (enteredPassword.isEmpty) {
      throw Exception('Password is required');
    }
    if (enteredConfirmPassword.isEmpty) {
      throw Exception('Please confirm password');
    }
    if (enteredPassword != enteredConfirmPassword) {
      throw Exception('Passwords do not match');
    }
    if (enteredPassword.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: enteredEmail,
      password: enteredPassword,
    );

    final user = cred.user;
    if (user == null) {
      throw Exception('Failed to create employee login');
    }

    return user;
  }

  Future<User> _refreshSignedInUser(User user) async {
    await user.reload();

    User? refreshedUser = FirebaseAuth.instance.currentUser;
    refreshedUser ??= user;

    await refreshedUser.getIdToken(true);
    await Future.delayed(const Duration(milliseconds: 500));

    return refreshedUser;
  }

  Future<void> _joinCompany() async {
    if (!_formKey.currentState!.validate()) return;

    final code = inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showError('Please enter invite code');
      return;
    }

    setState(() => isLoading = true);

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    final authUserBeforeFlow = auth.currentUser;
    User? currentUser;
    bool createdNewUserInThisFlow = false;

    try {
      if (authUserBeforeFlow == null) {
        currentUser = await _ensureAuthenticatedUser();
        createdNewUserInThisFlow = true;
        currentUser = await _refreshSignedInUser(currentUser);
      } else {
        currentUser = await _refreshSignedInUser(authUserBeforeFlow);
      }

      final currentEmail = (currentUser.email ?? '').trim().toLowerCase();

      final inviteDoc = await _getInviteDoc(firestore, code);
      final inviteData = inviteDoc.data();

      final companyRef = inviteDoc.reference.parent.parent;
      if (companyRef == null) {
        throw Exception('Company reference not found');
      }

      final companySnap = await companyRef.get();
      if (!companySnap.exists) {
        throw Exception('Company document not found');
      }

      final companyData = companySnap.data() as Map<String, dynamic>? ?? {};
      final companyName =
      (companyData['companyName'] ?? companyData['name'] ?? '')
          .toString()
          .trim();

      final inviteEmail =
      (inviteData['email'] ?? '').toString().trim().toLowerCase();

      if (inviteEmail.isNotEmpty &&
          currentEmail.isNotEmpty &&
          inviteEmail != currentEmail) {
        throw Exception('This invite belongs to another email');
      }

      final role = (inviteData['role'] ?? 'sales').toString().trim();
      final isAdmin = role == 'admin';
      final inviteName = (inviteData['name'] ?? '').toString().trim();
      final invitePhone = (inviteData['phone'] ?? '').toString().trim();
      final permissions =
      Map<String, dynamic>.from(inviteData['permissions'] ?? {});

      final enteredName = nameController.text.trim();
      final finalName = inviteName.isNotEmpty
          ? inviteName
          : (enteredName.isNotEmpty
          ? enteredName
          : (currentEmail.isNotEmpty ? currentEmail : 'User'));

      final rootUserRef = firestore.collection('users').doc(currentUser.uid);
      final companyUserRef = companyRef.collection('users').doc(currentUser.uid);

      final existingRootUserSnap = await rootUserRef.get();
      if (existingRootUserSnap.exists) {
        final existingData = existingRootUserSnap.data() ?? {};
        final existingCompanyId =
        (existingData['companyId'] ?? '').toString().trim();

        if (existingCompanyId.isNotEmpty && existingCompanyId != companyRef.id) {
          throw Exception(
            'This login is already linked to another company workspace',
          );
        }
      }

      final batch = firestore.batch();

      batch.set(
        rootUserRef,
        {
          'uid': currentUser.uid,
          'companyId': companyRef.id,
          'companyName': companyName,
          'role': role,
          'isAdmin': isAdmin,
          'isActive': true,
          'email': currentUser.email ?? '',
          'name': finalName,
          'phone': invitePhone,
          'permissions': permissions,
          'joinedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        companyUserRef,
        {
          'uid': currentUser.uid,
          'companyId': companyRef.id,
          'companyName': companyName,
          'name': finalName,
          'email': currentUser.email ?? '',
          'phone': invitePhone,
          'role': role,
          'isAdmin': isAdmin,
          'isActive': true,
          'permissions': permissions,
          'joinedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.update(inviteDoc.reference, {
        'status': 'accepted',
        'acceptedByUid': currentUser.uid,
        'acceptedByEmail': currentUser.email ?? '',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      _showSuccess('Joined company successfully');
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg =
          'This email is already registered. Please login first, then join company.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'weak-password':
          msg = 'Password is too weak.';
          break;
        default:
          msg = e.message ?? e.code;
      }

      _showError(msg);
    } catch (e) {
      if (createdNewUserInThisFlow) {
        try {
          final user = auth.currentUser;
          await user?.delete();
        } catch (_) {}
      }

      _showError(e.toString().replaceAll('Exception: ', ''));
      debugPrint('JOIN COMPANY ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    inviteCodeController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentEmail = currentUser?.email ?? '';
    final isLoggedIn = currentUser != null;

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: primaryColor),
        ),
        title: const Text(
          'Join Existing Company',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: borderColor,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Join Your Company Workspace',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLoggedIn
                              ? 'You are already logged in. Enter the invite code shared by your company admin to join the workspace.'
                              : 'Create your employee login and use the invite code shared by your company admin to join an existing workspace.',
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: mutedTextColor,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.apartment_outlined,
                                  color: primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Employee / Team Member Access',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Admins create the workspace. Team members create their own login and join it using invite codes.',
                                      style: TextStyle(
                                        color: mutedTextColor,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                    if (currentEmail.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                          BorderRadius.circular(999),
                                          border:
                                          Border.all(color: borderColor),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: accentColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                currentEmail,
                                                style: const TextStyle(
                                                  color: mutedTextColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLoggedIn) ...[
                          const SizedBox(height: 28),
                          const Text(
                            'Create Employee Login',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'These credentials will be your personal login for accessing the company workspace.',
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: nameController,
                            decoration: _inputDecoration(
                              label: 'Full Name',
                              hint: 'e.g. Bilal Khan',
                              icon: Icons.badge_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Full name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              label: 'Email Address',
                              hint: 'e.g. bilal@company.com',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: _inputDecoration(
                              label: 'Password',
                              hint: 'Minimum 6 characters',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Password is required';
                              }
                              if (value.trim().length < 6) {
                                return 'Minimum 6 characters required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: obscureConfirmPassword,
                            decoration: _inputDecoration(
                              label: 'Confirm Password',
                              hint: 'Re-enter password',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscureConfirmPassword =
                                    !obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please confirm password';
                              }
                              if (value.trim() !=
                                  passwordController.text.trim()) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 28),
                        const Text(
                          'Invite Code',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter the code exactly as shared by your company admin.',
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: inviteCodeController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: primaryColor,
                          ),
                          decoration: _inputDecoration(
                            label: 'Invite Code',
                            hint: 'e.g. ABCD1234',
                            icon: Icons.key_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Invite code is required';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!isLoading) {
                              _joinCompany();
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: accentColor,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'If the invite was created for a specific email address, you must use that same email while creating your employee login or while joining the company.',
                                  style: TextStyle(
                                    color: mutedTextColor,
                                    fontSize: 12.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _joinCompany,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : Text(
                              isLoggedIn
                                  ? 'Join Company'
                                  : 'Create Login & Join Company',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Center(
                          child: Text(
                            'Need a new company workspace instead? Go back and choose Create New Workspace.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: accentColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
    );
  }
}