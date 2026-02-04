// lib/features/reports/domain/repositories/report_repository.dart

import '../../../accounting/domain/entities/chart_of_account.dart';

abstract class ReportRepository {
  Future<Map<String, dynamic>> getLedgerData(
    String accountId, {
    DateTime? startDate, 
    DateTime? endDate, 
    int? organizationId,
    int? storeId,
    int? sYear,
    String? moduleAccount,
  });

  Future<List<Transaction>> getAccountLedger(
    String accountId, {
    DateTime? startDate, 
    DateTime? endDate, 
    int? organizationId,
    String? moduleAccount,
  });
  
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

  Future<List<Map<String, dynamic>>> getAgingData(
    String partnerId, {
    int? organizationId,
    int? storeId,
  });
}
