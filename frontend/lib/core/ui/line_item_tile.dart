import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'money_text.dart';

/// LineItemTile: name, product ID, qty x rate, line total, edit/remove actions (PART 4.7).
class LineItemTile extends StatelessWidget {
  final String productName;
  final String productId;
  final String unit;
  final int quantity;
  final double rate;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const LineItemTile({
    super.key,
    required this.productName,
    required this.productId,
    required this.unit,
    required this.quantity,
    required this.rate,
    this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final lineTotal = quantity * rate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  productName,
                  style: AppTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.almond,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        productId,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$quantity $unit × ₹${rate.toStringAsFixed(2)}',
                      style: AppTypography.caption.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyText(
                amountInRupees: lineTotal,
                style: AppTypography.tabularNumbers.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.matchaDeep,
                        ),
                      ),
                    ),
                  if (onRemove != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppColors.dangerFg,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
