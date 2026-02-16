import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/localization/app_localizations.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/organization/data/repositories/organization_repository_impl.dart';
import 'package:ordermate/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:ordermate/features/accounting/data/repositories/local_accounting_repository.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';

class WorkspaceSelectionScreen extends ConsumerStatefulWidget {
  const WorkspaceSelectionScreen({super.key});

  @override
  ConsumerState<WorkspaceSelectionScreen> createState() =>
      _WorkspaceSelectionScreenState();
}

class _WorkspaceSelectionScreenState
    extends ConsumerState<WorkspaceSelectionScreen> {
  bool _isLoading = true;
  bool _isProcessing = false; // Added processing flag
  List<Organization> _organizations = [];
  Organization? _selectedOrganization;
  List<Store> _stores = [];
  Store? _selectedStore;
  List<FinancialSession> _financialSessions = [];
  FinancialSession? _selectedSession;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final repo = OrganizationRepositoryImpl();
      final orgs = await repo.getOrganizations();

      if (!mounted) return;

      setState(() {
        _organizations = orgs;
        if (orgs.isNotEmpty) {
          // Check if an org is already selected in the provider
          final currentOrgId =
              ref.read(organizationProvider).selectedOrganizationId;
          _selectedOrganization =
              orgs.where((o) => o.id == currentOrgId).firstOrNull ?? orgs.first;
        }
      });

      if (_selectedOrganization != null) {
        await _fetchStores(_selectedOrganization!.id);
        await _fetchFinancialSessions(_selectedOrganization!.id);
      }
    } catch (e) {
      debugPrint('Error fetching initial workplace data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStores(int orgId) async {
    try {
      final repo = OrganizationRepositoryImpl();
      final stores = await repo.getStores(orgId);

      if (!mounted) return;
      setState(() {
        _stores = stores;
        if (stores.isNotEmpty) {
          final currentStoreId = ref.read(organizationProvider).selectedStoreId;
          _selectedStore =
              stores.where((s) => s.id == currentStoreId).firstOrNull ??
                  stores.first;
        } else {
          _selectedStore = null;
        }
      });
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
  }

  Future<void> _fetchFinancialSessions(int orgId) async {
    try {
      debugPrint('🔍 [WorkspaceSelection] Fetching financial sessions for orgId: $orgId');
      
      // Use the global provider to load sessions and other metadata
      await ref.read(accountingProvider.notifier).loadAll(organizationId: orgId);
      
      if (!mounted) return;
      
      final accountingState = ref.read(accountingProvider);
      final sessions = accountingState.financialSessions;

      debugPrint('📊 [WorkspaceSelection] Loaded ${sessions.length} financial sessions');
      for (var session in sessions) {
        debugPrint('   - sYear: ${session.sYear}, Active: ${session.isActive}, InUse: ${session.inUse}, OrgId: ${session.organizationId}');
      }

      setState(() {
        _financialSessions = sessions;
        if (sessions.isNotEmpty) {
          // Check if a year is already persisted in organization provider
          final persistedYear =
              ref.read(organizationProvider).selectedFinancialYear;
          
          debugPrint('💾 [WorkspaceSelection] Persisted year: $persistedYear');
          
          if (persistedYear != null) {
            _selectedSession = sessions
                .where((s) => s.sYear == persistedYear)
                .firstOrNull;
          }
          
          // Fallback to active or first
          if (_selectedSession == null) {
            _selectedSession = sessions.where((s) => s.isActive).firstOrNull ?? 
                             sessions.where((s) => s.inUse).firstOrNull ?? 
                             sessions.first;
          }
          
          debugPrint('✅ [WorkspaceSelection] Selected session: ${_selectedSession?.sYear}');
        } else {
          debugPrint('⚠️ [WorkspaceSelection] No financial sessions found!');
        }
      });
    } catch (e) {
      debugPrint('❌ [WorkspaceSelection] Error fetching financial sessions: $e');
    }
  }

  Future<void> _continueToDashboard() async {
    if (_isProcessing) return;

    final accountingState = ref.read(accountingProvider);
    // Only use sessions for the CURRENTLY selected organization
    final sessions = accountingState.financialSessions
        .where((s) => s.organizationId == _selectedOrganization?.id)
        .toList();

    // Determine the effective session to use, defaulting to first if local state is null
    final effectiveSession = _selectedSession ??
        (sessions.isNotEmpty ? sessions.first : null);

    debugPrint('WorkspaceSelectionScreen: Continue to Dashboard clicked.');
    debugPrint(' - Selected Org: ${_selectedOrganization?.id}');
    debugPrint(' - Selected Store: ${_selectedStore?.id}');
    debugPrint(' - Selected Session: ${effectiveSession?.sYear}');

    if (_selectedOrganization == null ||
        _selectedStore == null ||
        effectiveSession == null) {
      String missing = '';
      if (_selectedOrganization == null) missing += 'Organization, ';
      if (_selectedStore == null) missing += 'Store, ';
      if (effectiveSession == null) missing += 'Financial Year';

      debugPrint('WorkspaceSelectionScreen: Blocked - Missing: $missing');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select missing: $missing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final orgNotifier = ref.read(organizationProvider.notifier);

      await orgNotifier.setWorkspace(
        organization: _selectedOrganization!,
        store: _selectedStore,
        financialYear: effectiveSession.sYear,
      );

      // Also update accounting provider for consistency across app
      ref
          .read(accountingProvider.notifier)
          .selectFinancialSession(effectiveSession);

      if (!mounted) return;

      final landingPage = ref.read(settingsProvider).landingPage;
      debugPrint('WorkspaceSelectionScreen: Navigating to $landingPage');

      context.go(landingPage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Workspace selected: ${_selectedOrganization!.name} - ${_selectedStore!.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('WorkspaceSelectionScreen: Error continuing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final accountingState = ref.watch(accountingProvider);
    final sessions = accountingState.financialSessions;
    
    // Auto-sync selected session if local is null but provider has one
    if (_selectedSession == null && accountingState.selectedFinancialSession != null) {
      // Use a microtask to avoid setState during build
      Future.microtask(() {
        if (mounted && _selectedSession == null) {
          setState(() => _selectedSession = accountingState.selectedFinancialSession);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.get('select_workspace') ??
            'Select Workspace'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.grey.shade900, Colors.black]
                : [Colors.white, Colors.blue.shade50],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.business_center_rounded,
                          size: 80, color: AppColors.loginGradientStart),
                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)
                                ?.get('workspace_configuration') ??
                            'Configuration',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confirm your organization, store and financial period',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 32),

                      // Organization Dropdown
                      _buildDropdown(
                        label:
                            AppLocalizations.of(context)?.get('organization') ??
                                'Organization',
                        icon: Icons.domain,
                        value: _selectedOrganization,
                        items: _organizations
                            .map((org) => DropdownMenuItem(
                                  value: org,
                                  child: Text(org.name),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedOrganization = val;
                            _stores = [];
                            _selectedStore = null;
                            _financialSessions = [];
                            _selectedSession = null;
                          });
                          if (val != null) {
                            _fetchStores(val.id);
                            _fetchFinancialSessions(val.id);
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Store Dropdown
                      _buildDropdown(
                        label:
                            AppLocalizations.of(context)?.get('store_branch') ??
                                'Store / Branch',
                        icon: Icons.store,
                        value: _selectedStore,
                        items: _stores.map((store) => DropdownMenuItem(
                                value: store,
                                child: Text(store.name),
                              )).toList(),
                        onChanged: (val) {
                          setState(() => _selectedStore = val);
                        },
                        hintText: _stores.isEmpty ? 'Loading stores...' : 'Select Store',
                      ),
                      const SizedBox(height: 20),

                      // Financial Year Dropdown
                      _buildDropdown(
                        label: AppLocalizations.of(context)
                                ?.get('financial_year') ??
                            'Financial Year',
                        icon: Icons.calendar_today,
                        value: sessions.contains(_selectedSession) 
                            ? _selectedSession 
                            : (sessions.isNotEmpty ? sessions.first : null),
                        items: sessions
                            .map((session) => DropdownMenuItem(
                                  value: session,
                                  child: Text(
                                      '${session.sYear} (${DateFormat('MMM yy').format(session.startDate)} - ${DateFormat('MMM yy').format(session.endDate)})'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() => _selectedSession = val);
                        },
                        hintText: accountingState.isLoading 
                            ? 'Loading sessions...' 
                            : (sessions.isEmpty ? 'No sessions found' : 'Select Financial Year'),
                      ),

                      if (accountingState.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Error: ${accountingState.error}',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),

                      const SizedBox(height: 48),

                      ElevatedButton(
                        onPressed: (_selectedOrganization != null && 
                                _selectedStore != null && 
                                sessions.isNotEmpty && 
                                !_isProcessing)
                            ? _continueToDashboard
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.loginGradientStart,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)
                                            ?.get('continue_to_dashboard') ??
                                        'Continue to Dashboard',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward),
                                ],
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
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.loginGradientStart),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: items,
          onChanged: onChanged,
          hint: Text(hintText ?? 'Select $label'),
        ),
      ],
    );
  }
}
