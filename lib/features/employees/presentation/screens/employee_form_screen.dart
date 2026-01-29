// lib/features/employees/presentation/screens/employee_form_screen.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/utils/location_helper.dart';
import 'package:ordermate/core/widgets/lookup_field.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/domain/entities/app_user.dart';
import 'package:ordermate/core/widgets/loading_overlay.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:uuid/uuid.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  const EmployeeFormScreen({super.key, this.employeeId});
  final String? employeeId;

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _zipController = TextEditingController();

  double? _latitude;
  double? _longitude;
  String? _matchedAddress;
  bool _isFetchingLocation = false;
  String? _locationError;
  bool _isSubmitting = false;
  bool _isLoading = true;

  int? _selectedBusinessTypeId;
  int? _selectedDepartmentId;
  int? _selectedCityId;
  int? _selectedStateId;
  int? _selectedCountryId;
  String? _selectedChartOfAccountId;

  int? _selectedRoleId;
  bool _hasAppAccess = false;
  bool _obscurePassword = true;
  final _passwordController = TextEditingController();

  AppUser? _existingAppUser;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    setState(() => _isLoading = true);
    Future.microtask(() async {
      try {
        await ref.read(businessPartnerProvider.notifier).loadBusinessTypes();
        await ref.read(businessPartnerProvider.notifier).loadCities();
        await ref.read(businessPartnerProvider.notifier).loadStates();
        await ref.read(businessPartnerProvider.notifier).loadCountries();
        await ref.read(accountingProvider.notifier).loadAll();

        final selectedOrg = ref.read(organizationProvider).selectedOrganization;
        final user = ref.read(userProfileProvider).value;
        final orgId = selectedOrg?.id ?? user?.organizationId;

        if (orgId != null) {
          await ref
              .read(businessPartnerProvider.notifier)
              .loadDepartments(orgId);
          await ref
              .read(businessPartnerProvider.notifier)
              .loadRoles(organizationId: orgId);
        }

        if (widget.employeeId != null) {
          if (ref.read(businessPartnerProvider).employees.isEmpty) {
            await ref.read(businessPartnerProvider.notifier).loadEmployees();
          }
          await _loadEmployeeData();
        } else {
          _setDefaultCityAndCountry();
        }
      } catch (e) {
        debugPrint('Init error: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _zipController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getCityName(int? id) {
    if (id == null) return '';
    final cities = ref.read(businessPartnerProvider).cities;
    final item = cities.firstWhere((e) => e['id'] == id, orElse: () => {});
    return item['city_name'] as String? ?? '';
  }

  String _getStateName(int? id) {
    if (id == null) return '';
    final states = ref.read(businessPartnerProvider).states;
    final item = states.firstWhere((e) => e['id'] == id, orElse: () => {});
    return item['state_name'] as String? ?? '';
  }

  String _getCountryName(int? id) {
    if (id == null) return '';
    final countries = ref.read(businessPartnerProvider).countries;
    final item = countries.firstWhere((e) => e['id'] == id, orElse: () => {});
    return item['country_name'] as String? ?? '';
  }

  void _setDefaultCityAndCountry() {
    final cities = ref.read(businessPartnerProvider).cities;
    final countries = ref.read(businessPartnerProvider).countries;

    try {
      final khi = cities.firstWhere(
        (c) => (c['city_name'] as String).toLowerCase() == 'karachi',
      );
      _selectedCityId = khi['id'];
    } catch (_) {}

    try {
      final pak = countries.firstWhere(
        (c) => (c['country_name'] as String).toLowerCase() == 'pakistan',
      );
      _selectedCountryId = pak['id'];
    } catch (_) {}

    if (mounted) setState(() {});
  }

  Future<void> _loadEmployeeData() async {
    final partners = ref.read(businessPartnerProvider).employees;

    try {
      final employee = partners.cast<BusinessPartner>().firstWhere((c) => c.id == widget.employeeId);
      _nameController.text = employee.name;
      _contactPersonController.text = employee.contactPerson ?? '';
      _phoneController.text = employee.phone;
      _emailController.text = employee.email ?? '';

      _latitude = employee.latitude;
      _longitude = employee.longitude;
      _matchedAddress = 'Saved Location';

      _selectedBusinessTypeId = employee.businessTypeId;
      _selectedDepartmentId = employee.departmentId;
      _selectedRoleId = employee.roleId;
      _selectedCityId = employee.cityId;
      _selectedStateId = employee.stateId;
      _selectedCountryId = employee.countryId;
      _selectedChartOfAccountId = employee.chartOfAccountId;
      _zipController.text = employee.postalCode ?? '';

      _streetController.text = employee.address;

      final user = await ref
          .read(businessPartnerProvider.notifier)
          .repository
          .getAppUser(widget.employeeId!);
      if (user != null && user.isActive) {
        _existingAppUser = user;
        _hasAppAccess = true;
        if (user.email.isNotEmpty) _emailController.text = user.email;
      } else if (user != null) {
        _existingAppUser = user;
        _hasAppAccess = false;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Load Error: $e');
    }
  }

  String get _fullAddress {
    return [
      _streetController.text.trim(),
      _getCityName(_selectedCityId),
      _getStateName(_selectedStateId),
      _zipController.text.trim(),
      _getCountryName(_selectedCountryId),
    ].where((s) => s.isNotEmpty).join(', ');
  }

  Future<void> _setCityByName(String name) async {
    final cities = ref.read(businessPartnerProvider).cities;
    try {
      final existing = cities.firstWhere(
        (e) => (e['city_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedCityId = existing['id'];
    } catch (_) {
      await ref.read(businessPartnerProvider.notifier).addCity(name);
      final newCities = ref.read(businessPartnerProvider).cities;
      final newItem = newCities.firstWhere(
        (e) => (e['city_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedCityId = newItem['id'];
    }
    if (mounted) setState(() {});
  }

  Future<void> _setStateByName(String name) async {
    final states = ref.read(businessPartnerProvider).states;
    try {
      final existing = states.firstWhere(
        (e) => (e['state_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedStateId = existing['id'];
    } catch (_) {
      await ref.read(businessPartnerProvider.notifier).addState(name);
      final newItems = ref.read(businessPartnerProvider).states;
      final newItem = newItems.firstWhere(
        (e) => (e['state_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedStateId = newItem['id'];
    }
    if (mounted) setState(() {});
  }

  Future<void> _setCountryByName(String name) async {
    final countries = ref.read(businessPartnerProvider).countries;
    try {
      final existing = countries.firstWhere(
        (e) =>
            (e['country_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedCountryId = existing['id'];
    } catch (_) {
      await ref.read(businessPartnerProvider.notifier).addCountry(name);
      final newItems = ref.read(businessPartnerProvider).countries;
      final newItem = newItems.firstWhere(
        (e) =>
            (e['country_name'] as String).toLowerCase() == name.toLowerCase(),
      );
      _selectedCountryId = newItem['id'];
    }
    if (mounted) setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final position = await LocationHelper.getCurrentPosition();
      String? addressText;
      try {
        final placemark = await LocationHelper.getPlacemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        _streetController.text = placemark.street ?? '';
        _zipController.text = placemark.postalCode ?? '';

        if (placemark.locality != null)
          await _setCityByName(placemark.locality!);
        if (placemark.country != null)
          await _setCountryByName(placemark.country!);
        if (placemark.administrativeArea != null)
          await _setStateByName(placemark.administrativeArea!);

        addressText = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.postalCode,
          placemark.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      } catch (_) {
        addressText = 'GPS Coordinates Only';
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _matchedAddress = addressText ?? 'GPS Location';
      });
    } catch (e) {
      setState(() => _locationError = e.toString());
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _updateLocationFromAddress() async {
    final address = _fullAddress;
    if (address.isEmpty) return;

    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
          _matchedAddress = address;
        });
      }
    } catch (e) {
      setState(() => _locationError = 'Could not find location from address.');
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  String _cleanCityName(String rawCity) {
    return rawCity
        .replaceAll(RegExp(r'\s+Division', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+District', caseSensitive: false), '')
        .trim();
  }

  Future<List<Map<String, dynamic>>> _searchAddressWithOSM(String query) async {
    if (query.trim().isEmpty) return [];
    var fullQuery = query;
    final cName = _getCityName(_selectedCityId);
    if (cName.isNotEmpty) fullQuery += ', $cName';

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': fullQuery,
          'format': 'json',
          'addressdetails': 1,
          'limit': 5,
        },
        options: Options(headers: {'User-Agent': 'OrderMate_FlutterApp/1.0'}),
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      debugPrint('OSM Search Error: $e');
    }
    return [];
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_hasAppAccess && _selectedRoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Employee Role to grant application access')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final orgState = ref.read(organizationProvider);
      final partner = BusinessPartner(
        id: widget.employeeId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isEmpty
            ? null
            : _contactPersonController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: _streetController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        createdBy: SupabaseConfig.client.auth.currentUser?.id ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        businessTypeId: _selectedBusinessTypeId,
        departmentId: _selectedDepartmentId,
        cityId: _selectedCityId,
        stateId: _selectedStateId,
        countryId: _selectedCountryId,
        postalCode: _zipController.text.trim().isEmpty
            ? null
            : _zipController.text.trim(),
        chartOfAccountId: _selectedChartOfAccountId,
        isEmployee: true,
        roleId: _selectedRoleId,
        isActive: true,
        organizationId: orgState.selectedOrganization?.id ?? 0,
        storeId: orgState.selectedStore?.id ?? 0,
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
      );

      if (widget.employeeId == null) {
        await ref.read(businessPartnerProvider.notifier).addPartner(partner);
        await _handleAppUserSync(partner.id, partner.organizationId, partner.storeId);
      } else {
        await ref.read(businessPartnerProvider.notifier).updatePartner(partner);
        await _handleAppUserSync(partner.id, partner.organizationId, partner.storeId);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleAppUserSync(String partnerId, int? organizationId, int storeId) async {
    if (_hasAppAccess) {
      if (_selectedRoleId == null || _emailController.text.isEmpty) return;
      if (_existingAppUser == null) {
        await ref
            .read(businessPartnerProvider.notifier)
            .repository
            .createAppUser(
              partnerId: partnerId,
              email: _emailController.text.trim(),
              fullName: _nameController.text.trim(), // Added fullName
              roleId: _selectedRoleId!,
              organizationId: organizationId ?? 0,
              storeId: storeId,
              password: _passwordController.text.isNotEmpty
                  ? _passwordController.text
                  : null,
            );
      } else {
        final updatedUser = _existingAppUser!.copyWith(
          email: _emailController.text.trim(),
          roleId: _selectedRoleId!,
          isActive: true,
          updatedAt: DateTime.now(),
        );
        await ref
            .read(businessPartnerProvider.notifier)
            .repository
            .updateAppUser(
              updatedUser,
              password: _passwordController.text.isNotEmpty
                  ? _passwordController.text
                  : null,
            );
      }
    } else if (_existingAppUser != null && _existingAppUser!.isActive) {
      await ref.read(businessPartnerProvider.notifier).repository.updateAppUser(
          _existingAppUser!
              .copyWith(isActive: false, updatedAt: DateTime.now()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.employeeId == null ? 'New Employee' : 'Edit Employee'),
        actions: [
          IconButton(
            onPressed: (_isSubmitting || _isLoading) ? null : _submitForm,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Initializing form...',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                    labelText: 'Employee Name *',
                                    prefixIcon: Icon(Icons.person)),
                                validator: (v) =>
                                    v?.isEmpty ?? false ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _contactPersonController,
                                decoration: const InputDecoration(
                                    labelText: 'Contact Person (Emergency)',
                                    prefixIcon: Icon(Icons.contact_phone)),
                              ),
                              const SizedBox(height: 16),
                              LookupField<Map<String, dynamic>, int>(
                                label: 'Department',
                                value: _selectedDepartmentId,
                                items: ref
                                    .watch(businessPartnerProvider)
                                    .departments,
                                onChanged: (v) =>
                                    setState(() => _selectedDepartmentId = v),
                                labelBuilder: (item) =>
                                    item['name'] as String? ?? 'Unknown',
                                valueBuilder: (item) => item['id'] as int,
                                onAdd: (name) async {
                                  final orgId = ref
                                      .read(organizationProvider)
                                      .selectedOrganizationId;
                                  if (orgId != null)
                                    await ref
                                        .read(businessPartnerProvider.notifier)
                                        .addDepartment(name, orgId);
                                },
                              ),
                              const SizedBox(height: 16),
                              LookupField<ChartOfAccount, String>(
                                label: 'Salary GL Account',
                                value: _selectedChartOfAccountId,
                                items: ref.watch(accountingProvider).accounts,
                                onChanged: (v) => setState(
                                    () => _selectedChartOfAccountId = v),
                                labelBuilder: (item) =>
                                    '${item.accountCode} - ${item.accountTitle}',
                                valueBuilder: (item) => item.id,
                              ),
                              const SizedBox(height: 16),
                              LookupField<Map<String, dynamic>, int>(
                                label: 'Employee Role',
                                value: _selectedRoleId,
                                items: ref.watch(businessPartnerProvider).roles,
                                validationError: (_hasAppAccess && _selectedRoleId == null) ? 'Role is required for app access' : null,
                                onChanged: (v) =>
                                    setState(() => _selectedRoleId = v),
                                labelBuilder: (item) =>
                                    item['role_name'] as String? ?? 'Unknown',
                                valueBuilder: (item) => item['id'] as int,
                                onAdd: (name) async {
                                  final orgId = ref
                                      .read(organizationProvider)
                                      .selectedOrganizationId;
                                  if (orgId != null)
                                    await ref
                                        .read(businessPartnerProvider.notifier)
                                        .addRole(
                                            name, orgId, _selectedDepartmentId);
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                    labelText: 'Phone *',
                                    prefixIcon: Icon(Icons.phone)),
                                validator: (v) =>
                                    v?.isEmpty ?? false ? 'Required' : null,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.email)),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (_hasAppAccess && (v == null || v.isEmpty)) {
                                      return 'Email is required for app access';
                                    }
                                    return null;
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text('Grant Application Access'),
                                subtitle: Text(_hasAppAccess 
                                  ? 'An invitation email will be sent to the employee' 
                                  : 'Allow this employee to log in to the application'),
                                value: _hasAppAccess,
                                activeColor: Theme.of(context).primaryColor,
                                onChanged: (val) {
                                  if (val && _emailController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please provide an email address for app access')),
                                    );
                                  }
                                  setState(() {
                                    _hasAppAccess = val;
                                  });
                                },
                              ),
                              if (_hasAppAccess) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: _existingAppUser == null ? 'Password' : 'Change Password (optional)',
                                    hintText: 'Minimum 6 characters',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(_obscurePassword
                                              ? Icons.visibility
                                              : Icons.visibility_off),
                                          onPressed: () => setState(() =>
                                              _obscurePassword = !_obscurePassword),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.refresh),
                                          tooltip: 'Generate Random Password',
                                          onPressed: () {
                                            final randomPass = Uuid().v4().substring(0, 8);
                                            setState(() {
                                              _passwordController.text = randomPass;
                                              _obscurePassword = false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  validator: (v) {
                                    if (_hasAppAccess && _existingAppUser == null && (v == null || v.isEmpty)) {
                                      return 'Password is required for new app access';
                                    }
                                    if (_hasAppAccess && v != null && v.isNotEmpty && v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Address',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  TextButton.icon(
                                      onPressed: _getCurrentLocation,
                                      icon: const Icon(Icons.my_location),
                                      label: const Text('GPS')),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _streetController,
                                decoration: const InputDecoration(
                                    labelText: 'Street Address *'),
                                validator: (v) =>
                                    v?.isEmpty ?? false ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                      child: LookupField<Map<String, dynamic>,
                                              int>(
                                          label: 'City',
                                          value: _selectedCityId,
                                          items: ref
                                              .watch(businessPartnerProvider)
                                              .cities,
                                          labelBuilder: (item) =>
                                              item['city_name'],
                                          valueBuilder: (item) => item['id'],
                                          onChanged: (v) => setState(
                                              () => _selectedCityId = v),
                                          onAdd: _setCityByName)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: TextFormField(
                                          controller: _zipController,
                                          decoration: const InputDecoration(
                                              labelText: 'ZIP'))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                      child: LookupField<Map<String, dynamic>,
                                              int>(
                                          label: 'State',
                                          value: _selectedStateId,
                                          items: ref
                                              .watch(businessPartnerProvider)
                                              .states,
                                          labelBuilder: (item) =>
                                              item['state_name'],
                                          valueBuilder: (item) => item['id'],
                                          onChanged: (v) => setState(
                                              () => _selectedStateId = v),
                                          onAdd: _setStateByName)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: LookupField<Map<String, dynamic>,
                                              int>(
                                          label: 'Country',
                                          value: _selectedCountryId,
                                          items: ref
                                              .watch(businessPartnerProvider)
                                              .countries,
                                          labelBuilder: (item) =>
                                              item['country_name'],
                                          valueBuilder: (item) => item['id'],
                                          onChanged: (v) => setState(
                                              () => _selectedCountryId = v),
                                          onAdd: _setCountryByName)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                  onPressed: _updateLocationFromAddress,
                                  child: const Text('Detect Location')),
                              if (_isFetchingLocation)
                                const Center(
                                    child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator())),
                              if (_locationError != null)
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(_locationError!,
                                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              if (_matchedAddress != null)
                                Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text('Location: $_matchedAddress')),
                              if (_latitude != null)
                                Text('Lat: $_latitude, Lon: $_longitude'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: (_isSubmitting || _isLoading) ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(widget.employeeId == null ? 'Create Employee' : 'Save Changes'),
                      ),
                    ],
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
