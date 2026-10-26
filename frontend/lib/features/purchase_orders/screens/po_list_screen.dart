import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/entity_card.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/filter_chips_row.dart';
import '../../../core/ui/empty_state.dart';
import 'create_po_screen.dart';
import 'po_detail_screen.dart';

enum POFilter { all, pending, draft, received, cancelled }

enum POSort { dateDesc, dateAsc, amountDesc, amountAsc }

/// S4: PURCHASE ORDER LIST SCREEN (Purchasing > Orders) - Section 10.4.3
class POListScreen extends StatefulWidget {
  const POListScreen({super.key});

  @override
  State<POListScreen> createState() => _POListScreenState();
}

class _POListScreenState extends State<POListScreen> {
  String _searchQuery = '';
  POFilter _currentFilter = POFilter.all;
  POSort _currentSort = POSort.dateDesc;

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _currentFilter = POFilter.all;
      _currentSort = POSort.dateDesc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final pos = service.purchaseOrders.where((po) {
          // Status filter
          if (_currentFilter == POFilter.pending &&
              !(po.status == POStatus.sent ||
                  po.status == POStatus.partiallyReceived)) {
            return false;
          }
          if (_currentFilter == POFilter.draft && po.status != POStatus.draft)
            return false;
          if (_currentFilter == POFilter.received &&
              po.status != POStatus.received)
            return false;
          if (_currentFilter == POFilter.cancelled &&
              po.status != POStatus.cancelled)
            return false;

          // Search query
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return po.purchaseOrderNumber.toLowerCase().contains(q) ||
              po.supplierName.toLowerCase().contains(q);
        }).toList();

        // Apply sorting
        pos.sort((a, b) {
          switch (_currentSort) {
            case POSort.dateDesc:
              return b.orderDate.compareTo(a.orderDate);
            case POSort.dateAsc:
              return a.orderDate.compareTo(b.orderDate);
            case POSort.amountDesc:
              return b.totalAmount.compareTo(a.totalAmount);
            case POSort.amountAsc:
              return a.totalAmount.compareTo(b.totalAmount);
          }
        });

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchField(
                      hintText: 'Search by PO number or supplier…',
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                    const SizedBox(height: 12),
                    if (isNarrow) ...[
                      // 1. Status Filter Chips (Full width with smooth horizontal scrolling)
                      FilterChipsRow<POFilter>(
                        items: POFilter.values,
                        selectedItem: _currentFilter,
                        labelBuilder: (f) {
                          switch (f) {
                            case POFilter.all:
                              return strings.all;
                            case POFilter.pending:
                              return 'Pending';
                            case POFilter.draft:
                              return strings.statusDraft;
                            case POFilter.received:
                              return strings.statusReceived;
                            case POFilter.cancelled:
                              return strings.statusCancelled;
                          }
                        },
                        onSelected: (filter) =>
                            setState(() => _currentFilter = filter),
                      ),
                      const SizedBox(height: 10),

                      // 2. New Purchase Order action on its own full-width row
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.matchaDeep,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            strings.newPurchaseOrder,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreatePOScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      // Larger screens: side-by-side filters and create action
                      Row(
                        children: [
                          Expanded(
                            child: FilterChipsRow<POFilter>(
                              items: POFilter.values,
                              selectedItem: _currentFilter,
                              labelBuilder: (f) {
                                switch (f) {
                                  case POFilter.all:
                                    return strings.all;
                                  case POFilter.pending:
                                    return 'Pending';
                                  case POFilter.draft:
                                    return strings.statusDraft;
                                  case POFilter.received:
                                    return strings.statusReceived;
                                  case POFilter.cancelled:
                                    return strings.statusCancelled;
                                }
                              },
                              onSelected: (filter) =>
                                  setState(() => _currentFilter = filter),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.matchaDeep,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              strings.newPurchaseOrder,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CreatePOScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Sort & Active filters bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PopupMenuButton<POSort>(
                          initialValue: _currentSort,
                          onSelected: (sort) =>
                              setState(() => _currentSort = sort),
                          color: AppColors.surface,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.outline,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sort_rounded,
                                  size: 16,
                                  color: AppColors.matchaDeep,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getSortLabel(_currentSort),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: AppColors.inkSoft,
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: POSort.dateDesc,
                              child: Text('Date: Newest first'),
                            ),
                            const PopupMenuItem(
                              value: POSort.dateAsc,
                              child: Text('Date: Oldest first'),
                            ),
                            const PopupMenuItem(
                              value: POSort.amountDesc,
                              child: Text('Amount: High to Low'),
                            ),
                            const PopupMenuItem(
                              value: POSort.amountAsc,
                              child: Text('Amount: Low to High'),
                            ),
                          ],
                        ),
                        if (_currentFilter != POFilter.all ||
                            _searchQuery.isNotEmpty)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.filter_alt_off_outlined,
                              size: 14,
                              color: AppColors.inkSoft,
                            ),
                            label: Text(
                              strings.clearFilters,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.matchaDeep,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _clearFilters,
                          )
                        else
                          Text(
                            '${pos.length} orders',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: pos.isEmpty
                          ? EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title:
                                  (_searchQuery.isNotEmpty ||
                                      _currentFilter != POFilter.all)
                                  ? 'No matching orders found'
                                  : 'No purchase orders found',
                              subtitle:
                                  (_searchQuery.isNotEmpty ||
                                      _currentFilter != POFilter.all)
                                  ? 'Try adjusting your search query or status filter.'
                                  : null,
                              actionLabel:
                                  (_searchQuery.isNotEmpty ||
                                      _currentFilter != POFilter.all)
                                  ? strings.clearFilters
                                  : strings.newPurchaseOrder,
                              onAction: () {
                                if (_searchQuery.isNotEmpty ||
                                    _currentFilter != POFilter.all) {
                                  _clearFilters();
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CreatePOScreen(),
                                    ),
                                  );
                                }
                              },
                            )
                          : ListView.separated(
                              itemCount: pos.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final po = pos[index];
                                final isPending =
                                    po.status == POStatus.sent ||
                                    po.status == POStatus.partiallyReceived;

                                return EntityCard(
                                  title: po.purchaseOrderNumber,
                                  leadingIcon: Icons.receipt_outlined,
                                  leftAccentColor: isPending
                                      ? AppColors.chai
                                      : null,
                                  subtitle1: po.supplierName,
                                  subtitle2: isPending
                                      ? 'Awaiting delivery • Outstanding: ${po.totalRemainingQuantity} units'
                                      : '${po.orderDate.day}/${po.orderDate.month}/${po.orderDate.year} • ${po.items.length} lines',
                                  trailing: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 130,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        MoneyText(
                                          amountInRupees: po.totalAmount,
                                        ),
                                        const SizedBox(height: 4),
                                        StatusChip(
                                          status: _mapPOStatus(po.status),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PODetailScreen(poId: po.id),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getSortLabel(POSort sort) {
    switch (sort) {
      case POSort.dateDesc:
        return 'Date: Newest';
      case POSort.dateAsc:
        return 'Date: Oldest';
      case POSort.amountDesc:
        return 'Amount: High → Low';
      case POSort.amountAsc:
        return 'Amount: Low → High';
    }
  }

  StatusType _mapPOStatus(POStatus status) {
    switch (status) {
      case POStatus.draft:
        return StatusType.draft;
      case POStatus.sent:
        return StatusType.sent;
      case POStatus.partiallyReceived:
        return StatusType.partiallyReceived;
      case POStatus.received:
        return StatusType.received;
      case POStatus.cancelled:
        return StatusType.cancelled;
    }
  }
}
