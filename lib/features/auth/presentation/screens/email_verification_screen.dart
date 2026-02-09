import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';
import 'package:ordermate/core/services/email_service.dart';
import 'package:pinput/pinput.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> onboardingData;

  const EmailVerificationScreen({super.key, required this.onboardingData});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _isSending = false;
  String? _generatedOtp;
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _sendOtp());
  }

  Future<void> _sendOtp() async {
    setState(() => _isSending = true);

    // Get email from onboarding data.
    // It might be in 'userData' which was passed from RegisterScreen
    final email = widget.onboardingData['email'] ??
        widget.onboardingData['userData']?['email'];

    if (email == null) {
      debugPrint(
          'Error: Email not found in onboarding data: ${widget.onboardingData}');
      setState(() => _isSending = false);
      return;
    }

    _generatedOtp = (1000 + Random().nextInt(9000)).toString();

    try {
      bool sent = await EmailService().sendOtpEmail(email, _generatedOtp!);
      if (mounted) {
        if (sent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Verification code sent to your email'),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to send verification email'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending OTP: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyAndFinish() async {
    if (_otpController.text != _generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid verification code'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orgId = widget.onboardingData['orgId'];
      final storeId = widget.onboardingData['storeId'];
      final teamMembers =
          widget.onboardingData['teamMembers'] as List<dynamic>?;

      // 1. Save team members if any
      if (teamMembers != null) {
        for (var member in teamMembers) {
          await SupabaseConfig.client.from('omtbl_businesspartners').insert({
            'name': member['name'],
            'email': member['email']!.isEmpty ? null : member['email'],
            'phone': member['phone']!,
            'is_employee': 1,
            'organization_id': orgId,
            'store_id': storeId,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // 2. Clear onboarding state or whatever is needed
      // (Optional: perform any final verification flags in DB)

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Registration Complete!',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            content: const Text(
                'Your email has been verified and your account is ready.',
                style: TextStyle(color: Colors.black87)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.go('/login');
                },
                child: const Text('Login Now',
                    style: TextStyle(
                        color: AppColors.loginGradientStart,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
          fontSize: 22,
          color: AppColors.loginGradientStart,
          fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.loginGradientStart, AppColors.loginGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const StepIndicator(
                currentStep: 4,
                totalSteps: 5,
                stepLabels: [
                  'Account',
                  'Organization',
                  'Branch',
                  'Team',
                  'Verify'
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.mark_email_read_outlined,
                          size: 80, color: Colors.white),
                      const SizedBox(height: 24),
                      const Text(
                        'Verify Email',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter the 4-digit code sent to\n${widget.onboardingData['email'] ?? widget.onboardingData['userData']?['email'] ?? 'your email'}',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      Center(
                        child: Pinput(
                          controller: _otpController,
                          length: 4,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: defaultPinTheme.copyWith(
                            decoration: defaultPinTheme.decoration!.copyWith(
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                          onCompleted: (pin) => _verifyAndFinish(),
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (_isLoading)
                        const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white))
                      else
                        ElevatedButton(
                          onPressed: _verifyAndFinish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.loginGradientStart,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Verify & Complete',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _isSending ? null : _sendOtp,
                        child: Text(
                          _isSending ? 'Sending...' : 'Resend Code',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
