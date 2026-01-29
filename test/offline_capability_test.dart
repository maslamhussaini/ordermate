// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/products/data/repositories/product_local_repository.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/orders/data/repositories/order_local_repository.dart';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/business_partners/data/repositories/business_partner_local_repository.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Initialize FFI for tests
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Offline Mode Self Checks', () {
    test('DatabaseHelper can create tables', () async {
      // Use in-memory database
      // We manually invoke the _createDB logic or similar, 
      // but DatabaseHelper is a singleton hardcoded to 'ordermate_local.db' and getDatabasesPath().
      // To test DatabaseHelper strictly with FFI without modifying it, 
      // we rely on the fact that databaseFactoryFfi supports getDatabasesPath on desktop/test env usually 
      // pointing to a temp dir or local dir.
      
      // Let's rely on the actual valid instance.
      final instance = DatabaseHelper.instance;
      final database = await instance.database;
      
      expect(database.isOpen, true);
      
      // Verify tables exist
      final tables = await database.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
      final tableNames = tables.map((e) => e['name']).toList();
      
      print('Tables found: $tableNames');
      
      expect(tableNames.contains('local_users'), true);
      expect(tableNames.contains('local_products'), true);
      expect(tableNames.contains('local_orders'), true);
    });

    test('Offline Login: Credential Caching and Retrieval', () async {
      final db = await DatabaseHelper.instance.database;
      
      // 1. Simulate "Online Login" caching
      const email = 'test@offline.com';
      const password = 'password123';
      const userId = 'user_001';
      
      await db.insert(
        'local_users',
        {
          'email': email,
          'password': password,
          'id': userId,
          'full_name': 'Offline Tester',
          'role': 'admin',
          'table_prefix': 'otbl_'
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Simulate "Offline Login" attempt (Query)
      final result = await db.query(
        'local_users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      expect(result.isNotEmpty, true);
      expect(result.first['full_name'], 'Offline Tester');
      print('Offline Login Test: Successfully retrieved cached user.');
    });

    test('Data Sync: Product Cache and Retrieval (Type Safety Check)', () async {
      final repo = ProductLocalRepository();
      
      // 1. Mock Product
      final product = Product(
        id: 'prod_123',
        name: 'Offline Product',
        sku: 'SKU_OFF_1',
        rate: 150.0,
        cost: 100.0,
        brandId: 1, // Int
        categoryId: 2, // Int
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: 1,
        storeId: 1,
      );

      // 2. Cache it (Simulate SyncService)
      await repo.cacheProducts([product]);

      // 3. Retrieve it (Simulate Offline Fetch)
      // This will fail if Type conversion (Int -> TEXT -> Int) is broken
      try {
        final cachedProducts = await repo.getLocalProducts();
        
        expect(cachedProducts.isNotEmpty, true);
        final retrieved = cachedProducts.first;
        
        expect(retrieved.id, product.id);
        expect(retrieved.brandId, 1); // Verify int preservation
        expect(retrieved.categoryId, 2);
        
        print('Data Sync Test: Successfully handled Product Types.');
      } catch (e) {
        fail('Failed to retrieve products. Likely a Type mismatch in Repository: $e');
      }
    });

    test('Data Sync: Order Cache and Retrieval (numerics)', () async {
      final repo = OrderLocalRepository();
      
      // 1. Mock Order with Integer Amount (to test casting)
      final order = Order(
        id: 'ord_1',
        orderNumber: 'ORD-001',
        businessPartnerId: 'cust_1',
        orderType: 'SO',
        createdBy: 'Admin',
        status: OrderStatus.approved,
        totalAmount: 500.0, // Dart double, but might be stored as int 500
        orderDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: 1,
        storeId: 1,
      );

      // 2. Cache
      await repo.cacheOrders([order]);

      // 3. Retrieve
      try {
        final orders = await repo.getLocalOrders();
        expect(orders.isNotEmpty, true);
        final retrieved = orders.first;
        expect(retrieved.id, 'ord_1');
        expect(retrieved.totalAmount, 500.0);
        print('Data Sync Test: Successfully handled Order Numerics.');
      } catch (e) {
        fail('Failed to retrieve orders: $e');
      }
    });

    test('Offline CRUD: Business Partners', () async {
      final repo = BusinessPartnerLocalRepository();
      
      // CREATE
      final partner = BusinessPartner(
        id: 'cust_offline_1',
        name: 'Offline Customer',
        phone: '1234567890',
        email: 'offline@cust.com',
        address: '123 Offline St',
        isCustomer: true,
        isVendor: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        latitude: 0,
        longitude: 0,
        organizationId: 1,
        storeId: 1,
      );
      
      await repo.addPartner(partner);
      
      // READ
      var partners = await repo.getLocalCustomers();
      expect(partners.any((p) => p.id == 'cust_offline_1'), true);
      
      // UPDATE
      final updatedPartner = partner.copyWith(name: 'Offline Customer Updated');
      await repo.updatePartner(updatedPartner);
      
      partners = await repo.getLocalCustomers();
      final fetched = partners.firstWhere((p) => p.id == 'cust_offline_1');
      expect(fetched.name, 'Offline Customer Updated');
      
      // DELETE
      await repo.deletePartner('cust_offline_1');
      partners = await repo.getLocalCustomers();
      expect(partners.any((p) => p.id == 'cust_offline_1'), false);
      
      print('Offline CRUD Test: Business Partner operations successful.');
    });

    test('Offline CRUD: Orders', () async {
      final repo = OrderLocalRepository();
      
      // CREATE
      final order = Order(
        id: 'ord_offline_1',
        orderNumber: 'OFF-001',
        businessPartnerId: 'cust_1',
        orderType: 'SO',
        createdBy: 'Admin',
        status: OrderStatus.approved,
        totalAmount: 1000.0,
        orderDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationId: 1,
        storeId: 1,
      );
      
      await repo.addOrder(order);
      
      // READ
      var orders = await repo.getLocalOrders();
      expect(orders.any((o) => o.id == 'ord_offline_1'), true);
      
      // UPDATE
      final updatedOrder = order.copyWith(totalAmount: 1200.0);
      await repo.updateOrder(updatedOrder);
      
      orders = await repo.getLocalOrders();
      final fetched = orders.firstWhere((o) => o.id == 'ord_offline_1');
      expect(fetched.totalAmount, 1200.0);
      
      // DELETE
      await repo.deleteOrder('ord_offline_1');
      orders = await repo.getLocalOrders();
      expect(orders.any((o) => o.id == 'ord_offline_1'), false);
      
      print('Offline CRUD Test: Order operations successful.');
    });
  });
}
