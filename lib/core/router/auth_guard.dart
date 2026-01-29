import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

String? authGuard(BuildContext context, GoRouterState state, String landingPage, bool isLoggedIn) {
  final isAuthenticated = isLoggedIn;
  final isGoingToLogin = state.matchedLocation == '/login';
  final isGoingToSplash = state.matchedLocation == '/splash';
  final isGoingToRegister = state.matchedLocation == '/register';
  final isGoingToOnboarding = state.matchedLocation.startsWith('/onboarding');
  final isGoingToResetPassword = state.matchedLocation == '/reset-password';

  // Allow splash screen
  if (isGoingToSplash) {
    return null;
  }

  // Redirect to login if not authenticated and not going to public routes
  if (!isAuthenticated && !isGoingToLogin && !isGoingToResetPassword && !isGoingToRegister && !isGoingToOnboarding) {
    return '/login'; // Use RouteNames.login if imported, but string is fine for return value of redirect
  }

  // Redirect to landing page if authenticated and going to login or register
  if (isAuthenticated && (isGoingToLogin || isGoingToRegister)) {
    return landingPage;
  }

  return null;
}
