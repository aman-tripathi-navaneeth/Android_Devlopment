import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/ui/metric_strip.dart';
import '../../catalogue/screens/add_edit_medicine_screen.dart';
import '../../purchase_orders/screens/create_po_screen.dart';

/// Dashboard backed by the application repository with no seeded business records.
class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToPurchasing;
  final VoidCallback onNavigateToMedicines;

  const DashboardScreen({
    super.key,
    required this.onNavigateToPurchasing,
    required this.onNavigateToMedicines,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final service = MockDataService();
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final lowStock = service.medicines.where((m) => m.isLowStock).length;
        final openOrders = service.purchaseOrders
            .where((po) => po.status.name == 'sent' || po.status.name == 'partiallyReceived')
            .length;
        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shopHeader(),
                const SizedBox(height: 14),
                MetricStrip(items: [
                  MetricItem(label: strings.lowStockCount, value: '$lowStock'),
                  const MetricItem(label: 'Near Expiry', value: '0'),
                  MetricItem(label: strings.openOrdersCount, value: '$openOrders'),
                  const MetricItem(label: 'Pending Reviews', value: '0'),
                ]),
                const SizedBox(height: 18),
                Text(strings.quickActions, style: AppTypography.section),
                const SizedBox(height: 10),
                Row(children: [
                  _quickAction(Icons.add_shopping_cart_rounded, strings.newPoAction,
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePOScreen()))),
                  const SizedBox(width: 8),
                  _quickAction(Icons.medication_rounded, strings.addMedicineAction,
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddEditMedicineScreen()))),
                ]),
                const SizedBox(height: 22),
                Text(strings.needsAttention, style: AppTypography.section),
                const SizedBox(height: 10),
                const Text('No pending actions.'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shopHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outline),
        ),
        child: const Row(children: [
          Icon(Icons.local_pharmacy_rounded, color: AppColors.matchaDeep, size: 38),
          SizedBox(width: 12),
          Expanded(child: Text('Sri Balaji Medical Store')),
        ]),
      );

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(children: [
                Icon(icon, color: AppColors.matchaDeep),
                const SizedBox(height: 6),
                Text(label, style: AppTypography.bodyStrong),
              ]),
            ),
          ),
        ),
      );
}
