import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// ProgressBarSegmented: received vs ordered progress with matcha fill on almond track (PART 4.7).
class ProgressBarSegmented extends StatelessWidget {
  final int received;
  final int ordered;
  final String? unit;

  const ProgressBarSegmented({
    super.key,
    required this.received,
    required this.ordered,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = ordered > 0
        ? (received / ordered).clamp(0.0, 1.0)
        : 0.0;
    final int percent = (fraction * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Received $received / $ordered ${unit ?? 'units'}',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            Text(
              '$percent%',
              style: AppTypography.tabularNumbers.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fraction >= 1.0
                    ? AppColors.successFg
                    : AppColors.matchaDeep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.almond,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: fraction >= 1.0 ? AppColors.successFg : AppColors.matcha,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
