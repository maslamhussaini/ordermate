import 'package:flutter/material.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/core/router/route_names.dart';

// Imports (Orders, Invoices, Products, Inventory, Vendors, Employees, Stores, Reports, Organization, Settings)
import 'package:ordermate/features/orders/presentation/screens/create_order_screen.dart';
import 'package:ordermate/features/orders/presentation/screens/order_list_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/invoices_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/invoice_detail_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/invoice_entry_screen.dart';
import 'package:ordermate/features/products/presentation/screens/product_form_screen.dart';
import 'package:ordermate/features/products/presentation/screens/product_list_screen.dart';
import 'package:ordermate/features/products/presentation/screens/product_debug_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/brand_list_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/category_list_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/product_type_list_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/unit_conversions_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/units_of_measure_screen.dart';
import 'package:ordermate/features/vendors/presentation/screens/vendor_form_screen.dart';
import 'package:ordermate/features/vendors/presentation/screens/vendor_list_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/employee_form_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/employee_list_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/department_list_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/department_form_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/role_list_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/role_form_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/user_list_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/user_form_screen.dart';
import 'package:ordermate/features/employees/presentation/screens/privilege_management_screen.dart';
import 'package:ordermate/features/organization/presentation/screens/store_form_screen.dart';
import 'package:ordermate/features/organization/presentation/screens/store_list_screen.dart';
import 'package:ordermate/features/reports/presentation/screens/reports_hub_screen.dart';
import 'package:ordermate/features/reports/presentation/screens/ledger_report_screen.dart';
import 'package:ordermate/features/reports/presentation/screens/sales_report_screen.dart';
import 'package:ordermate/features/reports/presentation/screens/sales_location_report_screen.dart';
import 'package:ordermate/features/organization/presentation/screens/organization_profile_screen.dart';
import 'package:ordermate/features/reports/presentation/screens/day_closing_report_screen.dart';
import 'package:ordermate/features/organization/presentation/screens/organization_list_screen.dart';
import 'package:ordermate/features/organization/presentation/screens/organization_form_screen.dart';
import 'package:ordermate/features/organization/presentation/screens/workspace_selection_screen.dart';
import 'package:ordermate/features/settings/presentation/screens/settings_screen.dart';
import 'package:ordermate/features/settings/presentation/screens/printer_setup_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/brand_form_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/category_form_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/product_type_form_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/uom_form_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/unit_conversion_form_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/stock_transfer_list_screen.dart';
import 'package:ordermate/features/inventory/presentation/screens/stock_transfer_form_screen.dart';

final List<AppRoute> orderRoutes = [
  AppRoute(
    path: '/orders',
    title: 'Orders',
    routeName: RouteNames.orders,
    module: 'orders',
    icon: Icons.shopping_cart,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, state) {
       final extra = state.extra as Map<String, dynamic>?;
       return OrderListScreen(
         initialFilterType: extra?['initialFilterType'] as String?,
         initialFilterStatus: extra?['initialFilterStatus'] as String?,
       );
    },
    children: [
      AppRoute(
        path: 'create',
        title: 'Create Order',
        routeName: RouteNames.orderCreate,
        module: 'orders',
        showInMenu: false,
        roles: [UserRole.admin, UserRole.staff],
        builder: (_, state) {
           final extra = state.extra as Map<String, dynamic>?;
           return CreateOrderScreen(
             customerId: extra?['customerId'] as String?,
             customerName: extra?['customerName'] as String?,
             initialOrderType: extra?['initialOrderType'] as String? ?? 'SO',
             orderId: extra?['orderId'] as String?,
           );
        },
      ),
      AppRoute(path: 'edit/:id', title: 'Edit Order', routeName: RouteNames.orderEdit, module: 'orders', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => CreateOrderScreen(orderId: state.pathParameters['id']!)),
    ],
  ),
];

final List<AppRoute> invoiceRoutes = [
  AppRoute(
    path: '/invoices',
    title: 'Invoices',
    routeName: RouteNames.invoices,
    module: 'invoices',
    icon: Icons.receipt_long,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, state) {
      final extra = state.extra as Map<String, dynamic>?;
      return InvoicesScreen(initialFilterType: extra?['initialFilterType'] as String?);
    },
    children: [
      AppRoute(path: 'create', title: 'Create Invoice', routeName: RouteNames.invoiceCreate, module: 'invoices', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) {
           final extra = state.extra as Map<String, dynamic>?;
           return InvoiceEntryScreen(
             customerId: extra?['customerId'] as String?,
             customerName: extra?['customerName'] as String?,
             orderId: extra?['orderId'] as String?,
             idInvoiceType: extra?['idInvoiceType'] as String?,
           );
      }),
      AppRoute(path: 'edit/:id', title: 'Edit Invoice', routeName: RouteNames.invoiceEdit, module: 'invoices', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => InvoiceEntryScreen(invoiceId: state.pathParameters['id'])),
      AppRoute(path: 'detail/:id', title: 'Invoice Details', routeName: RouteNames.invoiceDetail, module: 'invoices', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id']!)),
    ],
  ),
];

// ... Bundling others for brevity in One Go. In reality, split further.
final List<AppRoute> productRoutes = [
  AppRoute(
    path: '/products',
    title: 'Products',
    routeName: RouteNames.products,
    module: 'products',
    icon: Icons.inventory_2,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, __) => const ProductListScreen(),
    children: [
       AppRoute(path: 'create', title: 'Create Product', routeName: RouteNames.productCreate, module: 'products', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const ProductFormScreen()),
       AppRoute(path: 'edit/:id', title: 'Edit Product', routeName: RouteNames.productEdit, module: 'products', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => ProductFormScreen(productId: state.pathParameters['id']!)),
       AppRoute(path: 'debug', title: 'Debug Product', routeName: RouteNames.productDebug, module: 'products', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const ProductDebugScreen()),
    ],
  ),
];

final List<AppRoute> inventoryRoutes = [
  AppRoute(
    path: '/inventory',
    title: 'Inventory Hub',
    routeName: RouteNames.inventory,
    module: 'inventory',
    icon: Icons.warehouse,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, __) => const InventoryDashboardScreen(),
    children: [
      AppRoute(path: 'brands', title: 'Brands', routeName: RouteNames.brands, module: 'inventory', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const BrandListScreen(), children: [
         AppRoute(path: 'create', title: 'New Brand', routeName: 'brand-create', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const BrandFormScreen()),
         AppRoute(path: 'edit/:id', title: 'Edit Brand', routeName: 'brand-edit', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => BrandFormScreen(brandId: state.pathParameters['id'])),
      ]),
      AppRoute(path: 'categories', title: 'Categories', routeName: RouteNames.categories, module: 'inventory', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const CategoryListScreen(), children: [
         AppRoute(path: 'create', title: 'New Category', routeName: 'category-create', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const CategoryFormScreen()),
         AppRoute(path: 'edit/:id', title: 'Edit Category', routeName: 'category-edit', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => CategoryFormScreen(categoryId: state.pathParameters['id'])),
      ]),
      AppRoute(path: 'product-types', title: 'Product Types', routeName: RouteNames.productTypes, module: 'inventory', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const ProductTypeListScreen(), children: [
         AppRoute(path: 'create', title: 'New Type', routeName: 'product-type-create', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const ProductTypeFormScreen()),
         AppRoute(path: 'edit/:id', title: 'Edit Type', routeName: 'product-type-edit', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => ProductTypeFormScreen(typeId: state.pathParameters['id'])),
      ]),
      AppRoute(path: 'units-of-measure', title: 'Units of Measure', routeName: RouteNames.unitsOfMeasure, module: 'inventory', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const UnitsOfMeasureScreen(), children: [
         AppRoute(path: 'create', title: 'New Unit', routeName: 'uom-create', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const UnitOfMeasureFormScreen()),
         AppRoute(path: 'edit/:id', title: 'Edit Unit', routeName: 'uom-edit', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => UnitOfMeasureFormScreen(uomId: state.pathParameters['id'])),
      ]),
      AppRoute(path: 'unit-conversions', title: 'Unit Conversions', routeName: RouteNames.unitConversions, module: 'inventory', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const UnitConversionsScreen(), children: [
         AppRoute(path: 'create', title: 'New Conversion', routeName: 'unit-conversion-create', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const UnitConversionFormScreen()),
         AppRoute(path: 'edit/:id', title: 'Edit Conversion', routeName: 'unit-conversion-edit', module: 'inventory', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => UnitConversionFormScreen(conversionId: state.pathParameters['id'])),
      ]),
      AppRoute(
         path: 'transfers', 
         title: 'Stock Transfers', 
         routeName: 'stock-transfers', 
         module: 'inventory', 
         roles: [UserRole.admin, UserRole.staff], 
         builder: (_, __) => const StockTransferListScreen(),
         children: [
           AppRoute(
             path: 'create', 
             title: 'New Transfer', 
             routeName: 'stock-transfer-create', 
             module: 'inventory', 
             showInMenu: false, 
             roles: [UserRole.admin, UserRole.staff], 
             builder: (_, __) => const StockTransferFormScreen()
           ),
         ]
      ),
    ],
  ),
];

final List<AppRoute> vendorRoutes = [
  AppRoute(
    path: '/vendors',
    title: 'Vendors',
    routeName: RouteNames.vendors,
    module: 'vendors',
    icon: Icons.local_shipping,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, state) {
      final extra = state.extra as Map<String, dynamic>?;
      return VendorListScreen(showSuppliersOnly: extra?['showSuppliersOnly'] == true);
    },
    children: [
      AppRoute(path: 'create', title: 'Create Vendor', routeName: RouteNames.vendorCreate, module: 'vendors', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const VendorFormScreen()),
      AppRoute(path: 'edit/:id', title: 'Edit Vendor', routeName: RouteNames.vendorEdit, module: 'vendors', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => VendorFormScreen(vendorId: state.pathParameters['id'])),
    ],
  ),
];

final List<AppRoute> employeeRoutes = [
  AppRoute(
    path: '/employees',
    title: 'Employees',
    routeName: RouteNames.employees,
    module: 'employees',
    icon: Icons.badge,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, __) => const EmployeeListScreen(),
    children: [
       AppRoute(path: 'create', title: 'Add Employee', routeName: RouteNames.employeeCreate, module: 'employees', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const EmployeeFormScreen()),
       AppRoute(path: 'edit/:id', title: 'Edit Employee', routeName: RouteNames.employeeEdit, module: 'employees', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => EmployeeFormScreen(employeeId: state.pathParameters['id']!)),
       AppRoute(path: 'departments', title: 'Departments', routeName: RouteNames.departments, module: 'employees', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const DepartmentListScreen(), children: [
          AppRoute(path: 'create', title: 'Add Dept', routeName: RouteNames.departmentCreate, module: 'employees', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const DepartmentFormScreen()),
          AppRoute(path: 'edit/:id', title: 'Edit Dept', routeName: RouteNames.departmentEdit, module: 'employees', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => DepartmentFormScreen(departmentId: state.pathParameters['id'])),
       ]),
       AppRoute(path: 'roles', title: 'Roles', routeName: RouteNames.roles, module: 'employees', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const RoleListScreen(), children: [
          AppRoute(path: 'create', title: 'Add Role', routeName: RouteNames.roleCreate, module: 'employees', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const RoleFormScreen()),
          AppRoute(path: 'edit/:id', title: 'Edit Role', routeName: RouteNames.roleEdit, module: 'employees', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => RoleFormScreen(roleId: state.pathParameters['id'])),
       ]),
       AppRoute(path: 'users', title: 'Users', routeName: RouteNames.users, module: 'employees', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const UserListScreen(), children: [
          AppRoute(path: 'create', title: 'Add User', routeName: RouteNames.userCreate, module: 'employees', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const UserFormScreen()),
          AppRoute(path: 'edit/:id', title: 'Edit User', routeName: RouteNames.userEdit, module: 'employees', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => UserFormScreen(userId: state.pathParameters['id']!)),
       ]),
        AppRoute(
          path: 'privileges',
          title: 'Privilege Management',
          routeName: RouteNames.privileges,
          module: 'employees',
          icon: Icons.admin_panel_settings,
          roles: [UserRole.admin, UserRole.staff],
          builder: (_, __) => const PrivilegeManagementScreen(),
        ),
    ]
  ),
];

final List<AppRoute> branchRoutes = [
  AppRoute(
    path: '/branches',
    title: 'Branches',
    routeName: RouteNames.branches,
    module: 'stores',
    icon: Icons.store,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, __) => const StoreListScreen(),
    children: [
       AppRoute(path: 'create', title: 'Add Store', routeName: RouteNames.storeCreate, module: 'stores', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const StoreFormScreen()),
       AppRoute(path: 'edit/:id', title: 'Edit Store', routeName: RouteNames.storeEdit, module: 'stores', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => StoreFormScreen(storeId: state.pathParameters['id'])),
    ]
  ),
];

final List<AppRoute> organizationRoutes = [
  AppRoute(
    path: '/organizations-list',
    title: 'Organizations',
    routeName: RouteNames.organizationsList,
    module: 'dashboard', // Changed from organization to allow access
    icon: Icons.business,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, __) => const OrganizationListScreen(),
    children: [
      AppRoute(
        path: 'create',
        title: 'New Organization',
        routeName: RouteNames.organizationCreate,
        module: 'dashboard', // Changed from organization to allow access
        showInMenu: false,
        roles: [UserRole.superUser],
        builder: (_, __) => const OrganizationFormScreen(),
      ),
      AppRoute(
        path: 'edit/:id',
        title: 'Edit Organization',
        routeName: RouteNames.organizationEdit,
        module: 'dashboard', // Changed from organization to allow access
        showInMenu: false,
        roles: [UserRole.superUser],
        builder: (_, state) => OrganizationFormScreen(organizationId: state.pathParameters['id']),
      ),
    ],
  ),
  AppRoute(
    path: '/workspace-selection',
    title: 'Select Workspace',
    routeName: RouteNames.workspaceSelection,
    module: 'dashboard', // Changed from organization to allow access
    icon: Icons.business_center,
    roles: [UserRole.admin, UserRole.staff],
    showInMenu: false,
    builder: (_, __) => const WorkspaceSelectionScreen(),
  ),
];

final List<AppRoute> reportRoutes = [
  AppRoute(
    path: '/reports',
    title: 'Reports',
    routeName: RouteNames.reports,
    module: 'reports',
    icon: Icons.analytics,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, __) => const ReportsHubScreen(),
    children: [
       AppRoute(path: 'ledger/:type', title: 'Ledger', routeName: RouteNames.ledgerReport, module: 'reports', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => LedgerReportScreen(type: state.pathParameters['type']!)),
       AppRoute(path: 'sales/:groupBy', title: 'Sales Report', routeName: RouteNames.salesReport, module: 'reports', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => SalesReportScreen(groupBy: state.pathParameters['groupBy']!, invoiceType: 'SI')),
       AppRoute(path: 'returns/:groupBy', title: 'Returns Report', routeName: RouteNames.returnsReport, module: 'reports', showInMenu: false, roles: [UserRole.admin, UserRole.staff], builder: (_, state) => SalesReportScreen(groupBy: state.pathParameters['groupBy']!, invoiceType: 'SIR')),
       AppRoute(
         path: 'location',
         title: 'Sales Location Report',
         routeName: RouteNames.salesLocationReport,
         module: 'reports',
         showInMenu: false,
         roles: [UserRole.admin, UserRole.staff],
         builder: (_, __) => const SalesLocationReportScreen(),
       ),
       AppRoute(
         path: 'day-closing',
         title: 'Day Closing Report',
         routeName: 'day-closing-report', 
         module: 'reports',
         showInMenu: false,
         roles: [UserRole.admin, UserRole.staff],
         builder: (_, __) => const DayClosingReportScreen(),
       ),
    ]
  ),
];

final List<AppRoute> coreRoutes = [
  AppRoute(
    path: '/organization',
    title: 'Organization',
    routeName: RouteNames.organizationProfile,
    module: 'organization',
    icon: Icons.business,
    roles: [UserRole.admin],
    builder: (_, __) => const OrganizationProfileScreen(),
  ),
  AppRoute(
    path: '/organization/profile',
    title: 'Organization Profile (Legacy)',
    routeName: 'org-profile-legacy',
    module: 'organization',
    showInMenu: false,
    roles: [UserRole.admin],
    builder: (_, __) => const OrganizationProfileScreen(), // Or use a redirect if GoRouter supports it within AppRoute
  ),
  AppRoute(
    path: '/settings',
    title: 'Settings',
    routeName: RouteNames.settings,
    module: 'settings',
    icon: Icons.settings,
    roles: [UserRole.admin, UserRole.staff],
    builder: (_, __) => const SettingsScreen(),
    children: [
      AppRoute(path: 'printer', title: 'Printer Setup', routeName: RouteNames.printerSetup, module: 'settings', roles: [UserRole.admin, UserRole.staff], builder: (_, __) => const PrinterSetupScreen()),
    ],
  ),
];
