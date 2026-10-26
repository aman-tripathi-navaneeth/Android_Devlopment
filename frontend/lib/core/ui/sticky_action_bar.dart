import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'money_text.dart';

/// StickyActionBar: pinned at bottom above keyboard with running total (PART 4.7).
class StickyActionBar extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final bool isPrimaryLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final double? runningTotal;
  final String? totalLabel;

  const StickyActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.isPrimaryLoading = false,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.runningTotal,
    this.totalLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.outline, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (runningTotal != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalLabel ?? 'Total Amount',
                  style: AppTypography.label.copyWith(color: AppColors.inkSoft),
                ),
                MoneyText(
                  amountInRupees: runningTotal,
                  style: AppTypography.tabularNumbersLarge.copyWith(
                    color: AppColors.matchaDeep,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (secondaryLabel != null && onSecondaryPressed != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondaryPressed,
                    child: Text(secondaryLabel!),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: isPrimaryLoading ? null : onPrimaryPressed,
                  child: isPrimaryLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(primaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
