import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../localization/app_localizations.dart';

/// BottomNavBar: 5 destinations per Section 4.1:
/// 1. Home
/// 2. Medicines
/// 3. Scan — central, visually prominent matcha-green action
/// 4. Transactions (Orders, Suppliers, Inward Bills, Sales Reports)
/// 5. More
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScanTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // 1. Home (index 0)
              _buildStandardItem(
                index: 0,
                selectedIcon: Icons.home_rounded,
                unselectedIcon: Icons.home_outlined,
                label: strings.navHome,
                isSelected: currentIndex == 0,
              ),

              // 2. Medicines (index 1)
              _buildStandardItem(
                index: 1,
                selectedIcon: Icons.medication_rounded,
                unselectedIcon: Icons.medication_outlined,
                label: strings.navMedicines,
                isSelected: currentIndex == 1,
              ),

              // 3. Central Prominent Scan Action (Section 4.1 & 4.3)
              Expanded(
                child: InkWell(
                  onTap: onScanTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.matchaDeep,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.matchaDeep.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        strings.navScan,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.matchaDeep,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Transactions (index 2)
              _buildStandardItem(
                index: 2,
                selectedIcon: Icons.swap_horiz_rounded,
                unselectedIcon: Icons.swap_horiz_outlined,
                label: strings.navTransactions,
                isSelected: currentIndex == 2,
              ),

              // 5. More (index 3)
              _buildStandardItem(
                index: 3,
                selectedIcon: Icons.menu_rounded,
                unselectedIcon: Icons.menu_rounded,
                label: strings.navMore,
                isSelected: currentIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardItem({
    required int index,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.matcha.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? selectedIcon : unselectedIcon,
                size: 22,
                color: isSelected ? AppColors.matchaDeep : AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.matchaDeep : AppColors.inkSoft,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
