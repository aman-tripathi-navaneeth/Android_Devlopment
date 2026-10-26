import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/medicine.dart';
import '../../../core/models/batch.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/quantity_stepper.dart';
import '../../../core/ui/difference_preview_card.dart';
import '../../../core/ui/confirm_sheet.dart';
import '../../../core/ui/inline_banner.dart';

/// Interactive Stock Count & Adjustment Sheet - Section 8
/// Follows strict 10-step stock-count workflow and immutable ledger rules.
class StockCountSheet extends StatefulWidget {
  final Medicine medicine;
  final MedicineBatch? initialBatch;

  const StockCountSheet({super.key, required this.medicine, this.initialBatch});

  static Future<bool?> show(
    BuildContext context, {
    required Medicine medicine,
    MedicineBatch? initialBatch,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          StockCountSheet(medicine: medicine, initialBatch: initialBatch),
    );
  }

  @override
  State<StockCountSheet> createState() => _StockCountSheetState();
}

class _StockCountSheetState extends State<StockCountSheet> {
  late MedicineBatch _selectedBatch;
  late int _countedQty;
  String _selectedReason = 'Counter Miscount / Reconciliation';
  final TextEditingController _customReasonController = TextEditingController();
  final TextEditingController _numericInputController = TextEditingController();

  final List<String> _reasonOptions = [
    'Counter Miscount / Reconciliation',
    'Damage / Broken Seal',
    'Supplier Shortage Undetected',
    'Sample Given / Dispensed',
    'Physical Spillage / Lost',
    'Other Custom Reason',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialBatch != null) {
      _selectedBatch = widget.initialBatch!;
    } else if (widget.medicine.batches.isNotEmpty) {
      _selectedBatch = widget.medicine.batches.first;
    } else {
      _selectedBatch = MedicineBatch(
        batchNumber: 'DEFAULT-BATCH',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        quantity: widget.medicine.currentStock,
      );
    }

    _countedQty = _selectedBatch.quantity;
    _numericInputController.text = _countedQty.toString();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    _numericInputController.dispose();
    super.dispose();
  }

  int get _difference => _countedQty - _selectedBatch.quantity;

  String get _effectiveReason => _selectedReason == 'Other Custom Reason'
      ? _customReasonController.text.trim()
      : _selectedReason;

  void _onConfirmAdjustment() async {
    if (_difference != 0 && _effectiveReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select or specify a reason for the discrepancy.',
          ),
        ),
      );
      return;
    }

    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Post Stock Adjustment?',
      message:
          'This will post an append-only ${_difference > 0 ? 'ADJUST_IN' : 'ADJUST_OUT'} movement (${_difference.abs()} ${widget.medicine.saleUnit}s) for Batch ${_selectedBatch.batchNumber} to the inventory stock ledger.',
      confirmLabel: 'Confirm & Post Movement',
    );

    if (confirmed == true) {
      final service = MockDataService();
      service.recordStockAdjustment(
        productId: widget.medicine.productId,
        batchNumber: _selectedBatch.batchNumber,
        countedQuantity: _countedQty,
        difference: _difference,
        reason: _effectiveReason,
        authorizedBy: 'Aditya (Pharmacist)',
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Physical Stock Count & Audit',
                        style: AppTypography.title.copyWith(fontSize: 17),
                      ),
                      Text(
                        '${widget.medicine.name} (${widget.medicine.productId})',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Batch selection if multiple batches exist
            if (widget.medicine.batches.length > 1) ...[
              Text('Select Batch to Count:', style: AppTypography.label),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MedicineBatch>(
                    value: _selectedBatch,
                    isExpanded: true,
                    items: widget.medicine.batches.map((b) {
                      return DropdownMenuItem(
                        value: b,
                        child: Text(
                          'Batch ${b.batchNumber} (Recorded: ${b.quantity} ${widget.medicine.saleUnit}s • Exp: ${b.expiryFormatted})',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (b) {
                      if (b != null) {
                        setState(() {
                          _selectedBatch = b;
                          _countedQty = b.quantity;
                          _numericInputController.text = b.quantity.toString();
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Step 1: Physical Count Entry with Stepper and numeric field
            Text(
              'Enter Physically Counted Quantity:',
              style: AppTypography.label,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _numericInputController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Direct Count (${widget.medicine.saleUnit}s)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null && parsed >= 0) {
                          setState(() => _countedQty = parsed);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  QuantityStepper(
                    value: _countedQty,
                    min: 0,
                    max: 9999,
                    unitLabel: widget.medicine.saleUnit,
                    onChanged: (val) {
                      setState(() {
                        _countedQty = val;
                        _numericInputController.text = val.toString();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Step 2: Difference Preview Card
            DifferencePreviewCard(
              medicineName: widget.medicine.name,
              batchNumber: _selectedBatch.batchNumber,
              recordedQuantity: _selectedBatch.quantity,
              countedQuantity: _countedQty,
              unitLabel: widget.medicine.saleUnit,
              reason: _difference != 0
                  ? _effectiveReason
                  : 'No variance detected',
              authorizedBy: 'Aditya (Pharmacist)',
            ),
            const SizedBox(height: 14),

            // Step 3: Mandatory Discrepancy Reason if difference != 0
            if (_difference != 0) ...[
              Text(
                'Discrepancy Reason (Mandatory):',
                style: AppTypography.label,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedReason,
                    isExpanded: true,
                    items: _reasonOptions.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(r, style: AppTypography.caption),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedReason = val);
                    },
                  ),
                ),
              ),
              if (_selectedReason == 'Other Custom Reason') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customReasonController,
                  decoration: const InputDecoration(
                    hintText: 'Enter specific reason for discrepancy...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 14),
            ],

            InlineBanner(
              type: BannerType.neutral,
              text: 'INVARIANT: Adjustments are committed as append-only records. Balances cannot be directly edited without audit logs.',
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      _difference == 0
                          ? 'Verified (No Change)'
                          : 'Confirm & Post Movement',
                    ),
                    onPressed: _difference == 0
                        ? () => Navigator.of(context).pop(false)
                        : _onConfirmAdjustment,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
