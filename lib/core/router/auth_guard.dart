import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ordermate/core/providers/auth_provider.dart';

String? authGuard(BuildContext context, GoRouterState state, String landingPage,
    AuthState auth) {
  final isAuthenticated = auth.isLoggedIn;
  final isGoingToLogin = state.matchedLocation == '/login';
  final isGoingToSplash = state.matchedLocation == '/splash';
  final isGoingToRegister = state.matchedLocation == '/register' ||
      state.matchedLocation == '/signup';
  final isGoingToOnboarding = state.matchedLocation.startsWith('/onboarding');
  final isGoingToResetPassword = state.matchedLocation == '/reset-password';

  // Allow splash screen
  if (isGoingToSplash) {
    return null;
  }

  // Password Recovery Flow
  if (auth.isPasswordRecovery) {
    if (!isGoingToResetPassword) {
      return '/reset-password';
    }
    return null;
  }

  // Redirect to login if not authenticated and not going to public routes
  if (!isAuthenticated &&
      !isGoingToLogin &&
      !isGoingToResetPassword &&
      !isGoingToRegister &&
      !isGoingToOnboarding) {
    return '/login';
  }

  // Redirect to workspace selection if authenticated and going to login or register
  if (isAuthenticated && (isGoingToLogin || isGoingToRegister)) {
    return '/workspace-selection';
  }

  return null;
}
