import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/gl_setup.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class GLSetupScreen extends ConsumerStatefulWidget {
  const GLSetupScreen({super.key});

  @override
  ConsumerState<GLSetupScreen> createState() => _GLSetupScreenState();
}

class _GLSetupScreenState extends ConsumerState<GLSetupScreen> {
  String? _selectedInventoryId;
  String? _selectedCogsId;
  String? _selectedSalesId;
  String? _selectedBankId;
  String? _selectedCashId;
  String? _selectedTaxOutputId;
  String? _selectedTaxInputId;
  String? _selectedSalesDiscountId;
  String? _selectedPurchaseDiscountId;

  // Removed _selectedReceivableId and _selectedPayableId

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final org = ref.read(organizationProvider).selectedOrganization;
      if (org != null) {
        ref
            .read(accountingProvider.notifier)
            .loadGLSetup(organizationId: org.id);
        ref.read(accountingProvider.notifier).loadAll(organizationId: org.id);
      }
    });
  }

  void _save() {
    final org = ref.read(organizationProvider).selectedOrganization;
    if (org == null) return;

    if (_selectedInventoryId == null ||
        _selectedCogsId == null ||
        _selectedSalesId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required accounts')),
      );
      return;
    }

    // Preserve existing AR/AP values from state if available, or leave null if not set
    final existingSetup = ref.read(accountingProvider).glSetup;

    final setup = GLSetup(
      organizationId: org.id,
      inventoryAccountId: _selectedInventoryId!,
      cogsAccountId: _selectedCogsId!,
      salesAccountId: _selectedSalesId!,
      receivableAccountId: existingSetup?.receivableAccountId, // Preserve
      payableAccountId: existingSetup?.payableAccountId, // Preserve
      bankAccountId: _selectedBankId,
      cashAccountId: _selectedCashId,
      taxOutputAccountId: _selectedTaxOutputId,
      taxInputAccountId: _selectedTaxInputId,
      salesDiscountAccountId: _selectedSalesDiscountId,
      purchaseDiscountAccountId: _selectedPurchaseDiscountId,
    );

    ref.read(accountingProvider.notifier).saveGLSetup(setup).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GL Setup saved successfully')),
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    });
  }

  // Filter Helper
  List<ChartOfAccount> _getFilteredAccounts(
      List<ChartOfAccount> allAccounts, String categoryKeyword) {
    // 1. Filter by Level 4 (Ledger) -> Assuming level 4 or leaf.
    // If level is not reliable, we might check if 'parentId' is present or logic changes.
    // User requirement: "no group account only ledger account".
    // 2. Filter by Category Name Like 'categoryKeyword'

    final categories = ref.read(accountingProvider).categories;

    return allAccounts.where((account) {
      // Filter Logic
      // Check if Level 4 (Leaf) ?? Or check if it has children?
      // For now assuming Level 4 is standard ledger level.
      // User said "no group account". In many systems Level < Max are groups.
      // Let's assume level 4.
      // UPDATE: If the user system allows variable depth, we might need a property 'isGroup'.
      // Previous code comments said "show all level 4".
      // Let's stick with Level 4 check IF consistent, or just use category filtering.
      // I'll filter by Category Name first.

      if (account.accountCategoryId == null) return false;

      final cat = categories.firstWhere(
          (c) => c.id == account.accountCategoryId,
          orElse: () => const AccountCategory(
              id: 0,
              categoryName: '',
              accountTypeId: 0,
              status: false,
              organizationId: 0));

      if (!cat.categoryName
          .toLowerCase()
          .contains(categoryKeyword.toLowerCase())) {
        return false;
      }

      // Check Group/Ledger (Assuming Level 4 is Ledger as per previous comments)
      // Or if 'level' isn't sufficient, maybe I check if others have parentId == account.id? Too expensive.
      // I will assume Level 4 is safe based on previous code.
      // Or I can check naming convention? No.
      // Let's use `level == 4`.
      if (account.level != 3 && account.level != 4) return false;

      return true;
    }).toList()
      ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);

    // Initialize selections from state if not already set
    if (state.glSetup != null && _selectedInventoryId == null) {
      final s = state.glSetup!;
      _selectedInventoryId = s.inventoryAccountId;
      _selectedCogsId = s.cogsAccountId;
      _selectedSalesId = s.salesAccountId;
      _selectedBankId = s.bankAccountId;
      _selectedCashId = s.cashAccountId;
      _selectedTaxOutputId = s.taxOutputAccountId;
      _selectedTaxInputId = s.taxInputAccountId;
      _selectedSalesDiscountId = s.salesDiscountAccountId;
      _selectedPurchaseDiscountId = s.purchaseDiscountAccountId;
    }

    final accounts = state.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('General Ledger Setup'),
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Standard Business Accounts (Required)'),
                  const SizedBox(height: 16),
                  _buildAccountDropdown(
                    'Inventory Account',
                    'Default account for stock/inventory',
                    _getFilteredAccounts(accounts, 'Inventory'),
                    _selectedInventoryId,
                    (val) => setState(() => _selectedInventoryId = val),
                  ),
                  _buildAccountDropdown(
                    'COGS Account',
                    'Cost of Goods Sold expense account',
                    _getFilteredAccounts(accounts, 'COGS'),
                    _selectedCogsId,
                    (val) => setState(() => _selectedCogsId = val),
                  ),
                  _buildAccountDropdown(
                    'Sales Revenue Account',
                    'Account for recording sales income',
                    _getFilteredAccounts(
                        accounts, 'BasicRevenue'), // Category Like BasicRevenue
                    _selectedSalesId,
                    (val) => setState(() => _selectedSalesId = val),
                  ),
                  // Removed AR/AP

                  const SizedBox(height: 16),
                  _buildSectionHeader('Discount Accounts'),
                  const SizedBox(height: 16),
                  _buildAccountDropdown(
                    'Default Sales Discount GL Account',
                    'Account for sales discounts',
                    _getFilteredAccounts(accounts, 'Revenue Discount'),
                    _selectedSalesDiscountId,
                    (val) => setState(() => _selectedSalesDiscountId = val),
                  ),
                  _buildAccountDropdown(
                    'Default Purchase Discount GL Account',
                    'Account for purchase discounts',
                    _getFilteredAccounts(accounts, 'Purchase Discount'),
                    _selectedPurchaseDiscountId,
                    (val) => setState(() => _selectedPurchaseDiscountId = val),
                  ),

                  const Divider(height: 48),
                  _buildSectionHeader('Financial & Tax Accounts (Optional)'),
                  const SizedBox(height: 16),
                  _buildAccountDropdown(
                    'Default Bank Account',
                    'Preferred bank for transactions',
                    _getFilteredAccounts(accounts, 'Bank'),
                    _selectedBankId,
                    (val) => setState(() => _selectedBankId = val),
                  ),
                  _buildAccountDropdown(
                    'Default Cash Account',
                    'Main cash-in-hand account',
                    _getFilteredAccounts(accounts, 'Cash'),
                    _selectedCashId,
                    (val) => setState(() => _selectedCashId = val),
                  ),
                  _buildAccountDropdown(
                    'GST Output Account',
                    'Tax collected on sales',
                    _getFilteredAccounts(accounts, 'Sales Tax PA'),
                    _selectedTaxOutputId,
                    (val) => setState(() => _selectedTaxOutputId = val),
                  ),
                  _buildAccountDropdown(
                    'GST Input Account',
                    'Tax paid on purchases',
                    _getFilteredAccounts(accounts, 'Sales Tax RA'),
                    _selectedTaxInputId,
                    (val) => setState(() => _selectedTaxInputId = val),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save GL Configuration'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    );
  }

  Widget _buildAccountDropdown(
    String label,
    String hint,
    List<ChartOfAccount> accounts,
    String? selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: DropdownButtonFormField<String>(
        initialValue: accounts.any((a) => a.id == selectedValue)
            ? selectedValue
            : null, // Safer initialization
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: accounts.map((account) {
          return DropdownMenuItem<String>(
            value: account.id,
            child: Text('${account.accountCode} - ${account.accountTitle}'),
          );
        }).toList(),
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }
}
