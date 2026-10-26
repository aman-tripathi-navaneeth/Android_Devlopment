import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/medicine.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/confirm_sheet.dart';
import '../../../core/ui/metric_strip.dart';
import '../widgets/pack_unit_converter_card.dart';
import '../../inventory/screens/stock_count_sheet.dart';
import 'add_edit_medicine_screen.dart';

/// Screen 3 — Medicine Detail Screen
/// Displays full product specifications, pack/sale unit rules, batch summaries,
/// and deactivation/reactivation controls.
class MedicineDetailScreen extends StatelessWidget {
  final String productId;

  const MedicineDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final med = service.medicines.firstWhere(
          (m) => m.productId == productId,
          orElse: () => const Medicine(
            productId: 'MED-000000',
            name: 'Not found',
            genericName: '',
            strength: '',
            form: '',
            category: '',
            manufacturer: '',
            packUnit: 'strip',
            saleUnit: 'tablet',
            unitsPerPack: 10,
            isActive: false,
          ),
        );

        final safeUnitsPerPack = med.unitsPerPack > 0 ? med.unitsPerPack : 1;
        final packEquivalent = (med.currentStock / safeUnitsPerPack)
            .toStringAsFixed(1);

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppTopBar(
            title: '${med.name} (${med.strength})',
            showLanguageToggle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Medicine',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AddEditMedicineScreen(medicineToEdit: med),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.outline, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: med.isActive
                          ? AppColors.dangerFg
                          : AppColors.successFg,
                      side: BorderSide(
                        color: med.isActive
                            ? AppColors.dangerFg
                            : AppColors.successFg,
                        width: 1,
                      ),
                    ),
                    onPressed: () async {
                      if (med.isActive) {
                        final confirmed = await ConfirmSheet.show(
                          context,
                          title: 'Deactivate ${med.name}?',
                          message: 'This medicine will no longer appear in search or in new orders. Old invoices and sales that use it will still show its name.',
                          confirmLabel: strings.deactivate,
                          isDestructive: true,
                        );
                        if (confirmed == true) {
                          service.toggleMedicineActive(med.productId, false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${med.name} deactivated. Product ID ${med.productId} preserved.',
                                ),
                                backgroundColor: AppColors.carob,
                              ),
                            );
                          }
                        }
                      } else {
                        final confirmed = await ConfirmSheet.show(
                          context,
                          title: strings.reactivateMedicine,
                          message:
                              'Reactivate ${med.name} for active procurement and sales dispensing?',
                          confirmLabel: strings.reactivate,
                        );
                        if (confirmed == true) {
                          service.toggleMedicineActive(med.productId, true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${med.name} reactivated successfully.',
                                ),
                                backgroundColor: AppColors.matchaDeep,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: Text(
                      med.isActive
                          ? strings.deactivateMedicine
                          : strings.reactivateMedicine,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Details'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AddEditMedicineScreen(medicineToEdit: med),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PRODUCT HEADER CARD
                Container(
                  padding: const EdgeInsets.all(16),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.almond,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              med.productId,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                          StatusChip(
                            status: med.isActive
                                ? StatusType.active
                                : StatusType.inactive,
                            customLabel: med.isActive
                                ? strings.active
                                : strings.inactive,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${med.name} ${med.strength}',
                        style: AppTypography.title.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 16,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Generic: ${med.genericName}',
                              style: AppTypography.bodyStrong.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 16,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Manufacturer: ${med.manufacturer}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 16,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Category: ${med.category} • Form: ${med.form}',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. STOCK METRICS STRIP
                MetricStrip(
                  items: [
                    MetricItem(
                      label: 'Stock (${med.saleUnit}s)',
                      value: '${med.currentStock}',
                    ),
                    MetricItem(
                      label: 'Pack Equivalent',
                      value: '$packEquivalent ${med.packUnit}s',
                    ),
                    MetricItem(
                      label: 'Batches Active',
                      value: '${med.batches.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. SCREEN 4: PACK & UNIT CONFIGURATION CARD
                Text(
                  'Pack Sizes & Unit Rules (Screen 4)',
                  style: AppTypography.section,
                ),
                const SizedBox(height: 8),
                PackUnitConverterCard(
                  packUnit: med.packUnit,
                  saleUnit: med.saleUnit,
                  unitsPerPack: med.unitsPerPack,
                  isInteractive: true,
                ),
                const SizedBox(height: 20),

                // 4. BATCH & INVENTORY BREAKDOWN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Batches & Physical Stock (${med.batches.length})',
                      style: AppTypography.section,
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.checklist_rtl_rounded, size: 16),
                      label: const Text('Stock Count'),
                      onPressed: () {
                        StockCountSheet.show(context, medicine: med);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (med.batches.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Center(
                      child: Text(
                        'No physical batches currently logged in inventory.',
                        style: AppTypography.caption,
                      ),
                    ),
                  )
                else
                  ...med.batches.map((b) {
                    Color? badgeColor;
                    String expText = b.expiryFormatted;
                    if (b.isExpired) {
                      badgeColor = AppColors.dangerFg;
                      expText += ' (Expired)';
                    } else if (b.isNearExpiry) {
                      badgeColor = AppColors.warningFg;
                      expText += ' (Near Expiry)';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Batch: ${b.batchNumber}',
                                style: AppTypography.bodyStrong,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Expiry: $expText',
                                style: AppTypography.caption.copyWith(
                                  color: badgeColor ?? AppColors.inkSoft,
                                  fontWeight: badgeColor != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (b.supplierName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Supplier: ${b.supplierName}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${b.quantity} ${med.saleUnit}s',
                                style: AppTypography.tabularNumbers.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '≈ ${(b.quantity / safeUnitsPerPack).toStringAsFixed(1)} ${med.packUnit}s',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }
}
