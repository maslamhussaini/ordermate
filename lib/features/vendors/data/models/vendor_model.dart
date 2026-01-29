import 'package:ordermate/features/vendors/domain/entities/vendor.dart';

class VendorModel extends Vendor {
  const VendorModel({
    required super.id,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    super.contactPerson,
    super.phone,
    super.email,
    super.address,
    super.isSupplier,
    super.isActive,
    required super.organizationId,
    required super.storeId,
    super.productCount,
    super.chartOfAccountId,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      isSupplier: json['is_supplier'] == 1 || json['is_supplier'] == true,
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == null,
      productCount: _parseProductCount(json['product_count']),
      organizationId: (json['organization_id'] as int?) ?? 0,
      storeId: (json['store_id'] as int?) ?? 0,
      chartOfAccountId: json['chart_of_account_id']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static int _parseProductCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is List) {
      if (value.isEmpty) return 0;
      final first = value.first;
      if (first is Map && first.containsKey('count')) {
        return first['count'] as int? ?? 0;
      }
      return value.length;
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'is_supplier': isSupplier ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'organization_id': organizationId,
      'store_id': storeId,
      'chart_of_account_id': chartOfAccountId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
