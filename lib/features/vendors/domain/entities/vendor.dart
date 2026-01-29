// lib/features/vendors/domain/entities/vendor.dart

import 'package:equatable/equatable.dart';

class Vendor extends Equatable {
  const Vendor({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.isSupplier = false,
    this.isActive = true,
    this.productCount,
    required this.organizationId,
    required this.storeId,
    this.chartOfAccountId,
  });
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final bool isSupplier;
  final bool isActive;
  final int? productCount;
  final int organizationId;
  final int storeId;
  final String? chartOfAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vendor copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    bool? isSupplier,
    bool? isActive,
    int? productCount,
    int? organizationId,
    int? storeId,
    String? chartOfAccountId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      isSupplier: isSupplier ?? this.isSupplier,
      isActive: isActive ?? this.isActive,
      productCount: productCount ?? this.productCount,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      chartOfAccountId: chartOfAccountId ?? this.chartOfAccountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        contactPerson,
        phone,
        email,
        address,
        isSupplier,
        isActive,
        productCount,
        organizationId,
        storeId,
        chartOfAccountId,
        createdAt,
        updatedAt,
      ];
}

