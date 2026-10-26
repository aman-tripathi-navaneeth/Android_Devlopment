import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/customer.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/confirm_sheet.dart';
import '../../../core/ui/inline_banner.dart';

/// Interactive Payment Entry Sheet - Section 13
/// Validates payment limits, prevents duplicate submissions, and updates derived balance.
class PaymentEntrySheet extends StatefulWidget {
  final Customer customer;

  const PaymentEntrySheet({super.key, required this.customer});

  static Future<bool?> show(
    BuildContext context, {
    required Customer customer,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentEntrySheet(customer: customer),
    );
  }

  @override
  State<PaymentEntrySheet> createState() => _PaymentEntrySheetState();
}

class _PaymentEntrySheetState extends State<PaymentEntrySheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedPaymentMethod = 'CASH';

  int _enteredPaise = 0;
  String? _validationError;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    setState(() {
      final parsedRupees = double.tryParse(val.trim());
      if (parsedRupees == null || parsedRupees <= 0) {
        _enteredPaise = 0;
        _validationError = 'Enter a valid amount greater than ₹0.00';
      } else {
        _enteredPaise = (parsedRupees * 100).round();
        if (_enteredPaise > widget.customer.balancePaise) {
          _validationError =
              'Payment cannot exceed the outstanding balance of ₹${(widget.customer.balancePaise / 100).toStringAsFixed(2)}';
        } else {
          _validationError = null;
        }
      }
    });
  }

  void _onQuickAmountSelected(int paise) {
    final capped = paise.clamp(0, widget.customer.balancePaise);
    final rupees = capped / 100.0;
    _amountController.text = rupees.toStringAsFixed(2);
    _onAmountChanged(_amountController.text);
  }

  void _onConfirmPayment() async {
    if (_validationError != null || _enteredPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _validationError ?? 'Please enter a valid payment amount.',
          ),
        ),
      );
      return;
    }

    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Confirm Payment Collection?',
      message:
          'Record ₹${(_enteredPaise / 100).toStringAsFixed(2)} via $_selectedPaymentMethod for ${widget.customer.name}? This will add an immutable payment transaction to their Udhaar ledger.',
      confirmLabel: 'Confirm & Post Payment',
    );

    if (confirmed == true) {
      final service = MockDataService();
      try {
        service.recordCustomerPayment(
          customerId: widget.customer.id,
          amountPaise: _enteredPaise,
          paymentMethod: _selectedPaymentMethod,
          note: _notesController.text.trim().isEmpty
              ? 'Counter Payment'
              : _notesController.text.trim(),
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final resultingBalancePaise = (widget.customer.balancePaise - _enteredPaise)
        .clamp(0, widget.customer.balancePaise);

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Customer Payment',
                      style: AppTypography.title.copyWith(fontSize: 17),
                    ),
                    Text(
                      '${widget.customer.name} • ${widget.customer.phone}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Outstanding balance banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.vanilla,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Outstanding Balance',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      MoneyText(
                        amountInPaise: widget.customer.balancePaise,
                        style: AppTypography.tabularNumbersLarge.copyWith(
                          color: AppColors.dangerFg,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () =>
                        _onQuickAmountSelected(widget.customer.balancePaise),
                    child: const Text(
                      'Pay Full',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Amount input
            Text('Enter Payment Amount (₹):', style: AppTypography.label),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppTypography.tabularNumbersLarge.copyWith(fontSize: 18),
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: '0.00',
                isDense: true,
                errorText: _validationError,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onChanged: _onAmountChanged,
            ),
            const SizedBox(height: 12),

            // Payment method selector chips
            Text('Payment Method:', style: AppTypography.label),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildMethodChip('CASH', Icons.money_rounded),
                const SizedBox(width: 8),
                _buildMethodChip('UPI', Icons.qr_code_2_rounded),
                const SizedBox(width: 8),
                _buildMethodChip('CARD', Icons.credit_card_rounded),
              ],
            ),
            const SizedBox(height: 14),

            // Live difference preview card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment Amount:',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '-₹${(_enteredPaise / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.successFg,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Remaining Balance After Payment:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      MoneyText(
                        amountInPaise: resultingBalancePaise,
                        style: AppTypography.tabularNumbers.copyWith(
                          fontWeight: FontWeight.bold,
                          color: resultingBalancePaise > 0
                              ? AppColors.dangerFg
                              : AppColors.successFg,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Payment Note (Optional)',
                hintText: 'e.g. GPay / Cash counter receipt #881',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 14),

            InlineBanner(
              type: BannerType.neutral,
              text: 'INVARIANT: Balances are calculated dynamically from immutable payment and credit logs.',
            ),
            const SizedBox(height: 16),

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
                    label: const Text('Confirm Payment'),
                    onPressed: (_enteredPaise > 0 && _validationError == null)
                        ? _onConfirmPayment
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? AppColors.onMatcha : AppColors.inkSoft,
      ),
      label: Text(method),
      selected: isSelected,
      selectedColor: AppColors.matcha,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.onMatcha : AppColors.ink,
      ),
      onSelected: (_) => setState(() => _selectedPaymentMethod = method),
    );
  }
}
