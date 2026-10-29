import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../localization/app_localizations.dart';
import '../../features/camera/screens/camera_capture_screen.dart';
import '../../features/manual_transaction/screens/manual_transaction_screen.dart';

/// Modal bottom sheet for choosing between Purchase Invoice (Stock In)
/// and Sales Report (Stock Out) per Section 4.3.
class ScanSelectionSheet extends StatelessWidget {
  const ScanSelectionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: const ScanSelectionSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Sheet title & subtitle per Section 4.3
              Text(
                strings.whatWouldYouLikeToScan,
                style: AppTypography.screenTitle,
              ),
              const SizedBox(height: 4),
              Text(
                strings.chooseDocumentType,
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 20),

              // Card 1: Purchase Invoice (Stock In)
              _buildScanOptionCard(
                context: context,
                title: strings.purchaseInvoice,
                subtitle: strings.addReceivedStockFromSupplier,
                badgeLabel: strings.stockIn,
                badgeBg: AppColors.matcha.withValues(alpha: 0.25),
                badgeFg: AppColors.matchaDeep,
                icon: Icons.receipt_long_rounded,
                iconBg: AppColors.matcha.withValues(alpha: 0.2),
                iconFg: AppColors.matchaDeep,
                borderColor: AppColors.matcha,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CameraCaptureScreen(
                        scanType: DocumentScanType.invoice,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Card 2: Sales Report / Bill Scan (Stock Out)
              _buildScanOptionCard(
                context: context,
                title: strings.salesReport,
                subtitle: strings.recordSoldMedicines,
                badgeLabel: strings.stockOut,
                badgeBg: AppColors.chai.withValues(alpha: 0.35),
                badgeFg: AppColors.carob,
                icon: Icons.point_of_sale_rounded,
                iconBg: AppColors.chai.withValues(alpha: 0.25),
                iconFg: AppColors.carob,
                borderColor: AppColors.chai,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CameraCaptureScreen(
                        scanType: DocumentScanType.salesReport,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Card 3: Manual Transaction (Stock Out)
              _buildScanOptionCard(
                context: context,
                title: strings.manualTransaction,
                subtitle: strings.manualTransactionSubtitle,
                badgeLabel: strings.stockOut,
                badgeBg: AppColors.pistache.withValues(alpha: 0.35),
                badgeFg: AppColors.matchaDeep,
                icon: Icons.edit_note_rounded,
                iconBg: AppColors.pistache.withValues(alpha: 0.28),
                iconFg: AppColors.matchaDeep,
                borderColor: AppColors.pistache,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManualTransactionScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badgeLabel,
    required Color badgeBg,
    required Color badgeFg,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.vanilla.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor.withValues(alpha: 0.7), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconFg, size: 26),
              ),
              const SizedBox(width: 14),

              // Title, Subtitle & Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: AppTypography.bodyStrong.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        // Supporting Badge (Stock In / Stock Out)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: badgeFg.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
