// lib/features/reports/data/repositories/report_repository_impl.dart

import 'package:ordermate/core/database/database_helper.dart';
import '../../domain/repositories/report_repository.dart';
import '../../../accounting/domain/entities/chart_of_account.dart';
import '../../../accounting/data/models/accounting_models.dart';

class ReportRepositoryImpl implements ReportRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<Map<String, dynamic>> getLedgerData(
    String accountId, {
    DateTime? startDate, 
    DateTime? endDate, 
    int? organizationId,
    int? storeId,
    int? sYear,
    String? moduleAccount,
  }) async {
    final db = await _dbHelper.database;
    
    // Determine if we are looking for a sub-ledger (BP/Bank/Cash) or a GL account
    final isSubLedger = moduleAccount != null && moduleAccount.isNotEmpty;
    final targetId = isSubLedger ? moduleAccount : accountId;

    // We need to find the specific GL account associated if it's a sub-ledger
    String? glAccountId = accountId; // Default to the provided accountId
    if (isSubLedger) {
       final bp = await db.query('local_businesspartners', where: 'id = ?', whereArgs: [targetId]);
       if (bp.isNotEmpty) {
         glAccountId = bp.first['chart_of_account_id'] as String?;
       } else {
         // If moduleAccount is provided but no BP found, it might be a Bank/Cash account
         final bc = await db.query('local_bank_cash', where: 'id = ?', whereArgs: [targetId]);
         if (bc.isNotEmpty) {
           glAccountId = bc.first['chart_of_account_id'] as String?;
         }
       }
    }
    
    // For queries, if glAccountId is null, use a dummy value that won't match anything
    final searchGlAccountId = glAccountId ?? 'NON_EXISTENT_ID_XYZ';

    // Filters Construction
    String extraWhere = '';
    final List<dynamic> extraArgs = [];
    if (organizationId != null && organizationId != 0) {
      extraWhere += ' AND (t.organization_id = ? OR t.organization_id IS NULL OR t.organization_id = 0)';
      extraArgs.add(organizationId);
    }
    if (storeId != null && storeId != 0) {
      // Be inclusive: show specific store XOR global/null entries
      extraWhere += ' AND (t.store_id = ? OR t.store_id IS NULL OR t.store_id = 0)';
      extraArgs.add(storeId);
    }
    if (sYear != null && sYear != 0) {
      extraWhere += ' AND (t.syear = ? OR t.syear IS NULL OR t.syear = 0)';
      extraArgs.add(sYear);
    }

    // 1. Calculate Opening Balance
    double openingBalance = 0.0;
    if (startDate != null) {
      // Inclusive search for opening balance
      String opWhere = '(t.module_account = ? OR t.account_id = ? OR t.offset_module_account = ? OR t.offset_account_id = ?)';
      
      final opSql = '''
        SELECT 
          SUM(CASE WHEN (t.module_account = ? OR t.account_id = ?) THEN t.amount ELSE 0 END) as total_debit,
          SUM(CASE WHEN (t.offset_module_account = ? OR t.offset_account_id = ?) THEN t.amount ELSE 0 END) as total_credit
        FROM local_transactions t
        WHERE $opWhere AND t.voucher_date < ? $extraWhere
      ''';
      
      // Args: 2 for first SUM, 2 for second SUM, 4 for WHERE, 1 for date, then extra filters
      final opArgs = [
        targetId, searchGlAccountId, 
        targetId, searchGlAccountId, 
        targetId, searchGlAccountId, targetId, searchGlAccountId, 
        startDate.millisecondsSinceEpoch, 
        ...extraArgs
      ];
      
      print('SQL (Opening Balance): $opSql');
      print('Args (Opening Balance): $opArgs');
      
      final opResult = await db.rawQuery(opSql, opArgs);

      if (opResult.isNotEmpty) {
        final dr = (opResult.first['total_debit'] as num?)?.toDouble() ?? 0.0;
        final cr = (opResult.first['total_credit'] as num?)?.toDouble() ?? 0.0;
        openingBalance = dr - cr;
      }
    }

    // --- DEEP DIAGNOSTICS ---
    print('--- DEEP DATABASE SCAN ---');
    // 1. Check if the target exists in Business Partners
    final bpCheck = await db.query('local_businesspartners', where: 'id = ?', whereArgs: [targetId]);
    print('BP Lookup: ${bpCheck.isNotEmpty ? "FOUND" : "NOT FOUND"} (ID: $targetId)');
    
    // 2. Scan for ANY row containing the ID in any column
    final anyMatches = await db.rawQuery('''
      SELECT voucher_number, module_account, offset_module_account, organization_id, store_id, syear 
      FROM local_transactions 
      WHERE module_account LIKE ? OR offset_module_account LIKE ? 
      LIMIT 10
    ''', ['%$targetId%', '%$targetId%']);
    print('Broad Partial ID Match: Found ${anyMatches.length} rows');
    for (var m in anyMatches) {
        print('  - ${m['voucher_number']} | Mod: ${m['module_account']} | Org: ${m['organization_id']} | Store: ${m['store_id']}');
    }

    // 3. Scan specifically for the missing INV vouchers to see their metadata
    final invCheck = await db.rawQuery("SELECT voucher_number, module_account, account_id, organization_id, store_id FROM local_transactions WHERE voucher_number LIKE 'INV%' LIMIT 10");
    print('INV Prefix Scan: Found ${invCheck.length} total Sales Invoices in DB');
    for (var i in invCheck) {
        print('  - ${i['voucher_number']} | Mod: ${i['module_account']} (GL: ${i['account_id']}) | Org: ${i['organization_id']}');
    }

    final glCheck = await db.rawQuery("SELECT voucher_number, module_account, account_id, organization_id, store_id FROM local_transactions WHERE account_id = ? OR module_account = ? LIMIT 10", [searchGlAccountId, targetId]);
    print('Target ID Direct Scan (ID: $targetId / GL: $searchGlAccountId): Found ${glCheck.length} rows');
    for (var g in glCheck) {
        print('  - ${g['voucher_number']} | Mod: ${g['module_account']} (GL: ${g['account_id']})');
    }
    print('--------------------------');

    // 2. Main Ledger Query matching User's Snippet logic (but with flexible metadata)
    final dateWhere = startDate != null ? ' AND t.voucher_date >= ?' : '';
    final dateEndWhere = endDate != null ? ' AND t.voucher_date <= ?' : '';

    String metaWhere = '';
    final filterArgs = [];
    if (organizationId != null && organizationId != 0) {
      metaWhere += ' AND (t.organization_id = ? OR t.organization_id IS NULL OR t.organization_id = 0)';
      filterArgs.add(organizationId);
    }
    if (storeId != null && storeId != 0) {
      metaWhere += ' AND (t.store_id = ? OR t.store_id IS NULL OR t.store_id = 0)';
      filterArgs.add(storeId);
    }
    if (sYear != null && sYear != 0) {
      metaWhere += ' AND (t.syear = ? OR t.syear IS NULL OR t.syear = 0)';
      filterArgs.add(sYear);
    }
    if (startDate != null) filterArgs.add(startDate.millisecondsSinceEpoch);
    if (endDate != null) filterArgs.add(endDate.millisecondsSinceEpoch);

    final sql = '''
      WITH unified_accounts AS (
        SELECT id as acid, account_code as accode, account_title as acname FROM local_chart_of_accounts
        UNION ALL
        SELECT id as acid, 'BP' as accode, name as acname FROM local_businesspartners
        UNION ALL
        SELECT id as acid, 'BC' as accode, bank_name as acname FROM local_bank_cash
      ),
      LedgerEntries AS (
        -- 1. Debits (Target as Primary)
        SELECT 
            t.id, 
            t.voucher_number, 
            t.voucher_date, 
            t.description, 
            COALESCE(vm.accode, vg.accode, '') as accode, 
            CASE 
              WHEN vm.acname IS NOT NULL AND vg.acname IS NOT NULL AND vm.acname != vg.acname 
              THEN vm.acname || ' (' || vg.acname || ')'
              ELSE COALESCE(vm.acname, vg.acname, 'General Ledger')
            END as acname,
            t.amount as debit, 
            0.0 as credit
        FROM local_transactions t
        LEFT JOIN unified_accounts vm ON t.offset_module_account = vm.acid
        LEFT JOIN unified_accounts vg ON t.offset_account_id = vg.acid
        WHERE (t.module_account = ? OR t.account_id = ?)
          $metaWhere
          $dateWhere
          $dateEndWhere

        UNION ALL

        -- 2. Credits (Target as Offset)
        SELECT 
            t.id, 
            t.voucher_number, 
            t.voucher_date, 
            t.description, 
            COALESCE(vm.accode, vg.accode, '') as accode, 
            CASE 
              WHEN vm.acname IS NOT NULL AND vg.acname IS NOT NULL AND vm.acname != vg.acname 
              THEN vm.acname || ' (' || vg.acname || ')'
              ELSE COALESCE(vm.acname, vg.acname, 'General Ledger')
            END as acname,
            0.0 as debit, 
            t.amount as credit
        FROM local_transactions t
        LEFT JOIN unified_accounts vm ON t.module_account = vm.acid
        LEFT JOIN unified_accounts vg ON t.account_id = vg.acid
        WHERE (t.offset_module_account = ? OR t.offset_account_id = ?)
          $metaWhere
          $dateWhere
          $dateEndWhere
    )
    SELECT *,
        SUM(debit - credit) OVER (ORDER BY voucher_date ASC, id ASC) as running_sum
    FROM LedgerEntries
    ORDER BY voucher_date ASC, id ASC;
    ''';

    final queryArgs = [
      targetId, searchGlAccountId, ...filterArgs,
      targetId, searchGlAccountId, ...filterArgs,
    ];
    
    // --- DIAGNOSTIC DEBUG ---
    print('DEBUG: Running Ledger for $targetId');
    print('DEBUG: Meta Filters: org=$organizationId, store=$storeId, year=$sYear');
    
    // Check total records for this ID ignoring everything else
    final globalCheck = await db.rawQuery('SELECT COUNT(*) as cnt FROM local_transactions WHERE module_account = ? OR offset_module_account = ?', [targetId, targetId]);
    print('DEBUG: GLOBAL COUNT for this ID (no filters): ${globalCheck.first['cnt']}');
    
    final periodMaps = await db.rawQuery(sql, queryArgs);
    print('DEBUG: PERIOD MATCHES found: ${periodMaps.length}');
    
    return {
      'openingBalance': openingBalance,
      'transactions': periodMaps.map((m) {
        final map = Map<String, dynamic>.from(m);
        final runningSum = (m['running_sum'] as num?)?.toDouble() ?? 0.0;
        map['running_balance'] = runningSum + openingBalance;
        return map;
      }).toList(),
    };
  }

  @override
  Future<List<Transaction>> getAccountLedger(
    String accountId, {
    DateTime? startDate, 
    DateTime? endDate, 
    int? organizationId,
    String? moduleAccount, 
  }) async {
    final db = await _dbHelper.database;
    
    // Determine Filter: Sub-Ledger (Customer/Vendor) OR General Ledger (Account)
    String where = '';
    List<dynamic> args = [];

    if (moduleAccount != null && moduleAccount.isNotEmpty) {
       // Search by Sub-Ledger ID (e.g. Customer ID)
       where = '(module_account = ? OR offset_module_account = ?)';
       args = [moduleAccount, moduleAccount];
    } else {
       // Search by General Ledger Account ID
       where = '(account_id = ? OR offset_account_id = ?)';
       args = [accountId, accountId];
    }
    
    if (organizationId != null) {
      where += ' AND organization_id = ?';
      args.add(organizationId);
    }
    
    if (startDate != null) {
      where += ' AND voucher_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    
    if (endDate != null) {
      where += ' AND voucher_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }
    
    final maps = await db.query('local_transactions', where: where, whereArgs: args, orderBy: 'voucher_date ASC');
    return maps.map((e) => TransactionModel(
      id: e['id'] as String,
      voucherPrefixId: e['voucher_prefix_id'] as int,
      voucherNumber: e['voucher_number'] as String,
      voucherDate: DateTime.fromMillisecondsSinceEpoch(e['voucher_date'] as int),
      accountId: e['account_id'] as String,
      offsetAccountId: e['offset_account_id'] as String?,
      amount: (e['amount'] as num).toDouble(),
      description: e['description'] as String?,
      status: e['status'] as String? ?? 'posted',
      organizationId: (e['organization_id'] as int?) ?? 0,
      storeId: (e['store_id'] as int?) ?? 0,
      sYear: e['syear'] as int?,
      moduleAccount: e['module_account'] as String?,
      offsetModuleAccount: e['offset_module_account'] as String?,
    )).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesByProduct({DateTime? startDate, DateTime? endDate, int? organizationId, String? type}) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT 
        ii.product_id, 
        MAX(COALESCE(p.name, ii.product_name, 'Unknown Product')) as product_name, 
        SUM(ii.quantity) as total_quantity, 
        SUM(ii.total) as total_amount
      FROM local_invoice_items ii
      JOIN local_invoices i ON ii.invoice_id = i.id
      LEFT JOIN local_products p ON ii.product_id = p.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];
    
    if (organizationId != null) {
      sql += ' AND i.organization_id = ?';
      args.add(organizationId);
    }
    
    if (type != null) {
      sql += ' AND i.id_invoice_type = ?';
      args.add(type);
    }
    
    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    
    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }
    
    sql += ' GROUP BY ii.product_id ORDER BY total_amount DESC';
    
    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesDetailsByProduct({DateTime? startDate, DateTime? endDate, int? organizationId, String? type}) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT 
        ii.product_id, 
        COALESCE(p.name, ii.product_name, 'Unknown Product') as product_name, 
        i.invoice_number,
        i.invoice_date,
        COALESCE(bp.name, 'Unknown Customer') as customer_name,
        ii.quantity, 
        ii.total as amount
      FROM local_invoice_items ii
      JOIN local_invoices i ON ii.invoice_id = i.id
      LEFT JOIN local_products p ON ii.product_id = p.id
      LEFT JOIN local_businesspartners bp ON i.business_partner_id = bp.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];
    
    if (organizationId != null) {
      sql += ' AND i.organization_id = ?';
      args.add(organizationId);
    }
    
    if (type != null) {
      sql += ' AND i.id_invoice_type = ?';
      args.add(type);
    }
    
    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    
    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }
    
    // Order by Product Name and then Invoice Date
    sql += ' ORDER BY product_name, i.invoice_date DESC';
    
    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesByCustomer({DateTime? startDate, DateTime? endDate, int? organizationId, String? type}) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT 
        i.business_partner_id, 
        MAX(COALESCE(bp.name, 'Unknown Customer')) as customer_name,
        COUNT(i.id) as total_invoices,
        SUM(i.total_amount) as total_amount
      FROM local_invoices i
      LEFT JOIN local_businesspartners bp ON i.business_partner_id = bp.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];
    
    if (organizationId != null) {
      sql += ' AND i.organization_id = ?';
      args.add(organizationId);
    }
    
    if (type != null) {
      sql += ' AND i.id_invoice_type = ?';
      args.add(type);
    }
    
    if (startDate != null) {
      sql += ' AND i.invoice_date >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    
    if (endDate != null) {
      sql += ' AND i.invoice_date <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }
    
    return await db.rawQuery(sql, args);
  }

  @override
  Future<List<Map<String, dynamic>>> getAgingData(
    String partnerId, {
    int? organizationId,
    int? storeId,
  }) async {
    final db = await _dbHelper.database;
    
    // We select unpaid invoices and calculate their age
    String sql = '''
      SELECT 
        id as invoice_id,
        invoice_number,
        invoice_date,
        due_date,
        total_amount,
        paid_amount,
        (total_amount - paid_amount) as outstanding_amount
      FROM local_invoices
      WHERE business_partner_id = ?
      AND (total_amount - paid_amount) > 0
    ''';
    
    List<dynamic> args = [partnerId];
    
    if (organizationId != null) {
      sql += ' AND organization_id = ?';
      args.add(organizationId);
    }
    
    if (storeId != null) {
      sql += ' AND store_id = ?';
      args.add(storeId);
    }
    
    sql += ' ORDER BY invoice_date ASC';
    
    return await db.rawQuery(sql, args);
  }
}
