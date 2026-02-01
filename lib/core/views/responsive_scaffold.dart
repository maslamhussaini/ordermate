import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/router/app_routes_config.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/views/breadcrumbs.dart';
import 'package:ordermate/core/widgets/app_drawer.dart';
import 'package:ordermate/features/auth/domain/entities/user.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';

class ResponsiveScaffold extends ConsumerWidget {
  final Widget child;
  final GoRouterState state;

  const ResponsiveScaffold({super.key, required this.child, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop breakpoint > 900
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final accountingState = ref.watch(accountingProvider);
    final selectedYear = accountingState.selectedFinancialSession?.sYear;

    return Scaffold(
      appBar: AppBar(
        // On desktop, we hide the hamburger (drawer icon) because sidebar is always visible
        leading: isDesktop ? const SizedBox.shrink() : null,
        title: _buildAppBarTitle(context, ref, state),
        actions: [

// Year Indicator
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
               final sessions = accountingState.financialSessions;
               final currentSession = accountingState.selectedFinancialSession;
               
               showDialog(
                 context: context, 
                 builder: (context) {
                    return AlertDialog(
                       title: const Text('Select Financial Year'),
                       content: SizedBox(
                         width: double.maxFinite,
                         child: ListView(
                            shrinkWrap: true,
                            children: [
                               ListTile(
                                 title: const Text('All Years'),
                                 leading: const Icon(Icons.calendar_view_week),
                                 selected: currentSession == null,
                                 onTap: () {
                                    ref.read(accountingProvider.notifier).selectFinancialSession(null);
                                    Navigator.pop(context);
                                 },
                               ),
                               const Divider(),
                               if (sessions.isEmpty)
                                 const ListTile(title: Text('No Financial Sessions Configured')),
                               ...sessions.map((s) => ListTile(
                                  title: Text('${s.sYear}'),
                                  subtitle: Text('${DateFormat.yMMMd().format(s.startDate)} - ${DateFormat.yMMMd().format(s.endDate)}'),
                                  leading: Icon(Icons.calendar_today, color: s.isClosed ? Colors.grey : Colors.green),
                                  trailing: s.isClosed 
                                      ? const Chip(label: Text('Closed', style: TextStyle(fontSize: 10)), backgroundColor: Colors.redAccent) 
                                      : const Chip(label: Text('Active', style: TextStyle(fontSize: 10)), backgroundColor: Colors.greenAccent),
                                  selected: currentSession?.sYear == s.sYear,
                                  onTap: () {
                                    ref.read(accountingProvider.notifier).selectFinancialSession(s);
                                    Navigator.pop(context);
                                  },
                               )).toList(),
                            ]
                         ),
                       ),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                       ],
                    );
                 }
               );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selectedYear != null 
                      ? Theme.of(context).colorScheme.primaryContainer.withAlpha(51) // Suble highlight
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selectedYear != null 
                        ? Theme.of(context).colorScheme.primary.withAlpha(76)
                        : (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedYear != null ? Icons.calendar_month : Icons.calendar_today, 
                      size: 16, 
                      color: selectedYear != null ? Theme.of(context).colorScheme.primary : Colors.grey
                    ),
                    const SizedBox(width: 6),
                    Text(
                      accountingState.selectedFinancialSession != null
                          ? '${accountingState.selectedFinancialSession!.sYear} (${DateFormat('MMM yy').format(accountingState.selectedFinancialSession!.startDate)} - ${DateFormat('MMM yy').format(accountingState.selectedFinancialSession!.endDate)})'
                          : 'All Years',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: selectedYear != null 
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface.withAlpha(178),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Workspace Selector
          IconButton(
            icon: const Icon(Icons.business_center_rounded, color: Colors.blueAccent),
            tooltip: 'Switch Workspace',
            onPressed: () => context.go('/workspace-selection'),
          ),

          // User Profile / Logout
          PopupMenuButton<String>(
            tooltip: 'My Profile',
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             icon: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.black54), // Darker icon for visibility on light/default appbar
            ),
            itemBuilder: (BuildContext context) {
              final userProfile = ref.watch(userProfileProvider).value;
              final orgState = ref.read(organizationProvider);
              final selectedOrg = orgState.selectedOrganization;
              final selectedStore = orgState.selectedStore;
              final sessionUser = SupabaseConfig.client.auth.currentUser;

              return [
                // User Profile Header
                PopupMenuItem<String>(
                  enabled: true,
                  onTap: () => _handleUserHeaderTap(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.person, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (userProfile?.fullName.isNotEmpty == true) 
                                    ? userProfile!.fullName 
                                    : (sessionUser?.userMetadata?['full_name'] as String?) ?? userProfile?.email ?? sessionUser?.email ?? 'User',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (userProfile?.email != null || sessionUser?.email != null)
                                Text(
                                  userProfile?.email ?? sessionUser?.email ?? '',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white54 
                                        : Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),

                // Workspace / Organization
                PopupMenuItem<String>(
                  enabled: true,
                  onTap: () {
                    if (selectedOrg != null) {
                      _showOrgDetailsDialog(context, selectedOrg, orgState.stores.length);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white10 
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.business, 
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade600, 
                            size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedOrg?.name ?? 'No Organization',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Workspace',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white54 
                                      : Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Current Store
                PopupMenuItem<String>(
                  enabled: true,
                  onTap: () {
                    if (selectedStore != null) {
                      _showStoreDetailsDialog(context, selectedStore);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.teal.withValues(alpha: 0.2) 
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.store, color: Colors.teal, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedStore?.name ?? 'All Stores',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Current Store',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white54 
                                      : Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),

                // Subscription Plan
                PopupMenuItem<String>(
                  enabled: true,
                  onTap: null, // Let button handle interaction
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Free',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'SUBSCRIPTION',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                             Navigator.pop(context); // Close menu
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Pro upgrade coming soon!')),
                             );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(double.infinity, 36),
                          ),
                          child: const Text('UPGRADE PRO'),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),

                // Sign Out
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Sign out',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authProvider.notifier).logout();
                ref.read(organizationProvider.notifier).clearSelection();
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isDesktop ? null : const AppDrawer(), // Mobile Drawer
      body: Row(
        children: [
          if (isDesktop) 
            const SizedBox(
              width: 300, // Increased width for the complex drawer
              child: AppDrawer(), // Desktop Sidebar
            ),
          if (isDesktop) const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _handleUserHeaderTap(BuildContext context, WidgetRef ref) {
    final userProfile = ref.read(userProfileProvider).value;
    _showUserDetailsDialog(context, userProfile);
  }

  void _showUserDetailsDialog(BuildContext context, User? user) {
    final sessionUser = SupabaseConfig.client.auth.currentUser;
    final displayName = (user?.fullName.isNotEmpty == true) 
        ? user!.fullName 
        : (sessionUser?.userMetadata?['full_name'] as String?) ?? user?.email ?? sessionUser?.email ?? 'User';
    final email = user?.email ?? sessionUser?.email ?? 'N/A';
    
    // Determine User Role with priority: Profile Object -> Session Metadata -> Default
    String userRole = user?.role ?? (sessionUser?.userMetadata?['role'] as String?) ?? 'EMPLOYEE';
    userRole = userRole.toUpperCase();
    
    final joinedDate = user?.createdAt ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailItem('Display Name', displayName),
            _detailItem('Email Address', email),
            _detailItem('User Role', userRole),
            _detailItem('Registered Since', DateFormat.yMMMd().format(joinedDate)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showOrgDetailsDialog(BuildContext context, dynamic org, int actualStoreCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organization Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailItem('Org Name', org.name),
            _detailItem('Number of Stores', actualStoreCount.toString()),
            _detailItem('Registered Since', DateFormat.yMMMd().format(org.createdAt)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showStoreDetailsDialog(BuildContext context, dynamic store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Store Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailItem('Store Name', store.name),
              _detailItem('Address', store.location ?? 'N/A'),
              _detailItem('City', store.city ?? 'N/A'),
              _detailItem('Postal', store.postalCode ?? 'N/A'),
              _detailItem('Country', store.country ?? 'N/A'),
              _detailItem('Currency', store.storeDefaultCurrency ?? 'N/A'),
              _detailItem('Registered Since', DateFormat.yMMMd().format(store.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
  Widget _buildAppBarTitle(BuildContext context, WidgetRef ref, GoRouterState state) {
    // Check if we are on the dashboard
    if (state.matchedLocation == '/dashboard') {
      final orgState = ref.watch(organizationProvider);
      final selectedOrg = orgState.selectedOrganization;

      if (selectedOrg != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedOrg.logoUrl != null && selectedOrg.logoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    selectedOrg.logoUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.business, size: 32),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.business, size: 24, color: Colors.white),
                ),
              ),
            Text(
              selectedOrg.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      }
    }
    
    // Default to Breadcrumbs
    return Breadcrumbs(state: state, routes: appRoutes);
  }
}
