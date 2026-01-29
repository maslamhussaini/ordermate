// lib/features/reports/presentation/screens/ledger_report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/reports/presentation/providers/report_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';

class LedgerReportScreen extends ConsumerStatefulWidget {
  final String type; // customer, vendor, bank, cash, gl
  const LedgerReportScreen({super.key, required this.type});

  @override
  ConsumerState<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends ConsumerState<LedgerReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  dynamic _selectedEntity; // BusinessPartner or ChartOfAccount
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.type == 'customer') {
        ref.read(businessPartnerProvider.notifier).loadCustomers();
      } else if (widget.type == 'vendor') {
        ref.read(businessPartnerProvider.notifier).loadVendors();
      } else if (widget.type == 'gl') {
        ref.read(accountingProvider.notifier).loadAll();
      } else if (widget.type == 'bank' || widget.type == 'cash') {
        ref.read(accountingProvider.notifier).loadBankCashAccounts();
        ref.read(accountingProvider.notifier).loadAll(); // For COA mapping
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = "${widget.type[0].toUpperCase()}${widget.type.substring(1)} Ledger";
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _selectedEntity == null
                ? _buildEntitySelector()
                : _buildLedgerView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  label: 'Start Date',
                  value: _startDate,
                  onChanged: (date) {
                    setState(() => _startDate = date);
                    if (_selectedEntity != null) _loadLedger();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDatePicker(
                  label: 'End Date',
                  value: _endDate,
                  onChanged: (date) {
                    setState(() => _endDate = date);
                    if (_selectedEntity != null) _loadLedger();
                  },
                ),
              ),
            ],
          ),
          if (_selectedEntity != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Account: ${_getEntityName()}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selectedEntity = null;
                    _transactions = [];
                  }),
                  icon: const Icon(Icons.change_circle_outlined, size: 18),
                  label: const Text('Change'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getEntityName() {
    if (_selectedEntity is BusinessPartner) return (_selectedEntity as BusinessPartner).name;
    if (_selectedEntity is ChartOfAccount) return (_selectedEntity as ChartOfAccount).accountTitle;
    return "Unknown";
  }

  String? _getEntityAccountId() {
    if (_selectedEntity is BusinessPartner) return (_selectedEntity as BusinessPartner).chartOfAccountId;
    if (_selectedEntity is ChartOfAccount) return (_selectedEntity as ChartOfAccount).id;
    return null;
  }

  Widget _buildDatePicker({required String label, required DateTime value, required ValueChanged<DateTime> onChanged}) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) onChanged(date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Text(DateFormat('MMM dd, yyyy').format(value)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntitySelector() {
    if (widget.type == 'customer' || widget.type == 'vendor') {
      final state = ref.watch(businessPartnerProvider);
      final partners = widget.type == 'customer' ? state.customers : state.vendors;
      
      return ListView.builder(
        itemCount: partners.length,
        itemBuilder: (context, index) {
          final p = partners[index];
          return ListTile(
            leading: CircleAvatar(child: Text(p.name[0])),
            title: Text(p.name),
            subtitle: Text(p.phone ?? p.email ?? ''),
            onTap: () {
              setState(() => _selectedEntity = p);
              _loadLedger();
            },
          );
        },
      );
    } else if (widget.type == 'bank' || widget.type == 'cash') {
      final accountingState = ref.watch(accountingProvider);
      final bankCash = accountingState.bankCashAccounts;
      final accounts = accountingState.accounts;
      final categories = accountingState.categories;

      final filteredList = bankCash.where((bc) {
        final account = accounts.where((a) => a.id == bc.chartOfAccountId).firstOrNull;
        if (account == null) return false;
        
        final category = categories.where((c) => c.id == account.accountCategoryId).firstOrNull;
        if (category == null) return false;
        
        final catName = category.categoryName.toLowerCase();
        if (widget.type == 'bank') return catName.contains('bank');
        if (widget.type == 'cash') return catName.contains('cash');
        return false;
      }).toList();

      return ListView.builder(
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final bc = filteredList[index];
          final account = accounts.where((a) => a.id == bc.chartOfAccountId).firstOrNull;
          
          return ListTile(
            leading: Icon(widget.type == 'bank' ? Icons.account_balance : Icons.payments, color: Colors.indigo),
            title: Text(bc.name),
            subtitle: Text(account?.accountTitle ?? ''),
            onTap: () {
              setState(() => _selectedEntity = account);
              _loadLedger();
            },
          );
        },
      );
    } else {
      // Generic GL
      final accounts = ref.watch(accountingProvider).accounts;
      return ListView.builder(
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final acc = accounts[index];
          return ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(acc.accountTitle),
            subtitle: Text(acc.accountCode),
            onTap: () {
              setState(() => _selectedEntity = acc);
              _loadLedger();
            },
          );
        },
      );
    }
  }

  Future<void> _loadLedger() async {
    final accountId = _getEntityAccountId();
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Critical: Account ID not linked to this entity.")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(reportRepositoryProvider);
      final results = await repo.getAccountLedger(
        accountId,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _transactions = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildLedgerView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_transactions.isEmpty) return const Center(child: Text("No transactions found for the selected period."));

    double runningBalance = 0.0; // Needs initial balance?
    
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Voucher #')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Debit')),
            DataColumn(label: Text('Credit')),
            DataColumn(label: Text('Balance')),
          ],
          rows: _transactions.map<DataRow>((tx) {
            final mainAccountId = _getEntityAccountId();
            bool isDebitEntry = tx.accountId == mainAccountId;
            
            // For Customer (Asset/Receivable), normal balance is Debit.
            // For Vendor (Liability/Payable), normal balance is Credit.
            bool isCreditNormal = widget.type == 'vendor'; 
            
            final debit = isDebitEntry ? tx.amount : 0.0;
            final credit = !isDebitEntry ? tx.amount : 0.0;
            
            if (isCreditNormal) {
               runningBalance += (credit - debit);
            } else {
               runningBalance += (debit - credit);
            }

            return DataRow(cells: [
              DataCell(Text(DateFormat('yyyy-MM-dd').format(tx.voucherDate))),
              DataCell(Text(tx.voucherNumber)),
              DataCell(SizedBox(width: 150, child: Text(tx.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis))),
              DataCell(Text(debit > 0 ? debit.toStringAsFixed(2) : '-')),
              DataCell(Text(credit > 0 ? credit.toStringAsFixed(2) : '-')),
              DataCell(Text(runningBalance.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
