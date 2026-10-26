import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/metric_strip.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/entity_card.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/filter_chips_row.dart';
import 'supplier_form_screen.dart';
import '../../purchase_orders/screens/create_po_screen.dart';
import '../../purchase_orders/screens/po_detail_screen.dart';
import '../../purchase_orders/screens/order_tracking_timeline_screen.dart';
import '../../purchase_orders/screens/po_list_screen.dart';

/// Screen 2 & Screen 10 — Supplier Detail & Supplier Purchase History
/// Displays supplier information, contacts, address, metrics, and complete
/// supplier-specific purchase history with search and status filtering.
class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  String _poSearchQuery = '';
  POFilter _poFilter = POFilter.all;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final supplier = service.suppliers.firstWhere(
          (s) => s.id == widget.supplierId,
          orElse: () => const Supplier(
            id: '',
            supplierCode: '',
            name: 'Not found',
            phone: '',
          ),
        );

        final allSupplierPOs = service.purchaseOrders
            .where((po) => po.supplierId == widget.supplierId)
            .toList();

        final totalValue = allSupplierPOs.fold<double>(
          0.0,
          (sum, po) => sum + po.totalAmount,
        );
        final openCount = allSupplierPOs
            .where(
              (po) =>
                  po.status == POStatus.sent ||
                  po.status == POStatus.partiallyReceived,
            )
            .length;
        final outstandingUnits = allSupplierPOs.fold<int>(
          0,
          (sum, po) => sum + po.totalRemainingQuantity,
        );

        // Filtered POs for Purchase History section
        final filteredPOs = allSupplierPOs.where((po) {
          if (_poFilter == POFilter.pending &&
              !(po.status == POStatus.sent ||
                  po.status == POStatus.partiallyReceived)) {
            return false;
          }
          if (_poFilter == POFilter.draft && po.status != POStatus.draft)
            return false;
          if (_poFilter == POFilter.received && po.status != POStatus.received)
            return false;
          if (_poFilter == POFilter.cancelled &&
              po.status != POStatus.cancelled)
            return false;

          if (_poSearchQuery.isEmpty) return true;
          return po.purchaseOrderNumber.toLowerCase().contains(
            _poSearchQuery.toLowerCase(),
          );
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppTopBar(
            title: supplier.name,
            showLanguageToggle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SupplierFormScreen(supplierToEdit: supplier),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: supplier.isActive
              ? Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.outline, width: 1),
                    ),
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(strings.newPurchaseOrder),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreatePOScreen(preselectedSupplier: supplier),
                        ),
                      );
                    },
                  ),
                )
              : null,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER ENTITY BOX
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline, width: 1),
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
                              supplier.supplierCode,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                          StatusChip(
                            status: supplier.isActive
                                ? StatusType.active
                                : StatusType.inactive,
                            customLabel: supplier.isActive
                                ? strings.active
                                : strings.inactive,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        supplier.name,
                        style: AppTypography.title.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            supplier.contactPerson ?? 'No contact person',
                            style: AppTypography.body,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(supplier.phone, style: AppTypography.body),
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                            ),
                            icon: const Icon(Icons.call, size: 16),
                            label: Text(strings.callSupplier),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Dialing ${supplier.phone}…'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. METRIC STRIP (vanilla)
                MetricStrip(
                  items: [
                    MetricItem(
                      label: strings.totalOrderValue,
                      value: '₹${totalValue.toStringAsFixed(0)}',
                    ),
                    MetricItem(label: strings.openOrders, value: '$openCount'),
                    MetricItem(
                      label: strings.outstandingUnits,
                      value: '$outstandingUnits',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. DETAILS LIST
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'GSTIN',
                        supplier.gstNumber ?? 'Not registered',
                      ),
                      const Divider(height: 14),
                      _buildDetailRow(
                        'Payment Terms',
                        supplier.paymentTerms ?? 'Net 30',
                      ),
                      const Divider(height: 14),
                      _buildDetailRow(
                        'Email',
                        supplier.email ?? 'Not provided',
                      ),
                      const Divider(height: 14),
                      _buildDetailRow('City', supplier.city ?? 'Not specified'),
                      const Divider(height: 14),
                      _buildDetailRow(
                        'Address',
                        supplier.address ?? 'Not provided',
                      ),
                      if (supplier.notes != null &&
                          supplier.notes!.isNotEmpty) ...[
                        const Divider(height: 14),
                        _buildDetailRow('Notes', supplier.notes!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. SCREEN 10: SUPPLIER PURCHASE HISTORY
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${strings.purchaseHistory} (${allSupplierPOs.length})',
                      style: AppTypography.section,
                    ),
                    if (allSupplierPOs.isNotEmpty)
                      Text(
                        '${strings.outstandingUnits}: $outstandingUnits',
                        style: AppTypography.caption,
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (allSupplierPOs.isNotEmpty) ...[
                  // In-supplier search bar
                  SearchField(
                    hintText: 'Search within supplier orders…',
                    onChanged: (q) => setState(() => _poSearchQuery = q),
                  ),
                  const SizedBox(height: 10),
                  // In-supplier status filter chips
                  FilterChipsRow<POFilter>(
                    items: POFilter.values,
                    selectedItem: _poFilter,
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
                    onSelected: (filter) => setState(() => _poFilter = filter),
                  ),
                  const SizedBox(height: 12),
                ],

                if (allSupplierPOs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outline, width: 1),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 36,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No purchase orders yet for this supplier',
                            style: AppTypography.bodyStrong,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create a draft PO to begin procuring medicines.',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (filteredPOs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outline, width: 1),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 32,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No matching orders found',
                            style: AppTypography.bodyStrong,
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _poSearchQuery = '';
                                _poFilter = POFilter.all;
                              });
                            },
                            child: Text(strings.clearFilters),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredPOs.map((po) {
                    final isPending =
                        po.status == POStatus.sent ||
                        po.status == POStatus.partiallyReceived;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: EntityCard(
                        title: po.purchaseOrderNumber,
                        leadingIcon: Icons.receipt_outlined,
                        leftAccentColor: isPending ? AppColors.chai : null,
                        subtitle1:
                            '${po.orderDate.day}/${po.orderDate.month}/${po.orderDate.year} • ${po.items.length} items',
                        subtitle2: isPending
                            ? 'Awaiting delivery • Remaining: ${po.totalRemainingQuantity} / ${po.totalOrderedQuantity} units'
                            : (po.status == POStatus.received
                                  ? 'Fully received (${po.totalReceivedQuantity} units)'
                                  : 'Total: ${po.totalOrderedQuantity} units'),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MoneyText(amountInRupees: po.totalAmount),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusChip(status: _mapPOStatus(po.status)),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            OrderTrackingTimelineScreen(
                                              poId: po.id,
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.timeline_rounded,
                                    size: 18,
                                    color: AppColors.matchaDeep,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PODetailScreen(poId: po.id),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: AppTypography.label)),
        Expanded(child: Text(value, style: AppTypography.bodyStrong)),
      ],
    );
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
