// lib/features/accounting/domain/entities/chart_of_account.dart

class ChartOfAccount {
  final String id;
  final String accountCode;
  final String accountTitle;
  final String? parentId;
  final int level;
  final int? accountTypeId;
  final int? accountCategoryId;
  final int organizationId;
  final bool isActive;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChartOfAccount({
    required this.id,
    required this.accountCode,
    required this.accountTitle,
    this.parentId,
    required this.level,
    this.accountTypeId,
    this.accountCategoryId,
    required this.organizationId,
    this.isActive = true,
    this.isSystem = false,
    required this.createdAt,
    required this.updatedAt,
  });
}

class AccountType {
  final int id;
  final String typeName;
  final bool status;
  final bool isSystem;
  final int organizationId;
  const AccountType({
    required this.id,
    required this.typeName,
    this.status = true,
    this.isSystem = false,
    required this.organizationId,
  });
}

class AccountCategory {
  final int id;
  final String categoryName;
  final int accountTypeId;
  final bool status;
  final bool isSystem;
  final int organizationId;
  const AccountCategory({
    required this.id,
    required this.categoryName,
    required this.accountTypeId,
    this.status = true,
    this.isSystem = false,
    required this.organizationId,
  });
}

class BankCash {
  final String id;
  final String name;
  final String chartOfAccountId;
  final String? accountNumber;
  final String? branchName;
  final int organizationId;
  final int storeId;
  final bool status;

  const BankCash({
    required this.id,
    required this.name,
    required this.chartOfAccountId,
    this.accountNumber,
    this.branchName,
    required this.organizationId,
    required this.storeId,
    this.status = true,
  });
}

class VoucherPrefix {
  final int id;
  final String prefixCode;
  final String? description;
  final String voucherType;
  final int organizationId;
  final bool status;
  final bool isSystem;

  const VoucherPrefix({
    required this.id,
    required this.prefixCode,
    this.description,
    required this.voucherType,
    required this.organizationId,
    this.status = true,
    this.isSystem = false,
  });
}

class Transaction {
  final String id;
  final int voucherPrefixId;
  final String voucherNumber;
  final DateTime voucherDate;
  final String accountId;
  final String? offsetAccountId;
  final double amount;
  final String? description;
  final String status;
  final int organizationId;
  final int storeId;
  final int? sYear;
  final String? moduleAccount;
  final String? offsetModuleAccount;

  const Transaction({
    required this.id,
    required this.voucherPrefixId,
    required this.voucherNumber,
    required this.voucherDate,
    required this.accountId,
    this.offsetAccountId,
    required this.amount,
    this.description,
    this.status = 'posted',
    required this.organizationId,
    required this.storeId,
    this.sYear,
    this.moduleAccount,
    this.offsetModuleAccount,
  });
}

class PaymentTerm {
  final int id;
  final String name;
  final String? description;
  final bool isActive;

  final int days;
  final int organizationId;

  const PaymentTerm({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.days = 0,
    required this.organizationId,
  });
}

class FinancialSession {
  final int sYear;
  final DateTime startDate;
  final DateTime endDate;
  final String? narration;
  final bool inUse;
  final bool isActive;
  final bool isClosed;
  final int organizationId;

  const FinancialSession({
    required this.sYear,
    required this.startDate,
    required this.endDate,
    this.narration,
    this.inUse = false,
    this.isActive = true,
    this.isClosed = false,
    required this.organizationId,
  });
}
