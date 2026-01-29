// lib/features/accounting/presentation/screens/transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accounting_provider.dart';
import 'transaction_form_screen.dart';
import '../utils/transaction_printer.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';

import 'package:intl/intl.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/core/widgets/processing_dialog.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy');
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
       final orgId = ref.read(organizationProvider).selectedOrganizationId;
       final storeId = ref.read(organizationProvider).selectedStore?.id;
       // Load using current global selection
       final sYear = ref.read(accountingProvider).selectedFinancialSession?.sYear;
       ref.read(accountingProvider.notifier).loadTransactions(organizationId: orgId, storeId: storeId, sYear: sYear);
       ref.read(accountingProvider.notifier).loadAll(organizationId: orgId);
       ref.read(businessPartnerProvider.notifier).loadCustomers();
       ref.read(businessPartnerProvider.notifier).loadVendors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final partnerState = ref.watch(businessPartnerProvider);
    final selectedStore = ref.watch(organizationProvider).selectedStore;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
               final orgId = ref.read(organizationProvider).selectedOrganizationId;
               final storeId = ref.read(organizationProvider).selectedStore?.id;
               final sYear = ref.read(accountingProvider).selectedFinancialSession?.sYear;
               ref.read(accountingProvider.notifier).loadTransactions(organizationId: orgId, storeId: storeId, sYear: sYear);
            },
          ),
        ],
      ),
      floatingActionButton: (state.selectedFinancialSession?.isClosed == true) 
          ? null // Hide Create button if closed year selected
          : FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TransactionFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: state.isLoading && state.transactions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.transactions.isEmpty
              ? Center(child: Text('Error: ${state.error}'))
              : state.transactions.isEmpty
                  ? const Center(child: Text('No transactions found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: state.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = state.transactions[index];

                        // Helper to find account name
                        String getAccountName(String id) {
                           final gl = state.accounts.where((a) => a.id == id).firstOrNull;
                           if (gl != null) return '${gl.accountCode} - ${gl.accountTitle}';
                           
                           final cust = partnerState.customers.where((c) => c.id == id).firstOrNull;
                           if (cust != null) return '[CUST] ${cust.name}';

                           final vend = partnerState.vendors.where((v) => v.id == id).firstOrNull;
                           if (vend != null) return '[VEND] ${vend.name}';

                           final bank = state.bankCashAccounts.where((b) => b.id == id).firstOrNull;
                           if (bank != null) return '[BANK] ${bank.name}';

                           return id; // Fallback
                        }

                        final accountName = getAccountName(tx.accountId);
                        final offsetAccountName = tx.offsetAccountId != null ? getAccountName(tx.offsetAccountId!) : null;
                        
                        // We also need Objects for Printer pass-through (if it expects ChartOfAccount)
                        // The printer expects ChartOfAccount. If it's a BP, we might need to mock or update Printer.
                        // TransactionPrinter uses: account?.accountTitle ?? tx.accountId.
                        // So passing null for 'account' (ChartOfAccount) means it prints the ID. 
                        // We should probably update printer too?
                        // For now, let's keep printer as is, but UI will show correct name.
                        // Wait, 'account' variable in build was ChartOfAccount.
                        // I will remove that strict type dependency in UI display logic.

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.blue.withValues(alpha: 0.12) 
                                  : Colors.blue.shade50,
                              child: const Icon(Icons.receipt_long, color: Colors.blue),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tx.voucherNumber,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  NumberFormat.currency(symbol: '').format(tx.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: tx.amount < 0 ? Colors.red : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_dateFormat.format(tx.voucherDate)),
                                Text(
                                  tx.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tx.status == 'posted' ? Colors.blue : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow('Account', accountName),
                                    if (tx.offsetAccountId != null)
                                      _buildDetailRow('Offset Account', offsetAccountName!),
                                    if (tx.description != null && tx.description!.isNotEmpty)
                                      _buildDetailRow('Description', tx.description!),
                                    _buildDetailRow('Voucher Type ID', tx.voucherPrefixId.toString()),
                                    
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        if (state.financialSessions.any((s) => s.sYear == tx.sYear && s.isClosed)) 
                                           const Padding(
                                             padding: EdgeInsets.all(8.0),
                                             child: Text('Read Only (Closed Year)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                           )
                                        else ...[
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.edit, size: 16),
                                            label: const Text('Edit'),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => TransactionFormScreen(transaction: tx)),
                                              );
                                            },
                                          ),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.print, size: 16),
                                            label: const Text('Print'),
                                            onPressed: () async {
                                              final org = ref.read(organizationProvider).selectedOrganization;
                                              
                                              // Mock ChartOfAccount wrappers for Printer using resolved names
                                              final mockAccount = ChartOfAccount(
                                                  id: tx.accountId, accountCode: '', accountTitle: accountName, 
                                                  level: 0, createdAt: DateTime.now(), updatedAt: DateTime.now(), organizationId: org?.id ?? 0);
                                              final mockOffset = tx.offsetAccountId != null ? ChartOfAccount(
                                                  id: tx.offsetAccountId!, accountCode: '', accountTitle: offsetAccountName!, 
                                                  level: 0, createdAt: DateTime.now(), updatedAt: DateTime.now(), organizationId: org?.id ?? 0) : null;
  
                                              await TransactionPrinter.printTransaction(
                                                tx: tx,
                                                account: mockAccount,
                                                offsetAccount: mockOffset,
                                                org: org,
                                              );
                                            },
                                          ),
                                           OutlinedButton.icon(
                                            icon: const Icon(Icons.share, size: 16),
                                            label: const Text('Share'),
                                            onPressed: () async {
                                             final org = ref.read(organizationProvider).selectedOrganization;
                                              // Mock for printer
                                              final mockAccount = ChartOfAccount(
                                                  id: tx.accountId, accountCode: '', accountTitle: accountName, 
                                                  level: 0, createdAt: DateTime.now(), updatedAt: DateTime.now(), organizationId: org?.id ?? 0);
                                              final mockOffset = tx.offsetAccountId != null ? ChartOfAccount(
                                                  id: tx.offsetAccountId!, accountCode: '', accountTitle: offsetAccountName!, 
                                                  level: 0, createdAt: DateTime.now(), updatedAt: DateTime.now(), organizationId: org?.id ?? 0) : null;
  
                                              await TransactionPrinter.shareTransaction(
                                                tx: tx,
                                                account: mockAccount,
                                                offsetAccount: mockOffset,
                                                org: org,
                                              );
                                            },
                                          ),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                            label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Delete Transaction'),
                                                  content: const Text('Are you sure you want to delete this transaction?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                      onPressed: () => Navigator.pop(context, true),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              
                                              if (confirm == true) {
                                                 await showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => ProcessingDialog(
                                                    initialMessage: 'Deleting Transaction...',
                                                    successMessage: 'Deleted Successfully!',
                                                    task: () async {
                                                      await ref.read(accountingProvider.notifier).deleteTransaction(tx.id);
                                                    },
                                                  ),
                                                 );
                                              }
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SContentText('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class SContentText extends Text {
  const SContentText(super.data, {super.key, super.style});
}
