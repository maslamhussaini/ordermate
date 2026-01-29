import 'package:equatable/equatable.dart';

class AppRole extends Equatable {
  final int id;
  final String roleName;
  final String? description;
  final int? organizationId;
  final int? departmentId;
  final bool canRead;
  final bool canWrite;
  final bool canEdit;
  final bool canPrint;

  const AppRole({
    required this.id,
    required this.roleName,
    this.description,
    required this.organizationId,
    this.departmentId,
    this.canRead = false,
    this.canWrite = false,
    this.canEdit = false,
    this.canPrint = false,
  });

  factory AppRole.fromJson(Map<String, dynamic> json) {
    return AppRole(
      id: json['id'] as int,
      roleName: json['role_name'] as String,
      description: json['description'] as String?,
      organizationId: (json['organization_id'] as int?) ?? 0,
      departmentId: json['department_id'] as int?,
      canRead: json['can_read'] == 1 || json['can_read'] == true,
      canWrite: json['can_write'] == 1 || json['can_write'] == true,
      canEdit: json['can_edit'] == 1 || json['can_edit'] == true,
      canPrint: json['can_print'] == 1 || json['can_print'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_name': roleName,
      'description': description,
      'organization_id': organizationId,
      'department_id': departmentId,
      'can_read': canRead ? 1 : 0,
      'can_write': canWrite ? 1 : 0,
      'can_edit': canEdit ? 1 : 0,
      'can_print': canPrint ? 1 : 0,
    };
  }

  @override
  List<Object?> get props => [
        id,
        roleName,
        description,
        organizationId,
        departmentId,
        canRead,
        canWrite,
        canEdit,
        canPrint,
      ];
}
