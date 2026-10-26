import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/metric_strip.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/filter_chips_row.dart';

enum ReportType { purchases, sales, stock }

/// Operational Reports Screen - Section 10.2
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportType _selectedReport = ReportType.purchases;
  String _dateRange = 'October 2026 (Month to Date)';

  @override
  Widget build(BuildContext context) {
    final service = MockDataService();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: 'Operational Reports',
        showLanguageToggle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report type chips
            FilterChipsRow<ReportType>(
              items: ReportType.values,
              selectedItem: _selectedReport,
              labelBuilder: (r) {
                switch (r) {
                  case ReportType.purchases:
                    return 'Purchase Report';
                  case ReportType.sales:
                    return 'Sales Report';
                  case ReportType.stock:
                    return 'Stock Ledger Report';
                }
              },
              onSelected: (val) => setState(() => _selectedReport = val),
            ),
            const SizedBox(height: 12),

            // Date selector strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outline, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.inkSoft,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dateRange,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Content per report type
            Expanded(
              child: _selectedReport == ReportType.purchases
                  ? _buildPurchasesReport(service)
                  : (_selectedReport == ReportType.sales
                        ? _buildSalesReport(service)
                        : _buildStockReport(service)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchasesReport(MockDataService service) {
    final pos = service.purchaseOrders;
    final totalSpent = pos.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
    final totalUnits = pos.fold<int>(
      0,
      (sum, p) => sum + p.totalOrderedQuantity,
    );

    return Column(
      children: [
        MetricStrip(
          items: [
            MetricItem(label: 'Total Orders', value: '${pos.length}'),
            MetricItem(
              label: 'Total Ordered Value',
              value: '₹${totalSpent.toStringAsFixed(0)}',
            ),
            MetricItem(label: 'Ordered Units', value: '$totalUnits'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: pos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final po = pos[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                title: Text(
                  po.purchaseOrderNumber,
                  style: AppTypography.bodyStrong,
                ),
                subtitle: Text(
                  '${po.supplierName} • ${po.items.length} items',
                  style: AppTypography.caption,
                ),
                trailing: MoneyText(amountInRupees: po.totalAmount),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSalesReport(MockDataService service) {
    return Column(
      children: [
        const MetricStrip(
          items: [
            MetricItem(label: 'Scanned Reports', value: '14'),
            MetricItem(label: 'Total Sales Deducted', value: '₹42,300'),
            MetricItem(label: 'Units Dispensed', value: '820'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _buildReportLine(
                'Dolo 650mg',
                '120 tablets dispensed',
                '₹260.00',
              ),
              const Divider(height: 1),
              _buildReportLine(
                'Augmentin 625 Duo',
                '40 tablets dispensed',
                '₹700.00',
              ),
              const Divider(height: 1),
              _buildReportLine('Pan 40', '60 tablets dispensed', '₹200.00'),
              const Divider(height: 1),
              _buildReportLine(
                'Glycomet 500',
                '180 tablets dispensed',
                '₹270.00',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockReport(MockDataService service) {
    final meds = service.medicines;
    return Column(
      children: [
        MetricStrip(
          items: [
            MetricItem(label: 'Catalogue Items', value: '${meds.length}'),
            MetricItem(
              label: 'Low Stock Flagged',
              value: '${meds.where((m) => m.isLowStock).length}',
            ),
            const MetricItem(label: 'Near Expiry Batches', value: '2'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: meds.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final m = meds[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                title: Text(m.name, style: AppTypography.bodyStrong),
                subtitle: Text(
                  '${m.productId} • Conversion: 1 ${m.packUnit} = ${m.unitsPerPack} ${m.saleUnit}s',
                  style: AppTypography.caption,
                ),
                trailing: Text(
                  '${m.currentStock} ${m.saleUnit}s',
                  style: AppTypography.tabularNumbers.copyWith(
                    color: m.isLowStock ? AppColors.dangerFg : AppColors.ink,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportLine(String title, String subtitle, String amount) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      title: Text(title, style: AppTypography.bodyStrong),
      subtitle: Text(subtitle, style: AppTypography.caption),
      trailing: Text(amount, style: AppTypography.tabularNumbers),
    );
  }
}
