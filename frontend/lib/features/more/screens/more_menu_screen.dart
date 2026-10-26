import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/ui/confirm_sheet.dart';
import '../../inventory/screens/stock_ledger_screen.dart';
import '../../inventory/screens/alerts_and_reconciliation_screen.dart';
import '../../customers/screens/customer_list_screen.dart';
import '../../customers/screens/udhaar_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../auth/screens/shop_setup_screen.dart';

/// Tab 5: MORE MENU SCREEN - Section 7.1
class MoreMenuScreen extends StatelessWidget {
  final VoidCallback onLogout;

  const MoreMenuScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final langController = LanguageController();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User / Store profile badge
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ShopSetupScreen(
                      onSaved: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.matcha.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.matchaDeep,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aditya Pakki (Owner)',
                            style: AppTypography.bodyStrong,
                          ),
                          Text(
                            'Sri Balaji Medicals • Tap to edit profile',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.inkSoft,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // INVENTORY & LEDGER
            Text('Inventory Operations', style: AppTypography.section),
            const SizedBox(height: 8),
            _buildMenuGroup([
              _MenuItem(
                icon: Icons.inventory_rounded,
                title: strings.stockLedger,
                subtitle: 'Append-only movements & batch breakdown',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StockLedgerScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.checklist_rounded,
                title: strings.reconciliation,
                subtitle: 'Count sessions & owner approval workflow',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AlertsAndReconciliationScreen(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 18),

            // CUSTOMERS & FINANCE
            Text('Customers & Udhaar', style: AppTypography.section),
            const SizedBox(height: 8),
            _buildMenuGroup([
              _MenuItem(
                icon: Icons.people_outline_rounded,
                title: strings.customers,
                subtitle: 'Prescriptions & refill tracking',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustomerListScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.account_balance_wallet_outlined,
                title: strings.udhaarCredit,
                subtitle: 'Derived customer balances & payment entries',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UdhaarScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 18),

            // REPORTS & ALERTS
            Text('Reports & Notifications', style: AppTypography.section),
            const SizedBox(height: 8),
            _buildMenuGroup([
              _MenuItem(
                icon: Icons.summarize_outlined,
                title: strings.reports,
                subtitle: 'Purchase, Sales & Stock ledger summaries',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.notifications_none_rounded,
                title: strings.notifications,
                subtitle: 'Low stock, expiry & delivery reminders',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen(),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 18),

            // SYSTEM & PREFERENCES
            Text(strings.settings, style: AppTypography.section),
            const SizedBox(height: 8),
            _buildMenuGroup([
              _MenuItem(
                icon: Icons.language_rounded,
                title: strings.languageSettings,
                subtitle: langController.isTelugu
                    ? 'ప్రస్తుత భాష: తెలుగు (Telugu)'
                    : 'Active: English (ఆంగ్లం)',
                onTap: () {
                  langController.toggleLanguage();
                },
              ),
              _MenuItem(
                icon: Icons.logout_rounded,
                title: strings.logout,
                subtitle: 'Sign out of store session',
                isDestructive: true,
                onTap: () async {
                  final confirmed = await ConfirmSheet.show(
                    context,
                    title: strings.logout,
                    message: 'Are you sure you want to sign out of the app?',
                    confirmLabel: strings.logout,
                    cancelLabel: strings.cancel,
                    isDestructive: true,
                  );
                  if (confirmed == true) {
                    onLogout();
                  }
                },
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGroup(List<_MenuItem> items) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.outline, width: 1),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (index > 0) const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                leading: Icon(
                  item.icon,
                  color: item.isDestructive
                      ? AppColors.dangerFg
                      : AppColors.matchaDeep,
                  size: 22,
                ),
                title: Text(
                  item.title,
                  style: AppTypography.bodyStrong.copyWith(
                    color: item.isDestructive
                        ? AppColors.dangerFg
                        : AppColors.ink,
                  ),
                ),
                subtitle: Text(item.subtitle, style: AppTypography.caption),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.inkSoft,
                ),
                onTap: item.onTap,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });
}
