import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/localization/app_localizations.dart';
import '../../purchase_orders/screens/po_list_screen.dart';
import '../../suppliers/screens/supplier_list_screen.dart';
import '../../invoices/screens/invoice_scan_screen.dart';
import '../../sales/screens/sales_hub_screen.dart';

/// TransactionsHubScreen per Section 4.2:
/// Combines Purchasing and Sales into a single Transactions destination
/// with 4 clear sub-sections/tabs:
/// 1. Orders (POListScreen)
/// 2. Suppliers (SupplierListScreen)
/// 3. Inward Bills (InvoiceScanScreen history)
/// 4. Sales Reports (SalesHubScreen history)
class TransactionsHubScreen extends StatefulWidget {
  final int initialTabIndex;

  const TransactionsHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<TransactionsHubScreen> createState() => _TransactionsHubScreenState();
}

class _TransactionsHubScreenState extends State<TransactionsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: AppColors.surface,
          child: SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.matchaDeep,
              unselectedLabelColor: AppColors.inkSoft,
              labelStyle: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: AppTypography.caption,
              indicatorColor: AppColors.matchaDeep,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppColors.outline,
              tabs: [
                Tab(
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  text: strings.orders,
                ),
                Tab(
                  icon: const Icon(Icons.people_alt_outlined, size: 18),
                  text: strings.suppliers,
                ),
                Tab(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  text: strings.inwardBills,
                ),
                Tab(
                  icon: const Icon(Icons.point_of_sale_outlined, size: 18),
                  text: strings.salesReports,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          POListScreen(),
          SupplierListScreen(),
          InvoiceScanScreen(),
          SalesHubScreen(),
        ],
      ),
    );
  }
}
