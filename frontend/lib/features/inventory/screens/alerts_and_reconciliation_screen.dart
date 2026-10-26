import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/medicine.dart';
import '../../../core/models/batch.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/filter_chips_row.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/confirm_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import 'stock_count_sheet.dart';

enum AlertTab { lowStock, nearExpiry, expired, reconciliation }

enum ExpiryViewMode { list, calendar }

/// Expiry, Low-stock alerts and Stock Reconciliation Screen - Section 10.6 & Section 10
class AlertsAndReconciliationScreen extends StatefulWidget {
  const AlertsAndReconciliationScreen({super.key});

  @override
  State<AlertsAndReconciliationScreen> createState() =>
      _AlertsAndReconciliationScreenState();
}

class _AlertsAndReconciliationScreenState
    extends State<AlertsAndReconciliationScreen> {
  AlertTab _selectedTab = AlertTab.nearExpiry;
  ExpiryViewMode _expiryViewMode = ExpiryViewMode.list;
  String _selectedMonth = 'All';
  bool _showSystemQuantity = false;

  final Map<String, int> _countedQuantities = {
    'MED-000101': 180,
    'MED-000102': 23, // 2 shortage
    'MED-000104': 15, // 3 surplus
  };

  final Map<String, String> _varianceReasons = {
    'MED-000102': 'Found broken seal on 2 strips during counter count',
    'MED-000104': 'Uncounted sample strip found behind display rack',
  };

  @override
  Widget build(BuildContext context) {
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        // Collect all batches across catalogue for expiry analysis
        final List<Map<String, dynamic>> allBatches = [];
        for (final m in service.medicines) {
          for (final b in m.batches) {
            allBatches.add({'medicine': m, 'batch': b});
          }
        }

        final nearExpiryList = allBatches.where((item) {
          final b = item['batch'] as MedicineBatch;
          return b.isNearExpiry;
        }).toList();

        final expiredList = allBatches.where((item) {
          final b = item['batch'] as MedicineBatch;
          return b.isExpired;
        }).toList();

        final lowStockList = service.medicines
            .where((m) => m.isLowStock)
            .toList();

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppTopBar(
            title: 'Alerts & Reconciliation',
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
                FilterChipsRow<AlertTab>(
                  items: AlertTab.values,
                  selectedItem: _selectedTab,
                  labelBuilder: (t) {
                    switch (t) {
                      case AlertTab.lowStock:
                        return 'Low Stock (${lowStockList.length})';
                      case AlertTab.nearExpiry:
                        return 'Near Expiry (${nearExpiryList.length})';
                      case AlertTab.expired:
                        return 'Expired (${expiredList.length})';
                      case AlertTab.reconciliation:
                        return 'Physical Audit';
                    }
                  },
                  onSelected: (val) => setState(() => _selectedTab = val),
                ),
                const SizedBox(height: 14),

                Expanded(
                  child: _buildTabContent(
                    service,
                    lowStockList,
                    nearExpiryList,
                    expiredList,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(
    MockDataService service,
    List<Medicine> lowStockList,
    List<Map<String, dynamic>> nearExpiryList,
    List<Map<String, dynamic>> expiredList,
  ) {
    switch (_selectedTab) {
      case AlertTab.lowStock:
        return _buildLowStockList(lowStockList);
      case AlertTab.nearExpiry:
        return _buildExpiryTab(nearExpiryList);
      case AlertTab.expired:
        return _buildExpiredTab(expiredList);
      case AlertTab.reconciliation:
        return _buildReconciliationWorkflow(service);
    }
  }

  // --- LOW STOCK VIEW ---
  Widget _buildLowStockList(List<Medicine> lowMeds) {
    if (lowMeds.isEmpty) {
      return const Center(
        child: Text('All medicines have healthy stock levels!'),
      );
    }

    return ListView.separated(
      itemCount: lowMeds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = lowMeds[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.dangerFg,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: AppTypography.bodyStrong),
                    Text(
                      'Stock: ${m.currentStock} ${m.saleUnit}s • Threshold: ${m.lowStockThreshold}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                icon: const Icon(Icons.calculate_outlined, size: 14),
                label: const Text('Count', style: TextStyle(fontSize: 11)),
                onPressed: () => StockCountSheet.show(context, medicine: m),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- INTERACTIVE EXPIRY TAB WITH TIMELINE & CALENDAR TOGGLE ---
  Widget _buildExpiryTab(List<Map<String, dynamic>> batches) {
    final filtered = batches.where((item) {
      if (_selectedMonth == 'All') return true;
      final b = item['batch'] as MedicineBatch;
      return b.expiryFormatted.contains(_selectedMonth);
    }).toList();

    final totalUnitsAtRisk = filtered.fold(
      0,
      (sum, i) => sum + (i['batch'] as MedicineBatch).quantity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // View mode toggle & month selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Month selector chips
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', '2026-10', '2026-11', '2026-12'].map((m) {
                    final isSel = _selectedMonth == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(m == 'All' ? 'All Months' : m),
                        selected: isSel,
                        selectedColor: AppColors.matcha,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSel ? AppColors.onMatcha : AppColors.ink,
                        ),
                        onSelected: (_) => setState(() => _selectedMonth = m),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _expiryViewMode == ExpiryViewMode.list
                    ? Icons.calendar_month_rounded
                    : Icons.view_list_rounded,
                size: 20,
                color: AppColors.matchaDeep,
              ),
              tooltip: 'Toggle Calendar/List View',
              onPressed: () {
                setState(() {
                  _expiryViewMode = _expiryViewMode == ExpiryViewMode.list
                      ? ExpiryViewMode.calendar
                      : ExpiryViewMode.list;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Summary Metric Strip
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.vanilla,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Near Expiry Batches at Risk',
                    style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  ),
                  Text(
                    '${filtered.length} Batches (${totalUnitsAtRisk} Units at Risk)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.carob,
                    ),
                  ),
                ],
              ),
              const StatusChip(
                status: StatusType.pending,
                customLabel: '< 90 Days',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _expiryViewMode == ExpiryViewMode.list
              ? _buildExpiryListView(filtered)
              : _buildExpiryCalendarTimeline(filtered),
        ),
      ],
    );
  }

  Widget _buildExpiryListView(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No batches expiring in this window.'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final med = items[i]['medicine'] as Medicine;
        final batch = items[i]['batch'] as MedicineBatch;
        final isCritical = batch.isCriticalExpiry;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: isCritical ? AppColors.dangerFg : AppColors.warningFg,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${med.name} (${med.strength})',
                      style: AppTypography.bodyStrong,
                    ),
                    Text(
                      'Batch: ${batch.batchNumber} • Expiry: ${batch.expiryFormatted} (${batch.daysUntilExpiry} days left)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isCritical
                            ? AppColors.dangerFg
                            : AppColors.warningFg,
                      ),
                    ),
                    Text(
                      'Stock at risk: ${batch.quantity} ${med.saleUnit}s • Supplier: ${batch.supplierName ?? 'Direct'}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                icon: const Icon(Icons.calculate_outlined, size: 14),
                label: const Text('Count', style: TextStyle(fontSize: 11)),
                onPressed: () => StockCountSheet.show(
                  context,
                  medicine: med,
                  initialBatch: batch,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpiryCalendarTimeline(List<Map<String, dynamic>> items) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expiry Timeline Calendar',
                      style: AppTypography.bodyStrong,
                    ),
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.matchaDeep,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'October 2026: 1 Batch Expiring (Azee 500 Batch AZ-12, 12 units)\nNovember 2026: 1 Batch Expiring (Dolo 650 Batch DL-84, 60 units)\nFuture: All other catalogue batches are within safe shelf-life (> 12 months)',
                  style: AppTypography.body.copyWith(
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Batch Inspection List:', style: AppTypography.section),
          const SizedBox(height: 8),
          _buildExpiryListView(items),
        ],
      ),
    );
  }

  // --- EXPIRED BATCHES TAB ---
  Widget _buildExpiredTab(List<Map<String, dynamic>> expiredBatches) {
    if (expiredBatches.isEmpty) {
      return const Center(
        child: Text('No expired batches currently in stock.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InlineBanner(
          type: BannerType.error,
          text: 'EXPIRED STOCK: These batches cannot be sold. Quarantine or initiate verified disposal to remove from active shelves.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: expiredBatches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final med = expiredBatches[i]['medicine'] as Medicine;
              final batch = expiredBatches[i]['batch'] as MedicineBatch;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.dangerFg,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${med.name} (Batch: ${batch.batchNumber})',
                            style: AppTypography.bodyStrong,
                          ),
                          Text(
                            'Expired on: ${batch.expiryFormatted}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.dangerFg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Quantity: ${batch.quantity} ${med.saleUnit}s • ${batch.isQuarantined ? 'Quarantined' : 'On Shelf'}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dangerBg,
                        foregroundColor: AppColors.dangerFg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 14),
                      label: const Text(
                        'Audit Disposal',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () => StockCountSheet.show(
                        context,
                        medicine: med,
                        initialBatch: batch,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- STOCK RECONCILIATION WORKFLOW ---
  Widget _buildReconciliationWorkflow(MockDataService service) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Count Session: RECON-2026-001',
                      style: AppTypography.bodyStrong,
                    ),
                    Text(
                      'Blind Count Active • Toggle to reveal system stock',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
                Switch(
                  value: _showSystemQuantity,
                  activeColor: AppColors.matchaDeep,
                  onChanged: (val) => setState(() => _showSystemQuantity = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Counted Items & Discrepancy Audits',
            style: AppTypography.section,
          ),
          const SizedBox(height: 8),

          _buildReconRow(
            'Dolo 650mg',
            'MED-000101',
            180,
            _countedQuantities['MED-000101']!,
          ),
          const SizedBox(height: 8),
          _buildReconRow(
            'Augmentin 625 Duo',
            'MED-000102',
            25,
            _countedQuantities['MED-000102']!,
            reason: _varianceReasons['MED-000102'],
          ),
          const SizedBox(height: 8),
          _buildReconRow(
            'Azee 500',
            'MED-000104',
            12,
            _countedQuantities['MED-000104']!,
            reason: _varianceReasons['MED-000104'],
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Approve Adjustments (Owner Only)'),
            onPressed: () async {
              final confirmed = await ConfirmSheet.show(
                context,
                title: 'Approve Stock Reconciliation?',
                message: 'This will post ADJUST_IN (+3) and ADJUST_OUT (-2) movements into the inventory ledger with mandatory audit reasons.',
                confirmLabel: 'Approve & Post Movements',
              );
              if (confirmed == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Reconciliation session approved! Movements recorded in ledger.',
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildReconRow(
    String name,
    String id,
    int systemQty,
    int countedQty, {
    String? reason,
  }) {
    final variance = countedQty - systemQty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: AppTypography.bodyStrong),
              Text(
                'Counted: $countedQty',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showSystemQuantity
                    ? 'Recorded: $systemQty'
                    : 'Recorded: *** (Blind Count)',
                style: AppTypography.caption,
              ),
              Text(
                _showSystemQuantity
                    ? 'Variance: ${variance > 0 ? '+' : ''}$variance'
                    : 'Variance: Hidden until reveal',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: variance < 0
                      ? AppColors.dangerFg
                      : (variance > 0
                            ? AppColors.successFg
                            : AppColors.inkSoft),
                ),
              ),
            ],
          ),
          if (reason != null && _showSystemQuantity) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: $reason',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
