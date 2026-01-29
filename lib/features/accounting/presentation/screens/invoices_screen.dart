import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/services/pdf_invoice_service.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';

import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:ordermate/features/settings/presentation/providers/settings_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/invoice.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart'; 
import 'package:ordermate/features/orders/presentation/screens/pdf_preview_screen.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:ordermate/core/providers/auth_provider.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  final String? initialFilterType;
  const InvoicesScreen({super.key, this.initialFilterType});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All';
  late String? _filterType;

  @override
  void initState() {
    super.initState();
    _filterType = widget.initialFilterType;
    Future.microtask(() {
      final orgId = ref.read(organizationProvider).selectedOrganizationId;
      final storeId = ref.read(organizationProvider).selectedStore?.id;
      ref.read(accountingProvider.notifier).loadInvoices(organizationId: orgId, storeId: storeId);
      ref.read(businessPartnerProvider.notifier).loadCustomers();
      ref.read(businessPartnerProvider.notifier).loadVendors(); // Ensure vendors are loaded for GL posting lookup
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTitle() {
    switch (_filterType) {
      case 'SI':
        return 'Sales Invoices';
      case 'SR':
        return 'Sales Returns';
      case 'PI':
        return 'Purchase Invoices';
      case 'PR':
        return 'Purchase Returns';
      default:
        return 'All Invoices';
    }
  }

  Future<void> _handlePdfAction(Invoice invoice, String action) async {
    // Show Loading
    if (!mounted) return;
    
    final ValueNotifier<String> statusMessage = ValueNotifier('Initializing...');
    final ValueNotifier<double> progressValue = ValueNotifier(0.0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              ValueListenableBuilder<double>(
                valueListenable: progressValue,
                builder: (context, val, _) => LinearProgressIndicator(value: val, minHeight: 6),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: statusMessage,
                builder: (context, msg, _) => Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<double>(
                 valueListenable: progressValue,
                 builder: (context, val, _) => Text('${(val * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Fetch Data
      statusMessage.value = 'Fetching invoice items...';
      progressValue.value = 0.1;
      final itemsList = await ref.read(accountingProvider.notifier).getInvoiceItems(invoice.id).timeout(const Duration(seconds: 10));
      final items = itemsList.map((e) {
        final amount = e.rate * e.quantity;
        return {
          'product_name': e.productName,
          'quantity': e.quantity,
          'rate': e.rate,
          'total': e.total,
          'uom_symbol': e.uomSymbol,
          'discount_percent': e.discountPercent,
          'discount': amount - e.total, // Calculate discount amount
        };
      }).toList();

      statusMessage.value = 'Fetching partner details...';
      progressValue.value = 0.2;
      final bpState = ref.read(businessPartnerProvider);
      final partner = bpState.customers.where((c) => c.id == invoice.businessPartnerId).firstOrNull 
                   ?? bpState.vendors.where((v) => v.id == invoice.businessPartnerId).firstOrNull;

      if (partner == null) throw Exception('Business Partner not found');

      final orgState = ref.read(organizationProvider);
      final org = orgState.selectedOrganization;
      final store = orgState.selectedStore ?? (orgState.stores.isNotEmpty ? orgState.stores.first : null);

      // Fetch Logo
      statusMessage.value = 'Fetching organization logo...';
      progressValue.value = 0.25;
      
      Uint8List? logoBytes;
      if (org != null && org.logoUrl != null) {
        try {
          final response = await http.get(Uri.parse(org.logoUrl!)).timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) logoBytes = response.bodyBytes;
        } catch (_) {}
      }

      // Convert Invoice to Order-like structure for the PdfService (which currently expects Order)
      // Or we can update the PdfService. For now, let's mock the Order object
      final mockOrder = Order(
        id: invoice.id,
        orderNumber: invoice.invoiceNumber,
        businessPartnerId: invoice.businessPartnerId,
        orderType: invoice.idInvoiceType, // Pass internal code SI/SIR
        createdBy: '',
        createdByName: ref.read(authProvider).userFullName, // Get current user name
        status: OrderStatus.approved,
        totalAmount: invoice.totalAmount,
        orderDate: invoice.invoiceDate,
        createdAt: invoice.createdAt ?? DateTime.now(),
        updatedAt: invoice.updatedAt ?? DateTime.now(),
        sYear: invoice.sYear,
        organizationId: org?.id ?? 0,
        storeId: store?.id ?? 0,
      );
      
      statusMessage.value = 'Preparing PDF Engine...';
      progressValue.value = 0.3;

      final pdfBytes = await PdfInvoiceService().generateInvoice(
        order: mockOrder,
        items: items,
        customer: partner,
        organizationName: org?.name,
        storeName: store?.name,
        storePhone: store?.phone,
        storeAddress: [
          store?.location ?? '',
          store?.city ?? '',
          store?.postalCode ?? '',
          store?.country ?? '',
        ].where((s) => s.isNotEmpty).join(', '),
        logoBytes: logoBytes,
        settings: ref.read(settingsProvider).pdfSettings,
        currencyCode: store?.storeDefaultCurrency ?? 'PKR',
        onProgress: (msg, val) {
           statusMessage.value = msg;
           progressValue.value = val;
        }
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog correctly

      statusMessage.value = 'Opening PDF...';
      final filename = '${invoice.invoiceNumber}.pdf';
      switch (action) {
        case 'print':
          await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes, name: filename);
        case 'preview':
          await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PdfPreviewScreen(pdfBytes: pdfBytes, fileName: filename)));
        case 'share':
          await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _updateStatus(Invoice invoice, String newStatus) async {
    try {
      if (newStatus == 'Posted') {
        await ref.read(accountingProvider.notifier).postInvoice(invoice);
      } else {
        final updated = invoice.copyWith(status: newStatus);
        await ref.read(accountingProvider.notifier).updateInvoice(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invoice ${newStatus.toLowerCase()} successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text('Are you sure you want to delete ${invoice.invoiceNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(accountingRepositoryProvider).deleteInvoice(invoice.id);
        final orgId = ref.read(organizationProvider).selectedOrganizationId;
        final storeId = ref.read(organizationProvider).selectedStore?.id;
        await ref.read(accountingProvider.notifier).loadInvoices(organizationId: orgId, storeId: storeId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final partnerState = ref.watch(businessPartnerProvider);
    final invoices = state.invoices;
    final isLoading = state.isLoading && invoices.isEmpty;

    // Filter Logic
    final filteredInvoices = invoices.where((invoice) {
      final query = _searchQuery.toLowerCase();
      final partnerName = partnerState.customers
          .where((c) => c.id == invoice.businessPartnerId)
          .firstOrNull
          ?.name ?? '';
      
      final matchesSearch = invoice.invoiceNumber.toLowerCase().contains(query) ||
          partnerName.toLowerCase().contains(query);

      // Type Filter
      if (_filterType != null && invoice.idInvoiceType != _filterType) {
        return false;
      }

      if (_filterStatus == 'All') return matchesSearch;
      return matchesSearch && invoice.status.toLowerCase() == _filterStatus.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final orgId = ref.read(organizationProvider).selectedOrganizationId;
              final storeId = ref.read(organizationProvider).selectedStore?.id;
              ref.read(accountingProvider.notifier).loadInvoices(organizationId: orgId, storeId: storeId);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/invoices/create', extra: {'idInvoiceType': _filterType ?? 'SI'});
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Invoice # or Customer...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      dropdownColor: Colors.indigo,
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      style: const TextStyle(color: Colors.white),
                      items: ['All', 'Draft', 'Posted', 'Paid', 'Cancelled']
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _filterStatus = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Invoices List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('No invoices found', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final orgId = ref.read(organizationProvider).selectedOrganizationId;
                          final storeId = ref.read(organizationProvider).selectedStore?.id;
                          await ref.read(accountingProvider.notifier).loadInvoices(organizationId: orgId, storeId: storeId);
                        },
                        child: ListView.builder(
                          itemCount: filteredInvoices.length,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemBuilder: (context, index) {
                            final invoice = filteredInvoices[index];
                            final partnerName = partnerState.customers
                                .where((c) => c.id == invoice.businessPartnerId)
                                .firstOrNull
                                ?.name ?? 'Customer #${invoice.businessPartnerId.substring(0, 8)}...';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withAlpha(26),
                                  child: const Icon(Icons.receipt, color: Colors.green),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        invoice.invoiceNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(symbol: '').format(invoice.totalAmount),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(partnerName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text('Date: ${DateFormat('dd MMM yyyy').format(invoice.invoiceDate)}'),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(invoice.status).withAlpha(26),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            invoice.status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _getStatusColor(invoice.status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (val) {
                                    if (val == 'view') {
                                      context.push('/invoices/${invoice.id}');
                                    } else if (val == 'edit') {
                                      context.push('/invoices/edit/${invoice.id}');
                                    } else if (val == 'preview') {
                                      _handlePdfAction(invoice, 'preview');
                                    } else if (val == 'print') {
                                      _handlePdfAction(invoice, 'print');
                                    } else if (val == 'share') {
                                      _handlePdfAction(invoice, 'share');
                                    } else if (val == 'post') {
                                      _updateStatus(invoice, 'Posted');
                                    } else if (val == 'unpost') {
                                      _updateStatus(invoice, 'Draft');
                                    } else if (val == 'delete') {
                                      _deleteInvoice(invoice);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'preview',
                                      child: Row(
                                        children: [
                                          Icon(Icons.visibility, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Preview PDF'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'print',
                                      child: Row(
                                        children: [
                                          Icon(Icons.print, color: Colors.grey),
                                          SizedBox(width: 8),
                                          Text('Print'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'share',
                                      child: Row(
                                        children: [
                                          Icon(Icons.share, color: Colors.teal),
                                          SizedBox(width: 8),
                                          Text('Share'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, color: Colors.indigo),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    if (invoice.status.toLowerCase() != 'posted')
                                      const PopupMenuItem(
                                        value: 'post',
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green),
                                            SizedBox(width: 8),
                                            Text('Post To GL'),
                                          ],
                                        ),
                                      ),
                                    if (invoice.status.toLowerCase() == 'posted')
                                      const PopupMenuItem(
                                        value: 'unpost',
                                        child: Row(
                                          children: [
                                            Icon(Icons.undo, color: Colors.orange),
                                            SizedBox(width: 8),
                                            Text('Unpost'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => context.push('/invoices/${invoice.id}'),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'posted':
        return Colors.blue;
      case 'draft':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
