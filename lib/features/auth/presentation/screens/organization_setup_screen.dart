import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/core/services/email_service.dart';

class OrganizationSetupScreen extends ConsumerStatefulWidget {
  final Map<String, String> userData;

  const OrganizationSetupScreen({super.key, required this.userData});

  @override
  ConsumerState<OrganizationSetupScreen> createState() =>
      _OrganizationSetupScreenState();
}

class _OrganizationSetupScreenState
    extends ConsumerState<OrganizationSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameController = TextEditingController();

  // Single Branch Address Fields
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _currencyController = TextEditingController();
  final _contactPersonController = TextEditingController();

  bool _hasMultipleBranch = false;
  int? _selectedBusinessTypeId;
  bool _isGL = true;
  bool _isSales = true;
  bool _isInventory = true;
  bool _isHR = true;
  final bool _isSettings = true;
  bool _isLoading = false;
  XFile? _pickedFile;
  Uint8List? _previewBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _orgNameController.text = widget.userData['organization_name'] ?? '';
    // Load business types
    Future.microtask(() =>
        ref.read(businessPartnerProvider.notifier).loadBusinessTypes());
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pickedFile = image;
          _previewBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _currencyController.dispose();
    _contactPersonController.dispose();
    super.dispose();
  }

  void _onNext() async {
    if (!_formKey.currentState!.validate()) return;
 
    final orgName = _orgNameController.text.trim();
    final bpState = ref.read(businessPartnerProvider);
    final businessType = bpState.businessTypes.firstWhere(
        (t) => t['id'] == _selectedBusinessTypeId,
        orElse: () => {'business_type': 'Unknown'})['business_type'];
 
    final email = widget.userData['email'] ?? '';
 

 
    if (_hasMultipleBranch) {
      context.push('/onboarding/store', extra: {
        'userData': widget.userData,
        'orgData': {
          'name': orgName,
          'hasMultipleBranch': 'true',
          'logoBytes': _previewBytes,
          'logoName': _pickedFile?.name,
          'businessTypeId': _selectedBusinessTypeId,
          'isGL': _isGL,
          'isSales': _isSales,
          'isInventory': _isInventory,
          'isHR': _isHR,
          'isSettings': _isSettings,
        }
      });
    } else {
      await _registerAndCreate(
        storeName: 'Main Store',
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        postal: _postalCodeController.text.trim(),
        currency: _currencyController.text.trim(),
        contact: _contactPersonController.text.trim(),
      );
    }
  }

  Future<void> _registerAndCreate({
    required String storeName,
    required String address,
    required String city,
    required String country,
    required String postal,
    required String currency,
    required String contact,
  }) async {
    setState(() => _isLoading = true);

    try {
      final email = widget.userData['email']!;
      final password = widget.userData['password']!;
      final fullName = widget.userData['fullName']!;
      final phone = widget.userData['phone']!;
      final orgName = _orgNameController.text.trim();

      const redirectTo = 'ordermate://login-callback';

      // 1. Sign Up User
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
      if (_pickedFile != null && _previewBytes != null) {
        try {
          final repo = ref.read(organizationRepositoryProvider);
          logoUrl = await repo.uploadOrganizationLogo(
              _previewBytes!, _pickedFile!.name);
        } catch (e) {
          debugPrint('Logo upload failed: $e');
        }
      }

      // 3. Create Organization
      final orgResponse = await SupabaseConfig.client
          .from('omtbl_organizations')
          .insert({
            'name': orgName,
            'logo_url': logoUrl,
            'business_type_id': _selectedBusinessTypeId,
            'is_gl': _isGL,
            'is_sales': _isSales,
            'is_inventory': _isInventory,
            'is_hr': _isHR,
            'is_settings': _isSettings,
            'auth_user_id': authResponse.user!.id,
          })
          .select()
          .single();

      final orgId = orgResponse['id'];

      // 3. Create Store
      final locationString = '$address, $city, $country';
      await SupabaseConfig.client.from('omtbl_stores').insert({
        'organization_id': orgId,
        'name': storeName,
        'location': locationString,
        'contact_person': contact,
        'store_city': city,
        'store_country': country,
        'store_postal_code': postal,
        'store_default_currency': currency,
      });

      // 4. Update User Profile with Org ID
      await SupabaseConfig.client.from('omtbl_users').update({
        'organization_id': orgId,
        'role': 'owner',
      }).eq('auth_id', authResponse.user!.id);

      // Send Module Configuration Email with Deep Link
      try {
        final link = 'https://ordermate-v619.vercel.app/module-access?orzid=$orgId';
        final businessTypeName = ref.read(businessPartnerProvider).businessTypes.firstWhere(
            (t) => t['id'] == _selectedBusinessTypeId,
            orElse: () => {'business_type': 'Unknown'})['business_type'];
            
        EmailService().sendModuleConfigurationEmail(
          recipientEmail: 'maslamhussaini@gmail.com',
          orgName: orgName,
          businessType: businessTypeName ?? 'Unknown',
          moduleConfigUrl: link,
        );
      } catch (e) {
        debugPrint('Email sending failed: $e');
      }

      if (mounted) {
        context.push('/onboarding/team', extra: {
          'orgId': orgId,
          'storeId': (await SupabaseConfig.client
              .from('omtbl_stores')
              .select('id')
              .eq('organization_id', orgId)
              .single())['id'],
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
          'Organization Setup',
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
                currentStep: 1,
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
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: _previewBytes != null
                                      ? ClipOval(
                                          child: Image.memory(_previewBytes!,
                                              fit: BoxFit.cover))
                                      : const Icon(Icons.add_a_photo,
                                          size: 30, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Organization Logo',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildLabel('Business Information'),
                        const SizedBox(height: 16),
                        _buildTextField(
                            controller: _orgNameController,
                            hint: 'Organization Name',
                            icon: Icons.business),
                        const SizedBox(height: 12),
                        // Business Type Dropdown
                        Consumer(
                          builder: (context, ref, child) {
                            final bpState = ref.watch(businessPartnerProvider);
                            final businessTypes = bpState.businessTypes;
 
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 1.5),
                              ),
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedBusinessTypeId,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.category,
                                      color: AppColors.loginGradientStart),
                                  border: InputBorder.none,
                                  hintText: 'Select Business Type',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                items: businessTypes.map((type) {
                                  return DropdownMenuItem<int>(
                                    value: type['id'] as int,
                                    child: Text(
                                        type['business_type']?.toString() ??
                                            'Unknown'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedBusinessTypeId = val;
                                  });
                                },
                                validator: (val) =>
                                    val == null ? 'Required' : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        const SizedBox(height: 16),
                        Theme(
                          data: Theme.of(context).copyWith(
                            switchTheme: SwitchThemeData(
                              trackColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                          ? Colors.white
                                          : Colors.white24),
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Multiple Branches / Stores',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: const Text(
                              'Enable if you have more than one location',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            value: _hasMultipleBranch,
                            activeThumbColor: Colors.white,
                            onChanged: (v) =>
                                setState(() => _hasMultipleBranch = v),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_hasMultipleBranch) ...[
                          _buildLabel('Store Details (Main Branch)'),
                          const SizedBox(height: 16),
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
                                      hint: 'Default Currency (e.g. PKR)',
                                      icon: Icons.money)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildTextField(
                                      controller: _contactPersonController,
                                      hint: 'Contact Person',
                                      icon: Icons.person_outline)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white))
                            : ElevatedButton(
                                onPressed: _onNext,
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
                        const SizedBox(height: 32),
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
