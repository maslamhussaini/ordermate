import 'package:equatable/equatable.dart';

class Organization extends Equatable {
  const Organization({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.logoUrl,
    this.storeCount = 0,
    this.businessTypeId,
    this.isGL = false,
    this.isSales = false,
    this.isInventory = false,
    this.isHR = false,
    this.isSettings = true,
  });

  final int id;
  final String name;
  final String? code;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? logoUrl;
  final int storeCount;
  final int? businessTypeId;
  final bool isGL;
  final bool isSales;
  final bool isInventory;
  final bool isHR;
  final bool isSettings;

  @override
  List<Object?> get props => [
        id,
        name,
        code,
        isActive,
        createdAt,
        updatedAt,
        logoUrl,
        storeCount,
        businessTypeId,
        isGL,
        isSales,
        isInventory,
        isHR,
        isSettings,
      ];
}
