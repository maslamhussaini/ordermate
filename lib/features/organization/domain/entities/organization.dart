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
  });

  final int id;
  final String name;
  final String? code;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? logoUrl;
  final int storeCount;

  @override
  List<Object?> get props =>
      [id, name, code, isActive, createdAt, updatedAt, logoUrl, storeCount];
}
