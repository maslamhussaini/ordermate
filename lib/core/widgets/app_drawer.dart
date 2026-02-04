import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/build_info.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/core/localization/app_localizations.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/providers/auth_provider.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _inventoryExpanded = false;
  bool _customersExpanded = false;
  bool _suppliersExpanded = false;
  bool _employeeExpanded = false;
  bool _managementExpanded = false;
  bool _setupsExpanded = false;
  bool _accountingExpanded = false;

  void _closeDrawerIfOpen(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).value;
    final auth = ref.watch(authProvider);
    var userName = userProfile?.fullName ?? '';
    if (userName.isEmpty || userName.toLowerCase() == 'unknown user') {
      userName = userProfile?.email ?? 'User';
    }

    return Drawer(
      width: 300,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.loginGradientStart,
                  AppColors.loginGradientEnd,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Triangletech\nOrder Mate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User: $userName',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
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
          
          // Menu Items
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 8.0,
              radius: const Radius.circular(4.0),
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                shrinkWrap: false,
                primary: false,
                children: [
                _buildMenuItem(
                  icon: Icons.dashboard,
                  title: AppLocalizations.of(context)?.get('dashboard') ?? 'Dashboard',
                  onTap: () {
                    _closeDrawerIfOpen(context);
                    context.go('/dashboard');
                  },
                ),
                
                const Divider(),

                // Accounting (Expandable)
                if (auth.can('accounting', Permission.read))
                _buildExpandableMenuItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Accounting',
                  isExpanded: _accountingExpanded,
                  onTap: () {
                    setState(() => _accountingExpanded = !_accountingExpanded);
                  },
                  children: [
                    _buildSubMenuItem(
                      title: 'Accounting Overview',
                      icon: Icons.grid_view_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Chart of Accounts',
                      icon: Icons.account_tree_outlined,
                      onTap: () {
                         _closeDrawerIfOpen(context);
                         context.push('/accounting/coa');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'General Ledger Setup',
                      icon: Icons.settings_applications_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting/gl-setup');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Account Types',
                      icon: Icons.category_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting/account-types');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Account Categories',
                      icon: Icons.list_alt_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting/account-categories');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Transactions',
                      icon: Icons.receipt_long_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting/transactions');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Payment Terms',
                      icon: Icons.calendar_today_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting/payment-terms');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Bank & Cash',
                      icon: Icons.account_balance_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting/bank-cash');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Voucher Prefixes',
                      icon: Icons.label_outline,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting/voucher-prefixes');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Financial Sessions',
                      icon: Icons.date_range_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/accounting/financial-sessions');
                      },
                    ),
                  ],
                ),

                // Admin Menu (Expandable)
                if (auth.can('organization', Permission.read) || auth.can('stores', Permission.read))
                _buildExpandableMenuItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: AppLocalizations.of(context)?.get('admin') ?? 'Admin',
                  isExpanded: _managementExpanded,
                  onTap: () {
                    setState(() => _managementExpanded = !_managementExpanded);
                  },
                  children: [
                    if (auth.can('organization', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('organizations_list') ?? 'Organizations List',
                      icon: Icons.list,
                      onTap: () {
                         _closeDrawerIfOpen(context);
                         context.push('/organizations-list');
                      },
                    ),
                    if (auth.can('stores', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('branches_list') ?? 'Branches List',
                      icon: Icons.store,
                      onTap: () {
                         _closeDrawerIfOpen(context);
                         context.push('/branches');
                      },
                    ),
                  ],
                ),

                // Customers Management
                if (auth.can('customers', Permission.read) || auth.can('orders', Permission.read) || auth.can('invoices', Permission.read))
                _buildExpandableMenuItem(
                  icon: Icons.people,
                  title: AppLocalizations.of(context)?.get('customers_management') ?? 'Customers Management',
                  isExpanded: _customersExpanded,
                  onTap: () {
                    setState(() => _customersExpanded = !_customersExpanded);
                  },
                  children: [
                    if (auth.can('customers', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('customer_list') ?? 'Customer List',
                      icon: Icons.list_alt,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/customers');
                      },
                    ),
                    if (auth.can('orders', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('orders') ?? 'Orders',
                      icon: Icons.shopping_cart,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/orders', extra: {'initialFilterType': 'SO'});
                      },
                    ),
                    if (auth.can('invoices', Permission.read))
                    _buildSubMenuItem(
                      title: 'Sales Invoices',
                      icon: Icons.receipt,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/invoices');
                      },
                    ),
                  ],
                ),

                // Employee Management
                if (auth.can('employees', Permission.read))
                _buildExpandableMenuItem(
                  icon: Icons.badge,
                  title: AppLocalizations.of(context)?.get('employee_management') ?? 'Employee Management',
                  isExpanded: _employeeExpanded,
                  onTap: () {
                    setState(() => _employeeExpanded = !_employeeExpanded);
                  },
                  children: [
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('employees_list') ?? 'Employees List',
                      icon: Icons.people_outline,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/employees');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Departments',
                      icon: Icons.work_outline,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/employees/departments');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Roles',
                      icon: Icons.security,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/employees/roles');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Application Users',
                      icon: Icons.people_alt_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/employees/users');
                      },
                    ),
                    _buildSubMenuItem(
                      title: 'Permissions & Privileges',
                      icon: Icons.admin_panel_settings,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/employees/privileges');
                      },
                    ),
                  ],
                ),
                
                // Inventory Management
                if (auth.can('inventory', Permission.read) || auth.can('products', Permission.read))
                _buildExpandableMenuItem(
                  icon: Icons.inventory_2,
                  title: AppLocalizations.of(context)?.get('inventory_management') ?? 'Inventory Management',
                  isExpanded: _inventoryExpanded,
                  onTap: () {
                    setState(() => _inventoryExpanded = !_inventoryExpanded);
                  },
                  children: [
                    if (auth.can('products', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('products') ?? 'Product',
                      icon: Icons.shopping_bag_outlined,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/products');
                      },
                    ),
                    if (auth.can('inventory', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('brands') ?? 'Brands',
                      icon: Icons.branding_watermark,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/inventory/brands');
                      },
                    ),
                    if (auth.can('inventory', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('categories') ?? 'Categories',
                      icon: Icons.category,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/inventory/categories');
                      },
                    ),
                    if (auth.can('inventory', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('product_types') ?? 'Product Types',
                      icon: Icons.merge_type,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/inventory/product-types');
                      },
                    ),
                    if (auth.can('inventory', Permission.read))
                    _buildSubMenuItem(
                      title: 'Units of Measure',
                      icon: Icons.straighten,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/inventory/units-of-measure');
                      },
                    ),
                    if (auth.can('inventory', Permission.read))
                    _buildSubMenuItem(
                      title: 'Unit Conversions',
                      icon: Icons.compare_arrows,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/inventory/unit-conversions');
                      },
                    ),
                    if (auth.can('stock_transfer', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('stock_transfers') ?? 'Stock Transfers',
                      icon: Icons.swap_horiz,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/inventory/transfers');
                      },
                    ),
                  ],
                ),

                if (auth.can('reports', Permission.read))
                _buildMenuItem(
                  icon: Icons.bar_chart_outlined,
                  title: 'Reports',
                  onTap: () {
                    _closeDrawerIfOpen(context);
                    context.go('/reports');
                  },
                ),

                // Setups (Expandable)
                if (auth.can('settings', Permission.read) || auth.can('organization', Permission.read))
                  _buildExpandableMenuItem(
                    icon: Icons.settings,
                    title: AppLocalizations.of(context)?.get('setups') ?? 'Setups',
                    isExpanded: _setupsExpanded,
                    onTap: () {
                      setState(() => _setupsExpanded = !_setupsExpanded);
                    },
                    children: [
                      if (auth.can('organization', Permission.read))
                      _buildSubMenuItem(
                        title: AppLocalizations.of(context)?.get('organization_profile') ?? 'Organization Profile',
                        icon: Icons.business,
                        onTap: () {
                          _closeDrawerIfOpen(context);
                          context.push('/organization');
                        },
                      ),
                      if (auth.can('organization', Permission.read)) // Usually same level
                      _buildSubMenuItem(
                        title: AppLocalizations.of(context)?.get('organizations_list') ?? 'Organizations List',
                        icon: Icons.list,
                        onTap: () {
                          _closeDrawerIfOpen(context);
                          context.push('/organizations-list');
                        },
                      ),
                      if (auth.can('stores', Permission.read))
                      _buildSubMenuItem(
                        title: AppLocalizations.of(context)?.get('branches_list') ?? 'Branches List',
                        icon: Icons.store_mall_directory,
                        onTap: () {
                          _closeDrawerIfOpen(context);
                          context.push('/branches');
                        },
                      ),
                    ],
                  ),
                
                // Suppliers Management
                if (auth.can('vendors', Permission.read) || auth.can('orders', Permission.read))
                _buildExpandableMenuItem(
                  icon: Icons.local_shipping,
                  title: AppLocalizations.of(context)?.get('suppliers_management') ?? 'Suppliers Management',
                  isExpanded: _suppliersExpanded,
                  onTap: () {
                    setState(() => _suppliersExpanded = !_suppliersExpanded);
                  },
                  children: [
                    if (auth.can('vendors', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('vendors') ?? 'Vendors',
                      icon: Icons.store,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/vendors');
                      },
                    ),
                    if (auth.can('vendors', Permission.read))
                    _buildSubMenuItem(
                      title: 'Suppliers',
                      icon: Icons.inventory,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/vendors', extra: {'showSuppliersOnly': true});
                      },
                    ),
                    if (auth.can('orders', Permission.read))
                    _buildSubMenuItem(
                      title: AppLocalizations.of(context)?.get('purchase_orders') ?? 'Orders',
                      icon: Icons.shopping_cart_checkout,
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/orders', extra: {'initialFilterType': 'PO'});
                      },
                    ),
                  ],
                ),

                const Divider(),

                if (auth.can('settings', Permission.read))
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: AppLocalizations.of(context)?.get('settings') ?? 'Settings',
                  onTap: () {
                    _closeDrawerIfOpen(context);
                    context.push('/settings');
                  },
                ),

              ],
            ),
          ),
          ),

          // Footer (Pinned at bottom)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white12 
                    : Colors.grey.shade300,
              )),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/triangletech_logo.jpg',
                  height: 50,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 4),
                Text(
                  // ignore: prefer_interpolation_to_compose_strings
                  (AppLocalizations.of(context)?.get('version') ?? 'Version') + ' $appVersion • Build $buildTime',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white54 
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(AppLocalizations.of(context)?.get('whats_new') ?? "What's New"),
                        content: const SingleChildScrollView(
                          child: Text(whatsNew),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(AppLocalizations.of(context)?.get('close') ?? 'Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      AppLocalizations.of(context)?.get('whats_new') ?? "What's New?",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      onTap: onTap,
    );
  }

  Widget _buildExpandableMenuItem({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, size: 24),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down),
          ),
          onTap: onTap,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: children),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildSubMenuItem({
    required String title,
    required VoidCallback onTap, IconData? icon,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16), // Reduced padding if icon exists
      leading: icon != null 
          ? Icon(icon, size: 20, 
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white70 
                  : Colors.grey.shade700) 
          : null,
      title: Text(
        title,
        style: const TextStyle(fontSize: 15),
      ),
      onTap: onTap,
    );
  }
}
