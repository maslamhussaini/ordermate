import 'package:ordermate/features/business_partners/data/repositories/business_partner_local_repository.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/vendors/data/models/vendor_model.dart';
import 'package:ordermate/features/vendors/domain/entities/vendor.dart';
import 'package:ordermate/features/vendors/domain/repositories/vendor_repository.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class VendorRepositoryImpl implements VendorRepository {
  final _localRepository = BusinessPartnerLocalRepository();

  @override
  Future<List<Vendor>> getVendors() async {
    // 1. Check Connectivity & Offline Mode
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn) {
       final localPartners = await _localRepository.getLocalPartners(isVendor: true);
       return localPartners.where((p) => !p.isSupplier).map((p) => _mapToVendor(p)).toList();
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .select('*, product_count:omtbl_products(count)')
          .or('is_active.eq.1,is_active.is.null')
          .eq('is_vendor', 1)
          .or('is_supplier.eq.0,is_supplier.is.null')
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 15));

      final vendors = (response as List)
          .map((json) => VendorModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Cache logic
      final partners = vendors.map((v) => BusinessPartner(
        id: v.id,
        name: v.name,
        phone: v.phone ?? '',
        email: v.email,
        address: v.address ?? '',
        contactPerson: v.contactPerson,
        isVendor: true,
        isSupplier: v.isSupplier,
        isActive: v.isActive,
        createdAt: v.createdAt,
        updatedAt: v.updatedAt,
        chartOfAccountId: v.chartOfAccountId,
        organizationId: v.organizationId,
        storeId: v.storeId,
      )).toList();
      await _localRepository.cachePartners(partners);

      // Final return: merged with unsynced local changes (standard practice here)
      final unsynced = await _localRepository.getUnsyncedPartners();
      final unsyncedVendors = unsynced.where((p) => p.isVendor && !p.isSupplier).map((p) => _mapToVendor(p)).toList();

      if (unsyncedVendors.isNotEmpty) {
        final Map<String, Vendor> mergedMap = {
          for (var v in vendors) v.id: v,
          for (var v in unsyncedVendors) v.id: v,
        };
        return mergedMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      }

      // If online returned nothing but local has data, we might be hitting RLS or sync issues.
      // To be safe and match dashboard, let's return local if online is empty.
      if (vendors.isEmpty) {
        final localPartners = await _localRepository.getLocalPartners(isVendor: true);
        final filteredLocal = localPartners.where((p) => !p.isSupplier).toList();
        if (filteredLocal.isNotEmpty) {
           return filteredLocal.map((p) => _mapToVendor(p)).toList();
        }
      }

      return vendors;
    } catch (e) {
      debugPrint('Online fetch vendors failed: $e. Falling back to local.');
      final localPartners = await _localRepository.getLocalPartners(isVendor: true);
      return localPartners.where((p) => !p.isSupplier).map((p) => _mapToVendor(p)).toList();
    }
  }

  Vendor _mapToVendor(BusinessPartner p) {
    return Vendor(
      id: p.id,
      name: p.name,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      contactPerson: p.contactPerson,
      phone: p.phone,
      email: p.email,
      address: p.address,
      isSupplier: p.isSupplier,
      isActive: p.isActive,
      chartOfAccountId: p.chartOfAccountId,
      organizationId: p.organizationId,
      storeId: p.storeId,
    );
  }

  @override
  Future<List<Vendor>> getSuppliers() async {
    // 1. Check Connectivity & Offline Mode
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) || SupabaseConfig.isOfflineLoggedIn) {
       final localPartners = await _localRepository.getLocalPartners(isSupplier: true);
       return localPartners.map((p) => _mapToVendor(p)).toList();
    }

    try {
      final response = await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .select()
          .eq('is_supplier', 1)
          .or('is_active.eq.1,is_active.is.null')
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 15));

      final vendors = (response as List)
          .map((json) => VendorModel.fromJson(json as Map<String, dynamic>))
          .toList();
          
      // Cache logic
      final partners = vendors.map((v) => BusinessPartner(
        id: v.id,
        name: v.name,
        phone: v.phone ?? '',
        email: v.email,
        address: v.address ?? '',
        contactPerson: v.contactPerson,
        isVendor: true,
        isSupplier: true,
        isActive: v.isActive,
        createdAt: v.createdAt,
        updatedAt: v.updatedAt,
        chartOfAccountId: v.chartOfAccountId,
        organizationId: v.organizationId,
        storeId: v.storeId,
      )).toList();
      await _localRepository.cachePartners(partners);

      // Merge with offline/unsynced suppliers
      final unsynced = await _localRepository.getUnsyncedPartners();
      final unsyncedSuppliers = unsynced.where((p) => p.isSupplier).map((p) => _mapToVendor(p)).toList();

      if (unsyncedSuppliers.isNotEmpty) {
        final Map<String, Vendor> mergedMap = {
          for (var v in vendors) v.id: v,
          for (var v in unsyncedSuppliers) v.id: v,
        };
        return mergedMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
      }

      // Fallback for empty online results
      if (vendors.isEmpty) {
        final localSuppliers = await _localRepository.getLocalPartners(isSupplier: true);
        if (localSuppliers.isNotEmpty) {
          return localSuppliers.map((p) => _mapToVendor(p)).toList();
        }
      }

      return vendors;
    } catch (e) {
      debugPrint('Online fetch suppliers failed: $e. Falling back to local.');
      final localPartners = await _localRepository.getLocalPartners(isSupplier: true);
      return localPartners.map((p) => _mapToVendor(p)).toList();
    }
  }

  @override
  Future<Vendor> createVendor(Vendor vendor) async {
    // 1. Prepare BusinessPartner for local storage
    final partner = BusinessPartner(
      id: vendor.id,
      name: vendor.name,
      phone: vendor.phone ?? '',
      email: vendor.email,
      address: vendor.address ?? '',
      contactPerson: vendor.contactPerson,
      isVendor: true,
      isSupplier: vendor.isSupplier,
      isActive: vendor.isActive,
      createdAt: vendor.createdAt,
      updatedAt: vendor.updatedAt,
      isCustomer: false,
      isEmployee: false,
      createdBy: SupabaseConfig.currentUserId,
      organizationId: vendor.organizationId,
      storeId: vendor.storeId,
      chartOfAccountId: vendor.chartOfAccountId,
    );

    // 2. Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    bool isOnline = !connectivityResult.contains(ConnectivityResult.none);

    if (!isOnline || SupabaseConfig.isOfflineLoggedIn) {
      // Offline: Save locally (marked as unsynced inside addPartner)
      await _localRepository.addPartner(partner);
      return vendor;
    }

    // 3. Online: Try Supabase
    try {
      final model = vendor is VendorModel
          ? vendor
          : VendorModel(
              id: vendor.id,
              name: vendor.name,
              createdAt: vendor.createdAt,
              updatedAt: vendor.updatedAt,
              contactPerson: vendor.contactPerson,
              phone: vendor.phone,
              email: vendor.email,
              address: vendor.address,
              isSupplier: vendor.isSupplier,
              isActive: vendor.isActive,
              organizationId: vendor.organizationId,
              storeId: vendor.storeId,
      chartOfAccountId: vendor.chartOfAccountId,
            );

      final json = model.toJson();
      // json.remove('id'); // DO NOT REMOVE ID. We generate it on client side now (UUID).
      json.remove('created_at');
      json.remove('updated_at');
      
      json['is_vendor'] = 1;

      final response = await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .insert(json)
          .select()
          .single();
      
      // Cache the result (sets is_synced = 1)
      await _localRepository.cachePartners([partner]);

      return VendorModel.fromJson(response);
    } catch (e) {
      // If online fails unexpectedly, fallback to local
      debugPrint('Online create vendor failed: $e. Saving locally.');
      await _localRepository.addPartner(partner);
      return vendor;
    }
  }

  @override
  Future<void> updateVendor(Vendor vendor) async {
    final partner = BusinessPartner(
      id: vendor.id,
      name: vendor.name,
      phone: vendor.phone ?? '',
      email: vendor.email,
      address: vendor.address ?? '',
      contactPerson: vendor.contactPerson,
      isVendor: true,
      isSupplier: vendor.isSupplier,
      isActive: vendor.isActive,
      createdAt: vendor.createdAt,
      updatedAt: vendor.updatedAt,
      isCustomer: false,
      isEmployee: false,
      createdBy: SupabaseConfig.currentUserId,
      organizationId: vendor.organizationId,
      storeId: vendor.storeId,
      chartOfAccountId: vendor.chartOfAccountId,
    );

    final connectivityResult = await ConnectivityHelper.check();
    bool isOnline = !connectivityResult.contains(ConnectivityResult.none);

    if (!isOnline) {
       await _localRepository.updatePartner(partner);
       return;
    }

    try {
      final model = vendor is VendorModel
          ? vendor
          : VendorModel(
              id: vendor.id,
              name: vendor.name,
              createdAt: vendor.createdAt,
              updatedAt: vendor.updatedAt,
              contactPerson: vendor.contactPerson,
              phone: vendor.phone,
              email: vendor.email,
              address: vendor.address,
              isSupplier: vendor.isSupplier,
              isActive: vendor.isActive,
              organizationId: vendor.organizationId,
              storeId: vendor.storeId,
      chartOfAccountId: vendor.chartOfAccountId,
            );

      final json = model.toJson();
      json.remove('id');
      json.remove('created_at');
      json.remove('updated_at');
      
      await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .update(json)
          .eq('id', vendor.id);

       // Update local cache
       await _localRepository.cachePartners([partner]);
    } catch (e) {
       debugPrint('Online update vendor failed: $e. Saving locally.');
       await _localRepository.updatePartner(partner);
    }
  }

  @override
  Future<void> deleteVendor(String id) async {
    // Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none)) {
       await _localRepository.deletePartner(id);
       return;
    }

    try {
      await SupabaseConfig.client
          .from('omtbl_businesspartners')
          .update({'is_active': 0})
          .eq('id', id);
          
      // Also delete locally if online success
      await _localRepository.deletePartner(id);

    } catch (e) {
      debugPrint('Online delete failed: $e. Falling back to local.');
      // Fallback
      try {
        await _localRepository.deletePartner(id);
      } catch (localE) {
        throw Exception('Failed to delete vendor: $e');
      }
    }
  }
}
