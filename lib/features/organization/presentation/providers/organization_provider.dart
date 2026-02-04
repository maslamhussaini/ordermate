import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/organization/data/repositories/organization_repository_impl.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:ordermate/features/organization/domain/repositories/organization_repository.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// State
class OrganizationState {

  // State
  const OrganizationState({
    this.isLoading = false,
    this.organizations = const [],
    this.selectedOrganization,
    this.selectedStore,
    this.selectedFinancialYear,
    this.stores = const [],
    this.error,
  });

  final bool isLoading;
  final List<Organization> organizations;
  final Organization? selectedOrganization;
  final Store? selectedStore;
  final int? selectedFinancialYear;
  final List<Store> stores;
  final String? error;

  int? get selectedOrganizationId => selectedOrganization?.id;
  int? get selectedStoreId => selectedStore?.id;

  OrganizationState copyWith({
    bool? isLoading,
    List<Organization>? organizations,
    Organization? selectedOrganization,
    Store? selectedStore,
    int? selectedFinancialYear,
    List<Store>? stores,
    String? error,
  }) {
    return OrganizationState(
      isLoading: isLoading ?? this.isLoading,
      organizations: organizations ?? this.organizations,
      selectedOrganization: selectedOrganization ?? this.selectedOrganization,
      selectedStore: selectedStore ?? this.selectedStore,
      selectedFinancialYear: selectedFinancialYear ?? this.selectedFinancialYear,
      stores: stores ?? this.stores,
      error: error,
    );
  }
}

// Notifier
class OrganizationNotifier extends StateNotifier<OrganizationState> {
  final OrganizationRepository _repository;
  final Ref ref;

  OrganizationNotifier(this._repository, this.ref) : super(const OrganizationState()) {
    _init();
    
    // Listen for logout events to reset state
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isLoggedIn == true && !next.isLoggedIn) {
        reset();
      }
    });
  }

  Future<void> _init() async {
    await loadOrganizations();
    await _loadPersistedSelection();
  }

  Future<void> _loadPersistedSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orgId = prefs.getInt('selected_organization_id');
      final storeId = prefs.getInt('selected_store_id');
      final year = prefs.getInt('selected_financial_year');

      if (orgId != null && state.organizations.isNotEmpty) {
        final org = state.organizations.where((o) => o.id == orgId).firstOrNull;
        if (org != null) {
          state = state.copyWith(selectedOrganization: org);
          await loadStores(orgId);
          
          if (storeId != null) {
            final store = state.stores.where((s) => s.id == storeId).firstOrNull;
            if (store != null) {
              state = state.copyWith(selectedStore: store);
            }
          }
          
          if (year != null) {
            state = state.copyWith(selectedFinancialYear: year);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading persisted selection: $e');
    }
  }

  Future<void> _persistSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.selectedOrganization != null) {
        await prefs.setInt('selected_organization_id', state.selectedOrganization!.id);
      }
      if (state.selectedStore != null) {
        await prefs.setInt('selected_store_id', state.selectedStore!.id);
      }
      if (state.selectedFinancialYear != null) {
        await prefs.setInt('selected_financial_year', state.selectedFinancialYear!);
      }
    } catch (e) {
      debugPrint('Error persisting selection: $e');
    }
  }

  Future<void> loadOrganizations() async {
    state = state.copyWith(isLoading: true);
    try {
      final orgs = await _repository.getOrganizations();
      
      // Auto-select first org if available and none selected, or if selected is no longer in list
      var selected = state.selectedOrganization;
      if (selected != null && !orgs.any((o) => o.id == selected!.id)) {
        selected = null;
      }
      
      if (selected == null && orgs.isNotEmpty) {
        if (orgs.length == 1) {
          selected = orgs.first;
        }
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        organizations: orgs,
        selectedOrganization: selected,
      );

      if (selected != null) {
        await loadStores(selected.id);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> deleteOrganization(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteOrganization(id);
      await loadOrganizations();
    } catch(e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> selectOrganization(Organization org) async {
    state = state.copyWith(selectedOrganization: org);
    await loadStores(org.id);
    await _persistSelection();
  }

  Future<void> selectStore(Store? store) async {
     state = state.copyWith(selectedStore: store);
     await _persistSelection();
  }

  void clearSelection() {
    state = const OrganizationState();
  }

  void reset() {
    state = const OrganizationState();
  }

  void selectFinancialYear(int? year) {
    state = state.copyWith(selectedFinancialYear: year);
    _persistSelection();
  }

  Future<Organization> createOrganization(
      String name, String? taxId, bool hasMultipleBranches, File? logoFile,) async {
    state = state.copyWith(isLoading: true);
    try {
      String? logoUrl;
      if (logoFile != null) {
        logoUrl = await _repository.uploadOrganizationLogo(logoFile);
      }

      final newOrg = await _repository.createOrganization(
          name, taxId, hasMultipleBranches, logoUrl,);

      // Trigger Accounting Setup in background
      _setupAccounting(newOrg.id);

      // Reload to refresh list and select new org
      await loadOrganizations();
      await selectOrganization(newOrg); // Ensure we select the new one
      if (!mounted) return newOrg;
      return newOrg;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> updateOrganization(Organization org, {File? newLogoFile}) async {
    state = state.copyWith(isLoading: true);
    try {
      var orgToUpdate = org;
      if (newLogoFile != null) {
        final logoUrl = await _repository.uploadOrganizationLogo(newLogoFile);
        orgToUpdate = Organization(
          id: org.id,
          name: org.name,
          code: org.code,
          isActive: org.isActive,
          createdAt: org.createdAt,
          updatedAt: DateTime.now(),
          logoUrl: logoUrl,
          storeCount: org.storeCount,
        );
      }

      await _repository.updateOrganization(orgToUpdate);
      await loadOrganizations(); // Refresh list
      if (!mounted) return;
      state = state.copyWith(selectedOrganization: orgToUpdate);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // Stores
  Future<void> loadStores(int orgId) async {
    try {
      final allStores = await _repository.getStores(orgId);
      
      // Filter stores based on user access
      final userProfile = await ref.read(userProfileProvider.future);
      List<Store> allowedStores = allStores;

      if (userProfile != null) {
        // Corporate Admins see all stores. 
        // Others (ADMIN, EMPLOYEE) might be restricted to one store.
        final role = userProfile.role.toUpperCase();
        print('DEBUG_LOG: Check Access - Role: $role, Assigned StoreID: ${userProfile.storeId}');
        
        if (role != 'CORPORATE_ADMIN' && role != 'ADMIN' && role != 'SUPER USER' && role != 'OWNER' && userProfile.storeId != null) {
          allowedStores = allStores.where((s) => s.id == userProfile.storeId).toList();
        }
        print('DEBUG_LOG: Filter Results - All: ${allStores.length}, Allowed: ${allowedStores.length}');
      }

      // Auto select first store logic
      var selected = state.selectedStore;
      
      // If currently selected store is not in the allowed list, clear it
      if (selected != null) {
        final fresh = allowedStores.where((s) => s.id == selected!.id).firstOrNull;
        if (fresh != null) {
          selected = fresh;
        } else {
          selected = null;
        }
      }

      // If nothing selected, pick first if stores are available
      if (selected == null && allowedStores.isNotEmpty) {
          selected = allowedStores.first;
      }
      
      if (!mounted) return;
      state = state.copyWith(stores: allowedStores, selectedStore: selected);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addStore(Store params) async {
    try {
      final newStore = await _repository.createStore(params);
      await loadStores(params.organizationId);
      await selectStore(newStore);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateStore(Store params) async {
    try {
      await _repository.updateStore(params);
      await loadStores(params.organizationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteStore(int storeId, int orgId) async {
    try {
      await _repository.deleteStore(storeId);
      await loadStores(orgId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> _setupAccounting(int orgId) async {
    try {
      await ref.read(accountingSetupServiceProvider).setupDefaultAccounting(orgId);
    } catch (e) {
      debugPrint('Accounting setup error: $e');
    }
  }
}

// Providers
final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepositoryImpl();
});

final organizationProvider =
    StateNotifierProvider<OrganizationNotifier, OrganizationState>((ref) {
  final repository = ref.watch(organizationRepositoryProvider);
  return OrganizationNotifier(repository, ref);
});
