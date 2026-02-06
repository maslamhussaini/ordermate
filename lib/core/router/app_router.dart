import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/core/router/app_routes_config.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/router/auth_guard.dart';
import 'package:ordermate/core/router/route_names.dart';
import 'package:ordermate/core/views/responsive_scaffold.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';

// Public/Auth Screens outside the Shell
import 'package:ordermate/features/auth/presentation/screens/login_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/register_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/splash_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/organization_setup_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/store_setup_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/team_setup_screen.dart';

// Helper to convert AppRoutes to GoRoutes recursively
List<GoRoute> buildGoRoutes(List<AppRoute> routes) {
  return routes.map((r) {
    return GoRoute(
      path: r.path,
      name: r.routeName,
      builder: r.builder,
      routes: buildGoRoutes(r.children),
    );
  }).toList();
}

// Helper to find metadata
AppRoute? findAppRoute(List<AppRoute> routes, String location, {String parentPath = ''}) {
  final cleanLocation = location.split('?').first;
  
  for (final route in routes) {
    // Construct full path for comparison
    String fullPath = route.path;
    if (!fullPath.startsWith('/') && parentPath.isNotEmpty) {
      fullPath = parentPath.endsWith('/') ? '$parentPath$fullPath' : '$parentPath/$fullPath';
    }
    
    // Normalize path to remove double slashes
    fullPath = fullPath.replaceAll('//', '/');

    // Simple path matching logic (handling :id parameters)
    if (_pathMatches(fullPath, cleanLocation)) {
      // If there are children, try to find a deeper match first
      if (route.children.isNotEmpty) {
        final childMatch = findAppRoute(route.children, cleanLocation, parentPath: fullPath);
        if (childMatch != null) return childMatch;
      }
      return route;
    }

    // Recurse if the current route is a parent prefix of the target location
    // Ensure we only match true parents (e.g. /accounting matches /accounting/coa but not /accounting-reports)
    final isParent = fullPath.startsWith('/') && 
                    (cleanLocation.startsWith('$fullPath/') || cleanLocation == fullPath);

    if (isParent && route.children.isNotEmpty) {
       final childMatch = findAppRoute(route.children, cleanLocation, parentPath: fullPath);
       if (childMatch != null) return childMatch;
    }
  }
  return null;
}

bool _pathMatches(String routePath, String location) {
  if (routePath == location) return true;
  
  // Handle path parameters like :id
  final pattern = routePath.replaceAllMapped(RegExp(r':\w+'), (match) => r'[^/]+');
  final regex = RegExp('^' + pattern + r'$');
  return regex.hasMatch(location);
}

final routerProvider = Provider<GoRouter>((ref) {
  // Use ref.read inside redirect to prevent router recreation on state changes
  // Listens to provider changes via refreshListenable
  
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final auth = ref.read(authProvider);
      
      // 0. Safeguard for Supabase tokens in URL fragment being parsed as paths
      if (state.matchedLocation.contains('access_token')) {
         debugPrint('Router: Token detected in path, redirecting to splash/handle');
         return '/splash';
      }
 
      // 1. Password Recovery Guard (Highest Priority)
      if (auth.isPasswordRecovery && state.matchedLocation != '/reset-password') {
         debugPrint('Router: Redirecting to password recovery');
         return '/reset-password';
      }
 
      // 2. Auth Check (Login/Splash logic)
      final authRedirect = authGuard(context, state, settings.landingPage, auth);
      if (authRedirect != null) return authRedirect;

      // 3. Logic for Logged In Users (Redirect to login covered by authGuard)
      if (!auth.isLoggedIn) return null;

      // 4. Workspace Selection check (Org, Store, Year) 
      // Mandatory before dashboard access
      final orgState = ref.read(organizationProvider);
      
      if (orgState.isInitialized) {
        final isWorkspaceSelected = orgState.selectedOrganization != null && 
                                    orgState.selectedStore != null && 
                                    orgState.selectedFinancialYear != null;

        final location = state.matchedLocation;
        
        // Exempt onboarding and workspace-selection itself
        final isExempt = location.startsWith('/onboarding') || 
                         location == '/workspace-selection' || 
                         location.startsWith('/organizations-list') || 
                         location == '/splash' ||
                         location == '/login';

        if (!isWorkspaceSelected && !isExempt) {
            debugPrint('Router: Workspace not fully configured (Org: ${orgState.selectedOrganizationId}, Store: ${orgState.selectedStoreId}, Year: ${orgState.selectedFinancialYear}). Redirecting to workspace-selection.');
            return '/workspace-selection';
        }
      } else {
        // While initializing, if we're logged in, we stay on splash or whatever non-auth page we're at
        debugPrint('Router: Workspace initializing...');
        return null;
      }
      
      final location = state.matchedLocation;
      
      // 4. Permission & Role Guard
      // If permissions are still loading from the DB, don't redirect yet
      if (auth.isPermissionLoading) {
         debugPrint('Router: Permissions loading, skipping RBAC for $location');
         return null;
      }

      final route = findAppRoute(appRoutes, location);

      if (route != null) {
         // A. Role Check 
         if (auth.role != UserRole.superUser && !route.roles.contains(auth.role)) {
             debugPrint('RBAC: Role ${auth.role} denied for $location');
             return '/dashboard';
         }
         
         // B. Granular Permission Check (Read Access)
         // DB-Driven logic: Check if user has 'read' permission for this module
         if (!auth.can(route.module, Permission.read)) {
             debugPrint('RBAC: Permission Read denied for module ${route.module}');
             return '/dashboard';
         }
      }

      return null;
    },
    refreshListenable: _RiverpodListenable(ref), // Listens to provider changes including Auth
    routes: [
      GoRoute(path: '/splash', name: RouteNames.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', name: RouteNames.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', name: RouteNames.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/signup', redirect: (_, __) => '/register'),
      GoRoute(path: '/reset-password', name: RouteNames.resetPassword, builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(path: '/organizations', redirect: (context, state) => '/organizations-list'),
      GoRoute(path: '/onboarding', redirect: (context, state) => state.fullPath == '/onboarding' ? '/onboarding/organization' : null, routes: [
           GoRoute(path: 'organization', builder: (context, state) => OrganizationSetupScreen(userData: state.extra as Map<String, String>)),
           GoRoute(path: 'store', builder: (context, state) { final extra = state.extra as Map<String, dynamic>; return StoreSetupScreen(userData: extra['userData'] as Map<String, String>, orgData: extra['orgData'] as Map<String, String>); }),
           GoRoute(path: 'team', builder: (context, state) => TeamSetupScreen(onboardingData: state.extra as Map<String, dynamic>)),
      ]),

      ShellRoute(
        builder: (context, state, child) {
          return ResponsiveScaffold(state: state, child: child);
        },
        routes: buildGoRoutes(appRoutes),
      ),
      
      // Catch-all route for malformed URLs or Supabase tokens
      GoRoute(path: '/:catchAll(.*)', builder: (_, __) => const SplashScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(body: Center(child: Text('Page Not Found: ${state.error}')))
  );
});

// Helper class to make GoRouter listen to Riverpod
class _RiverpodListenable extends ChangeNotifier {
  _RiverpodListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(settingsProvider, (_, __) => notifyListeners());
    ref.listen(organizationProvider, (_, __) => notifyListeners());
  }
}
