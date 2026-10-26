import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/entity_card.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/filter_chips_row.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/confirm_sheet.dart';
import 'supplier_form_screen.dart';
import 'supplier_detail_screen.dart';

enum SupplierFilter { all, active, inactive }

/// S1: SUPPLIER LIST SCREEN (Purchasing > Suppliers) - Section 10.4.3
class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  String _searchQuery = '';
  SupplierFilter _currentFilter = SupplierFilter.all;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final suppliers = service.suppliers.where((s) {
          // Status filter
          if (_currentFilter == SupplierFilter.active && !s.isActive)
            return false;
          if (_currentFilter == SupplierFilter.inactive && s.isActive)
            return false;

          // Search query
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return s.name.toLowerCase().contains(q) ||
              s.supplierCode.toLowerCase().contains(q) ||
              s.phone.contains(q) ||
              (s.contactPerson?.toLowerCase().contains(q) ?? false);
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchField(
                  hintText: strings.search,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilterChipsRow<SupplierFilter>(
                        items: SupplierFilter.values,
                        selectedItem: _currentFilter,
                        labelBuilder: (f) {
                          switch (f) {
                            case SupplierFilter.all:
                              return strings.all;
                            case SupplierFilter.active:
                              return strings.active;
                            case SupplierFilter.inactive:
                              return strings.inactive;
                          }
                        },
                        onSelected: (filter) =>
                            setState(() => _currentFilter = filter),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(strings.addSupplier),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SupplierFormScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: suppliers.isEmpty
                      ? EmptyState(
                          icon: Icons.local_shipping_outlined,
                          title: strings.noSuppliersYet,
                          actionLabel: strings.addSupplier,
                          onAction: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SupplierFormScreen(),
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          itemCount: suppliers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final supplier = suppliers[index];
                            return EntityCard(
                              title: supplier.name,
                              leadingText: supplier.name.isNotEmpty
                                  ? supplier.name.substring(0, 1).toUpperCase()
                                  : 'S',
                              subtitle1:
                                  '${supplier.supplierCode} • ${supplier.contactPerson ?? '-'}',
                              subtitle2:
                                  'Phone: ${supplier.phone} • Terms: ${supplier.paymentTerms ?? 'Net 30'}',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusChip(
                                    status: supplier.isActive
                                        ? StatusType.active
                                        : StatusType.inactive,
                                    customLabel: supplier.isActive
                                        ? strings.active
                                        : strings.inactive,
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert_rounded,
                                      size: 18,
                                      color: AppColors.inkSoft,
                                    ),
                                    padding: EdgeInsets.zero,
                                    onSelected: (action) async {
                                      if (action == 'edit') {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SupplierFormScreen(
                                              supplierToEdit: supplier,
                                            ),
                                          ),
                                        );
                                      } else if (action == 'toggle') {
                                        final willDeactivate =
                                            supplier.isActive;
                                        final confirmed = await ConfirmSheet.show(
                                          context,
                                          title: willDeactivate
                                              ? strings.deactivate
                                              : strings.reactivate,
                                          message: willDeactivate
                                              ? 'Are you sure you want to deactivate ${supplier.name}? This supplier has ${supplier.openPurchaseOrderCount} open purchase orders.'
                                              : 'Reactivate ${supplier.name} for creating new purchase orders?',
                                          isDestructive: willDeactivate,
                                          confirmLabel: willDeactivate
                                              ? strings.deactivate
                                              : strings.reactivate,
                                          cancelLabel: strings.cancel,
                                        );
                                        if (confirmed == true) {
                                          service.toggleSupplierStatus(
                                            supplier.id,
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(strings.editSupplier),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(
                                          supplier.isActive
                                              ? strings.deactivate
                                              : strings.reactivate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SupplierDetailScreen(
                                      supplierId: supplier.id,
                                    ),
                                  ),
                                );
                              },
                            );
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
}
