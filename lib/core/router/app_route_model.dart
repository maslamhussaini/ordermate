import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/enums/user_role.dart';

class AppRoute {
  final String path;
  final String title; // Display Name (Menu)
  final String? routeName; // GoRouter Name (Slug)
  final String module; // Permission Module
  final Widget Function(BuildContext, GoRouterState) builder;
  final List<UserRole> roles;
  final IconData? icon;
  final List<AppRoute> children;
  final bool showInMenu;

  AppRoute({
    required this.path,
    required this.title,
    required this.module,
    required this.builder,
    required this.roles,
    this.routeName,
    this.icon,
    this.children = const [],
    this.showInMenu = true, // Defaults to true, set false for details pages
  });
}
