// lib/features/accounting/presentation/providers/voucher_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/accounting_repository.dart';
import 'accounting_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/chart_of_account.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_item.dart';
// Ensure type is available if needed

import 'package:ordermate/features/orders/domain/repositories/order_repository.dart';
import 'package:ordermate/features/products/domain/repositories/product_repository.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';

import 'package:ordermate/features/business_partners/domain/repositories/business_partner_repository.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';

class VoucherService {
  final AccountingRepository _repository;
  final OrderRepository _orderRepository;
  final ProductRepository _productRepository;
  final BusinessPartnerRepository _businessPartnerRepository;

  VoucherService(
    this._repository, 
    this._orderRepository, 
    this._productRepository,
    this._businessPartnerRepository,
  );

  Future<String> generateVoucherNumber({
    required String prefixCode,
    required int storeId,
    String storePrefix = 'ST',
  }) async {
    final now = DateTime.now();
    final currentYear = now.year;
    final nextYear = currentYear + 1;
    final fiscalYear = '$currentYear-$nextYear';

    // Get count of existing vouchers for this prefix, store, and year to determine next number
    final txs = await _repository.getTransactions(storeId: storeId);
    final count = txs.where((t) => 
      t.voucherNumber.startsWith(prefixCode) && 
      t.voucherNumber.endsWith(fiscalYear)
    ).length;

    final sequenceNum = (count + 1).toString().padLeft(7, '0');
    return '$prefixCode-$sequenceNum-$storePrefix$storeId/$fiscalYear';
  }

  int _validateSYear(DateTime date, List<FinancialSession> sessions) {
    if (sessions.isEmpty) {
      throw Exception('No financial years configured. Please configure a financial session first.');
    }
    
    final session = sessions.cast<FinancialSession?>().firstWhere(
      (s) => s != null && 
             (date.isAtSameMomentAs(s.startDate) || date.isAfter(s.startDate)) &&
             (date.isAtSameMomentAs(s.endDate) || date.isBefore(s.endDate.add(const Duration(days: 1)))), 
      orElse: () => null,
    );

    if (session == null) {
       final dateStr = date.toIso8601String().split('T')[0];
       throw Exception('Date $dateStr does not fall within any configured Financial Year.');
    }
    
    if (session.isClosed) {
       throw Exception('Financial Year ${session.sYear} is closed. Cannot transact.');
    }
    
    return session.sYear;
  }

  Future<void> convertOrderToInvoice(Order order, {required List<ChartOfAccount> accounts}) async {
    // if (order.isInvoiced) return; // Allow manual regeneration
    final sessions = await _repository.getFinancialSessions(organizationId: order.organizationId);
    final voucherDate = DateTime.now(); // Date used for all entries
    final sYear = _validateSYear(voucherDate, sessions);
    // ---------------------------------

    // 0. Fetch GL Setup
    final glSetup = await _repository.getGLSetup(order.organizationId);
    if (glSetup == null) {
      throw Exception('Accounting GL Configuration not found for this organization. Please setup GL accounts first.');
    }

    // Fetch Customer to get specific GL Account logic
    final customer = await _businessPartnerRepository.getPartnerById(order.businessPartnerId);
    final customerGLAccountId = customer?.chartOfAccountId;

    // Use Customer GL Account, fallback to Global Receivable if set, else error
    final receivableAccountId = customerGLAccountId ?? glSetup.receivableAccountId;
    if (receivableAccountId == null) {
      throw Exception('No Receivable GL Account found. Please set "Customer GL Account" for this customer or configure a default "Accounts Receivable" in GL Setup.');
    }

    // Fetch up-to-date prefixes
    final prefixes = await _repository.getVoucherPrefixes();
    
    // 1. Generate SINV Voucher (Revenue)
    final sinvPrefix = prefixes.firstWhere(
      (p) => p.voucherType.replaceAll(' ', '_') == 'SALES_INVOICE' || p.prefixCode == 'SINV',
      orElse: () => throw Exception('Sales Invoice (SINV) prefix not configured'),
    );

    final voucherNumber = await generateVoucherNumber(
      prefixCode: sinvPrefix.prefixCode,
      storeId: order.storeId ?? 0,
    );

    final invoiceId = const Uuid().v4();
    final jvPrefix = prefixes.where((p) => p.prefixCode == 'JV').firstOrNull;

    // 2. Create Transaction Entry (Revenue: Dr Receivable, Cr Sales)
    final revenueTransaction = Transaction(
      id: const Uuid().v4(),
      voucherPrefixId: sinvPrefix.id, 
      voucherNumber: voucherNumber,
      voucherDate: voucherDate,
      accountId: receivableAccountId, // Debit Receivable (GL Account)
      moduleAccount: order.businessPartnerId, // Sub-Ledger: Customer
      offsetAccountId: glSetup.salesAccountId, // Credit Sales
      offsetModuleAccount: glSetup.salesAccountId,
      amount: order.totalAmount,
      description: 'Sales Invoice for Order #${order.orderNumber}',
      organizationId: order.organizationId,
      storeId: order.storeId,
      sYear: sYear,
      invoiceId: invoiceId,
    );

    await _repository.createTransaction(revenueTransaction);

    // 3. Automated Inventory/COGS Entry (Dr COGS, Cr Inventory)
    try {
      final orderItemsData = await _orderRepository.getOrderItems(order.id);
      double totalCost = 0;
      
      for (final itemJson in orderItemsData) {
        final productId = itemJson['product_id'] as String;
        final qty = (itemJson['quantity'] as num).toDouble();
        try {
          final product = await _productRepository.getProductById(productId);
          totalCost += (product.cost * qty);
        } catch (e) {
          // ignore: avoid_print
          print('VoucherService: Could not fetch cost for product $productId, skipping in COGS calculation');
        }
      }

      if (totalCost > 0) {
        // Generate a dedicated JV number for COGS
        final jvVoucherNumber = jvPrefix != null 
            ? await generateVoucherNumber(prefixCode: jvPrefix.prefixCode, storeId: order.storeId ?? 0)
            : 'COGS-$voucherNumber';

        final cogsTransaction = Transaction(
          id: const Uuid().v4(),
          voucherPrefixId: jvPrefix?.id ?? sinvPrefix.id,
          voucherNumber: jvVoucherNumber,
          voucherDate: voucherDate,
          accountId: glSetup.cogsAccountId, // Debit COGS
          moduleAccount: glSetup.cogsAccountId, // Internal: Module same as Account
          offsetAccountId: glSetup.inventoryAccountId, // Credit Inventory
          offsetModuleAccount: glSetup.inventoryAccountId, // Internal: Offset Module same as Offset Account
          amount: totalCost,
          description: 'COGS for Order #${order.orderNumber}',
          organizationId: order.organizationId,
          storeId: order.storeId,
          sYear: sYear,
          invoiceId: invoiceId,
        );
        await _repository.createTransaction(cogsTransaction);
      }
    } catch (e) {
      // ignore: avoid_print
      print('VoucherService: Error generating COGS entry: $e');
    }

    // 4. Handle Cash Receipt if Payment Term is Cash (ID = 1 or Name = Cash)
    if (order.paymentTermId == 1) { 
      try {
        final crvPrefix = prefixes.firstWhere(
          (p) => p.voucherType.replaceAll(' ', '_') == 'PAYMENT_VOUCHER' || p.prefixCode == 'CRV' || p.prefixCode == 'RV',
          orElse: () => throw Exception('Receipt Voucher prefix not configured'),
        );

        final receiptVoucherNumber = await generateVoucherNumber(
          prefixCode: crvPrefix.prefixCode,
          storeId: order.storeId ?? 0,
        );

        final cashAcctId = glSetup.cashAccountId;
        if (cashAcctId == null && receivableAccountId == null) {
           throw Exception('No Cash Account configured and no Receivable Account available for receipt.'); 
        }

        final bankCashAccounts = await _repository.getBankCashAccounts(organizationId: order.organizationId);
        final cashModuleId = bankCashAccounts.where((bc) => bc.chartOfAccountId == cashAcctId).firstOrNull?.id;

        final receiptTransaction = Transaction(
          id: const Uuid().v4(),
          voucherPrefixId: crvPrefix.id,
          voucherNumber: receiptVoucherNumber,
          voucherDate: voucherDate,
          accountId: cashAcctId ?? receivableAccountId, // Debit Cash
          moduleAccount: cashModuleId, // Sub-Ledger: Bank/Cash
          offsetAccountId: receivableAccountId, // Credit Receivable (GL Account)
          offsetModuleAccount: order.businessPartnerId, // Sub-Ledger: Customer
          amount: order.totalAmount,
          description: 'Receipt for Order #${order.orderNumber}',
          organizationId: order.organizationId,
          storeId: order.storeId,
          sYear: sYear,
          invoiceId: invoiceId,
        );

        await _repository.createTransaction(receiptTransaction);
      } catch (e) {
        // ignore: avoid_print
        print('VoucherService: Receipt voucher generation failed: $e');
        rethrow;
      }
    }
    
    // 5. Create Invoice Record (Header + Details)
    // ---------------------------------------------------------
    // Fetch or determine Invoice Type
    // Explicitly cast to List<InvoiceType> to force runtime type compatibility for firstWhere
    final rawInvoiceTypes = await _repository.getInvoiceTypes(organizationId: order.organizationId);
    final invoiceTypes = rawInvoiceTypes.cast<InvoiceType>();
    
    // logic to find SI type, default to SI if not found
    final sinvType = invoiceTypes.firstWhere(
      (t) => t.idInvoiceType == 'SI' || t.description.toLowerCase().contains('sales'), 
      orElse: () => InvoiceType(
        idInvoiceType: 'SI', 
        description: 'Sales Invoice', 
        forUsed: 'Sales', 
        isActive: true,
        organizationId: order.organizationId,
      ),
    );

    final newInvoice = Invoice(
      id: invoiceId, 
      invoiceNumber: voucherNumber, // Use same number as GL voucher
      invoiceDate: voucherDate,
      idInvoiceType: sinvType.idInvoiceType,
      businessPartnerId: order.businessPartnerId,
      orderId: order.id,
      totalAmount: order.totalAmount,
      status: 'Unpaid', 
      organizationId: order.organizationId,
      storeId: order.storeId,
      sYear: sYear, // Set sYear here
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repository.createInvoice(newInvoice);

    // Create Items
    final orderItemsData = await _orderRepository.getOrderItems(order.id);
    final invoiceItems = <InvoiceItem>[];

    for (final itemJson in orderItemsData) {
      final productId = itemJson['product_id'] as String;
      final qty = (itemJson['quantity'] as num).toDouble();
      // Ensure we handle various pricing field names if schema differs
      final price = (itemJson['price'] as num?)?.toDouble() 
                 ?? (itemJson['rate'] as num?)?.toDouble() 
                 ?? 0.0; 
      final total = (itemJson['total'] as num?)?.toDouble() ?? (qty * price);

      String? productName;
      try {
        final p = await _productRepository.getProductById(productId);
        productName = p.name;
      } catch (_) {}

      invoiceItems.add(InvoiceItem(
        id: const Uuid().v4(),
        invoiceId: invoiceId,
        productId: productId,
        productName: productName,
        quantity: qty,
        rate: price,
        total: total, // or qty * price
        createdAt: DateTime.now(),
      ));
    }

    if (invoiceItems.isNotEmpty) {
      await _repository.createInvoiceItems(invoiceItems);
    }

    // 6. Update Order status
    await _orderRepository.updateOrderInvoiced(order.id, true);
  }
}

final voucherServiceProvider = Provider<VoucherService>((ref) {
  final repo = ref.watch(accountingRepositoryProvider);
  final orderRepo = ref.watch(orderRepositoryProvider);
  final productRepo = ref.watch(productRepositoryProvider);
  final partnerRepo = ref.watch(businessPartnerRepositoryProvider);
  return VoucherService(repo, orderRepo, productRepo, partnerRepo);
});
