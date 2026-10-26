import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/inline_banner.dart';
import '../models/sales_report.dart';
import '../services/mock_sales_ocr_adapter.dart';
import 'sales_report_scan_screen.dart';
import 'sales_report_detail_screen.dart';

/// Screen 5: SALES HUB & REPORT HISTORY SCREEN per Section 9.
/// Displays previously imported reports with search, status filtering,
/// duplicate awareness, resume review action, and tap-to-view detail.
class SalesHubScreen extends StatefulWidget {
  const SalesHubScreen({super.key});

  @override
  State<SalesHubScreen> createState() => _SalesHubScreenState();
}

class _SalesHubScreenState extends State<SalesHubScreen> {
  final MockSalesOcrAdapter _ocrAdapter = MockSalesOcrAdapter();
  String _searchQuery = '';
  SalesReportStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _ocrAdapter.addListener(_onAdapterUpdated);
  }

  @override
  void dispose() {
    _ocrAdapter.removeListener(_onAdapterUpdated);
    super.dispose();
  }

  void _onAdapterUpdated() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final history = _ocrAdapter.history;

    // Filter list
    final filtered = history.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchRef = r.reportReference.toLowerCase().contains(q);
        final matchAuth = r.authorizer.toLowerCase().contains(q);
        final matchFile = r.selectedFileName.toLowerCase().contains(q);
        if (!matchRef && !matchAuth && !matchFile) return false;
      }
      return true;
    }).toList();

    final postedCount = history
        .where((r) => r.status == SalesReportStatus.posted)
        .length;
    final totalUnitsDeducted = history
        .where((r) => r.status == SalesReportStatus.posted)
        .fold<int>(0, (sum, r) => sum + r.totalLooseUnitsDeducted);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Golden Rule G4 Banner
            InlineBanner(
              type: BannerType.warning,
              text: 'MANDATORY RULE G4: Scanning proposes. Staff verifies. Stock decreases ONLY after explicit staff review & confirmation.',
            ),
            const SizedBox(height: 12),

            // Top Metric Strip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.vanilla,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  _buildMetricItem('$postedCount', 'Posted Reports'),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.carob.withOpacity(0.2),
                  ),
                  _buildMetricItem(
                    '${history.length - postedCount}',
                    'Drafts / Pending',
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.carob.withOpacity(0.2),
                  ),
                  _buildMetricItem('$totalUnitsDeducted', 'Units Deducted'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar & Scan Action Button
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search report reference, authorizer...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.matchaDeep,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                  icon: const Icon(Icons.document_scanner_rounded, size: 18),
                  label: const Text(
                    '+ Scan Report',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SalesReportScanScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'All (${history.length})',
                    _statusFilter == null,
                    () {
                      setState(() => _statusFilter = null);
                    },
                  ),
                  _buildFilterChip(
                    'Posted ($postedCount)',
                    _statusFilter == SalesReportStatus.posted,
                    () {
                      setState(() => _statusFilter = SalesReportStatus.posted);
                    },
                  ),
                  _buildFilterChip(
                    'Pending Review',
                    _statusFilter == SalesReportStatus.pendingReview,
                    () {
                      setState(
                        () => _statusFilter = SalesReportStatus.pendingReview,
                      );
                    },
                  ),
                  _buildFilterChip(
                    'Drafts',
                    _statusFilter == SalesReportStatus.draft,
                    () {
                      setState(() => _statusFilter = SalesReportStatus.draft);
                    },
                  ),
                  if (_statusFilter != null || _searchQuery.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _statusFilter = null;
                          _searchQuery = '';
                        });
                      },
                      child: Text(
                        strings.clearFilters,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // History List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No sales reports match your search or filters.',
                            style: AppTypography.bodyStrong,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Import an end-of-day sales register using the button above.',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) {
                        final report = filtered[index];
                        return _buildReportHistoryCard(report);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String val, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: AppTypography.tabularNumbers.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.carob,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.matcha,
        checkmarkColor: AppColors.ink,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.ink : AppColors.inkSoft,
        ),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? AppColors.matchaDeep : AppColors.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildReportHistoryCard(SalesReport report) {
    final bool isPosted = report.status == SalesReportStatus.posted;
    final int units = report.totalLooseUnitsDeducted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isPosted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SalesReportDetailScreen(report: report),
              ),
            );
          } else {
            // Resume review
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SalesReportScanScreen(initialDraft: report),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.almond,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          report.reportReference,
                          style: AppTypography.bodyStrong.copyWith(
                            color: AppColors.carob,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${report.reportDate.day}/${report.reportDate.month}/${report.reportDate.year}',
                        style: AppTypography.caption,
                      ),
                    ],
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
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${report.lines.length} lines • $units loose units deducted',
                    style: AppTypography.bodyStrong.copyWith(fontSize: 13),
                  ),
                  Text(
                    'By: ${report.authorizer}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),

              if (report.unresolvedLinesCount > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${report.unresolvedLinesCount} item(s) require manual match',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.dangerFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],

              const Divider(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    report.transactionReference ??
                        'Draft (No stock deducted yet)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isPosted ? FontWeight.w700 : FontWeight.w500,
                      color: isPosted
                          ? AppColors.matchaDeep
                          : AppColors.inkSoft,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        isPosted ? 'View Details' : 'Resume Review',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.matchaDeep,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.matchaDeep,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
