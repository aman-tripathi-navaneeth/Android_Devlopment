import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/customer.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/money_text.dart';
import '../../../core/ui/expandable_card.dart';
import 'payment_entry_sheet.dart';
import 'udhaar_screen.dart';

/// Customers, Refills and Prescriptions Screen - Section 10.9 & Section 13
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final customers = service.customers.where((c) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return c.name.toLowerCase().contains(q) || c.phone.contains(q);
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppTopBar(
            title: 'Customer Directory & Khata',
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
                SearchField(
                  hintText: 'Search customer name or phone…',
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Registered Customers (${customers.length})',
                      style: AppTypography.section,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                      ),
                      icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                      ),
                      label: const Text(
                        'Udhaar Ledger',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const UdhaarScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: customers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.person_search_rounded,
                                size: 40,
                                color: AppColors.inkSoft,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No customers found',
                                style: AppTypography.bodyStrong,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: customers.length,
                          itemBuilder: (context, index) {
                            final cust = customers[index];
                            return _buildCustomerExpandableCard(context, cust);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerExpandableCard(BuildContext context, Customer cust) {
    return ExpandableCard(
      borderColor: cust.hasOutstandingBalance ? AppColors.outlineStrong : null,
      header: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.almond,
            child: Text(
              cust.name.isNotEmpty ? cust.name[0] : 'C',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.carob,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cust.name, style: AppTypography.bodyStrong),
                Text('Phone: ${cust.phone}', style: AppTypography.caption),
                if (cust.refillDueMedicine != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.alarm_rounded,
                        size: 11,
                        color: cust.isRefillOverdue
                            ? AppColors.dangerFg
                            : AppColors.warningFg,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Refill: ${cust.refillDueMedicine} ${cust.isRefillOverdue ? '(Overdue)' : '(Due Soon)'}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: cust.isRefillOverdue
                              ? AppColors.dangerFg
                              : AppColors.warningFg,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cust.hasOutstandingBalance ? 'Owes' : 'Settled',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: cust.hasOutstandingBalance
                      ? AppColors.dangerFg
                      : AppColors.successFg,
                ),
              ),
              MoneyText(
                amountInPaise: cust.balancePaise,
                style: AppTypography.tabularNumbers.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cust.hasOutstandingBalance
                      ? AppColors.dangerFg
                      : AppColors.successFg,
                ),
              ),
            ],
          ),
        ],
      ),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Address: ${cust.address}', style: AppTypography.caption),
              Text(
                '${cust.prescriptionsCount} Prescriptions on file',
                style: AppTypography.caption,
              ),
            ],
          ),
          const Divider(height: 16),

          Text('Recent Transaction History:', style: AppTypography.label),
          const SizedBox(height: 6),

          if (cust.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No credit or payment entries yet.',
                style: AppTypography.caption.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...cust.entries.reversed.take(3).map((entry) {
              final isCredit = entry.type == UdhaarEntryType.credit;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCredit
                              ? Icons.arrow_outward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 12,
                          color: isCredit
                              ? AppColors.dangerFg
                              : AppColors.successFg,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isCredit ? 'Credit' : 'Payment'}: ${entry.note}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                    MoneyText(
                      amountInPaise: entry.amountPaise,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isCredit
                            ? AppColors.dangerFg
                            : AppColors.successFg,
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 12),
          Row(
            children: [
              if (cust.hasOutstandingBalance)
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
              if (cust.hasOutstandingBalance) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 14),
                  label: const Text(
                    'Full Statement',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UdhaarScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
