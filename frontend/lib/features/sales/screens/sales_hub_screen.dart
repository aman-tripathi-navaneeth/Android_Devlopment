import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/status_chip.dart';
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
    _ocrAdapter.syncReportsFromBackend();
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
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Rule G4 Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.chai.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.chai.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: AppColors.carob, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rule G4: Scanning proposes, staff verifies. Stock deducts only upon explicit confirmation.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.carob,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Top Metric Cards Row
            Row(
              children: [
                _buildMetricCard(
                  title: '$postedCount',
                  subtitle: 'Posted',
                  icon: Icons.check_circle_outline_rounded,
                  accentColor: AppColors.matchaDeep,
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  title: '${history.length - postedCount}',
                  subtitle: 'Pending',
                  icon: Icons.schedule_rounded,
                  accentColor: AppColors.carob,
                ),
                const SizedBox(width: 8),
                _buildMetricCard(
                  title: '$totalUnitsDeducted',
                  subtitle: 'Units Sold',
                  icon: Icons.medication_outlined,
                  accentColor: AppColors.matchaDeep,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar & Scan Button
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search report reference, authorizer...',
                        hintStyle: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.inkSoft),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.matchaDeep,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: const Size(0, 42),
                  ),
                  icon: const Icon(Icons.document_scanner_rounded, size: 16),
                  label: const Text(
                    '+ Scan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'All (${history.length})',
                    _statusFilter == null,
                    () => setState(() => _statusFilter = null),
                  ),
                  _buildFilterChip(
                    'Posted ($postedCount)',
                    _statusFilter == SalesReportStatus.posted,
                    () => setState(() => _statusFilter = SalesReportStatus.posted),
                  ),
                  _buildFilterChip(
                    'Pending Review',
                    _statusFilter == SalesReportStatus.pendingReview,
                    () => setState(() => _statusFilter = SalesReportStatus.pendingReview),
                  ),
                  _buildFilterChip(
                    'Drafts',
                    _statusFilter == SalesReportStatus.draft,
                    () => setState(() => _statusFilter = SalesReportStatus.draft),
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
                        style: const TextStyle(fontSize: 11, color: AppColors.matchaDeep),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // History List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _ocrAdapter.syncReportsFromBackend(),
                child: filtered.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 60),
                          Center(
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
                                  'Pull down to refresh or register a new counter sale.',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final report = filtered[index];
                          return _buildReportHistoryCard(report);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.tabularNumbers.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.carob,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
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
        selectedColor: AppColors.matcha.withOpacity(0.35),
        checkmarkColor: AppColors.matchaDeep,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.matchaDeep : AppColors.inkSoft,
        ),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
    final dateStr =
        '${report.reportDate.day.toString().padLeft(2, '0')}/${report.reportDate.month.toString().padLeft(2, '0')}/${report.reportDate.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (isPosted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SalesReportDetailScreen(report: report),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SalesReportScanScreen(initialDraft: report),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Type Pill + Reference + Date + Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: report.isCounterSale
                          ? AppColors.matchaDeep.withOpacity(0.12)
                          : AppColors.chai.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      report.isCounterSale ? 'Counter Sale' : 'Register Scan',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: report.isCounterSale ? AppColors.matchaDeep : AppColors.carob,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.reportReference,
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.carob,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                  const SizedBox(width: 6),
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

              // Middle Row: Line summary & Operator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${report.lines.length} items • $units units deducted',
                      style: AppTypography.bodyStrong.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'By: ${report.authorizer}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkSoft,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Only show manual match warning if the report is actually UNRESOLVED and NOT posted
              if (report.unresolvedLinesCount > 0 && !isPosted) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.outline),
              const SizedBox(height: 8),

              // Bottom Row: Txn Reference & View Details action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isPosted ? Icons.check_circle_rounded : Icons.pending_outlined,
                          size: 13,
                          color: isPosted ? AppColors.matchaDeep : AppColors.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isPosted
                                ? (report.transactionReference != null
                                    ? 'Txn: ${report.transactionReference}'
                                    : 'Stock Deducted • Posted')
                                : 'Draft (No stock deducted yet)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isPosted ? FontWeight.w700 : FontWeight.w500,
                              color: isPosted ? AppColors.matchaDeep : AppColors.inkSoft,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPosted ? 'View Details' : 'Resume Review',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.matchaDeep,
                          fontSize: 11,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
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
