import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/core/router/app_routes_config.dart';
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
AppRoute? findAppRoute(List<AppRoute> routes, String location) {
  // First pass: Exact match (highest priority)
  for (final r in routes) {
    if (location == r.path) return r;
  }

  // Second pass: Prefix match with children (recursive)
  for (final r in routes) {
    if (r.path.startsWith('/') && location.startsWith(r.path)) {
      // Ensure it's a true directory match or perfect prefix (e.g., /orders matches /orders/create)
      // Check if the next character is a slash or if it's the end of string
      if (location.length == r.path.length || location[r.path.length] == '/') {
        final child = findAppRoute(r.children, location);
        if (child != null) return child;
        return r;
      }
    }
  }
  return null;
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
      
      // 1. Password Recovery Guard (Highest Priority)
      if (auth.isPasswordRecovery && state.matchedLocation != '/reset-password') {
         debugPrint('Router: Redirecting to password recovery');
         return '/reset-password';
      }
 
      // 2. Auth Check (Login/Splash logic)
      final authRedirect = authGuard(context, state, settings.landingPage, auth);
      if (authRedirect != null) return authRedirect;

      // 3. Logic for Logged In Users
      if (!auth.isLoggedIn) return '/login';
      
      // 4. Permission & Role Guard
      final route = findAppRoute(appRoutes, state.matchedLocation);

      if (route != null) {
         // A. Role Check 
         if (!route.roles.contains(auth.role)) {
             debugPrint('RBAC: Role ${auth.role} denied for ${state.matchedLocation}');
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
    ],
    errorBuilder: (context, state) => Scaffold(body: Center(child: Text('Page Not Found: ${state.error}')))
  );
});

// Helper class to make GoRouter listen to Riverpod
class _RiverpodListenable extends ChangeNotifier {
  _RiverpodListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(settingsProvider, (_, __) => notifyListeners());
  }
}
