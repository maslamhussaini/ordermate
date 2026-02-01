import 'dart:async';
import 'package:intl/intl.dart';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/core/widgets/app_drawer.dart';
import 'package:ordermate/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:ordermate/features/dashboard/presentation/widgets/sync_progress_indicator.dart';
import 'package:ordermate/features/dashboard/presentation/widgets/refresh_button.dart';
import 'package:ordermate/features/dashboard/presentation/widgets/stat_card.dart';
import 'package:ordermate/core/localization/app_localizations.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/providers/session_provider.dart';
import 'package:ordermate/core/services/connectivity_provider.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/features/auth/domain/entities/user.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialSelection;
  const DashboardScreen({super.key, this.initialSelection});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _expandedSections = {
    'Accounts': true,
    'Customers': true,
    'Employee': true,
    'Inventory': true,
    'Suppliers': true,
    'Vendors': true,
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // ref.read(dashboardProvider.notifier).refresh(); // Removed redundant call - already triggered by provider creation
      
      // Handle Initial Selection from Login
      if (widget.initialSelection != null) {
        final orgId = widget.initialSelection!['organizationId'] as int?;
        final storeId = widget.initialSelection!['storeId'] as int?;
        
        if (orgId != null) {
           final orgNotifier = ref.read(organizationProvider.notifier);
           orgNotifier.loadOrganizations().then((_) {
               // Find the org in the loaded list
               final orgs = ref.read(organizationProvider).organizations;
               final selectedOrg = orgs.firstWhere((o) => o.id == orgId, orElse: () => orgs.first);
               
               // Select Org (this triggers loadStores)
               orgNotifier.selectOrganization(selectedOrg).then((_) {
                   if (storeId != null) {
                       final stores = ref.read(organizationProvider).stores;
                       try {
                           final selectedStore = stores.firstWhere((s) => s.id == storeId);
                           orgNotifier.selectStore(selectedStore);
                       } catch (e) {
                           debugPrint('Initial store ID $storeId not found in loaded stores.');
                       }
                   }
               });
           });
        }
      } else {
        // Ensure Organization is loaded if not already selected (e.g. reload or direct nav)
        final orgState = ref.read(organizationProvider);
        if (orgState.selectedOrganization == null) {
           ref.read(organizationProvider.notifier).loadOrganizations();
        } else if (orgState.stores.isEmpty) {
           ref.read(organizationProvider.notifier).loadStores(orgState.selectedOrganization!.id);
        }
      }
    });

    Future.microtask(() => _checkSessionLocation()); // Trigger location check
  }

  Future<void> _checkSessionLocation() async {
    final session = ref.read(sessionProvider);
    if (session.loginLatitude == null) {
      debugPrint('Dashboard: Session location missing. Attempting capture...');
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
             desiredAccuracy: LocationAccuracy.medium,
             timeLimit: const Duration(seconds: 10),
          );
          
          if (mounted && kDebugMode) {
             ref.read(sessionProvider.notifier).setLoginLocation(position.latitude, position.longitude);
             debugPrint('Dashboard: Captured session location: ${position.latitude}, ${position.longitude}');
             // Optional: Show subtle feedback
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text('Location Active: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'),
               backgroundColor: Colors.teal,
               duration: const Duration(milliseconds: 1500),
               behavior: SnackBarBehavior.floating,
             ));
          } else if (mounted) {
             ref.read(sessionProvider.notifier).setLoginLocation(position.latitude, position.longitude);
          }
        }
      } catch (e) {
        debugPrint('Dashboard: Failed to capture session loc: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildResponsiveRow(BuildContext context, List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1100) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        final double spacing = 16.0;
        final double totalSpacing = spacing * (crossAxisCount - 1);
        // Ensure we don't divide by zero or have negative width
        final double itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            return SizedBox(
              width: itemWidth,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required List<Widget> cards,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 12),
          _buildResponsiveRow(context, cards),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for connectivity changes to trigger sync
    ref.listen<ConnectionStatus>(connectivityProvider, (previous, next) {
      if (previous == ConnectionStatus.offline && next == ConnectionStatus.online) {
        debugPrint('Dashboard: Detected online status via provider, triggering sync...');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Back online - Syncing data...'),
            duration: Duration(seconds: 2),
          ),
        );
        ref.read(dashboardProvider.notifier).refresh();
      }
    });

    // Redirect if no organizations found
    ref.listen<OrganizationState>(organizationProvider, (previous, next) {
      if (!next.isLoading &&
          next.organizations.isEmpty &&
          next.error == null) {
        // Prevent redirect loop if already there (though this is dashboard)
        // Check if we just finished loading
        if (previous?.isLoading == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) context.goNamed('organization-create');
            });
        }
      }

      
      // Redirect to Organization Selection if multiple available and none selected
      if (!next.isLoading &&
          next.organizations.isNotEmpty &&
          next.selectedOrganization == null &&
          next.error == null) {
         if (previous?.isLoading == true || previous?.selectedOrganization != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) context.go('/organizations-list');
            });
         }
      }
    });

    final dashboardState = ref.watch(dashboardProvider);
    final accountingState = ref.watch(accountingProvider);
    final stats = dashboardState.stats;
    
    final orgState = ref.watch(organizationProvider);
    final auth = ref.watch(authProvider);
    final sessionUser = SupabaseConfig.client.auth.currentUser;
    final stores = orgState.stores;
    final showTabs = stores.length > 1;
    
    // Manage TabController
    if (showTabs) {
      if (_tabController == null || _tabController!.length != stores.length) {
        final initialIndex = orgState.selectedStore != null 
             ? stores.indexWhere((s) => s.id == orgState.selectedStore!.id)
             : 0;
        _tabController?.dispose();
        _tabController = TabController(
          length: stores.length, 
          vsync: this,
          initialIndex: (initialIndex >= 0) ? initialIndex : 0,
        );
        _tabController!.addListener(_handleTabSelection);
      } else {
        // Sync index if changed externally (e.g. drawer)
        // But only if not currently animating to avoid loops
        if (!_tabController!.indexIsChanging) {
             final index = orgState.selectedStore != null 
                 ? stores.indexWhere((s) => s.id == orgState.selectedStore!.id)
                 : -1;
             if (index >= 0 && index != _tabController!.index) {
                _tabController!.animateTo(index);
             }
        }
      }
    } else {
      _tabController?.dispose();
      _tabController = null;
    }

    final syncStatus = ref.watch(syncProgressProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_refresh',
        onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
        child: dashboardState.isLoading 
           ? const Padding(
               padding: EdgeInsets.all(12), 
               child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
             ) 
           : const Icon(Icons.refresh),
      ),
      appBar: showTabs ? AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: stores.map((s) => Tab(text: s.name)).toList(),
        ),
      ) : null,
      // drawer: const AppDrawer(), // Removed to avoid double drawer
      body: (dashboardState.isLoading && stats == null && !syncStatus.isSyncing)
          ? const Center(child: CircularProgressIndicator())
          : dashboardState.error != null && !syncStatus.isSyncing
              ? Center(child: Text('Error: ${dashboardState.error}'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SyncProgressIndicator(syncStatus: syncStatus),
                        if (dashboardState.lastRefreshed != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              'Last updated: ${_formatTime(dashboardState.lastRefreshed!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        
                        // Session Location logic is handled in initState
                        const SizedBox(height: 16),

                        // 1. ACCOUNTS SECTION
                        _buildCollapsibleSection(
                          title: 'Accounts',
                          icon: Icons.account_balance_rounded,
                          isExpanded: _expandedSections['Accounts'] ?? true,
                          onToggle: () => setState(() => _expandedSections['Accounts'] = !(_expandedSections['Accounts'] ?? true)),
                          cards: [
                            if (auth.can('accounting', Permission.read)) ...[
                              StatCard(
                                title: 'Accounting Overview',
                                value: 'Finance',
                                icon: Icons.account_balance_rounded,
                                color: Colors.indigo,
                                onTap: () => context.push('/accounting'),
                              ),
                              StatCard(
                                title: 'Chart of Accounts',
                                value: '${accountingState.accounts.length}',
                                icon: Icons.account_tree_rounded,
                                color: Colors.blueAccent,
                                onTap: () => context.push('/accounting/coa'),
                              ),
                              StatCard(
                                 title: 'Transactions',
                                 value: '${accountingState.transactions.length}',
                                 icon: Icons.receipt_long_rounded,
                                 color: Colors.cyan,
                                 onTap: () => context.push('/accounting/transactions'),
                              ),
                              StatCard(
                                 title: 'Bank & Cash',
                                 value: '${accountingState.bankCashAccounts.length}',
                                 icon: Icons.savings_rounded,
                                 color: Colors.teal,
                                 onTap: () => context.push('/accounting/bank-cash'),
                              ),
                            ]
                          ],
                        ),

                        // 2. CUSTOMERS SECTION
                        _buildCollapsibleSection(
                          title: 'Customers',
                          icon: Icons.people_alt_rounded,
                          isExpanded: _expandedSections['Customers'] ?? true,
                          onToggle: () => setState(() => _expandedSections['Customers'] = !(_expandedSections['Customers'] ?? true)),
                          cards: [
                            if (auth.can('customers', Permission.read))
                            StatCard(
                              title: AppLocalizations.of(context)?.get('customers') ?? 'Customers',
                              value: '${stats?.totalCustomers ?? 0}',
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF7C4DFF), // Deep Purple/Indigo
                              onTap: () => context.push('/customers'),
                            ),
                            if (auth.can('orders', Permission.read)) ...[
                              StatCard(
                                title: 'Orders Booked',
                                value: '${stats?.ordersBooked ?? 0}',
                                icon: Icons.bookmark_rounded,
                                color: const Color(0xFF2962FF), // Royal Blue
                                onTap: () => context.push('/orders', extra: {'initialFilterType': 'SO', 'initialFilterStatus': 'Booked'}),
                              ),
                              StatCard(
                                title: 'Orders Approved',
                                value: '${stats?.ordersApproved ?? 0}',
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF00C853), // Emerald Green
                                onTap: () => context.push('/orders', extra: {'initialFilterType': 'SO', 'initialFilterStatus': 'Approved'}),
                              ),
                              StatCard(
                                title: 'Orders Pending',
                                value: '${stats?.ordersPending ?? 0}',
                                icon: Icons.pending_actions_rounded,
                                color: const Color(0xFFFF9100), // Deep Orange
                                onTap: () => context.push('/orders', extra: {'initialFilterType': 'SO', 'initialFilterStatus': 'Pending'}),
                              ),
                              StatCard(
                                title: 'Orders Rejected',
                                value: '${stats?.ordersRejected ?? 0}',
                                icon: Icons.cancel_rounded,
                                color: const Color(0xFFFF1744), // Critical Rose/Red
                                onTap: () => context.push('/orders', extra: {'initialFilterType': 'SO', 'initialFilterStatus': 'Rejected'}),
                              ),
                            ],
                            if (auth.can('invoices', Permission.read)) ...[
                              StatCard(
                                title: 'Sales Invoice',
                                value: '${stats?.salesInvoicesCount ?? 0}',
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFF4CAF50),
                                onTap: () => context.push('/invoices', extra: {'initialFilterType': 'SI'}),
                              ),
                              StatCard(
                                title: 'Sales Return',
                                value: '${stats?.salesReturnsCount ?? 0}',
                                icon: Icons.assignment_return_rounded,
                                color: const Color(0xFFF44336),
                                onTap: () => context.push('/invoices', extra: {'initialFilterType': 'SR'}),
                              ),
                            ],
                          ],
                        ),

                        // 3. EMPLOYEE SECTION
                        _buildCollapsibleSection(
                          title: 'Employee',
                          icon: Icons.badge_rounded,
                          isExpanded: _expandedSections['Employee'] ?? true,
                          onToggle: () => setState(() => _expandedSections['Employee'] = !(_expandedSections['Employee'] ?? true)),
                          cards: [
                            if (auth.can('employees', Permission.read))
                            StatCard(
                              title: 'Total Employees',
                              value: '${stats?.totalEmployees ?? 0}',
                              icon: Icons.badge_rounded,
                              color: Colors.teal,
                              onTap: () => context.push('/employees'),
                            ),
                          ],
                        ),

                        // 4. INVENTORY SECTION
                        _buildCollapsibleSection(
                          title: 'Inventory',
                          icon: Icons.inventory_2_rounded,
                          isExpanded: _expandedSections['Inventory'] ?? true,
                          onToggle: () => setState(() => _expandedSections['Inventory'] = !(_expandedSections['Inventory'] ?? true)),
                          cards: [
                            if (auth.can('products', Permission.read))
                            StatCard(
                              title: AppLocalizations.of(context)?.get('products') ?? 'Products',
                              value: '${stats?.totalProducts ?? 0}',
                              icon: Icons.inventory_2_rounded,
                              color: const Color(0xFF6200EA), // Deep Purple
                              onTap: () => context.push('/products'),
                            ),
                            if (auth.can('inventory', Permission.read))
                            StatCard(
                              title: 'Inventory Overview',
                              value: 'Stock',
                              icon: Icons.warehouse_rounded,
                              color: Colors.blueGrey,
                              onTap: () => context.push('/inventory'),
                            ),
                          ],
                        ),

                        // 5. SUPPLIERS SECTION
                        _buildCollapsibleSection(
                          title: 'Suppliers',
                          icon: Icons.local_shipping_rounded,
                          isExpanded: _expandedSections['Suppliers'] ?? true,
                          onToggle: () => setState(() => _expandedSections['Suppliers'] = !(_expandedSections['Suppliers'] ?? true)),
                          cards: [
                            if (auth.can('vendors', Permission.read))
                            StatCard(
                              title: 'Total Suppliers',
                              value: '${stats?.totalSuppliers ?? 0}',
                              icon: Icons.local_shipping_rounded,
                              color: const Color(0xFFFF4081), // Pink/Magenta
                              onTap: () => context.push('/vendors', extra: {'showSuppliersOnly': true}),
                            ),
                            if (auth.can('invoices', Permission.read)) ...[
                              StatCard(
                                title: 'Purchase Invoice',
                                value: '${stats?.purchaseInvoicesCount ?? 0}',
                                icon: Icons.inventory_rounded,
                                color: const Color(0xFF2196F3),
                                onTap: () => context.push('/invoices', extra: {'initialFilterType': 'PI'}),
                              ),
                              StatCard(
                                title: 'Purchase Return',
                                value: '${stats?.purchaseReturnsCount ?? 0}',
                                icon: Icons.keyboard_return_rounded,
                                color: const Color(0xFFFF5722),
                                onTap: () => context.push('/invoices', extra: {'initialFilterType': 'PR'}),
                              ),
                            ],
                          ],
                        ),

                        // 6. VENDORS SECTION
                        _buildCollapsibleSection(
                          title: 'Vendors',
                          icon: Icons.storefront_rounded,
                          isExpanded: _expandedSections['Vendors'] ?? true,
                          onToggle: () => setState(() => _expandedSections['Vendors'] = !(_expandedSections['Vendors'] ?? true)),
                          cards: [
                            if (auth.can('vendors', Permission.read))
                            StatCard(
                              title: 'Total Vendors',
                              value: '${stats?.totalVendors ?? 0}',
                              icon: Icons.storefront_rounded,
                              color: const Color(0xFFFFAB00), // Amber/Gold
                              onTap: () => context.push('/vendors'),
                            ),
                          ],
                        ),
                        
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  void _handleTabSelection() {
    if (_tabController!.indexIsChanging) {
      final stores = ref.read(organizationProvider).stores;
      final selectedIndex = _tabController!.index;
      if (selectedIndex >= 0 && selectedIndex < stores.length) {
         ref.read(organizationProvider.notifier).selectStore(stores[selectedIndex]);
      }
    }
  }

  void _handleUserHeaderTap(BuildContext context) {
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
}
