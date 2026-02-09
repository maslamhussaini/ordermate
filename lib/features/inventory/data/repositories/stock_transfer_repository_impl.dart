import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/utils/connectivity_helper.dart';
import 'package:ordermate/features/inventory/data/models/stock_transfer_model.dart';
import 'package:ordermate/features/inventory/data/repositories/stock_transfer_local_repository.dart';
import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';
import 'package:ordermate/features/inventory/domain/repositories/stock_transfer_repository.dart';

class StockTransferRepositoryImpl implements StockTransferRepository {
  final StockTransferLocalRepository _localRepository =
      StockTransferLocalRepository();

  @override
  Future<List<StockTransfer>> getTransfers(
      {int? organizationId, int? storeId}) async {
    // 1. Check Connectivity
    final connectivityResult = await ConnectivityHelper.check();
    if (connectivityResult.contains(ConnectivityResult.none) ||
        SupabaseConfig.isOfflineLoggedIn) {
      return _localRepository.getTransfers(
          organizationId: organizationId, storeId: storeId);
    }

    try {
      // 2. Fetch from Supabase
      var query = SupabaseConfig.client.from('omtbl_stock_transfers').select();

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      if (storeId != null) {
        // Complex OR query for store participation: Source OR Destination matching storeId
        query = query
            .or('source_store_id.eq.$storeId,destination_store_id.eq.$storeId');
      }

      final response = await query.order('transfer_date', ascending: false);

      final transfers = (response as List)
          .map((json) => StockTransferModel.fromJson(json))
          .toList();

      // 3. Update Local Cache
      for (final t in transfers) {
        // Fetch Items for each transfer
        try {
          final itemsResponse = await SupabaseConfig.client
              .from('omtbl_stock_transfer_items')
              .select(
                  '*, omtbl_products(name), omtbl_units_of_measure(unit_symbol)')
              .eq('transfer_id', t.id);

          final items = (itemsResponse as List).map((i) {
            if (i['omtbl_products'] != null)
              i['product_name'] = i['omtbl_products']['name'];
            if (i['omtbl_units_of_measure'] != null)
              i['uom_symbol'] = i['omtbl_units_of_measure']['unit_symbol'];
            return StockTransferItem.fromJson(i);
          }).toList();

          final fullModel =
              StockTransferModel.fromEntity(t.copyWith(items: items));
          await _localRepository.addTransfer(fullModel);
        } catch (e) {
          // If items fetch fails, save header at least
          final fullModel = StockTransferModel.fromEntity(t);
          await _localRepository.addTransfer(fullModel);
        }
      }

      return await _localRepository.getTransfers(
          organizationId: organizationId, storeId: storeId);
    } catch (e) {
      // Fallback
      return _localRepository.getTransfers(
          organizationId: organizationId, storeId: storeId);
    }
  }

  @override
  Future<StockTransfer> createTransfer(StockTransfer transfer) async {
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) ||
        SupabaseConfig.isOfflineLoggedIn;

    // Local Save (Optimistic)
    final model = StockTransferModel.fromEntity(transfer);
    await _localRepository.addTransfer(model);

    if (isOffline) {
      return transfer;
    }

    try {
      final json = model.toJson();
      json.remove(
          'created_at'); // Let DB specific handling if needed, or send it (usually preferred to control)
      json.remove('updated_at'); // Send updated_at if we control it
      json.remove('items_payload');
      json.remove('items');

      // 1. Upsert Transfer Header
      await SupabaseConfig.client.from('omtbl_stock_transfers').upsert(json);

      // 2. Insert Items
      if (transfer.items.isNotEmpty) {
        final itemsJson = transfer.items.map((i) {
          final m = i.toJson();
          m.remove('product_name'); // Not in table
          m.remove('uom_symbol'); // Not in table
          // Keep 'id' to ensure we use our UUIDs
          return m;
        }).toList();

        await SupabaseConfig.client
            .from('omtbl_stock_transfer_items')
            .upsert(itemsJson);
      }

      return transfer;
    } catch (e) {
      // If sync fails, mark unsynced locally
      final unsyncedModel =
          StockTransferModel.fromEntity(transfer.copyWith(isSynced: false));
      await _localRepository.addTransfer(unsyncedModel);
      rethrow;
    }
  }

  @override
  Future<void> updateTransfer(StockTransfer transfer) async {
    final connectivityResult = await ConnectivityHelper.check();
    final isOffline = connectivityResult.contains(ConnectivityResult.none) ||
        SupabaseConfig.isOfflineLoggedIn;

    // Local Save
    final model = StockTransferModel.fromEntity(transfer);
    await _localRepository.addTransfer(model);

    if (isOffline) return;

    try {
      final json = model.toJson();
      json.remove('items_payload');
      json.remove('items');

      // 1. Update Header
      await SupabaseConfig.client.from('omtbl_stock_transfers').upsert(json);

      // 2. Update Items (Strategy: Delete All for this Transfer, Then Insert New)
      // This handles removed items correctly.
      await SupabaseConfig.client
          .from('omtbl_stock_transfer_items')
          .delete()
          .eq('transfer_id', transfer.id);

      if (transfer.items.isNotEmpty) {
        final itemsJson = transfer.items.map((i) {
          final m = i.toJson();
          m.remove('product_name');
          m.remove('uom_symbol');
          return m;
        }).toList();

        await SupabaseConfig.client
            .from('omtbl_stock_transfer_items')
            .insert(itemsJson);
      }
    } catch (e) {
      final unsyncedModel =
          StockTransferModel.fromEntity(transfer.copyWith(isSynced: false));
      await _localRepository.addTransfer(unsyncedModel);
      rethrow;
    }
  }

  @override
  Future<void> deleteTransfer(String id) async {
    await _localRepository.deleteTransfer(id);

    try {
      // Items should be cascaded if DB configured, but check manually
      await SupabaseConfig.client
          .from('omtbl_stock_transfer_items')
          .delete()
          .eq('transfer_id', id);
      await SupabaseConfig.client
          .from('omtbl_stock_transfers')
          .delete()
          .eq('id', id);
    } catch (_) {}
  }

  @override
  Future<String> generateTransferNumber(String prefix) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '$prefix-TR-$dateStr-$timeStr';
  }
}
