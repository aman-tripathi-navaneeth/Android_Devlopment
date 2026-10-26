import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/entity_card.dart';

/// Stock Ledger & Batch Movements Screen - Section 10.5
class StockLedgerScreen extends StatelessWidget {
  const StockLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = MockDataService();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: 'Inventory & Stock Ledger',
        showLanguageToggle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.vanilla.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: AppColors.carob),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Golden Rule G1: The stock ledger is the sole source of truth. Balances are derived from validated, append-only movements.',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.carob,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Text(
              'Current Stock Balances (Dual Units)',
              style: AppTypography.section,
            ),
            const SizedBox(height: 8),

            ...service.medicines.map((m) {
              final packs = m.currentStock ~/ m.unitsPerPack;
              final loose = m.currentStock % m.unitsPerPack;
              final dualUnit = '$packs ${m.packUnit}s + $loose ${m.saleUnit}s';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: EntityCard(
                  title: m.name,
                  subtitle1:
                      '${m.productId} • Conversion: 1 ${m.packUnit} = ${m.unitsPerPack} ${m.saleUnit}s',
                  subtitle2:
                      'Display: $dualUnit (${m.currentStock} ${m.saleUnit}s)',
                  leadingIcon: Icons.inventory_2_outlined,
                  trailing: Text(
                    '${m.currentStock}',
                    style: AppTypography.tabularNumbersLarge.copyWith(
                      color: m.isLowStock
                          ? AppColors.dangerFg
                          : AppColors.matchaDeep,
                    ),
                  ),
                  onTap: () => _showMovementHistory(context, m),
                ),
              );
            }).toList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showMovementHistory(BuildContext context, dynamic m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '${m.name} — Batch & Movements',
              style: AppTypography.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Ledger Movement Audit Trail (Traceable)',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 16),

            // Active batches
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.almond.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Batch: DL-2024-91 (Exp: Nov 2027)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${m.currentStock} ${m.saleUnit}s',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text('Movement History', style: AppTypography.section),
            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                children: [
                  _movementItem(
                    'IN',
                    '+600 tablets',
                    'GRN-2026-000001 (Goods Receipt)',
                    '10 Oct 2026',
                  ),
                  const Divider(height: 1),
                  _movementItem(
                    'OUT',
                    '-120 tablets',
                    'SALES-2026-10-11 (Sales Report)',
                    '11 Oct 2026',
                  ),
                  const Divider(height: 1),
                  _movementItem(
                    'ADJUST_IN',
                    '+10 tablets',
                    'RECON-2026-01 (Approved Count Variance)',
                    '12 Oct 2026',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _movementItem(String type, String qty, String source, String date) {
    Color color = AppColors.successFg;
    if (type == 'OUT') color = AppColors.dangerFg;
    if (type.startsWith('ADJUST')) color = AppColors.warningFg;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          type,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
      title: Text(
        source,
        style: AppTypography.bodyStrong.copyWith(fontSize: 13),
      ),
      subtitle: Text(date, style: AppTypography.caption),
      trailing: Text(
        qty,
        style: AppTypography.tabularNumbers.copyWith(color: color),
      ),
    );
  }
}
