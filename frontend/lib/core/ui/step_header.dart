import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// StepHeader: multi-step progress indicator for flows like Purchase Invoice & Sales OCR.
/// Compact, responsive, and tap-interactive matching the interactive web preview.
class StepHeader extends StatelessWidget {
  final int currentStep; // 0-indexed
  final List<String> steps;
  final ValueChanged<int>? onStepTap;

  const StepHeader({
    super.key,
    required this.currentStep,
    required this.steps,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = steps.length >= 4;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 16,
          vertical: isCompact ? 8 : 12,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8),
                  child: Text(
                    '›',
                    style: TextStyle(
                      fontSize: isCompact ? 12 : 14,
                      color: i <= currentStep
                          ? AppColors.matchaDeep
                          : AppColors.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              InkWell(
                onTap: onStepTap != null ? () => onStepTap!(i) : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 4 : 8,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isCompact ? 20 : 24,
                        height: isCompact ? 20 : 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i < currentStep
                              ? AppColors.matchaDeep
                              : (i == currentStep
                                    ? AppColors.matcha
                                    : AppColors.almond),
                          shape: BoxShape.circle,
                        ),
                        child: i < currentStep
                            ? Icon(
                                Icons.check,
                                size: isCompact ? 12 : 14,
                                color: Colors.white,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: isCompact ? 10.5 : 12,
                                  fontWeight: FontWeight.w700,
                                  color: i == currentStep
                                      ? AppColors.onMatcha
                                      : AppColors.inkSoft,
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: isCompact ? 11 : 12.5,
                          fontWeight: i == currentStep
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: i == currentStep
                              ? AppColors.ink
                              : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
