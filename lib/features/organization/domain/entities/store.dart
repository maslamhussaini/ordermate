import 'package:equatable/equatable.dart';

class Store extends Equatable {
  const Store({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.storeDefaultCurrency = 'USD',
    this.location,
    this.city,
    this.country,
    this.postalCode,
    this.phone,
    this.isActive = true,
  });

  final int id;
  final int organizationId;
  final String name;
  final String storeDefaultCurrency;
  final String? location;
  final String? city;
  final String? country;
  final String? postalCode;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        organizationId,
        name,
        storeDefaultCurrency,
        location,
        city,
        country,
        postalCode,
        phone,
        isActive,
        createdAt,
        updatedAt
      ];
}
