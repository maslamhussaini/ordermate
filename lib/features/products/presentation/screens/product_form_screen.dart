import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/widgets/lookup_field.dart';

import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/vendors/domain/entities/vendor.dart';
import 'package:ordermate/features/vendors/presentation/providers/vendor_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart' show AccountCategory;

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController(text: '0.0');
  final _priceController = TextEditingController(text: '0.0');
  final _limitPriceController = TextEditingController(text: '0.0');
  final _stockQtyController = TextEditingController(text: '0.0');
  final _baseQuantityController = TextEditingController(text: '1.0');
  final _defaultDiscountController = TextEditingController(text: '0.0');
  final _discountLimitController = TextEditingController(text: '0.0');

  // Selected Values
  int? _selectedTypeId;
  int? _selectedCategoryId;
  int? _selectedBrandId;
  int? _selectedUomId;
  String? _uomSymbol;
  String? _selectedBusinessPartnerId;

  // GL Accounts
  String? _selectedInventoryGlId;
  String? _selectedCogsGlId;
  String? _selectedRevenueGlId;
  String? _selectedSalesDiscountGlId;

  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInitialData);
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      
      // Load lookup data with individual try-catches and timeouts
      final loadTasks = [
        ('Inventory', () => ref.read(inventoryProvider.notifier).loadAll()),
        ('Vendors', () => ref.read(vendorProvider.notifier).loadVendors()),
        ('Suppliers', () => ref.read(vendorProvider.notifier).loadSuppliers()),
        ('Accounting', () => ref.read(accountingProvider.notifier).loadAll(organizationId: orgId)),
        ('GL Setup', () => ref.read(accountingProvider.notifier).loadGLSetup(organizationId: orgId)),
      ];

      for (final task in loadTasks) {
        try {
          await task.$2().timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('ProductForm: Failed to load ${task.$1}: $e');
          // We continue to allow the screen to open even if one fails
        }
      }
      
      if (!mounted) return;

      // Handle extra from navigation
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null && extra.containsKey('vendorId')) {
         final vId = extra['vendorId'] as String;
         final vState = ref.read(vendorProvider);
         final vendor = [...vState.vendors, ...vState.suppliers]
             .cast<Vendor?>()
             .firstWhere((v) => v?.id == vId, orElse: () => null);
             
         if (vendor != null) {
           _selectedBusinessPartnerId = vId;
           try {
             final matchingBrand = ref.read(inventoryProvider).brands.firstWhere(
               (b) => b.name.toLowerCase() == vendor.name.toLowerCase(),
             );
             _selectedBrandId = matchingBrand.id;
           } catch (_) {}
         }
      }

      // If editing, populate fields
      if (widget.productId != null) {
        final products = ref.read(productProvider).products;
        if (products.isEmpty) {
          await ref.read(productProvider.notifier).loadProducts();
        }

        final product = ref.read(productProvider).products
            .cast<Product>()
            .firstWhere((p) => p.id == widget.productId, orElse: () => throw Exception('Product not found'),);

        _nameController.text = product.name;
        _skuController.text = product.sku;
        _descriptionController.text = product.description ?? '';
        _costController.text = product.cost.toString();
        _priceController.text = product.rate.toString();
        _limitPriceController.text = product.limitPrice.toString();
        _stockQtyController.text = product.stockQty.toString();
        _baseQuantityController.text = product.baseQuantity.toString();
        _selectedUomId = product.uomId;
        _uomSymbol = product.uomSymbol;
        _selectedInventoryGlId = product.inventoryGlId;
        _selectedCogsGlId = product.cogsGlId;
        _selectedRevenueGlId = product.revenueGlId;
        _selectedSalesDiscountGlId = product.salesDiscountGlId;
        _defaultDiscountController.text = product.defaultDiscountPercent.toString();
        _discountLimitController.text = product.defaultDiscountPercentLimit.toString();

        final invState = ref.read(inventoryProvider);
        final vendorState = ref.read(vendorProvider);

        if (invState.productTypes.any((t) => t.id == product.productTypeId)) {
          _selectedTypeId = product.productTypeId;
        }
        if (invState.categories.any((c) => c.id == product.categoryId)) {
          _selectedCategoryId = product.categoryId;
        }
        if (invState.brands.any((b) => b.id == product.brandId)) {
          _selectedBrandId = product.brandId;
        }
        if ([...vendorState.vendors, ...vendorState.suppliers].any((v) => v.id == product.businessPartnerId)) {
          _selectedBusinessPartnerId = product.businessPartnerId;
        }

        // If sales discount account is missing, try to get from GLSetup
        if (_selectedSalesDiscountGlId == null) {
           _selectedSalesDiscountGlId = ref.read(accountingProvider).glSetup?.salesDiscountAccountId;
        }
      } else {
        // New Product - default GL accounts from GLSetup
        final setup = ref.read(accountingProvider).glSetup;
        if (setup != null) {
           _selectedInventoryGlId = setup.inventoryAccountId;
           _selectedCogsGlId = setup.cogsAccountId;
           _selectedRevenueGlId = setup.salesAccountId;
           _selectedSalesDiscountGlId = setup.salesDiscountAccountId;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _limitPriceController.dispose();
    _stockQtyController.dispose();
    _baseQuantityController.dispose();
    _defaultDiscountController.dispose();
    _discountLimitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ChartOfAccount> _getFilteredAccounts(String categoryKeyword) {
    final accState = ref.read(accountingProvider);
    final allAccounts = accState.accounts;
    final categories = accState.categories;
    
    return allAccounts.where((account) {
       if (account.accountCategoryId == null) return false;
       final cat = categories.firstWhere((c) => c.id == account.accountCategoryId, orElse: () => const AccountCategory(id: 0, categoryName: '', accountTypeId: 0, organizationId: 0, status: false));
       if (!cat.categoryName.toLowerCase().contains(categoryKeyword.toLowerCase())) return false;
       if (account.level != 3 && account.level != 4) return false;
       return true;
    }).toList()..sort((a, b) => a.accountCode.compareTo(b.accountCode));
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final orgState = ref.read(organizationProvider);
      final product = Product(
        id: widget.productId ?? '',
        name: _nameController.text.trim(),
        sku: _skuController.text.trim(),
        description: _descriptionController.text.trim(),
        rate: double.tryParse(_priceController.text) ?? 0.0,
        cost: double.tryParse(_costController.text) ?? 0.0,
        limitPrice: double.tryParse(_limitPriceController.text) ?? 0.0,
        stockQty: double.tryParse(_stockQtyController.text) ?? 0.0,
        inventoryGlId: _selectedInventoryGlId,
        cogsGlId: _selectedCogsGlId,
        revenueGlId: _selectedRevenueGlId,
        businessPartnerId: (_selectedBusinessPartnerId?.isEmpty ?? true) ? null : _selectedBusinessPartnerId,
        productTypeId: _selectedTypeId,
        categoryId: _selectedCategoryId,
        brandId: _selectedBrandId,
        uomSymbol: _uomSymbol,
        baseQuantity: double.tryParse(_baseQuantityController.text) ?? 1.0,
        defaultDiscountPercent: double.tryParse(_defaultDiscountController.text) ?? 0.0,
        defaultDiscountPercentLimit: double.tryParse(_discountLimitController.text) ?? 0.0,
        salesDiscountGlId: _selectedSalesDiscountGlId,
        storeId: orgState.selectedStore?.id ?? 0,
        organizationId: orgState.selectedOrganization?.id ?? 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.productId == null) {
        await ref.read(productProvider.notifier).addProduct(product);
      } else {
        await ref.read(productProvider.notifier).updateProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product saved successfully')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final vendorState = ref.watch(vendorProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product'),
        actions: [
          IconButton(onPressed: _isLoading ? null : _saveProduct, icon: const Icon(Icons.save)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Scrollbar(
                    controller: _scrollController,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        _buildSectionHeader('Basic Information'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(labelText: 'SKU', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Classification'),
                        const SizedBox(height: 16),
                        LookupField<ProductType, int>(
                          label: 'Product Type',
                          value: _selectedTypeId,
                          items: inventoryState.productTypes,
                          onChanged: (v) => setState(() => _selectedTypeId = v),
                          labelBuilder: (item) => item.name,
                          valueBuilder: (item) => item.id,
                          onAdd: (name) async {
                            await ref.read(inventoryProvider.notifier).addProductType(name);
                            final newItem = ref.read(inventoryProvider).productTypes.firstWhere((i) => i.name == name);
                            setState(() => _selectedTypeId = newItem.id);
                          },
                        ),
                        const SizedBox(height: 16),
                        LookupField<ProductCategory, int>(
                          label: 'Category',
                          value: _selectedCategoryId,
                          items: inventoryState.categories,
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                          labelBuilder: (item) => item.name,
                          valueBuilder: (item) => item.id,
                          onAdd: (name) async {
                            await ref.read(inventoryProvider.notifier).addCategory(name);
                            final newItem = ref.read(inventoryProvider).categories.firstWhere((i) => i.name == name);
                            setState(() => _selectedCategoryId = newItem.id);
                          },
                        ),
                        const SizedBox(height: 16),
                        LookupField<Brand, int>(
                          label: 'Brand',
                          value: _selectedBrandId,
                          items: inventoryState.brands,
                          onChanged: (v) => setState(() => _selectedBrandId = v),
                          labelBuilder: (item) => item.name,
                          valueBuilder: (item) => item.id,
                          onAdd: (name) async {
                            await ref.read(inventoryProvider.notifier).addBrand(name);
                            final newItem = ref.read(inventoryProvider).brands.firstWhere((i) => i.name == name);
                            setState(() => _selectedBrandId = newItem.id);
                          },
                        ),
                        const SizedBox(height: 16),
                        LookupField<Vendor, String>(
                          label: 'Supplier',
                          value: _selectedBusinessPartnerId,
                          items: vendorState.suppliers,
                          onChanged: (v) => setState(() => _selectedBusinessPartnerId = v),
                          labelBuilder: (item) => item.name,
                          valueBuilder: (item) => item.id,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Pricing & Inventory'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: LookupField<UnitOfMeasure, int>(
                                label: 'Base Unit',
                                value: _selectedUomId,
                                items: inventoryState.unitsOfMeasure,
                                onChanged: (v) {
                                  final uom = inventoryState.unitsOfMeasure.firstWhere((u) => u.id == v);
                                  setState(() {
                                    _selectedUomId = v;
                                    _uomSymbol = uom.symbol;
                                  });
                                },
                                labelBuilder: (item) => '${item.name} (${item.symbol})',
                                valueBuilder: (item) => item.id,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _baseQuantityController,
                                decoration: InputDecoration(
                                  labelText: 'Base Qty (e.g. 1.0)',
                                  border: const OutlineInputBorder(),
                                  suffixText: _uomSymbol ?? '',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _costController,
                                decoration: const InputDecoration(labelText: 'Cost Price', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                decoration: const InputDecoration(labelText: 'Sales Price', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _limitPriceController,
                                decoration: const InputDecoration(labelText: 'Limit Price (Min)', border: OutlineInputBorder(), hintText: 'Minimum Price'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _stockQtyController,
                                decoration: const InputDecoration(labelText: 'Opening Stock', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Accounting (GL Accounts)'),
                        const SizedBox(height: 16),
                        LookupField<ChartOfAccount, String>(
                          label: 'Inventory Asset Account',
                          value: _selectedInventoryGlId,
                          items: _getFilteredAccounts('Inventory'),
                          onChanged: (v) => setState(() => _selectedInventoryGlId = v),
                          labelBuilder: (item) => '${item.accountCode} - ${item.accountTitle}',
                          valueBuilder: (item) => item.id,
                        ),
                        const SizedBox(height: 16),
                        LookupField<ChartOfAccount, String>(
                          label: 'COGS Account',
                          value: _selectedCogsGlId,
                          items: _getFilteredAccounts('COGS'),
                          onChanged: (v) => setState(() => _selectedCogsGlId = v),
                          labelBuilder: (item) => '${item.accountCode} - ${item.accountTitle}',
                          valueBuilder: (item) => item.id,
                        ),
                        const SizedBox(height: 16),
                        LookupField<ChartOfAccount, String>(
                          label: 'Revenue/Sales Account',
                          value: _selectedRevenueGlId,
                          items: _getFilteredAccounts('BasicRevenue'),
                          onChanged: (v) => setState(() => _selectedRevenueGlId = v),
                          labelBuilder: (item) => '${item.accountCode} - ${item.accountTitle}',
                          valueBuilder: (item) => item.id,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Discounts'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _defaultDiscountController,
                                decoration: const InputDecoration(
                                  labelText: 'Default Discount %',
                                  border: OutlineInputBorder(),
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _discountLimitController,
                                decoration: const InputDecoration(
                                  labelText: 'Discount Limit %',
                                  border: OutlineInputBorder(),
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LookupField<ChartOfAccount, String>(
                          label: 'Sales Discount Account',
                          value: _selectedSalesDiscountGlId,
                          items: _getFilteredAccounts('Discount'),
                          onChanged: (v) => setState(() => _selectedSalesDiscountGlId = v),
                          labelBuilder: (item) => '${item.accountCode} - ${item.accountTitle}',
                          valueBuilder: (item) => item.id,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.indigo)),
        const Divider(),
      ],
    );
  }
}
