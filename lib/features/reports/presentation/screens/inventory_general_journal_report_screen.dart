import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';
import 'package:ordermate/features/inventory/presentation/providers/stock_transfer_provider.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class InventoryGeneralJournalReportScreen extends ConsumerStatefulWidget {
  const InventoryGeneralJournalReportScreen({super.key});

  @override
  ConsumerState<InventoryGeneralJournalReportScreen> createState() =>
      _InventoryGeneralJournalReportScreenState();
}

class _InventoryGeneralJournalReportScreenState
    extends ConsumerState<InventoryGeneralJournalReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedProductId;
  int? _selectedStoreId;

  bool _isLoading = false;
  List<JournalEntry> _reportData = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productProvider.notifier).loadProducts();
      ref
          .read(organizationProvider.notifier)
          .loadOrganizations(); // Loads stores
      _generateReport();
    });
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    // 1. Fetch Data
    // We force reload to ensure latest
    await ref.read(stockTransferProvider.notifier).loadTransfers();
    await ref.read(orderProvider.notifier).loadOrders();

    final transfers = ref.read(stockTransferProvider).transfers;
    final orders = ref.read(orderProvider).orders;
    final products = ref.read(productProvider).products;

    List<JournalEntry> entries = [];

    // 2. Process Stock Transfers
    for (final t in transfers) {
      if (t.transferDate.isBefore(_startDate) ||
          t.transferDate.isAfter(_endDate.add(const Duration(days: 1))))
        continue;

      // Filter by Store if selected
      // A transfer involves two stores: Source (Out) and Destination (In)
      bool involvesSelectedStore = _selectedStoreId == null ||
          t.sourceStoreId == _selectedStoreId ||
          t.destinationStoreId == _selectedStoreId;

      if (!involvesSelectedStore) continue;

      for (final item in t.items) {
        if (_selectedProductId != null && item.productId != _selectedProductId)
          continue;

        // Out from Source
        if (_selectedStoreId == null || t.sourceStoreId == _selectedStoreId) {
          entries.add(JournalEntry(
            date: t.transferDate,
            type: 'Transfer Out',
            reference: t.transferNumber,
            productName: item.productName,
            qtyIn: 0,
            qtyOut: item.quantity,
            storeId: t.sourceStoreId,
            storeName: _getStoreName(t.sourceStoreId),
          ));
        }

        // In to Destination
        if (t.destinationStoreId != null &&
            (_selectedStoreId == null ||
                t.destinationStoreId == _selectedStoreId)) {
          entries.add(JournalEntry(
            date: t.transferDate,
            type: 'Transfer In',
            reference: t.transferNumber,
            productName: item.productName,
            qtyIn: item.quantity,
            qtyOut: 0,
            storeId: t.destinationStoreId!,
            storeName: _getStoreName(t.destinationStoreId),
          ));
        }
      }
    }

    // 3. Process Orders (Sales = Out, Returns = In, Purchase = In)
    for (final o in orders) {
      // Filter Date
      if (o.orderDate.isBefore(_startDate) ||
          o.orderDate.isAfter(_endDate.add(const Duration(days: 1)))) continue;

      // Filter Store (Orders usually belong to one store)
      if (_selectedStoreId != null && o.storeId != _selectedStoreId) continue;

      for (final line in o.items) {
        if (_selectedProductId != null && line.productId != _selectedProductId)
          continue;

        double qtyIn = 0;
        double qtyOut = 0;
        String type = 'Sale';

        if (o.orderType == 'SO' || o.orderType == 'Sales Order') {
          type = 'Sale';
          qtyOut = line.quantity;
        } else if (o.orderType == 'PO' || o.orderType == 'Purchase Order') {
          type = 'Purchase';
          qtyIn = line.quantity;
        } else if (o.orderType == 'SR' || o.orderType.contains('Return')) {
          type = 'Return';
          qtyIn = line.quantity; // Return comes back IN
        }

        entries.add(JournalEntry(
          date: o.orderDate,
          type: type,
          reference: o.orderNumber,
          productName: line.productName ?? 'Unknown Product',
          qtyIn: qtyIn,
          qtyOut: qtyOut,
          storeId: o.storeId,
          storeName: _getStoreName(o.storeId),
        ));
      }
    }

    // Sort by Date Descending
    entries.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _reportData = entries;
      _isLoading = false;
    });
  }

  String _getStoreName(int? id) {
    final stores = ref.read(organizationProvider).stores;
    return stores.where((s) => s.id == id).firstOrNull?.name ?? '#$id';
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider).products;
    final stores = ref.watch(organizationProvider).stores;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory General Journal')),
      body: Column(
        children: [
          // Filters
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedStoreId,
                          decoration: const InputDecoration(
                              labelText: 'Store',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<int>(
                                value: null, child: Text('All Stores')),
                            ...stores.map((s) => DropdownMenuItem(
                                value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedStoreId = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedProductId,
                          decoration: const InputDecoration(
                              labelText: 'Product',
                              isDense: true,
                              border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null, child: Text('All Products')),
                            ...products.map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.name))),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedProductId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context, true),
                          icon: const Icon(Icons.date_range),
                          label: Text(
                              'From: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context, false),
                          icon: const Icon(Icons.date_range),
                          label: Text(
                              'To: ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _generateReport,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white),
                        child: const Text('Generate'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                    ? const Center(
                        child: Text('No records found for criteria.'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Store')),
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Reference')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Qty In'), numeric: true),
                              DataColumn(label: Text('Qty Out'), numeric: true),
                            ],
                            rows: _reportData
                                .map((e) => DataRow(cells: [
                                      DataCell(Text(DateFormat('yy-MM-dd')
                                          .format(e.date))),
                                      DataCell(Text(e.storeName)),
                                      DataCell(Text(e.productName)),
                                      DataCell(Text(e.reference)),
                                      DataCell(Text(e.type)),
                                      DataCell(Text(
                                          e.qtyIn > 0
                                              ? e.qtyIn.toStringAsFixed(2)
                                              : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green))),
                                      DataCell(Text(
                                          e.qtyOut > 0
                                              ? e.qtyOut.toStringAsFixed(2)
                                              : '-',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red))),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class JournalEntry {
  final DateTime date;
  final String type;
  final String reference;
  final String productName;
  final double qtyIn;
  final double qtyOut;
  final int storeId;
  final String storeName;

  JournalEntry({
    required this.date,
    required this.type,
    required this.reference,
    required this.productName,
    required this.qtyIn,
    required this.qtyOut,
    required this.storeId,
    required this.storeName,
  });
}
