import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/company/screen_join_company_otp.dart';
import 'package:QUIK/modules/administration/company/services/join_company_service.dart';

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
  final JoinCompanyService _joinService = JoinCompanyService();

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

  String _friendlyError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'Unable to continue. Please try again.';
    }

    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }

    return message;
  }

  Future<void> _joinCompany() async {
    if (isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final inviteCode = inviteCodeController.text.trim().toUpperCase();
    final fullName = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (inviteCode.isEmpty) {
      _showError('Please enter invite code');
      return;
    }

    if (fullName.isEmpty) {
      _showError('Full name is required');
      return;
    }

    if (email.isEmpty) {
      _showError('Email is required');
      return;
    }

    if (password.isEmpty) {
      _showError('Password is required');
      return;
    }

    if (confirmPassword.isEmpty) {
      _showError('Please confirm password');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => isLoading = true);

    try {
      final draftId = await _joinService.createJoinRequestDraft(
        inviteCode: inviteCode,
        fullName: fullName,
        email: email,
      );

      if (!mounted) return;

      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ScreenJoinCompanyOtp(
            draftId: draftId,
            email: email,
            fullName: fullName,
            password: password,
          ),
        ),
      );

      if (verified == true) {
        _showSuccess('Email verified and company joined successfully');
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError(_friendlyError(e));
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
    return PopScope(
      canPop: !isLoading,
      child: Scaffold(
        backgroundColor: pageBgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: primaryColor),
          ),
          title: const Text(
            'Join Existing Company',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: borderColor),
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
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: AbsorbPointer(
                      absorbing: isLoading,
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
                            const Text(
                              'This is a one-time company joining process. Verify your employee email by OTP, create your login, and then use only email and password for future sign-ins.',
                              style: TextStyle(
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
                                      color: primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.apartment_outlined,
                                      color: primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'One-Time Employee Onboarding',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: primaryColor,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Use the invite code shared by your company admin. OTP will be sent to your employee email before your account is created.',
                                          style: TextStyle(
                                            color: mutedTextColor,
                                            fontSize: 13,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Employee Details',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'These credentials will become your permanent login after successful OTP verification.',
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
                                label: 'Employee Email',
                                hint: 'e.g. bilal@company.com',
                                icon: Icons.email_outlined,
                              ),
                              validator: (value) {
                                final email = (value ?? '').trim();
                                if (email.isEmpty) {
                                  return 'Email is required';
                                }
                                final emailRegex = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                );
                                if (!emailRegex.hasMatch(email)) {
                                  return 'Enter a valid email';
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
                                if (value == null || value.isEmpty) {
                                  return 'Password is required';
                                }
                                if (value.length < 6) {
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
                                final confirmValue = value ?? '';
                                if (confirmValue.isEmpty) {
                                  return 'Please confirm password';
                                }
                                if (confirmValue != passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
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
                                      'OTP will be sent to the employee email entered above. After successful verification, your account will be created and attached to the company. Later, you will use only email and password to login.',
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
                                    : const Text(
                                        'Send OTP & Continue',
                                        style: TextStyle(
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
