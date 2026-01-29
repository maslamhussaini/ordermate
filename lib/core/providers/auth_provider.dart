import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/entities/permission_object.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/services/auth_service.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthState {
  final String userFullName;
  final bool isLoggedIn;
  final bool isPasswordRecovery;
  final UserRole role;
  final List<PermissionObject> permissions;
 
  const AuthState({
    this.userFullName = '',
    this.isLoggedIn = false,
    this.isPasswordRecovery = false,
    this.role = UserRole.staff,
    this.permissions = const [],
  });

  bool can(String module, Permission action) {
    if (role == UserRole.admin) return true; 

    return permissions.any(
      (p) => p.module == module && p.action == action,
    );
  }
  
  AuthState copyWith({
    String? userFullName,
    bool? isLoggedIn,
    bool? isPasswordRecovery,
    UserRole? role,
    List<PermissionObject>? permissions,
  }) {
    return AuthState(
      userFullName: userFullName ?? this.userFullName,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<supabase.AuthState>? _authSubscription;

  @override
  AuthState build() {
    final initialState = AuthState(
      isLoggedIn: AuthService.isLoggedIn,
      role: AuthService.role,
      permissions: _getPermissionsForRole(AuthService.role),
    );
    
    // Listen to Supabase Auth Changes
    _setupAuthListener();
    
    // Attempt to load dynamic permissions if logged in
    if (initialState.isLoggedIn) {
      Future.microtask(() => loadDynamicPermissions());
    }
    
    // Cleanup on dispose
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return initialState;
  }

  void _setupAuthListener() {
    _authSubscription?.cancel(); // Cancel any existing
    
    // Subscribe to the Supabase Auth State Stream
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      debugPrint('AuthNotifier: Event $event');

      if (event == supabase.AuthChangeEvent.passwordRecovery) {
         state = state.copyWith(
           isLoggedIn: true,
           isPasswordRecovery: true,
         );
      } else if (event == supabase.AuthChangeEvent.signedIn) {
         // Only update if not already logged in to avoid loops
         if (!state.isLoggedIn) {
             final fullName = session?.user.userMetadata?['full_name'] ?? '';
             // Default to existing role or fetch? We'll rely on the existing login method logic ideally,
             // but for auto-login we assume basic access until profile is fetched.
             state = state.copyWith(
               isLoggedIn: true,
               userFullName: fullName,
               isPasswordRecovery: false, 
             );
             loadDynamicPermissions();
         }
      } else if (event == supabase.AuthChangeEvent.signedOut) {
         logout();
      }
    });
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
      // 1. Get User Profile
      final userResponse = await SupabaseConfig.client
          .from('omtbl_users')
          .select('id, role_id, role, full_name')
          .eq('auth_id', sessionUser.id)
          .maybeSingle();

      if (userResponse == null) return;

      final roleId = userResponse['role_id'] as int?;
      final employeeId = userResponse['id'] as String?;
      final roleStr = (userResponse['role'] as String?)?.toUpperCase();
      final fullName = userResponse['full_name'] as String?;

      if (fullName != null && fullName.isNotEmpty) {
         state = state.copyWith(userFullName: fullName);
      }

      // Corporate Admins bypass all checks
      if (roleStr == 'CORPORATE_ADMIN') return;

      // 2. Fetch Privileges
      final privsResponse = await SupabaseConfig.client
          .from('omtbl_role_form_privileges')
          .select('*, omtbl_app_forms(form_code, module_name)')
          .or('role_id.eq.$roleId,employee_id.eq.$employeeId');

      if (privsResponse.isEmpty) return;

      // 3. Map Privileges
      final List<PermissionObject> dynamicPermissions = [];
      for (var p in privsResponse) {
        final form = p['omtbl_app_forms'] as Map<String, dynamic>?;
        if (form == null) continue;

        final module = form['form_code'].toString().toLowerCase().replaceFirst('frm_', '');
        
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
      isPasswordRecovery: false, 
    );
    AuthService.testRole = role; 
    loadDynamicPermissions();
  }
  
  void logout() {
    state = const AuthState(isLoggedIn: false);
    AuthService.testRole = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
