import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class StoreSetupScreen extends ConsumerStatefulWidget {
  final Map<String, String> userData;
  final Map<String, dynamic> orgData;

  const StoreSetupScreen({
    super.key,
    required this.userData,
    required this.orgData,
  });

  @override
  ConsumerState<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends ConsumerState<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _currencyController = TextEditingController();
  final _contactPersonController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _currencyController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = widget.userData['email']!;
      final password = widget.userData['password']!;
      final fullName = widget.userData['fullName']!;
      final phone = widget.userData['phone']!;
      final orgName = widget.orgData['name']!;

      const redirectTo = 'ordermate://login-callback';

      // 1. Sign Up
      final authResponse = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectTo,
        data: {
          'full_name': fullName,
          'phone': phone,
          'organization_name': orgName,
        },
      );

      if (authResponse.user == null) {
        throw 'Registration failed. Please try again.';
      }

      String? logoUrl;
      final logoBytes = widget.orgData['logoBytes'] as Uint8List?;
      final logoName = widget.orgData['logoName'] as String?;

      if (logoBytes != null && logoName != null) {
        try {
          final repo = ref.read(organizationRepositoryProvider);
          logoUrl = await repo.uploadOrganizationLogo(logoBytes, logoName);
        } catch (e) {
          debugPrint('Logo upload failed: $e');
        }
      }

      // 2. Create Organization
      final orgResponse = await SupabaseConfig.client
          .from('omtbl_organizations')
          .insert({
            'name': orgName,
            'logo_url': logoUrl,
            'business_type_id': widget.orgData['businessTypeId'],
            'is_gl': widget.orgData['isGL'] ?? true,
            'is_sales': widget.orgData['isSales'] ?? true,
            'is_inventory': widget.orgData['isInventory'] ?? true,
            'is_hr': widget.orgData['isHR'] ?? true,
            'is_settings': widget.orgData['isSettings'] ?? true,
          })
          .select()
          .single();

      final orgId = orgResponse['id'];

      // 3. Create Store
      final locationString =
          '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_countryController.text.trim()}';

      final storeResponse = await SupabaseConfig.client
          .from('omtbl_stores')
          .insert({
            'organization_id': orgId,
            'name': _nameController.text.trim(),
            'location': locationString,
            'contact_person': _contactPersonController.text.trim(),
            'store_city': _cityController.text.trim(),
            'store_country': _countryController.text.trim(),
            'store_postal_code': _postalCodeController.text.trim(),
            'store_default_currency': _currencyController.text.trim(),
            'is_active': true,
          })
          .select()
          .single();

      final storeId = storeResponse['id'];

      // 4. Update User Profile
      await SupabaseConfig.client.from('omtbl_users').update({
        'organization_id': orgId,
        'role': 'owner',
      }).eq('auth_id', authResponse.user!.id);

      if (mounted) {
        context.push('/onboarding/team', extra: {
          'orgId': orgId,
          'storeId': storeId,
          'email': email,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          'Branch Setup',
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
                currentStep: 2,
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        const Center(
                          child: Icon(Icons.store_mall_directory_outlined,
                              size: 80, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Branch Setup',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configure your first location',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildLabel('Store Information'),
                        const SizedBox(height: 16),
                        _buildTextField(
                            controller: _nameController,
                            hint: 'Store Name (e.g. Downtown Branch)',
                            icon: Icons.store),
                        const SizedBox(height: 12),
                        _buildTextField(
                            controller: _addressController,
                            hint: 'Street Address',
                            icon: Icons.location_on),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildTextField(
                                    controller: _cityController,
                                    hint: 'City',
                                    icon: Icons.location_city)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    controller: _postalCodeController,
                                    hint: 'Postal Code',
                                    icon: Icons.pin_drop)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                            controller: _countryController,
                            hint: 'Country',
                            icon: Icons.public),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildTextField(
                                    controller: _currencyController,
                                    hint: 'Currency (e.g. PKR)',
                                    icon: Icons.money)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildTextField(
                                    controller: _contactPersonController,
                                    hint: 'Contact Person',
                                    icon: Icons.person_outline)),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white))
                            : ElevatedButton(
                                onPressed: _create,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.loginGradientStart,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Next',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
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
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
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
}
