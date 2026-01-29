import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/entities/permission_object.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/services/auth_service.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:flutter/foundation.dart';

class AuthState {
  final String userFullName;
  final bool isLoggedIn;
  final UserRole role;
  final List<PermissionObject> permissions;
 
  const AuthState({
    this.userFullName = '',
    this.isLoggedIn = false,
    this.role = UserRole.staff,
    this.permissions = const [],
  });

  bool can(String module, Permission action) {
    // Admins usually have all permissions, but strict DB model might separate.
    // For Enterprise, even Admins rely on DB permissions (Implicitly All or Explicitly All).
    // Here we check explicit permissions OR Role override.
    if (role == UserRole.admin) return true; 

    return permissions.any(
      (p) => p.module == module && p.action == action,
    );
  }
  
  AuthState copyWith({
    String? userFullName,
    bool? isLoggedIn,
    UserRole? role,
    List<PermissionObject>? permissions,
  }) {
    return AuthState(
      userFullName: userFullName ?? this.userFullName,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Initial State: Synced with static AuthService for compatibility or DB load
    final initialState = AuthState(
      isLoggedIn: AuthService.isLoggedIn,
      role: AuthService.role,
      permissions: _getPermissionsForRole(AuthService.role),
    );
    
    // Attempt to load dynamic permissions if logged in
    if (initialState.isLoggedIn) {
      Future.microtask(() => loadDynamicPermissions());
    }
    
    return initialState;
  }
  
  // Fetch Permissions from the RolePermissions Configuration (Static Defaults)
  List<PermissionObject> _getPermissionsForRole(UserRole role) {
    final Map<String, Set<Permission>> permissionMap = (role == UserRole.admin) 
        ? RolePermissions.admin 
        : RolePermissions.staff;

    List<PermissionObject> objects = [];
    permissionMap.forEach((module, actions) {
      for (final action in actions) {
        objects.add(PermissionObject(module, action));
      }
    });

    return objects;
  }

  /// Loads permissions from omtbl_role_form_privileges for the current user
  Future<void> loadDynamicPermissions() async {
    final sessionUser = SupabaseConfig.client.auth.currentUser;
    if (sessionUser == null) return;

    try {
      // 1. Get User Profile to find Role ID and Employee ID
      final userResponse = await SupabaseConfig.client
          .from('omtbl_users')
          .select('id, role_id, role')
          .eq('auth_id', sessionUser.id)
          .maybeSingle();

      if (userResponse == null) return;

      final roleId = userResponse['role_id'] as int?;
      final employeeId = userResponse['id'] as String?;
      final roleStr = (userResponse['role'] as String?)?.toUpperCase();

      // Corporate Admins bypass all checks (logic in AuthState.can)
      if (roleStr == 'CORPORATE_ADMIN') return;

      // 2. Fetch Privileges
      final privsResponse = await SupabaseConfig.client
          .from('omtbl_role_form_privileges')
          .select('*, omtbl_app_forms(form_code, module_name)')
          .or('role_id.eq.$roleId,employee_id.eq.$employeeId');

      if (privsResponse.isEmpty) return;

      // 3. Map Privileges to PermissionObjects
      final List<PermissionObject> dynamicPermissions = [];
      for (var p in privsResponse) {
        final form = p['omtbl_app_forms'] as Map<String, dynamic>?;
        if (form == null) continue;

        final module = form['form_code'].toString().toLowerCase().replaceFirst('frm_', '');
        
        // Map Database flags to Enum Permission
        if (p['can_view'] == true || p['can_read'] == true) {
          dynamicPermissions.add(PermissionObject(module, Permission.read));
        }
        if (p['can_add'] == true || p['can_edit'] == true) {
          dynamicPermissions.add(PermissionObject(module, Permission.write));
        }
        if (p['can_delete'] == true) {
          dynamicPermissions.add(PermissionObject(module, Permission.delete));
        }
      }

      // 4. Fallback to module-level permissions if form-specific not found?
      // For now, we Merge or Replace? 
      // The user wants it "Dynamic as pvg", so we should probably REPLACE or strongly PRIORITIZE these.
      if (dynamicPermissions.isNotEmpty) {
        state = state.copyWith(permissions: dynamicPermissions);
      }
      
    } catch (e) {
      debugPrint('Error loading dynamic permissions: $e');
    }
  }
  
  void login(UserRole role, {String fullName = ''}) {
    state = state.copyWith(
      isLoggedIn: true, 
      role: role,
      userFullName: fullName,
      permissions: _getPermissionsForRole(role),
    );
    // Sync static for backward compat if needed
    AuthService.testRole = role; 

    // Load dynamic perks after successful auth
    loadDynamicPermissions();
  }
  
  void logout() {
    state = const AuthState(isLoggedIn: false);
    AuthService.testRole = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
