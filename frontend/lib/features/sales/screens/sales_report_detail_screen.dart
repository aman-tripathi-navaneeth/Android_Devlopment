import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/inline_banner.dart';
import '../models/sales_report.dart';
import '../widgets/sales_stock_deduction_summary_card.dart';

/// Screen 6 — Sales Report Detail Screen per Section 10.
/// Displays full read-only audit information, matched medicines, Product IDs,
/// quantities, units, batch allocations, and resulting stock movement transaction references.
class SalesReportDetailScreen extends StatelessWidget {
  final SalesReport report;

  const SalesReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isPosted = report.status == SalesReportStatus.posted;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: 'Report Detail: ${report.reportReference}',
        showLanguageToggle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Identity Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.almond,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          report.reportReference,
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.carob,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      StatusChip(
                        status: isPosted
                            ? StatusType.posted
                            : (report.status == SalesReportStatus.rejected
                                  ? StatusType.inactive
                                  : StatusType.pending),
                        customLabel: report.status.label,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Imported: ${_formatDate(report.importTimestamp)}',
                    style: AppTypography.caption,
                  ),
                  Text(
                    'Report Source File: ${report.selectedFileName} (${report.selectedFileSize})',
                    style: AppTypography.caption,
                  ),
                  Text(
                    'Authorized Pharmacist: ${report.authorizer}',
                    style: AppTypography.caption,
                  ),
                  if (report.transactionReference != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ledger Transaction Ref: ${report.transactionReference}',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.matchaDeep,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Read-only indicator banner
            if (isPosted)
              InlineBanner(
                type: BannerType.info,
                text: 'READ-ONLY AUDIT RECORD: This sales report was confirmed and posted to the inventory ledger. Stock deductions are final and immutable.',
              )
            else if (report.status == SalesReportStatus.failed)
              InlineBanner(
                type: BannerType.error,
                text: 'POSTING FAILED: Stock deduction could not be completed. No inventory ledgers were altered.',
              )
            else
              InlineBanner(
                type: BannerType.warning,
                text: 'DRAFT / PENDING REVIEW: This report has not been posted. Stock ledger remains unaffected.',
              ),
            const SizedBox(height: 16),

            // Proposed or Executed Stock Deduction Summary Card
            SalesStockDeductionSummaryCard(
              report: report,
              isConfirmedPosted: isPosted,
            ),
            const SizedBox(height: 18),

            // Detailed Line Items List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report Line Items (${report.lines.length}):',
                  style: AppTypography.section,
                ),
                Text(
                  '${report.totalLooseUnitsDeducted} total units',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...report.lines.map(
              (line) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (line.matchedProductId.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.almond,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  line.matchedProductId,
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    color: AppColors.carob,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              line.matchedProductName.isEmpty
                                  ? 'Unmatched'
                                  : line.matchedProductName,
                              style: AppTypography.bodyStrong.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '-${line.calculatedLooseUnits} loose units',
                          style: AppTypography.tabularNumbers.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.dangerFg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Raw OCR: "${line.originalOcrText}"',
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reported: ${line.quantity} ${line.unit} • ${line.batchAllocationRule}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Confidence: ${(line.confidenceScore * 100).toInt()}%',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_getMonthName(dt.month)} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
