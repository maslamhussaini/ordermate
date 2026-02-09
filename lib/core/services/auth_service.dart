import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/network/supabase_client.dart';

class AuthService {
  // Check if user is logged in via Supabase or Offline Mode
  static bool? _testIsLoggedIn;
  static set testIsLoggedIn(bool? val) => _testIsLoggedIn = val;

  static bool get isLoggedIn =>
      _testIsLoggedIn ??
      (SupabaseConfig.currentUser != null || SupabaseConfig.isOfflineLoggedIn);

  // TODO: Fetch actual role from user profile/metadata
  static UserRole? _testRole;
  static set testRole(UserRole? role) => _testRole = role;

  static UserRole get role => _testRole ?? UserRole.admin;

  static String? get currentUserId => SupabaseConfig.currentUser?.id;

  static Set<Permission> permissionsFor(String module) {
    return role == UserRole.admin
        ? RolePermissions.admin[module] ?? <Permission>{}
        : RolePermissions.staff[module] ?? <Permission>{};
  }
}
