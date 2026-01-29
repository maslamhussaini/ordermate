import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(accountingProvider.notifier).getInvoiceItems(widget.invoiceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final partnerState = ref.watch(businessPartnerProvider);
    
    // Find Invoice in list (it should be loaded if coming from list)
    final invoice = state.invoices.where((i) => i.id == widget.invoiceId).firstOrNull;
    final items = state.currentInvoiceItems; // updated by getInvoiceItems

    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice Details')),
        body: const Center(child: Text('Invoice not found')),
      );
    }

    final partnerName = partnerState.customers.where((c) => c.id == invoice.businessPartnerId).firstOrNull?.name 
                        ?? 'Customer ID: ${invoice.businessPartnerId}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice ${invoice.invoiceNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer: $partnerName', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    _buildRow('Invoice Number', invoice.invoiceNumber),
                    _buildRow('Date', DateFormat('dd MMM yyyy').format(invoice.invoiceDate)),
                    if (invoice.dueDate != null)
                      _buildRow('Due Date', DateFormat('dd MMM yyyy').format(invoice.dueDate!)),
                    _buildRow('Status', invoice.status),
                    Divider(),
                    _buildRow('Total Amount', NumberFormat.currency(symbol: '').format(invoice.totalAmount), isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Items Table
            const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            state.isLoading && items.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('Qty'), numeric: true),
                        DataColumn(label: Text('Rate'), numeric: true),
                        DataColumn(label: Text('Total'), numeric: true),
                      ],
                      rows: items.map((item) {
                        return DataRow(cells: [
                          DataCell(Text(item.productName ?? item.productId)),
                          DataCell(Text(item.quantity.toString())),
                          DataCell(Text(NumberFormat.currency(symbol: '').format(item.rate))),
                          DataCell(Text(NumberFormat.currency(symbol: '').format(item.total))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14)),
        ],
      ),
    );
  }
}
