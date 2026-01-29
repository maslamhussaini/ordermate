// lib/features/reports/data/repositories/report_repository_impl.dart

import 'package:ordermate/core/database/database_helper.dart';
import '../../domain/repositories/report_repository.dart';
import '../../../accounting/domain/entities/chart_of_account.dart';
import '../../../accounting/data/models/accounting_models.dart';

class ReportRepositoryImpl implements ReportRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Transaction>> getAccountLedger(String accountId, {DateTime? startDate, DateTime? endDate, int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = '(account_id = ? OR offset_account_id = ?)';
    List<dynamic> args = [accountId, accountId];
    
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
    
    sql += ' GROUP BY i.business_partner_id ORDER BY total_amount DESC';
    
    return await db.rawQuery(sql, args);
  }
}
