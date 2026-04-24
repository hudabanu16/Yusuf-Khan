import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/company/services/join_company_service.dart';

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF2563EB);
const Color pageBgColor = Color(0xFFF5F7FB);
const Color borderColor = Color(0xFFE5E7EB);
const Color mutedTextColor = Color(0xFF6B7280);
const Color successColor = Color(0xFF16A34A);

class ScreenJoinCompanyOtp extends StatefulWidget {
  final String draftId;
  final String email;
  final String fullName;
  final String password;

  const ScreenJoinCompanyOtp({
    super.key,
    required this.draftId,
    required this.email,
    required this.fullName,
    required this.password,
  });

  @override
  State<ScreenJoinCompanyOtp> createState() => _ScreenJoinCompanyOtpState();
}

class _ScreenJoinCompanyOtpState extends State<ScreenJoinCompanyOtp> {
  final JoinCompanyService _joinService = JoinCompanyService();
  final TextEditingController otpController = TextEditingController();

  bool isLoading = false;
  bool isResending = false;

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
      _showError('Enter a valid 6-digit OTP');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _joinService.verifyJoinRequestOtpAndComplete(
        draftId: widget.draftId,
        otp: otp,
        password: widget.password,
      );

      if (!mounted) return;
      _showSuccess('Email verified and company joined successfully');
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => isResending = true);

    try {
      await _joinService.resendJoinRequestOtp(draftId: widget.draftId);
      _showSuccess('OTP sent again to ${widget.email}');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => isResending = false);
      }
    }
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Verify Employee Email',
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
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                padding: const EdgeInsets.all(28),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify your employee email',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a 6-digit verification code to ${widget.email} for ${widget.fullName}. Enter the OTP below to complete joining the company workspace.',
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: mutedTextColor,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: otpController,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Email OTP',
                        hintText: 'Enter 6-digit OTP',
                        counterText: '',
                        prefixIcon: const Icon(Icons.password_outlined),
                        filled: true,
                        fillColor: Colors.white,
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
                          borderSide: BorderSide(
                            color: accentColor,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _verifyOtp,
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
                                'Verify & Join Company',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: isResending ? null : _resendOtp,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Resend OTP',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
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
    );
  }
}
