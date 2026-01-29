// lib/features/reports/domain/repositories/report_repository.dart

import '../../../accounting/domain/entities/chart_of_account.dart';
import '../../../accounting/domain/entities/invoice.dart';
import '../../../accounting/domain/entities/invoice_item.dart';

abstract class ReportRepository {
  Future<List<Transaction>> getAccountLedger(String accountId, {DateTime? startDate, DateTime? endDate, int? organizationId});
  
  Future<List<Map<String, dynamic>>> getSalesByProduct({
    DateTime? startDate, 
    DateTime? endDate, 
    int? organizationId,
    String? type, // 'SI' or 'SIR'
  });

  Future<List<Map<String, dynamic>>> getSalesDetailsByProduct({
    DateTime? startDate, 
    DateTime? endDate, 
    int? organizationId,
    String? type,
  });

  Future<List<Map<String, dynamic>>> getSalesByCustomer({
    DateTime? startDate, 
    DateTime? endDate, 
    int? organizationId,
    String? type, // 'SI' or 'SIR'
  });
}
