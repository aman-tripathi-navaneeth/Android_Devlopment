import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Interactive difference preview card displaying:
/// Recorded Qty, Physically Counted Qty, Proposed Variance, Resulting Qty, and Reason.
/// Section 8 Mandatory Invariant: Never overwrite inventory silently.
class DifferencePreviewCard extends StatelessWidget {
  final String medicineName;
  final String batchNumber;
  final int recordedQuantity;
  final int countedQuantity;
  final String unitLabel;
  final String? reason;
  final String? authorizedBy;

  const DifferencePreviewCard({
    super.key,
    required this.medicineName,
    required this.batchNumber,
    required this.recordedQuantity,
    required this.countedQuantity,
    required this.unitLabel,
    this.reason,
    this.authorizedBy,
  });

  int get difference => countedQuantity - recordedQuantity;

  @override
  Widget build(BuildContext context) {
    final isNegative = difference < 0;
    final isZero = difference == 0;
    final diffColor = isZero
        ? AppColors.inkSoft
        : (isNegative ? AppColors.dangerFg : AppColors.successFg);

    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  medicineName,
                  style: AppTypography.bodyStrong.copyWith(fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.almond,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Batch: $batchNumber',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3-metric strip
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'Recorded',
                  '$recordedQuantity',
                  unitLabel,
                  AppColors.ink,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.outline),
              Expanded(
                child: _buildMetric(
                  'Physical Count',
                  '$countedQuantity',
                  unitLabel,
                  AppColors.ink,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.outline),
              Expanded(
                child: _buildMetric(
                  'Variance',
                  '${difference > 0 ? '+' : ''}$difference',
                  unitLabel,
                  diffColor,
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Resulting balance and Reason
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Resulting Balance:', style: AppTypography.caption),
              Text(
                '$countedQuantity $unitLabel',
                style: AppTypography.tabularNumbers.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.carob,
                ),
              ),
            ],
          ),

          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Adjustment Reason:', style: AppTypography.caption),
                Expanded(
                  child: Text(
                    reason!,
                    textAlign: TextAlign.right,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (authorizedBy != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Authorized By:', style: AppTypography.caption),
                Text(
                  authorizedBy!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.matchaDeep,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, String unit, Color valColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.tabularNumbersLarge.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: valColor,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(fontSize: 9.5, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}
