
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';
import 'package:ordermate/features/inventory/presentation/providers/stock_transfer_provider.dart';

class StockTransferListScreen extends ConsumerStatefulWidget {
  const StockTransferListScreen({super.key});

  @override
  ConsumerState<StockTransferListScreen> createState() => _StockTransferListScreenState();
}

class _StockTransferListScreenState extends ConsumerState<StockTransferListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(stockTransferProvider.notifier).loadTransfers());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockTransferProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Pass / Stock Transfers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(stockTransferProvider.notifier).loadTransfers(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/inventory/transfers/create'), // Ensure route exists
        label: const Text('New Transfer'),
        icon: const Icon(Icons.add),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : state.transfers.isEmpty
                  ? const Center(child: Text('No Stock Transfers found.'))
                  : ListView.builder(
                      itemCount: state.transfers.length,
                      itemBuilder: (context, index) {
                        final transfer = state.transfers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(transfer.transferNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${DateFormat('yyyy-MM-dd').format(transfer.transferDate)}'),
                                Text('Items: ${transfer.items.length}'),
                                if (transfer.destinationStoreId != null)
                                  Text('Dest: Store #${transfer.destinationStoreId}'), // Ideally show Store Name
                              ],
                            ),
                            trailing: Chip(
                              label: Text(transfer.status),
                              backgroundColor: _getStatusColor(transfer.status),
                            ),
                            onTap: () {
                               // View details or Edit
                               // context.push('/inventory/transfers/${transfer.id}');
                            },
                          ),
                        );
                      },
                    ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft': return Colors.grey.shade300;
      case 'approved': return Colors.blue.shade100;
      case 'completed': return Colors.green.shade100;
      case 'cancelled': return Colors.red.shade100;
      default: return Colors.white;
    }
  }
}
