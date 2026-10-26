import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/models/goods_receipt.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/step_header.dart';
import '../../../core/ui/quantity_stepper.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../../core/ui/confirm_sheet.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/inline_banner.dart';

/// S7: GOODS RECEIPT FLOW SCREEN (3-step wizard) - Section 10.4.3
/// Strictly enforces all 10 Mandatory Manual Verification & Correction rules.
class GoodsReceiptFlowScreen extends StatefulWidget {
  final PurchaseOrder purchaseOrder;

  const GoodsReceiptFlowScreen({super.key, required this.purchaseOrder});

  @override
  State<GoodsReceiptFlowScreen> createState() => _GoodsReceiptFlowScreenState();
}

class _GoodsReceiptFlowScreenState extends State<GoodsReceiptFlowScreen> {
  int _currentStep =
      0; // 0: Physical Count & Batch, 1: Review & Stock Impact, 2: Result

  // Input states per line
  final Map<String, int> _receivedNow = {};
  final Map<String, int> _damagedNow = {};
  final Map<String, String> _damageReasons = {};
  final Map<String, String> _batchNumbers = {};
  final Map<String, String> _expiryDates = {};
  final TextEditingController _notesController = TextEditingController();

  bool _overReceiptAuthorized = false;
  final String _verifiedBy = 'Aditya (Pharmacist)';

  GoodsReceipt? _recordedReceipt;

  @override
  void initState() {
    super.initState();
    for (final line in widget.purchaseOrder.items) {
      _receivedNow[line.lineId] = 0;
      _damagedNow[line.lineId] = 0;
      _damageReasons[line.lineId] = '';
      _batchNumbers[line.lineId] =
          'B-${line.productId.replaceAll('MED-', '')}-26';
      _expiryDates[line.lineId] = '2028-10';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _totalAcceptedNow {
    int total = 0;
    for (final line in widget.purchaseOrder.items) {
      final rec = _receivedNow[line.lineId] ?? 0;
      final dam = _damagedNow[line.lineId] ?? 0;
      total += (rec - dam).clamp(0, rec);
    }
    return total;
  }

  bool get _hasAnyReceivedQuantity {
    return _receivedNow.values.any((q) => q > 0);
  }

  bool get _hasAnyOverReceipt {
    return widget.purchaseOrder.items.any((line) {
      final rec = _receivedNow[line.lineId] ?? 0;
      return rec > line.remainingQuantity;
    });
  }

  void _onConfirmReceipt() async {
    final strings = AppStrings.of(context);

    // Validate every received item has non-empty batch and non-expired expiry date
    for (final line in widget.purchaseOrder.items) {
      final rec = _receivedNow[line.lineId] ?? 0;
      if (rec > 0) {
        final batch = (_batchNumbers[line.lineId] ?? '').trim();
        final exp = (_expiryDates[line.lineId] ?? '').trim();
        if (batch.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Batch number is required for ${line.productName}'),
              backgroundColor: AppColors.dangerFg,
            ),
          );
          return;
        }
        if (exp.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Expiry date is required for ${line.productName}'),
              backgroundColor: AppColors.dangerFg,
            ),
          );
          return;
        }
        DateTime? expDate;
        try {
          final parts = exp.split('-');
          if (parts.length == 2) {
            expDate = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 0);
          } else if (parts.length == 3) {
            expDate = DateTime.parse(exp);
          }
        } catch (_) {}
        if (expDate == null || expDate.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Expired stock rejected for ${line.productName} (Expiry: $exp)',
              ),
              backgroundColor: AppColors.dangerFg,
            ),
          );
          return;
        }
      }
    }

    final confirmed = await ConfirmSheet.show(
      context,
      title: strings.confirmReceiptAction,
      message:
          'This will post $_totalAcceptedNow accepted units into the append-only stock ledger under verifier $_verifiedBy. Stock movements cannot be deleted.',
      confirmLabel: 'Confirm & Post to Ledger',
      cancelLabel: strings.cancel,
    );

    if (confirmed == true) {
      final service = MockDataService();

      final List<GRNLineItem> grnLines = [];
      for (final line in widget.purchaseOrder.items) {
        final rec = _receivedNow[line.lineId] ?? 0;
        final dam = _damagedNow[line.lineId] ?? 0;
        if (rec > 0) {
          grnLines.add(
            GRNLineItem(
              lineId: line.lineId,
              productId: line.productId,
              productName: line.productName,
              unitOfPurchase: line.unitOfPurchase,
              originalOrderedQuantity: line.orderedQuantity,
              quantityReceived: rec,
              quantityDamaged: dam,
              quantityAccepted: rec - dam,
              damageReason: _damageReasons[line.lineId],
              batchNumber: _batchNumbers[line.lineId],
              expiryDate: _expiryDates[line.lineId],
            ),
          );
        }
      }

      final grn = service.recordGoodsReceipt(
        poId: widget.purchaseOrder.id,
        receivedItems: grnLines,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      setState(() {
        _recordedReceipt = grn;
        _currentStep = 2; // Jump to Result step
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final po = widget.purchaseOrder;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: '${strings.goodsReceiptTitle} (${po.purchaseOrderNumber})',
        showLanguageToggle: false,
        leading: _currentStep < 2
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Column(
        children: [
          StepHeader(
            currentStep: _currentStep,
            steps: [strings.stepCount, strings.stepReview, strings.stepResult],
          ),
          Expanded(
            child: _currentStep == 0
                ? _buildCountStep(strings)
                : (_currentStep == 1
                      ? _buildReviewStep(strings)
                      : _buildResultStep(strings)),
          ),
        ],
      ),
      bottomNavigationBar: _currentStep == 0
          ? StickyActionBar(
              secondaryLabel: 'Cancel',
              onSecondaryPressed: () => Navigator.of(context).maybePop(),
              primaryLabel: _hasAnyOverReceipt && !_overReceiptAuthorized
                  ? 'Authorize Over-Receipt to Proceed'
                  : 'Proceed to Review ($_totalAcceptedNow accepted units)',
              onPrimaryPressed:
                  (_hasAnyReceivedQuantity &&
                      (!_hasAnyOverReceipt || _overReceiptAuthorized))
                  ? () => setState(() => _currentStep = 1)
                  : null,
            )
          : (_currentStep == 1
                ? StickyActionBar(
                    primaryLabel: strings.confirmReceiptAction,
                    secondaryLabel: 'Back to Count',
                    onSecondaryPressed: () => setState(() => _currentStep = 0),
                    onPrimaryPressed: _onConfirmReceipt,
                  )
                : null),
    );
  }

  // STEP 1: PHYSICAL COUNT & BATCH VERIFICATION (Rules 2, 3, 7, 9)
  Widget _buildCountStep(AppStrings strings) {
    final po = widget.purchaseOrder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineBanner(
            type: BannerType.warning,
            text: 'PHYSICAL VERIFICATION MANDATORY: Compare physical delivery against app PO records. Enter physical counts, batch numbers, and expiry dates below.',
          ),
          const SizedBox(height: 14),

          ...po.items.map((line) {
            final received = _receivedNow[line.lineId] ?? 0;
            final damaged = _damagedNow[line.lineId] ?? 0;
            final isOverReceipt = received > line.remainingQuantity;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOverReceipt
                      ? AppColors.warningFg
                      : AppColors.outline,
                  width: isOverReceipt ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          line.productName,
                          style: AppTypography.bodyStrong,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.almond,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          line.productId,
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ordered: ${line.orderedQuantity} • Previously Rec: ${line.receivedQuantity} • Remaining: ${line.remainingQuantity} ${line.unitOfPurchase}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const Divider(height: 16),

                  // Quantity Steppers (Rule 2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        strings.receivedNow,
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      QuantityStepper(
                        value: received,
                        min: 0,
                        max: 9999,
                        unitLabel: line.unitOfPurchase,
                        onChanged: (val) {
                          setState(() {
                            _receivedNow[line.lineId] = val;
                            if ((_damagedNow[line.lineId] ?? 0) > val) {
                              _damagedNow[line.lineId] = val;
                            }
                          });
                        },
                      ),
                    ],
                  ),

                  if (isOverReceipt) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Over-receipt: Received ($received) exceeds remaining (${line.remainingQuantity}) by +${received - line.remainingQuantity} units.',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warningFg,
                        ),
                      ),
                    ),
                  ],

                  if (received > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(strings.damagedShort, style: AppTypography.label),
                        QuantityStepper(
                          value: damaged,
                          min: 0,
                          max: received,
                          unitLabel: line.unitOfPurchase,
                          onChanged: (val) {
                            setState(() => _damagedNow[line.lineId] = val);
                          },
                        ),
                      ],
                    ),
                    if (damaged > 0) ...[
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: strings.damageReason,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (val) => _damageReasons[line.lineId] = val,
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Physical Batch & Expiry Entry (Rule 2 & 3)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _batchNumbers[line.lineId],
                            decoration: const InputDecoration(
                              labelText: 'Physical Batch No.',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            onChanged: (val) =>
                                _batchNumbers[line.lineId] = val.trim(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: _expiryDates[line.lineId],
                            decoration: const InputDecoration(
                              labelText: 'Physical Expiry (YYYY-MM)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            onChanged: (val) =>
                                _expiryDates[line.lineId] = val.trim(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }).toList(),

          if (_hasAnyOverReceipt) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warningFg),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _overReceiptAuthorized,
                    onChanged: (val) =>
                        setState(() => _overReceiptAuthorized = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'I explicitly authorize the detected over-receipt delivery on behalf of the pharmacy.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // STEP 2: REVIEW BEFORE CONFIRMATION (Rules 1, 5, 8)
  Widget _buildReviewStep(AppStrings strings) {
    final po = widget.purchaseOrder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineBanner(
            type: BannerType.warning,
            text: 'FINAL VERIFICATION: Review the stock ledger impact below. Only confirmed receipts post stock. Undelivered balances will remain open on the PO.',
          ),
          const SizedBox(height: 16),

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
                Text(
                  'Goods Receipt Audit Metadata',
                  style: AppTypography.bodyStrong,
                ),
                const Divider(height: 14),
                Text(
                  'Purchase Order: ${po.purchaseOrderNumber}',
                  style: AppTypography.caption,
                ),
                Text(
                  'Supplier: ${po.supplierName}',
                  style: AppTypography.caption,
                ),
                Text(
                  'Physically Verified By: $_verifiedBy',
                  style: AppTypography.caption,
                ),
                Text(
                  'Current Status: Pending Staff Confirmation',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(strings.receiptSummary, style: AppTypography.section),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline, width: 1),
            ),
            child: Column(
              children: po.items.map((line) {
                final rec = _receivedNow[line.lineId] ?? 0;
                final dam = _damagedNow[line.lineId] ?? 0;
                final accepted = rec - dam;
                final batch = _batchNumbers[line.lineId] ?? 'N/A';
                final expiry = _expiryDates[line.lineId] ?? 'N/A';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.productName,
                              style: AppTypography.bodyStrong,
                            ),
                            Text(
                              'Accepted: $accepted • Damaged: $dam',
                              style: AppTypography.caption,
                            ),
                            Text(
                              'Batch: $batch • Expiry: $expiry',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+$accepted ${line.unitOfPurchase}',
                        style: AppTypography.tabularNumbers.copyWith(
                          color: accepted > 0
                              ? AppColors.successFg
                              : AppColors.inkSoft,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          Text('Receipt Notes (Optional)', style: AppTypography.section),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText:
                  'Enter invoice number, lorry receipt, or delivery remarks...',
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // STEP 3: RESULT
  Widget _buildResultStep(AppStrings strings) {
    final grn = _recordedReceipt;
    if (grn == null) return const SizedBox();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.successFg,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.receiptRecordedSuccess,
              style: AppTypography.screenTitle,
            ),
            const SizedBox(height: 6),
            Text(
              '${grn.receiptNumber} verified by $_verifiedBy.\n+${grn.totalAcceptedQuantity} units successfully posted to the inventory stock ledger.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Order Details'),
            ),
          ],
        ),
      ),
    );
  }
}
