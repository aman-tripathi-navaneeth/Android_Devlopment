import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/progress_bar_segmented.dart';
import 'goods_receipt_flow_screen.dart';
import 'po_review_screen.dart';

enum MilestoneState { completed, current, pending, cancelled }

class _MilestoneItem {
  final String title;
  final String description;
  final DateTime? timestamp;
  final MilestoneState state;
  final IconData icon;

  const _MilestoneItem({
    required this.title,
    required this.description,
    this.timestamp,
    required this.state,
    required this.icon,
  });
}

/// Screen 7 — Order Tracking Timeline
/// Displays the complete 8-milestone visual tracking timeline for a purchase order.
/// Completely decoupled from backend, using reactive frontend mock state.
class OrderTrackingTimelineScreen extends StatelessWidget {
  final String poId;

  const OrderTrackingTimelineScreen({super.key, required this.poId});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final poIndex = service.purchaseOrders.indexWhere((p) => p.id == poId);
        if (poIndex == -1) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            appBar: AppTopBar(
              title: strings.orderTrackingTimeline,
              showLanguageToggle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: AppColors.inkSoft,
                  ),
                  const SizedBox(height: 12),
                  Text('Purchase Order Not Found', style: AppTypography.title),
                  const SizedBox(height: 6),
                  Text(
                    'Unable to locate order tracking data.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Orders'),
                  ),
                ],
              ),
            ),
          );
        }

        final po = service.purchaseOrders[poIndex];
        final milestones = _buildMilestones(po, strings);

        final canReceive =
            po.status == POStatus.sent ||
            po.status == POStatus.partiallyReceived;
        final isDraft = po.status == POStatus.draft;

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppTopBar(
            title:
                '${strings.orderTrackingTimeline}: ${po.purchaseOrderNumber}',
            showLanguageToggle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          bottomNavigationBar: (canReceive || isDraft)
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
                  child: Row(
                    children: [
                      if (isDraft)
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.fact_check_outlined,
                              size: 18,
                            ),
                            label: Text(strings.reviewOrder),
                            onPressed: () {
                              final supplier = service.suppliers.firstWhere(
                                (s) => s.id == po.supplierId,
                                orElse: () => service.suppliers.first,
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => POReviewScreen(
                                    supplier: supplier,
                                    items: po.items,
                                    orderDate: po.orderDate,
                                    expectedDeliveryDate:
                                        po.expectedDeliveryDate,
                                    notes: po.notes,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      if (canReceive)
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                            ),
                            label: Text(strings.recordGoodsReceipt),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GoodsReceiptFlowScreen(purchaseOrder: po),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                )
              : null,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ORDER SUMMARY CARD
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
                          Text(
                            po.purchaseOrderNumber,
                            style: AppTypography.title.copyWith(fontSize: 18),
                          ),
                          StatusChip(status: _mapPOStatus(po.status)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 16,
                            color: AppColors.matchaDeep,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              po.supplierName,
                              style: AppTypography.bodyStrong.copyWith(
                                color: AppColors.matchaDeep,
                              ),
                            ),
                          ),
                          MoneyText(
                            amountInRupees: po.totalAmount,
                            style: AppTypography.tabularNumbersLarge.copyWith(
                              color: AppColors.matchaDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Created on: ${po.orderDate.day}/${po.orderDate.month}/${po.orderDate.year}',
                        style: AppTypography.caption,
                      ),
                      if (po.expectedDeliveryDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Expected Delivery: ${po.expectedDeliveryDate!.day}/${po.expectedDeliveryDate!.month}/${po.expectedDeliveryDate!.year}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.carob,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Divider(height: 20),
                      ProgressBarSegmented(
                        received: po.totalReceivedQuantity,
                        ordered: po.totalOrderedQuantity,
                        unit: 'units',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. TIMELINE MILESTONES HEADER
                Text(
                  'Order Progression (8 Milestones)',
                  style: AppTypography.section,
                ),
                const SizedBox(height: 4),
                Text(
                  'Track all purchasing and verification stages in sequence.',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 16),

                // 3. VERTICAL TIMELINE
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: milestones.length,
                    separatorBuilder: (context, index) {
                      final isPrevCompleted =
                          milestones[index].state == MilestoneState.completed;
                      return Row(
                        children: [
                          const SizedBox(width: 17),
                          Container(
                            width: 2,
                            height: 28,
                            color: isPrevCompleted
                                ? AppColors.matchaDeep
                                : AppColors.outline,
                          ),
                          const SizedBox(width: 20),
                        ],
                      );
                    },
                    itemBuilder: (context, index) {
                      final m = milestones[index];
                      return _buildMilestoneRow(m, index + 1);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // 4. NOTICE CARD
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.almond.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Timeline statuses are synchronized with verified physical goods receipts.',
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMilestoneRow(_MilestoneItem m, int stepNum) {
    Color iconBg;
    Color iconFg;
    Color borderColor;

    switch (m.state) {
      case MilestoneState.completed:
        iconBg = AppColors.matchaDeep;
        iconFg = Colors.white;
        borderColor = AppColors.matchaDeep;
        break;
      case MilestoneState.current:
        iconBg = AppColors.chai;
        iconFg = AppColors.carob;
        borderColor = AppColors.carob;
        break;
      case MilestoneState.pending:
        iconBg = AppColors.canvas;
        iconFg = AppColors.inkSoft;
        borderColor = AppColors.outline;
        break;
      case MilestoneState.cancelled:
        iconBg = AppColors.dangerFg;
        iconFg = Colors.white;
        borderColor = AppColors.dangerFg;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Milestone indicator node
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
            boxShadow: m.state == MilestoneState.current
                ? [
                    BoxShadow(
                      color: AppColors.chai.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              m.state == MilestoneState.completed
                  ? Icons.check
                  : (m.state == MilestoneState.cancelled
                        ? Icons.close
                        : m.icon),
              size: 18,
              color: iconFg,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Milestone text details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$stepNum. ${m.title}',
                      style: AppTypography.bodyStrong.copyWith(
                        color: m.state == MilestoneState.pending
                            ? AppColors.inkSoft
                            : AppColors.ink,
                        fontWeight: m.state == MilestoneState.current
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (m.timestamp != null)
                    Text(
                      '${m.timestamp!.day}/${m.timestamp!.month} ${m.timestamp!.hour.toString().padLeft(2, '0')}:${m.timestamp!.minute.toString().padLeft(2, '0')}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkSoft,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                m.description,
                style: AppTypography.caption.copyWith(
                  color: m.state == MilestoneState.pending
                      ? AppColors.inkSoft.withOpacity(0.7)
                      : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_MilestoneItem> _buildMilestones(PurchaseOrder po, AppStrings strings) {
    final status = po.status;
    final isCancelled = status == POStatus.cancelled;

    return [
      // 1. Draft Created
      _MilestoneItem(
        title: strings.draftCreatedMilestone,
        description:
            'Purchase order initiated with ${po.items.length} line items.',
        timestamp: po.orderDate,
        state: isCancelled && po.sentAt == null
            ? MilestoneState.cancelled
            : MilestoneState.completed,
        icon: Icons.edit_note,
      ),

      // 2. Order Reviewed
      _MilestoneItem(
        title: strings.orderReviewedMilestone,
        description: 'Quantities, units and purchase rates verified.',
        timestamp: po.orderDate.add(const Duration(minutes: 5)),
        state: isCancelled
            ? MilestoneState.cancelled
            : (status == POStatus.draft
                  ? MilestoneState.current
                  : MilestoneState.completed),
        icon: Icons.fact_check_outlined,
      ),

      // 3. Order Confirmed
      _MilestoneItem(
        title: strings.orderConfirmedMilestone,
        description: 'Draft validated and confirmed for supplier transmission.',
        timestamp: po.orderDate.add(const Duration(minutes: 10)),
        state: isCancelled
            ? MilestoneState.cancelled
            : (status == POStatus.draft
                  ? MilestoneState.pending
                  : MilestoneState.completed),
        icon: Icons.check_circle_outline,
      ),

      // 4. Placed with Supplier
      _MilestoneItem(
        title: strings.orderPlacedMilestone,
        description: po.sentAt != null
            ? 'Order transmitted to ${po.supplierName}.'
            : 'Order will be transmitted upon sending.',
        timestamp: po.sentAt,
        state: isCancelled
            ? MilestoneState.cancelled
            : (status == POStatus.draft
                  ? MilestoneState.pending
                  : MilestoneState.completed),
        icon: Icons.send_rounded,
      ),

      // 5. Delivery in Progress
      _MilestoneItem(
        title: strings.deliveryInProgressMilestone,
        description: po.expectedDeliveryDate != null
            ? 'Supplier dispatching goods. ETA: ${po.expectedDeliveryDate!.day}/${po.expectedDeliveryDate!.month}/${po.expectedDeliveryDate!.year}'
            : 'Supplier dispatching goods to pharmacy premises.',
        timestamp: po.sentAt?.add(const Duration(hours: 4)),
        state: isCancelled
            ? MilestoneState.cancelled
            : (status == POStatus.sent
                  ? MilestoneState.current
                  : (status == POStatus.partiallyReceived ||
                            status == POStatus.received
                        ? MilestoneState.completed
                        : MilestoneState.pending)),
        icon: Icons.local_shipping_outlined,
      ),

      // 6. Delivery Partially Received
      _MilestoneItem(
        title: strings.partialDeliveryMilestone,
        description: po.status == POStatus.partiallyReceived
            ? '${po.totalReceivedQuantity} of ${po.totalOrderedQuantity} units received across ${po.receipts.length} delivery batches.'
            : (po.status == POStatus.received
                  ? 'All initial deliveries accepted.'
                  : 'Awaiting first physical delivery receipt.'),
        timestamp: po.receipts.isNotEmpty ? po.receipts.first.receivedAt : null,
        state: isCancelled
            ? MilestoneState.cancelled
            : (status == POStatus.partiallyReceived
                  ? MilestoneState.current
                  : (status == POStatus.received
                        ? MilestoneState.completed
                        : MilestoneState.pending)),
        icon: Icons.hourglass_bottom_rounded,
      ),

      // 7. Delivery Completed
      _MilestoneItem(
        title: strings.deliveryCompletedMilestone,
        description: po.status == POStatus.received
            ? 'Full ordered quantity (${po.totalOrderedQuantity} units) received and accepted.'
            : 'Pending remaining ${po.totalRemainingQuantity} units.',
        timestamp: po.status == POStatus.received && po.receipts.isNotEmpty
            ? po.receipts.last.receivedAt
            : null,
        state: isCancelled
            ? MilestoneState.cancelled
            : (status == POStatus.received
                  ? MilestoneState.completed
                  : MilestoneState.pending),
        icon: Icons.inventory_2_outlined,
      ),

      // 8. Order Closed
      _MilestoneItem(
        title: strings.orderClosedMilestone,
        description: isCancelled
            ? 'Order cancelled: ${po.cancelReason ?? 'No reason stated'}'
            : (status == POStatus.received
                  ? 'All stock receipts posted to ledger. Purchase order closed.'
                  : 'Order remains open pending delivery and goods receipt verification.'),
        timestamp: isCancelled
            ? po.cancelledAt
            : (status == POStatus.received
                  ? po.receipts.last.receivedAt
                  : null),
        state: isCancelled
            ? MilestoneState.cancelled
            : (status == POStatus.received
                  ? MilestoneState.completed
                  : MilestoneState.pending),
        icon: isCancelled ? Icons.cancel_outlined : Icons.lock_outline,
      ),
    ];
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
