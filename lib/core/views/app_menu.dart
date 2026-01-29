import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/router/app_routes_config.dart';

class AppMenu extends ConsumerWidget {
  const AppMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // Filter by Role AND DB-Driven Permission (Read Access)
    final menuItems = appRoutes.where((r) => 
      r.roles.contains(auth.role) && 
      r.showInMenu &&
      auth.can(r.module, Permission.read)
    ).toList();

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
             accountName: Text('Role: ${auth.role.name.toUpperCase()}'),
             accountEmail: Text(auth.isLoggedIn ? 'Online' : 'Offline'),
             currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final route = menuItems[index];
                return ListTile(
                  leading: Icon(route.icon ?? Icons.circle_outlined),
                  title: Text(route.title),
                  onTap: () {
                    if (route.routeName != null) {
                      context.goNamed(route.routeName!);
                    } else {
                      context.go(route.path);
                    }
                    if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
                       Navigator.pop(context); 
                    }
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
