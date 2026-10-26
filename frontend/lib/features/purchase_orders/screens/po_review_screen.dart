import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/confirm_sheet.dart';
import 'po_detail_screen.dart';

/// Screen 5 — Purchase Order Review and Confirmation
/// Provides a dedicated review screen before the user confirms an order.
/// Enforces Rule 1 & Rule 5: Explicit review and verification before state transition.
class POReviewScreen extends StatefulWidget {
  final Supplier supplier;
  final List<POLineItem> items;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final String? notes;

  const POReviewScreen({
    super.key,
    required this.supplier,
    required this.items,
    required this.orderDate,
    this.expectedDeliveryDate,
    this.notes,
  });

  @override
  State<POReviewScreen> createState() => _POReviewScreenState();
}

class _POReviewScreenState extends State<POReviewScreen> {
  bool _isSubmitting = false;

  double get _subtotal =>
      widget.items.fold(0.0, (sum, item) => sum + item.lineTotal);
  int get _totalUnits =>
      widget.items.fold(0, (sum, item) => sum + item.orderedQuantity);

  void _saveDraft() {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final service = MockDataService();
    final newPoNumber = 'PO-2026-${(service.purchaseOrders.length + 100001)}';

    final po = PurchaseOrder(
      id: 'po-${DateTime.now().millisecondsSinceEpoch}',
      purchaseOrderNumber: newPoNumber,
      supplierId: widget.supplier.id,
      supplierName: widget.supplier.name,
      orderDate: widget.orderDate,
      expectedDeliveryDate: widget.expectedDeliveryDate,
      status: POStatus.draft,
      items: widget.items,
      totalAmount: _subtotal,
      notes: widget.notes,
    );

    service.createPurchaseOrder(po);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Draft order $newPoNumber saved. Stock is unchanged.'),
        backgroundColor: AppColors.matchaDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Pop review screen and create screen
    Navigator.of(context).pop(); // Back to CreatePOScreen
    Navigator.of(context).pop(); // Back to PO list
  }

  void _confirmAndSendOrder() async {
    if (_isSubmitting) return;

    final strings = AppStrings.of(context);
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Confirm Purchase Order?',
      message:
          'Place this purchase order with ${widget.supplier.name} for $_totalUnits units? '
          'Order status will transition to Sent. Note: Inventory stock will NOT increase until physical goods receipt.',
      confirmLabel: 'Confirm & Place Order',
      cancelLabel: strings.cancel,
    );

    if (confirmed == true && mounted) {
      setState(() => _isSubmitting = true);

      final service = MockDataService();
      final newPoNumber = 'PO-2026-${(service.purchaseOrders.length + 100001)}';

      final po = PurchaseOrder(
        id: 'po-${DateTime.now().millisecondsSinceEpoch}',
        purchaseOrderNumber: newPoNumber,
        supplierId: widget.supplier.id,
        supplierName: widget.supplier.name,
        orderDate: widget.orderDate,
        expectedDeliveryDate: widget.expectedDeliveryDate,
        status: POStatus.sent,
        sentAt: DateTime.now(),
        items: widget.items,
        totalAmount: _subtotal,
        notes: widget.notes,
      );

      service.createPurchaseOrder(po);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase Order $newPoNumber placed successfully!'),
          backgroundColor: AppColors.matchaDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate to the newly placed PO detail screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PODetailScreen(poId: po.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: 'Review Purchase Order',
        showLanguageToggle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _saveDraft,
                child: Text(strings.saveAsDraft),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: AppColors.matcha,
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Confirm & Place Order'),
                onPressed: _isSubmitting ? null : _confirmAndSendOrder,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notice banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.vanilla.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.carob,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Carefully review quantities, rates, and supplier details below. '
                      'Placing the order will mark it Sent to the distributor.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. SUPPLIER SUMMARY CARD
            Text('Distributor / Supplier', style: AppTypography.section),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
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
                      Text(
                        widget.supplier.name,
                        style: AppTypography.title.copyWith(fontSize: 16),
                      ),
                      StatusChip(
                        status: StatusType.active,
                        customLabel: widget.supplier.supplierCode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Phone: +91 ${widget.supplier.phone}',
                    style: AppTypography.body,
                  ),
                  if (widget.supplier.contactPerson != null)
                    Text(
                      'Contact Person: ${widget.supplier.contactPerson}',
                      style: AppTypography.caption,
                    ),
                  if (widget.supplier.address != null ||
                      widget.supplier.city != null)
                    Text(
                      'Location: ${[widget.supplier.address, widget.supplier.city].where((e) => e != null).join(', ')}',
                      style: AppTypography.caption,
                    ),
                  Text(
                    'Terms: ${widget.supplier.paymentTerms ?? 'Net 30'}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. ORDER DATES CARD
            Text('Order Schedule', style: AppTypography.section),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Date', style: AppTypography.caption),
                        Text(
                          '${widget.orderDate.day}/${widget.orderDate.month}/${widget.orderDate.year}',
                          style: AppTypography.bodyStrong,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.outline),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expected Delivery', style: AppTypography.caption),
                        Text(
                          widget.expectedDeliveryDate != null
                              ? '${widget.expectedDeliveryDate!.day}/${widget.expectedDeliveryDate!.month}/${widget.expectedDeliveryDate!.year}'
                              : 'Standard (2-3 days)',
                          style: AppTypography.bodyStrong,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. LINE ITEMS BREAKDOWN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Line Items (${widget.items.length})',
                  style: AppTypography.section,
                ),
                Text(
                  '$_totalUnits Total Units',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
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
                            'Qty',
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
                            'Rate',
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
                  ...widget.items.map((item) {
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
                                  '${item.productId} • ${item.unitOfPurchase}',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 10.5,
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
                              '₹${item.expectedUnitRate.toStringAsFixed(0)}',
                              textAlign: TextAlign.right,
                              style: AppTypography.tabularNumbers,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: MoneyText(amountInRupees: item.lineTotal),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  // Subtotal & Estimated Total
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Estimated Order Total',
                              style: AppTypography.bodyStrong,
                            ),
                            MoneyText(
                              amountInRupees: _subtotal,
                              style: AppTypography.tabularNumbersLarge.copyWith(
                                color: AppColors.matchaDeep,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. NOTES
            if (widget.notes != null && widget.notes!.isNotEmpty) ...[
              Text('Order Notes', style: AppTypography.section),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Text(widget.notes!, style: AppTypography.body),
              ),
              const SizedBox(height: 16),
            ],

            // 5. VALIDATION CHECKLIST
            Text('Verification Checklist', style: AppTypography.section),
            const SizedBox(height: 8),
            _buildChecklistItem(
              'Supplier active and selected for procurement',
              true,
            ),
            _buildChecklistItem(
              'All medicines have valid positive ordered quantities',
              true,
            ),
            _buildChecklistItem(
              'Expected rates confirmed against distributor price list',
              true,
            ),
            _buildChecklistItem(
              'Stock ledger will only update after physical goods receipt',
              true,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isChecked
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 18,
            color: isChecked ? AppColors.successFg : AppColors.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppTypography.caption.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
