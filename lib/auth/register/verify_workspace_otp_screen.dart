import 'package:flutter/material.dart';

import 'register_workspace_service.dart';

const Color _otpPrimary = Color(0xFF17324D);
const Color _otpAccent = Color(0xFF3B82F6);
const Color _otpBg = Color(0xFFF4F7FB);
const Color _otpBorder = Color(0xFFE2E8F0);
const Color _otpMuted = Color(0xFF64748B);
const Color _otpText = Color(0xFF0F172A);

class VerifyWorkspaceOtpScreen extends StatefulWidget {
  final String registrationId;
  final String businessEmail;
  final String entityName;

  const VerifyWorkspaceOtpScreen({
    super.key,
    required this.registrationId,
    required this.businessEmail,
    required this.entityName,
  });

  @override
  State<VerifyWorkspaceOtpScreen> createState() =>
      _VerifyWorkspaceOtpScreenState();
}

class _VerifyWorkspaceOtpScreenState extends State<VerifyWorkspaceOtpScreen> {
  final RegisterWorkspaceService _service = RegisterWorkspaceService();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showSnack('Enter a valid 6-digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _service.verifyWorkspaceOtpAndCreateWorkspace(
        registrationId: widget.registrationId,
        otp: otp,
      );

      if (!mounted) return;

      _showSnack('Business email verified successfully');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack(
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);

    try {
      await _service.sendWorkspaceOtp(
        registrationId: widget.registrationId,
      );
      _showSnack('OTP sent again to ${widget.businessEmail}');
    } catch (e) {
      _showSnack(
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _otpBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _otpText,
        elevation: 0,
        title: const Text(
          'Verify Business Email',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _otpBorder),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _otpBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D0F172A),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verify your business email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _otpText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a 6-digit verification code to ${widget.businessEmail} for ${widget.entityName}. Enter the OTP below to complete workspace creation.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _otpMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Email OTP',
                      hintText: 'Enter 6-digit OTP',
                      counterText: '',
                      prefixIcon: const Icon(Icons.password_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _otpBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _otpBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _otpAccent, width: 1.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _otpPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.3,
                        ),
                      )
                          : const Text(
                        'Verify & Create Workspace',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _isResending ? null : _resendOtp,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _otpBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isResending
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _otpText,
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
    );
  }
}