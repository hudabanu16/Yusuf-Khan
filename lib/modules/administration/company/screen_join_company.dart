import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/company/join_company/join_company_constants.dart';
import 'package:QUIK/modules/administration/company/join_company/join_company_input_decoration.dart';
import 'package:QUIK/modules/administration/company/join_company/join_company_validators.dart';
import 'package:QUIK/modules/administration/company/join_company/join_company_widgets.dart';
import 'package:QUIK/modules/administration/company/screen_join_company_otp.dart'
    show ScreenJoinCompanyOtp;
import 'package:QUIK/modules/administration/company/services/join_company_service.dart';

part 'join_company/join_company_sections.dart';

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

  void _togglePasswordVisibility() {
    setState(() {
      obscurePassword = !obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      obscureConfirmPassword = !obscureConfirmPassword;
    });
  }

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
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: JoinCompanyPanel(
                  child: AbsorbPointer(
                    absorbing: isLoading,
                    child: Form(key: _formKey, child: _buildJoinCompanyForm()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
