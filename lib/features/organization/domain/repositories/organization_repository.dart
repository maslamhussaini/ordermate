import 'dart:io';
import 'dart:typed_data';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';

abstract class OrganizationRepository {
  // Organization
  Future<List<Organization>> getOrganizations();
  Future<Organization?> getOrganization(int id);
  Future<void> updateOrganization(Organization organization);
  Future<String> uploadOrganizationLogo(File file);
  Future<Organization> createOrganization(
    String name,
    String? taxId,
    bool hasMultipleBranches,
    String? logoUrl,
  );
  Future<void> deleteOrganization(int id);

  // Logo caching
  Future<void> cacheLogo(int orgId, Uint8List logoBytes);
  Future<Uint8List?> getCachedLogo(int orgId);

  // Stores
  Future<List<Store>> getStores(int organizationId);
  Future<Store> createStore(Store store);
  Future<void> updateStore(Store store);
  Future<void> deleteStore(int storeId);
}
