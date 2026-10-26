import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// FilterChipsRow: horizontal scrollable single-selection chips (PART 4.7).
class FilterChipsRow<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onSelected;

  const FilterChipsRow({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = item == selectedItem;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ChoiceChip(
              label: Text(labelBuilder(item)),
              selected: isSelected,
              onSelected: (_) => onSelected(item),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.matcha,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.onMatcha : AppColors.inkSoft,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.matchaDeep : AppColors.outline,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}
