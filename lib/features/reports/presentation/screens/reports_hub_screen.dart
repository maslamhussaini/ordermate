// lib/features/reports/presentation/screens/reports_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Reports Center',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      // drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('FINANCIAL LEDGERS'),
            _buildReportGrid(context, [
              _ReportItem(
                  title: 'Customer Ledgers',
                  icon: Icons.person_search,
                  route: '/reports/ledger/customer',
                  color: Colors.blue),
              _ReportItem(
                  title: 'Vendor Ledgers',
                  icon: Icons.local_shipping,
                  route: '/reports/ledger/vendor',
                  color: Colors.orange),
              _ReportItem(
                  title: 'Bank Ledgers',
                  icon: Icons.account_balance,
                  route: '/reports/ledger/bank',
                  color: Colors.green),
              _ReportItem(
                  title: 'Cash Ledgers',
                  icon: Icons.payments,
                  route: '/reports/ledger/cash',
                  color: Colors.teal),
              _ReportItem(
                  title: 'GL Account Ledgers',
                  icon: Icons.account_tree,
                  route: '/reports/ledger/gl',
                  color: Colors.indigo),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('SALES REPORTS'),
            _buildReportGrid(context, [
              _ReportItem(
                  title: 'Sales - Product Wise',
                  icon: Icons.inventory_2,
                  route: '/reports/sales/product',
                  color: Colors.purple),
              _ReportItem(
                  title: 'Sales - Customer Wise',
                  icon: Icons.groups,
                  route: '/reports/sales/customer',
                  color: Colors.deepPurple),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('SALES RETURNS'),
            _buildReportGrid(context, [
              _ReportItem(
                  title: 'Returns - Product Wise',
                  icon: Icons.assignment_return,
                  route: '/reports/returns/product',
                  color: Colors.red),
              _ReportItem(
                  title: 'Returns - Customer Wise',
                  icon: Icons.person_remove,
                  route: '/reports/returns/customer',
                  color: Colors.pink),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('INVENTORY REPORTS'),
            _buildReportGrid(context, [
              _ReportItem(
                  title: 'General Journal',
                  icon: Icons.history_edu,
                  route: '/reports/inventory-journal',
                  color: Colors.brown),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('OTHER REPORTS'),
            _buildReportGrid(context, [
              _ReportItem(
                  title: 'Sales Manager (Loc)',
                  icon: Icons.location_on,
                  route: '/reports/location',
                  color: Colors.blueGrey),
              _ReportItem(
                  title: 'Day Summary Report',
                  icon: Icons.summarize,
                  route: '/reports/day-closing',
                  color: Colors.indigo),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildReportGrid(BuildContext context, List<_ReportItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1100) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: () => context.push(item.route),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: item.color, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportItem {
  final String title;
  final IconData icon;
  final String route;
  final Color color;

  _ReportItem(
      {required this.title,
      required this.icon,
      required this.route,
      required this.color});
}
