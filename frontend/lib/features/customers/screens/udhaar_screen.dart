import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/customer.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/inline_banner.dart';
import 'payment_entry_sheet.dart';

/// Udhaar (Credit) and Payments Ledger Screen - Section 10.10 & Section 13
/// Connects live to MockDataService with immutable audit trail and payment collection flow.
class UdhaarScreen extends StatefulWidget {
  const UdhaarScreen({super.key});

  @override
  State<UdhaarScreen> createState() => _UdhaarScreenState();
}

class _UdhaarScreenState extends State<UdhaarScreen> {
  @override
  Widget build(BuildContext context) {
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final customersWithBalance = service.customers
            .where((c) => c.hasOutstandingBalance)
            .toList();
        final totalOutstandingPaise = customersWithBalance.fold(
          0,
          (sum, c) => sum + c.balancePaise,
        );

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppTopBar(
            title: 'Udhaar (Credit) & Payments',
            showLanguageToggle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InlineBanner(
                  type: BannerType.warning,
                  text: 'GOLDEN RULE G7: Balances are strictly DERIVED from credit & payment history. No field allows typing a balance.',
                ),
                const SizedBox(height: 14),

                // Total credit summary strip
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
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
                            'Total Outstanding Khata Balance',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 2),
                          MoneyText(
                            amountInPaise: totalOutstandingPaise,
                            style: AppTypography.tabularNumbersLarge.copyWith(
                              color: AppColors.dangerFg,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${customersWithBalance.length} Customers with dues',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dangerFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Customer Credit Accounts (${customersWithBalance.length})',
                  style: AppTypography.section,
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: customersWithBalance.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: AppColors.successFg,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All customer accounts are settled!',
                                style: AppTypography.bodyStrong,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: customersWithBalance.length,
                          itemBuilder: (context, i) {
                            final cust = customersWithBalance[i];
                            return _buildCustomerLedgerCard(context, cust);
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerLedgerCard(BuildContext context, Customer cust) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cust.name, style: AppTypography.bodyStrong),
                  Text(
                    'Phone: ${cust.phone} • ${cust.entries.length} Ledger entries',
                    style: AppTypography.caption,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Owes',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dangerFg,
                    ),
                  ),
                  MoneyText(
                    amountInPaise: cust.balancePaise,
                    style: AppTypography.tabularNumbersLarge.copyWith(
                      color: AppColors.dangerFg,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.payment_rounded, size: 14),
                  label: const Text(
                    'Record Payment',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    PaymentEntrySheet.show(context, customer: cust);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 14),
                  label: const Text(
                    'View Timeline',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _showLedgerTimelineModal(context, cust),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLedgerTimelineModal(BuildContext context, Customer cust) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cust.name,
                  style: AppTypography.title.copyWith(fontSize: 18),
                ),
                MoneyText(
                  amountInPaise: cust.balancePaise,
                  style: AppTypography.tabularNumbersLarge.copyWith(
                    color: AppColors.dangerFg,
                  ),
                ),
              ],
            ),
            Text(
              'Derived from immutable audit entries • ${cust.phone}',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
              icon: const Icon(Icons.payment_rounded, size: 16),
              label: const Text('Collect Payment Now'),
              onPressed: () {
                Navigator.of(ctx).pop();
                PaymentEntrySheet.show(context, customer: cust);
              },
            ),
            const SizedBox(height: 16),

            Text(
              'Complete Transaction Audit Timeline',
              style: AppTypography.section,
            ),
            const SizedBox(height: 8),

            Expanded(
              child: cust.entries.isEmpty
                  ? Center(
                      child: Text(
                        'No transactions recorded.',
                        style: AppTypography.caption,
                      ),
                    )
                  : ListView(
                      children: cust.entries.reversed.map<Widget>((e) {
                        final isCredit = e.type == UdhaarEntryType.credit;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isCredit
                                      ? AppColors.dangerBg
                                      : AppColors.successBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  isCredit
                                      ? Icons.arrow_outward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 16,
                                  color: isCredit
                                      ? AppColors.dangerFg
                                      : AppColors.successFg,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${isCredit ? 'Credit' : 'Payment'}: ${e.note}',
                                      style: AppTypography.bodyStrong.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Recorded By: ${e.recordedBy} • Method: ${e.paymentMethod ?? 'Credit'}',
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                              ),
                              MoneyText(
                                amountInPaise: e.amountPaise,
                                style: AppTypography.tabularNumbers.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCredit
                                      ? AppColors.dangerFg
                                      : AppColors.successFg,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
