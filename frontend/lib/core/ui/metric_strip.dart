import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class MetricItem {
  final String label;
  final String value;
  final String? subtitle;

  const MetricItem({required this.label, required this.value, this.subtitle});
}

/// MetricStrip: horizontal row of 2-4 compact figures on vanilla (PART 4.7).
class MetricStrip extends StatelessWidget {
  final List<MetricItem> items;

  const MetricStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.vanilla,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                height: 32,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppColors.carob.withOpacity(0.18),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[i].value,
                    style: AppTypography.tabularNumbers.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.carob,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
