import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/bottom_nav_bar.dart';
import '../../../core/ui/scan_selection_sheet.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../catalogue/screens/medicine_list_screen.dart';
import '../../transactions/screens/transactions_hub_screen.dart';
import '../../more/screens/more_menu_screen.dart';

/// Main navigation shell preserving tab states per Section 4.1.
/// 5 navigation destinations with central prominent Scan action.
class MainShellScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MainShellScreen({super.key, required this.onLogout});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _openScanSheet() {
    ScanSelectionSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    final titles = [
      strings.navHome,
      strings.medicineCatalogue,
      strings.navTransactions,
      strings.navMore,
    ];

    return AppScaffold(
      appBar: AppTopBar(
        title: titles[_currentIndex],
        subtitle: 'Sri Balaji Medical Store',
        showLanguageToggle: true,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _navigateToTab,
        onScanTap: _openScanSheet,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            onNavigateToPurchasing: () => _navigateToTab(2),
            onNavigateToMedicines: () => _navigateToTab(1),
          ),
          const MedicineListScreen(),
          const TransactionsHubScreen(),
          MoreMenuScreen(onLogout: widget.onLogout),
        ],
      ),
    );
  }
}
