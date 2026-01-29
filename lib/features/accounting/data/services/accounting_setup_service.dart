import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/features/accounting/domain/repositories/accounting_repository.dart';
import '../../data/models/accounting_models.dart';

class AccountingSetupService {
  final AccountingRepository _repository;

  AccountingSetupService(this._repository);

  Future<void> setupDefaultAccounting(int organizationId) async {
    try {
      // 1. Import Account Types
      final typesJson = await rootBundle.loadString('assets/json/accounting/account_types.json');
      final List<dynamic> typesData = jsonDecode(typesJson);
      final types = typesData.map((e) {
        final model = AccountTypeModel.fromJson(e);
        return AccountTypeModel(
          id: model.id,
          typeName: model.typeName,
          status: model.status,
          isSystem: model.isSystem,
          organizationId: organizationId,
        );
      }).toList();
      await _repository.bulkCreateAccountTypes(types);

      // 2. Import Account Categories
      final catsJson = await rootBundle.loadString('assets/json/accounting/account_categories.json');
      final List<dynamic> catsData = jsonDecode(catsJson);
      final categories = catsData.map((e) {
        final model = AccountCategoryModel.fromJson(e);
        return AccountCategoryModel(
          id: model.id,
          categoryName: model.categoryName,
          accountTypeId: model.accountTypeId,
          status: model.status,
          isSystem: model.isSystem,
          organizationId: organizationId,
        );
      }).toList();
      await _repository.bulkCreateAccountCategories(categories);

      // 3. Import Chart of Accounts
      final coaJson = await rootBundle.loadString('assets/json/accounting/chart_of_accounts.json');
      final List<dynamic> coaData = jsonDecode(coaJson);
      
      final now = DateTime.now();
      final accounts = coaData.map((json) {
        // We might want to give them unique IDs for this organization if needed,
        // but if IDs are 'sys-xxx' they might be shared or need to be unique.
        // The user said "import json file into chart of account with is active = 1 and isystme = 1"
        return ChartOfAccountModel(
          id: '${json['id']}-$organizationId', // Make it unique per org
          accountCode: json['account_code'],
          accountTitle: json['account_title'],
          level: json['level'],
          accountTypeId: json['account_type_id'],
          accountCategoryId: json['account_category_id'],
          organizationId: organizationId,
          isActive: true,
          isSystem: true,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      await _repository.bulkCreateChartOfAccounts(accounts);
      
      // 4. Create default Invoice Types
      final defaultInvoiceTypes = [
        const InvoiceTypeModel(idInvoiceType: 'SI', description: 'Sales Invoice', forUsed: 'Sales Invoice', isActive: true, organizationId: 0),
        const InvoiceTypeModel(idInvoiceType: 'SIR', description: 'Sales Invoice Return', forUsed: 'Sales Return', isActive: true, organizationId: 0),
        const InvoiceTypeModel(idInvoiceType: 'PI', description: 'Purchase Invoice', forUsed: 'Purchase Invoice', isActive: true, organizationId: 0),
        const InvoiceTypeModel(idInvoiceType: 'PR', description: 'Purchase Return', forUsed: 'Purchase Return', isActive: true, organizationId: 0),
      ];

      for (var type in defaultInvoiceTypes) {
        try {
          await _repository.createInvoiceType(InvoiceTypeModel(
            idInvoiceType: type.idInvoiceType,
            description: type.description,
            forUsed: type.forUsed,
            organizationId: organizationId,
            isActive: true,
          ));
        } catch (e) {
          debugPrint('Error creating default invoice type ${type.idInvoiceType}: $e');
        }
      }

      // 5. Create default Voucher Prefixes
      final defaultPrefixes = [
        {'code': 'CRV', 'desc': 'Cash Receipt Voucher', 'type': 'Receipt'},
        {'code': 'BRV', 'desc': 'Bank Receipt Voucher', 'type': 'Receipt'},
        {'code': 'SI', 'desc': 'Sales Invoice', 'type': 'Sales'},
        {'code': 'SIR', 'desc': 'Sales Invoice Return', 'type': 'Returns'},
        {'code': 'CPV', 'desc': 'Cash Payment Voucher', 'type': 'Payment'},
        {'code': 'BPV', 'desc': 'Bank Payment Voucher', 'type': 'Payment'},
        {'code': 'JV', 'desc': 'Journal Voucher', 'type': 'Journal'},
      ];

      for (var p in defaultPrefixes) {
        try {
          await _repository.createVoucherPrefix(VoucherPrefixModel(
            id: 0,
            prefixCode: p['code']!,
            description: p['desc'],
            voucherType: p['type']!,
            organizationId: organizationId,
            status: true,
          ));
        } catch (e) {
          debugPrint('Error creating default prefix ${p['code']}: $e');
        }
      }

      debugPrint('Accounting setup complete for organization: $organizationId');
    } catch (e) {
      debugPrint('Error during accounting setup: $e');
    }
  }
}
