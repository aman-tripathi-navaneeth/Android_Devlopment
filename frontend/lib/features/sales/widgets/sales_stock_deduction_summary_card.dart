import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../models/sales_report.dart';

/// Reusable proposed stock deduction summary widget for Screen 4 & Screen 6.
class SalesStockDeductionSummaryCard extends StatelessWidget {
  final SalesReport report;
  final bool isConfirmedPosted;

  const SalesStockDeductionSummaryCard({
    super.key,
    required this.report,
    this.isConfirmedPosted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.vanilla.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.outline.withOpacity(0.6)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.carob,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConfirmedPosted
                          ? 'Executed Stock Deductions'
                          : 'Proposed Stock Deductions',
                      style: AppTypography.subheading.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.carob,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.almond,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${report.totalLooseUnitsDeducted} Total Loose Units',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                      color: AppColors.carob,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Audit Metadata
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetadataRow('Source Register:', report.reportReference),
                _buildMetadataRow(
                  'Report Date:',
                  '${report.reportDate.day} ${_getMonthName(report.reportDate.month)} ${report.reportDate.year}',
                ),
                _buildMetadataRow('Authorized Staff:', report.authorizer),
                _buildMetadataRow(
                  'Deduction Strategy:',
                  'First Expiry, First Out (FEFO)',
                ),
                if (report.transactionReference != null)
                  _buildMetadataRow(
                    'Ledger Transaction Ref:',
                    report.transactionReference!,
                    isHighlight: true,
                  ),
                const Divider(height: 18),

                // Line items deduction breakdown
                Text(
                  'Inventory OUT Movements Breakdown:',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 8),

                ...report.lines.map((l) {
                  final looseUnits = l.calculatedLooseUnits;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.outline.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.matchedProductName.isEmpty
                                    ? 'Unmatched Item'
                                    : l.matchedProductName,
                                style: AppTypography.bodyStrong.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                '${l.matchedProductId.isEmpty ? "NO ID" : l.matchedProductId} • Qty Sold: ${l.quantity} (${l.batchAllocationRule})',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '-$looseUnits to deduct',
                          style: AppTypography.tabularNumbers.copyWith(
                            color: AppColors.dangerFg,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
                color: isHighlight ? AppColors.matchaDeep : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
