import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/medicine.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/filter_chips_row.dart';

/// Screen 5 — Catalogue Search and Selection Sheet
/// Reusable disambiguated medicine picker for Member 3 (Purchase Orders)
/// and Member 7 (Outward Sales Scanning).
class MedicinePickerSheet extends StatefulWidget {
  final ValueChanged<Medicine> onSelect;
  final String? initialQuery;

  const MedicinePickerSheet({
    super.key,
    required this.onSelect,
    this.initialQuery,
  });

  static Future<Medicine?> show(BuildContext context, {String? initialQuery}) {
    return showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicinePickerSheet(
        initialQuery: initialQuery,
        onSelect: (med) => Navigator.of(ctx).pop(med),
      ),
    );
  }

  @override
  State<MedicinePickerSheet> createState() => _MedicinePickerSheetState();
}

class _MedicinePickerSheetState extends State<MedicinePickerSheet> {
  late String _query;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final service = MockDataService();
    final allActiveMeds = service.medicines.where((m) => m.isActive).toList();

    // Extract categories including official taxonomy
    final categories = <String>['All', ...MedicineCategories.all];
    for (final m in allActiveMeds) {
      if (m.category.isNotEmpty && !categories.contains(m.category)) {
        categories.add(m.category);
      }
    }

    final filtered = allActiveMeds.where((m) {
      if (_selectedCategory != 'All' && m.category != _selectedCategory) {
        return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase().trim();
      final tokens = q.split(RegExp(r'\s+'));
      final searchable =
          '${m.name} ${m.genericName} ${m.productId} ${m.category} ${m.manufacturer} ${m.strength} ${m.form}'
              .toLowerCase();
      return tokens.every((token) => searchable.contains(token));
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
              Text(
                'Select Catalogue Medicine',
                style: AppTypography.title.copyWith(fontSize: 18),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.inkSoft,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Search Field
          SearchField(
            hintText: 'Search brand, generic, strength, or Product ID…',
            onChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: 10),

          // Category Chips
          FilterChipsRow<String>(
            items: categories,
            selectedItem: _selectedCategory,
            labelBuilder: (c) => c,
            onSelected: (cat) => setState(() => _selectedCategory = cat),
          ),
          const SizedBox(height: 10),

          // Disambiguation results count
          Text(
            '${filtered.length} matching products found:',
            style: AppTypography.caption.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),

          // Medicines List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 36,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No medicines match your search',
                          style: AppTypography.bodyStrong,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verify spelling or choose a different category.',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final med = filtered[index];
                      return InkWell(
                        onTap: () => widget.onSelect(med),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10.0,
                            horizontal: 4.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.almond,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.medication_rounded,
                                  size: 20,
                                  color: AppColors.matchaDeep,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${med.name} (${med.strength})',
                                            style: AppTypography.bodyStrong
                                                .copyWith(fontSize: 14),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.almond,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            med.productId,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.carob,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Generic: ${med.genericName} • ${med.manufacturer}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.vanilla
                                                .withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '1 ${med.packUnit} = ${med.unitsPerPack} ${med.saleUnit}s',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.carob,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Stock: ${med.currentStock} ${med.saleUnit}s',
                                          style: AppTypography.caption.copyWith(
                                            color: med.isLowStock
                                                ? AppColors.dangerFg
                                                : AppColors.inkSoft,
                                            fontWeight: med.isLowStock
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 22,
                                color: AppColors.matchaDeep,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
