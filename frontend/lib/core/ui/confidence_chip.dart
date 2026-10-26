import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// ConfidenceChip: High / Medium / Low match indicator (PART 4.7, D19).
class ConfidenceChip extends StatelessWidget {
  final double confidence; // 0.0 to 1.0

  const ConfidenceChip({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (confidence >= 0.90) {
      bg = AppColors.successBg;
      fg = AppColors.successFg;
      label = 'High match';
      icon = Icons.verified_rounded;
    } else if (confidence >= 0.70) {
      bg = AppColors.warningBg;
      fg = AppColors.warningFg;
      label = 'Medium match';
      icon = Icons.help_outline_rounded;
    } else {
      bg = AppColors.dangerBg;
      fg = AppColors.dangerFg;
      label = 'Low match';
      icon = Icons.priority_high_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
