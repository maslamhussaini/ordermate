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
import 'package:ordermate/features/auth/presentation/screens/organization_configure_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/store_setup_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/team_setup_screen.dart';
import 'package:ordermate/features/auth/presentation/screens/email_verification_screen.dart';

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
AppRoute? findAppRoute(List<AppRoute> routes, String location,
    {String parentPath = ''}) {
  final cleanLocation = location.split('?').first;

  for (final route in routes) {
    // Construct full path for comparison
    String fullPath = route.path;
    if (!fullPath.startsWith('/') && parentPath.isNotEmpty) {
      fullPath = parentPath.endsWith('/')
          ? '$parentPath$fullPath'
          : '$parentPath/$fullPath';
    }

    // Normalize path to remove double slashes
    fullPath = fullPath.replaceAll('//', '/');

    // Simple path matching logic (handling :id parameters)
    if (_pathMatches(fullPath, cleanLocation)) {
      // If there are children, try to find a deeper match first
      if (route.children.isNotEmpty) {
        final childMatch =
            findAppRoute(route.children, cleanLocation, parentPath: fullPath);
        if (childMatch != null) return childMatch;
      }
      return route;
    }

    // Recurse if the current route is a parent prefix of the target location
    // Ensure we only match true parents (e.g. /accounting matches /accounting/coa but not /accounting-reports)
    final isParent = fullPath.startsWith('/') &&
        (cleanLocation.startsWith('$fullPath/') || cleanLocation == fullPath);

    if (isParent && route.children.isNotEmpty) {
      final childMatch =
          findAppRoute(route.children, cleanLocation, parentPath: fullPath);
      if (childMatch != null) return childMatch;
    }
  }
  return null;
}

bool _pathMatches(String routePath, String location) {
  if (routePath == location) return true;

  // Handle path parameters like :id
  final pattern =
      routePath.replaceAllMapped(RegExp(r':\w+'), (match) => r'[^/]+');
  final regex = RegExp('^' + pattern + r'$');
  return regex.hasMatch(location);
}

final routerProvider = Provider<GoRouter>((ref) {
  // Use ref.read to keep the GoRouter instance stable across state changes.
  // This prevents the application from resetting to the initial route (/splash) 
  // every time a dependency changes, which was causing the infinite loop.

  return GoRouter(
      initialLocation: '/splash',
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final settings = ref.read(settingsProvider);
        final auth = ref.read(authProvider);
        final location = state.matchedLocation;
        debugPrint('Router: Redirect check for $location');

        // 0. Safeguard for Supabase tokens
        if (location.contains('access_token')) {
          debugPrint('Router: Token detected in path, redirecting to splash');
          return '/splash';
        }

        // 1. Password Recovery Guard
        if (auth.isPasswordRecovery &&
            state.matchedLocation != '/reset-password') {
          return '/reset-password';
        }

        // 2. Auth Check (Login/Splash logic)
        final authRedirect =
            authGuard(context, state, settings.landingPage, auth);
        if (authRedirect != null) return authRedirect;

        // 3. Logic for Logged In Users
        if (!auth.isLoggedIn) return null;

        if (settings.offlineMode) return null;

        // 4. Workspace Selection check
        final orgState = ref.read(organizationProvider);
        final isWorkspaceSelected = orgState.selectedOrganization != null &&
            orgState.selectedStore != null &&
            orgState.selectedFinancialYear != null;

        // final location = state.matchedLocation; // Moved to top

        // Exempt onboarding and workspace-selection
        final isWorkspacePath = location.startsWith('/workspace-selection') ||
            location == '/organizations-list' ||
            location.startsWith('/onboarding') ||
            location.startsWith('/module-access') ||
            location == '/splash';

        if (!isWorkspaceSelected && !isWorkspacePath) {
          debugPrint(
              'Router: Workspace missing (Org: ${orgState.selectedOrganizationId}, Store: ${orgState.selectedStoreId}, Year: ${orgState.selectedFinancialYear}). Redirecting.');
          return '/workspace-selection';
        }

        if (isWorkspaceSelected && location.startsWith('/workspace-selection')) {
          return null;
        }

        // 5. Permission & Role Guard
        if (auth.isPermissionLoading) {
          debugPrint('Router: Permissions loading, skipping RBAC for $location');
          return null;
        }

        if (location.startsWith('/workspace-selection')) return null;

        final route = findAppRoute(appRoutes, location);

        if (route != null) {
          if (auth.role != UserRole.superUser &&
              !route.roles.contains(auth.role)) {
            debugPrint('RBAC: Role ${auth.role} denied for $location');
            return '/dashboard';
          }

          if (!auth.can(route.module, Permission.read)) {
            debugPrint('RBAC: Permission Read denied for ${route.module}');
            return '/dashboard';
          }
        }

        return null;
      },
      // GoRouter automatically listens to this if it manages to survive rebuilds, 
      // but since we watch at top level, recreated GoRouter will pick up new state.
      // We can actually omit refreshListenable if we watch at top level, 
      // but keeping it doesn't hurt as long as it doesn't use the ref in a stale way.
      refreshListenable: _RiverpodListenable(ref), 
      routes: [
        GoRoute(
            path: '/splash',
            name: RouteNames.splash,
            builder: (_, __) => const SplashScreen()),
        GoRoute(
            path: '/login',
            name: RouteNames.login,
            builder: (_, __) => const LoginScreen()),
        GoRoute(
            path: '/register',
            name: RouteNames.register,
            builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/signup', redirect: (_, __) => '/register'),
        GoRoute(
            path: '/reset-password',
            name: RouteNames.resetPassword,
            builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(
            path: '/organizations',
            redirect: (context, state) => '/organizations-list'),
        GoRoute(
            path: '/onboarding',
            redirect: (context, state) => state.fullPath == '/onboarding'
                ? '/onboarding/organization'
                : null,
            routes: [
              GoRoute(
                  path: 'organization',
                  builder: (context, state) => OrganizationSetupScreen(
                      userData: state.extra as Map<String, dynamic>)),
              GoRoute(
                  path: 'store',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>;
                    return StoreSetupScreen(
                        userData: extra['userData'] as Map<String, dynamic>,
                        orgData: extra['orgData'] as Map<String, dynamic>);
                  }),
              GoRoute(
                  path: 'team',
                  builder: (context, state) => TeamSetupScreen(
                      onboardingData: state.extra as Map<String, dynamic>)),
              GoRoute(
                  path: 'verify',
                  builder: (context, state) => EmailVerificationScreen(
                      onboardingData: state.extra as Map<String, dynamic>)),
              GoRoute(
                  path: 'configure/:orgId',
                  builder: (context, state) {
                    final orgIdStr = state.pathParameters['orgId'];
                    final orgId = int.tryParse(orgIdStr ?? '') ?? 0;
                    return OrganizationConfigureScreen(orgId: orgId);
                  }),
            ]),

        ShellRoute(
          builder: (context, state, child) {
            return ResponsiveScaffold(state: state, child: child);
          },
          routes: buildGoRoutes(appRoutes),
        ),

        // Catch-all route for malformed URLs or Supabase tokens
        GoRoute(
            path: '/:catchAll(.*)', builder: (_, __) => const SplashScreen()),
      ],
      errorBuilder: (context, state) => Scaffold(
          body: Center(child: Text('Page Not Found: ${state.error}'))));
});

// Helper class to make GoRouter listen to Riverpod
class _RiverpodListenable extends ChangeNotifier {
  _RiverpodListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => _safeNotify());
    ref.listen(settingsProvider, (_, __) => _safeNotify());
    ref.listen(organizationProvider, (_, __) => _safeNotify());
  }

  void _safeNotify() {
    // notifyListeners() can lead to synchronous redirect() call.
    // If redirect() uses ref.read(), it might trigger an assertion if called
    // while a provider is still updating its dependencies.
    // Using microtask ensures it runs after the current build/update cycle.
    Future.microtask(() => notifyListeners());
  }
}
