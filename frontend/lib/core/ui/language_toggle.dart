import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../localization/language_controller.dart';

/// Segmented language toggle: "English | తెలుగు"
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LanguageController();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isTe = controller.isTelugu;
        return Container(
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.almond,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.outline, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegment(
                label: 'English',
                isSelected: !isTe,
                onTap: () => controller.setLocale(const Locale('en')),
              ),
              _buildSegment(
                label: 'తెలుగు',
                isSelected: isTe,
                onTap: () => controller.setLocale(const Locale('te')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegment({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.matchaDeep : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
