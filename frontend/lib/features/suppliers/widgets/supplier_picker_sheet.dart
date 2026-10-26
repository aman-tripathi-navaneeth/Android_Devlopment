import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/supplier.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/search_field.dart';

/// Searchable bottom sheet to choose an active supplier (PART 4.7).
class SupplierPickerSheet extends StatefulWidget {
  final ValueChanged<Supplier> onSelect;

  const SupplierPickerSheet({super.key, required this.onSelect});

  static Future<Supplier?> show(BuildContext context) {
    return showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SupplierPickerSheet(
        onSelect: (supplier) => Navigator.of(ctx).pop(supplier),
      ),
    );
  }

  @override
  State<SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<SupplierPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allSuppliers = MockDataService().suppliers
        .where((s) => s.isActive)
        .toList();
    final filtered = allSuppliers.where((s) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.supplierCode.toLowerCase().contains(q) ||
          (s.contactPerson?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            'Select Active Supplier',
            style: AppTypography.title.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          SearchField(
            hintText: 'Search by supplier name or code…',
            onChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching active suppliers found',
                      style: AppTypography.caption,
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = filtered[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.almond,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.matchaDeep,
                            ),
                          ),
                        ),
                        title: Text(s.name, style: AppTypography.bodyStrong),
                        subtitle: Text(
                          '${s.supplierCode} • ${s.contactPerson ?? s.phone}',
                          style: AppTypography.caption,
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        onTap: () => widget.onSelect(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
