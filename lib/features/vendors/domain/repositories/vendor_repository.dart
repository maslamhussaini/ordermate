import 'package:ordermate/features/vendors/domain/entities/vendor.dart';

abstract class VendorRepository {
  Future<List<Vendor>> getVendors();
  Future<List<Vendor>> getSuppliers();
  Future<Vendor> createVendor(Vendor vendor);
  Future<void> updateVendor(Vendor vendor);
  Future<void> deleteVendor(String id);
}
