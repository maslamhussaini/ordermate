
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';
import 'package:ordermate/features/inventory/presentation/providers/stock_transfer_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';

class StockTransferFormScreen extends ConsumerStatefulWidget {
  const StockTransferFormScreen({super.key});

  @override
  ConsumerState<StockTransferFormScreen> createState() => _StockTransferFormScreenState();
}

class _StockTransferFormScreenState extends ConsumerState<StockTransferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  
  String? _transferNumber;
  DateTime _transferDate = DateTime.now();
  int? _destinationStoreId;
  final List<StockTransferItem> _items = [];
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final notifier = ref.read(stockTransferProvider.notifier);
    final number = await notifier.generateNumber();
    setState(() {
      _transferNumber = number;
    });
    // Load products if empty
    if (ref.read(productProvider).products.isEmpty) {
        ref.read(productProvider.notifier).loadProducts();
    }
    ref.read(businessPartnerProvider.notifier).loadEmployees();
  }

  int? _sourceStoreId;

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(organizationProvider);
    final productState = ref.watch(productProvider);
    final partnerState = ref.watch(businessPartnerProvider);
    
    // Valid sources are allow stores if none selected
    // Valid destinations: All stores except source
    
    final currentStoreId = orgState.selectedStore?.id ?? _sourceStoreId;
    final validDestinations = orgState.stores.where((s) => s.id != currentStoreId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('New Gate Pass')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               // Header Info
               Card(
                 child: Padding(
                   padding: const EdgeInsets.all(16),
                   child: Column(
                     children: [
                       Text('Transfer #: ${_transferNumber ?? 'Loading...'}', style: Theme.of(context).textTheme.titleMedium),
                       const SizedBox(height: 10),
                       Row(
                         children: [
                           Expanded(
                             child: orgState.selectedStore != null 
                             ? Text('Source: ${orgState.selectedStore!.name}', style: const TextStyle(fontWeight: FontWeight.bold))
                             : DropdownButtonFormField<int>(
                               value: _sourceStoreId,
                               decoration: const InputDecoration(labelText: 'Source Store'),
                               items: orgState.stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                               onChanged: (val) => setState(() {
                                 _sourceStoreId = val;
                                 if (_destinationStoreId == val) _destinationStoreId = null; // Reset dest if same
                               }),
                               validator: (val) => val == null ? 'Required' : null,
                             ),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: DropdownButtonFormField<int>(
                               value: _destinationStoreId,
                               decoration: const InputDecoration(labelText: 'Destination Store'),
                               items: validDestinations.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                               onChanged: (val) => setState(() => _destinationStoreId = val),
                               validator: (val) => val == null ? 'Required' : null,
                             )
                           ),
                         ],
                       ),
                       const SizedBox(height: 10),
                       DropdownButtonFormField<String>(
                         value: _driverController.text.isNotEmpty && partnerState.employees.any((e) => e.name == _driverController.text) ? _driverController.text : null,
                         decoration: const InputDecoration(labelText: 'Driver Name (Optional)'),
                         items: partnerState.employees.map((e) => DropdownMenuItem(value: e.name, child: Text(e.name))).toList(),
                         onChanged: (val) {
                           if (val != null) {
                             _driverController.text = val;
                           }
                         },
                       ),
                       TextFormField(
                         controller: _vehicleController,
                         decoration: const InputDecoration(labelText: 'Vehicle # (Optional)'),
                       ),
                       TextFormField(
                         controller: _remarksController,
                         decoration: const InputDecoration(labelText: 'Remarks'),
                         maxLines: 2,
                       ),
                     ],
                   ),
                 ),
               ),
               
               const SizedBox(height: 16),
               
               // Items Section
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   IconButton(onPressed: _showAddItemDialog, icon: const Icon(Icons.add_circle, color: Colors.teal)),
                 ],
               ),
               
               ..._items.map((item) => Card(
                 color: Colors.grey.shade50,
                 child: ListTile(
                   title: Text(item.productName),
                   subtitle: Text('${item.quantity} ${item.uomSymbol}'),
                   trailing: IconButton(
                     icon: const Icon(Icons.delete, color: Colors.red),
                     onPressed: () {
                       setState(() {
                         _items.remove(item);
                       });
                     },
                   ),
                 ),
               )),
               
               if (_items.isEmpty)
                 const Padding(
                   padding: EdgeInsets.all(16.0),
                   child: Center(child: Text('No items added', style: TextStyle(color: Colors.grey))),
                 ),
                 
               const SizedBox(height: 24),
               ElevatedButton(
                 onPressed: _submit,
                 style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                 child: const Text('Create Gate Pass'),
               )
             ],
          ),
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    final productState = ref.read(productProvider);
    String? selectedProductId;
    double quantity = 1;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedProduct = productState.products.where((p) => p.id == selectedProductId).firstOrNull;
          return AlertDialog(
            title: const Text('Add Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  isExpanded: true,
                  hint: const Text('Select Product'),
                  items: productState.products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedProductId = val);
                  },
                ),
                if (selectedProduct != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Available Stock: ${selectedProduct.stockQty}'),
                   ),
                TextFormField(
                  initialValue: '1',
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => quantity = double.tryParse(val) ?? 0,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                   if (selectedProductId != null && quantity > 0) {
                      final product = productState.products.firstWhere((p) => p.id == selectedProductId);
                      setState(() {
                        _items.add(StockTransferItem(
                          id: const Uuid().v4(),
                          transferId: '', // Set on submit
                          productId: product.id,
                          productName: product.name,
                          quantity: quantity,
                          uomId: product.uomId ?? 0,
                          uomSymbol: product.uomSymbol ?? '',
                        ));
                      });
                      Navigator.pop(ctx);
                   }
                },
                child: const Text('Add'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one item')));
      return;
    }
    
    final orgState = ref.read(organizationProvider);
    final currentStoreId = orgState.selectedStore?.id ?? _sourceStoreId;
    
    if (currentStoreId == null || currentStoreId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Source Store')));
      return;
    }
    
    final newId = const Uuid().v4();
    
    // Update items with the new Transfer ID
    final updatedItems = _items.map((item) => StockTransferItem(
      id: item.id,
      transferId: newId,
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      uomId: item.uomId,
      uomSymbol: item.uomSymbol,
    )).toList();

    final authState = ref.read(authProvider);
    final accountingState = ref.read(accountingProvider);

    final transfer = StockTransfer(
      id: newId,
      transferNumber: _transferNumber ?? 'DRAFT',
      sourceStoreId: currentStoreId,
      destinationStoreId: _destinationStoreId,
      status: 'Draft',
      transferDate: _transferDate,
      createdBy: authState.userId,
      driverName: _driverController.text,
      vehicleNumber: _vehicleController.text,
      remarks: _remarksController.text,
      organizationId: orgState.selectedOrganizationId ?? 0,
      sYear: accountingState.selectedFinancialSession?.sYear ?? 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: updatedItems,
      isSynced: false,
    );
    
    try {
      await ref.read(stockTransferProvider.notifier).createTransfer(transfer);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock Transfer Created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
