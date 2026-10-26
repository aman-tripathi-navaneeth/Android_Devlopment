import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// QuantityStepper: minus / numeric field / plus, min/max, unit label (PART 4.7).
class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final String? unitLabel;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.unitLabel,
  });

  void _decrement() {
    if (value > min) {
      onChanged(value - 1);
    }
  }

  void _increment() {
    if (max == null || value < max!) {
      onChanged(value + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = max == null || value < max!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildButton(
          icon: Icons.remove_rounded,
          enabled: canDecrement,
          onTap: _decrement,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: AppTypography.tabularNumbersLarge.copyWith(
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              if (unitLabel != null)
                Text(
                  unitLabel!,
                  style: AppTypography.caption.copyWith(fontSize: 10),
                ),
            ],
          ),
        ),
        _buildButton(
          icon: Icons.add_rounded,
          enabled: canIncrement,
          onTap: _increment,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled ? AppColors.surface : AppColors.almond.withOpacity(0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? AppColors.outlineStrong : AppColors.outline,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.ink : AppColors.inkSoft.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
