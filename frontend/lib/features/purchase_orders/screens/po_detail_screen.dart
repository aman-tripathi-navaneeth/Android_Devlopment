import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/models/goods_receipt.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/progress_bar_segmented.dart';
import '../../../core/ui/confirm_sheet.dart';
import 'goods_receipt_flow_screen.dart';
import 'order_tracking_timeline_screen.dart';
import 'po_review_screen.dart';
import '../../suppliers/screens/supplier_detail_screen.dart';

/// S6: PURCHASE ORDER DETAIL AND TRACKING SCREEN - Section 10.4.3
class PODetailScreen extends StatelessWidget {
  final String poId;

  const PODetailScreen({super.key, required this.poId});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final po = service.purchaseOrders.firstWhere(
          (p) => p.id == poId,
          orElse: () => PurchaseOrder(
            id: '',
            purchaseOrderNumber: 'Not Found',
            supplierId: '',
            supplierName: '',
            orderDate: DateTime.now(),
            status: POStatus.cancelled,
            items: [],
            totalAmount: 0.0,
          ),
        );

        final canReceive =
            po.status == POStatus.sent ||
            po.status == POStatus.partiallyReceived;
        final canSend = po.status == POStatus.draft;
        final canCancel =
            po.status == POStatus.draft ||
            po.status == POStatus.sent ||
            po.status == POStatus.partiallyReceived;

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppTopBar(
            title: po.purchaseOrderNumber,
            showLanguageToggle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.timeline_rounded),
                tooltip: strings.viewTimeline,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingTimelineScreen(poId: po.id),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: (canReceive || canSend)
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
                      if (canCancel) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.dangerFg,
                            side: const BorderSide(
                              color: AppColors.dangerFg,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          child: Text(strings.cancelOrder),
                          onPressed: () async {
                            final confirmed = await ConfirmSheet.show(
                              context,
                              title: strings.cancelOrder,
                              message: po.status == POStatus.partiallyReceived
                                  ? 'Cancelling this partially received order stops remaining deliveries. Any stock already received from GRNs remains in inventory.'
                                  : 'Are you sure you want to cancel this order? This action is permanent.',
                              isDestructive: true,
                              confirmLabel: strings.cancelOrder,
                              cancelLabel: strings.cancel,
                            );
                            if (confirmed == true) {
                              service.cancelOrder(po.id, 'Cancelled by user');
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (canSend) ...[
                        Expanded(
                          child: OutlinedButton(
                            child: Text(strings.reviewOrder),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            child: Text(strings.sendOrder),
                            onPressed: () async {
                              final confirmed = await ConfirmSheet.show(
                                context,
                                title: strings.sendOrder,
                                message:
                                    'Mark this purchase order as Sent to ${po.supplierName}? Once sent, items cannot be edited.',
                                confirmLabel: strings.sendOrder,
                              );
                              if (confirmed == true) {
                                service.markOrderAsSent(po.id);
                              }
                            },
                          ),
                        ),
                      ],
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
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SupplierDetailScreen(
                                supplierId: po.supplierId,
                              ),
                            ),
                          );
                        },
                        child: Row(
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
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: AppColors.matchaDeep,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ordered on: ${po.orderDate.day}/${po.orderDate.month}/${po.orderDate.year}',
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
                      if (po.sentAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sent on: ${po.sentAt!.day}/${po.sentAt!.month}/${po.sentAt!.year}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.matchaDeep,
                          ),
                        ),
                      ],
                      if (po.cancelledAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Cancelled: ${po.cancelReason ?? 'No reason stated'}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.dangerFg,
                          ),
                        ),
                      ],
                      const Divider(height: 20),
                      ProgressBarSegmented(
                        received: po.totalReceivedQuantity,
                        ordered: po.totalOrderedQuantity,
                        unit: 'units',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.timeline_rounded, size: 16),
                          label: Text(strings.viewTimeline),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderTrackingTimelineScreen(poId: po.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. LINE ITEMS TABLE
                Text(
                  'Line Items (${po.items.length})',
                  style: AppTypography.section,
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.almond,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(9),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Medicine',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Ord',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Rec',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Rem',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Total',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...po.items.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.outline,
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: AppTypography.bodyStrong.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${item.productId} • ₹${item.expectedUnitRate.toStringAsFixed(2)}/${item.unitOfPurchase}',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${item.orderedQuantity}',
                                  textAlign: TextAlign.right,
                                  style: AppTypography.tabularNumbers,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${item.receivedQuantity}',
                                  textAlign: TextAlign.right,
                                  style: AppTypography.tabularNumbers.copyWith(
                                    color: AppColors.successFg,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${item.remainingQuantity}',
                                  textAlign: TextAlign.right,
                                  style: AppTypography.tabularNumbers.copyWith(
                                    color: item.remainingQuantity > 0
                                        ? AppColors.warningFg
                                        : AppColors.inkSoft,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: MoneyText(
                                  amountInRupees: item.lineTotal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      // Total row
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order Total',
                              style: AppTypography.bodyStrong,
                            ),
                            MoneyText(
                              amountInRupees: po.totalAmount,
                              style: AppTypography.tabularNumbersLarge.copyWith(
                                color: AppColors.matchaDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. GOODS RECEIPT HISTORY (GRNs)
                Text(
                  '${strings.receiptHistory} (${po.receipts.length})',
                  style: AppTypography.section,
                ),
                const SizedBox(height: 8),

                if (po.receipts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outline, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        'No goods receipts recorded yet',
                        style: AppTypography.caption,
                      ),
                    ),
                  )
                else
                  ...po.receipts.map((grn) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
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
                                grn.receiptNumber,
                                style: AppTypography.bodyStrong,
                              ),
                              StatusChip(
                                status:
                                    grn.inventoryPostingStatus ==
                                        InventoryPostingStatus.posted
                                    ? StatusType.posted
                                    : (grn.inventoryPostingStatus ==
                                              InventoryPostingStatus.pending
                                          ? StatusType.pending
                                          : StatusType.failed),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Received: ${grn.receivedAt.day}/${grn.receivedAt.month}/${grn.receivedAt.year} • Accepted ${grn.totalAcceptedQuantity} units',
                            style: AppTypography.caption,
                          ),
                          if (grn.notes != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Note: ${grn.notes}',
                              style: AppTypography.caption,
                            ),
                          ],
                        ],
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
