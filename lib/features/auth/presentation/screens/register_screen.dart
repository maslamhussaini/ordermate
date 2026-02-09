import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:ordermate/core/theme/app_colors.dart';
import 'package:pinput/pinput.dart';

import 'package:ordermate/core/services/email_service.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _mobileNumberWithCode = '';
  String _generatedEmailOtp = ''; // For Email

  // bool _isLoading = false;
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _emailController.addListener(() {
      if (_isEmailVerified) {
        setState(() => _isEmailVerified = false);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await ConnectivityHelper.check();
    if (result.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Offline Mode: Registration requires an internet connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _registerScrollController.dispose();
    super.dispose();
  }

  // Mobile verification logic removed

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email first')),
      );
      return;
    }

    // Generate Email OTP
    _generatedEmailOtp = (1000 + Random().nextInt(9000)).toString();

    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Sending Verification Email..."),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Add a 30 second timeout to prevent infinite spinner
      bool sent = await EmailService()
          .sendOtpEmail(email, _generatedEmailOtp)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        debugPrint('Email sending timed out after 30s');
        return false;
      });

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (sent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email OTP sent! Check your inbox.'),
              backgroundColor: Colors.green,
            ),
          );

          // Small delay to let snackbar be seen before dialog covers it
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showOtpDialog(
                target: 'email',
                otp: _generatedEmailOtp,
                onVerified: () {
                  setState(() => _isEmailVerified = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Email Verified Successfully!')),
                  );
                },
              );
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to send verification email. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showOtpDialog({
    required String target,
    required String otp,
    required VoidCallback onVerified,
  }) {
    final otpController = TextEditingController();
    // final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: AppColors.loginGradientStart,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: Colors.white,
        border: Border.all(color: AppColors.loginGradientStart, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.loginGradientStart.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFFE8F5E9), // Light green success background
        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
      ),
    );

    final followingPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Center(
          child: Text(
            'Verify ${target == 'email' ? 'Email' : 'Mobile'}',
            style: const TextStyle(
              color: Color(0xFF1A1C1E),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please enter the 4-digit OTP sent to your $target',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Pinput(
              controller: otpController,
              length: 4,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              followingPinTheme: followingPinTheme,
              separatorBuilder: (index) => const SizedBox(width: 8),
              onCompleted: (val) {
                if (val == otp) {
                  Navigator.pop(context);
                  onVerified();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Invalid OTP'),
                        backgroundColor: Colors.red),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (otpController.text == otp) {
                      Navigator.pop(context);
                      onVerified();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Invalid OTP'),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.loginGradientStart,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Verify',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Obsolete _verifyOtp method removed as logic is now in _showOtpDialog callback

  void _onNext() {
    if (!_formKey.currentState!.validate()) return;

    // Mobile/Email verification moved to final stage

    // Navigate to Organization Setup
    context.push('/onboarding/organization', extra: {
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'phone': _mobileNumberWithCode,
    });
  }

  final _registerScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'New Account',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
                currentStep: 0,
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
                child: Scrollbar(
                  controller: _registerScrollController,
                  child: SingleChildScrollView(
                    controller: _registerScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Top 3D Icon (Placeholder)
                        Center(
                          child: SizedBox(
                            height: 100,
                            width: 100,
                            child: Image.asset(
                              'assets/icons/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        const Text(
                          'Create Account',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        // Inlined Form Column for better scrolling
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildLabel('Enter the Full Name'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _fullNameController,
                                  hint: 'Full Name',
                                  icon: Icons.person,
                                ),
                                const SizedBox(height: 16),

                                _buildLabel('Enter Mobile Number'),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1.5),
                                        ),
                                        child: IntlPhoneField(
                                          controller: _mobileController,
                                          decoration: const InputDecoration(
                                            hintText: 'Mobile Number',
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 16),
                                            counterText: '',
                                          ),
                                          initialCountryCode:
                                              'PK', // Default to Pakistan as per +92 request
                                          dropdownIconPosition:
                                              IconPosition.trailing,
                                          flagsButtonPadding:
                                              const EdgeInsets.only(left: 8),
                                          disableLengthCheck:
                                              true, // We handle validation loosely or via onChanged
                                          onChanged: (phone) {
                                            _mobileNumberWithCode =
                                                phone.completeNumber;
                                          },
                                          style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.black),
                                        ),
                                      ),
                                    ),
                                    // Mobile verification button removed
                                  ],
                                ),
                                const SizedBox(height: 16),

                                _buildLabel('Enter your Email'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _emailController,
                                        hint: 'example@email.com',
                                        icon: Icons.email,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                _buildLabel('Create New Password'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _passwordController,
                                  hint: 'Password',
                                  icon: Icons.lock,
                                  isPassword: true,
                                ),
                                const SizedBox(height: 16),

                                _buildLabel('Confirm Password'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  hint: 'Confirm Password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  validator: (val) {
                                    if (val != _passwordController.text)
                                      return 'Passwords do not match';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 40),

                                // Create Button
                                ElevatedButton(
                                  onPressed: _onNext,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor:
                                        AppColors.loginGradientStart,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: const Text(
                                    'Next',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account?",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => context.go('/login'),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator:
            validator ?? (val) => val?.isEmpty ?? false ? 'Required' : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.loginGradientStart),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildVerifyButton(
      {required VoidCallback onPressed, required bool isVerified}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isVerified ? Colors.green : Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          isVerified ? Icons.check : Icons.send,
          color: Colors.white,
        ),
        onPressed: isVerified ? null : onPressed,
        tooltip: isVerified ? 'Verified' : 'Verify',
      ),
    );
  }
}
