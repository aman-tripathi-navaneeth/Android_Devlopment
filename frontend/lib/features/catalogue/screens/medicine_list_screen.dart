import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/medicine.dart';
import '../../../core/models/batch.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/filter_chips_row.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/expandable_card.dart';
import '../../inventory/screens/stock_count_sheet.dart';
import 'add_edit_medicine_screen.dart';
import 'medicine_detail_screen.dart';

enum MedicineStatusFilter { all, active, inactive, lowStock, nearExpiry }

enum MedicineSort { nameAsc, nameDesc, stockDesc, stockAsc, idAsc }

/// Screen 1 — Medicine Catalogue & Inventory Screen - Sections 7, 9 & 10.3
/// Acts as the single source of product identity, unit conversions, and search.
class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  String _searchQuery = '';
  MedicineStatusFilter _statusFilter = MedicineStatusFilter.all;
  String _selectedCategory = 'All';
  MedicineSort _currentSort = MedicineSort.nameAsc;

  @override
  void initState() {
    super.initState();
    MockDataService().syncFromBackend();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = MedicineStatusFilter.all;
      _selectedCategory = 'All';
      _currentSort = MedicineSort.nameAsc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final service = MockDataService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        // Extract unique categories for filter including official categories
        final categories = <String>{'All', ...MedicineCategories.all};
        for (final m in service.medicines) {
          if (m.category.isNotEmpty) categories.add(m.category);
        }

        // Apply filters & search
        final medicines = service.medicines.where((m) {
          // Status filter
          if (_statusFilter == MedicineStatusFilter.active && !m.isActive)
            return false;
          if (_statusFilter == MedicineStatusFilter.inactive && m.isActive)
            return false;
          if (_statusFilter == MedicineStatusFilter.lowStock && !m.isLowStock)
            return false;
          if (_statusFilter == MedicineStatusFilter.nearExpiry &&
              !m.hasExpiringBatches)
            return false;

          // Category filter
          if (_selectedCategory != 'All' && m.category != _selectedCategory)
            return false;

          // Search query: brand name, generic name, category, product ID, strength, manufacturer, batch number
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase().trim();
          final tokens = q.split(RegExp(r'\s+'));

          final searchable =
              '${m.name} ${m.genericName} ${m.productId} ${m.category} ${m.manufacturer} ${m.strength} ${m.form}'
                  .toLowerCase();
          final matchesBatch = m.batches.any(
            (b) => b.batchNumber.toLowerCase().contains(q),
          );

          // Tokenized match: every token must match somewhere
          return tokens.every((token) => searchable.contains(token)) ||
              matchesBatch;
        }).toList();

        // Apply sorting
        medicines.sort((a, b) {
          switch (_currentSort) {
            case MedicineSort.nameAsc:
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            case MedicineSort.nameDesc:
              return b.name.toLowerCase().compareTo(a.name.toLowerCase());
            case MedicineSort.stockDesc:
              return b.currentStock.compareTo(a.currentStock);
            case MedicineSort.stockAsc:
              return a.currentStock.compareTo(b.currentStock);
            case MedicineSort.idAsc:
              return a.productId.compareTo(b.productId);
          }
        });

        final hasActiveFilters =
            _searchQuery.isNotEmpty ||
            _statusFilter != MedicineStatusFilter.all ||
            _selectedCategory != 'All';

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. SEARCH FIELD
                    SearchField(
                      hintText: 'Search brand, generic, product ID (MED-…), category…',
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                    const SizedBox(height: 10),

                    // 2. STATUS FILTER CHIPS & ADD ACTION
                    if (isNarrow) ...[
                      // Full-width horizontally scrollable filter chips
                      FilterChipsRow<MedicineStatusFilter>(
                        items: MedicineStatusFilter.values,
                        selectedItem: _statusFilter,
                        labelBuilder: (f) {
                          switch (f) {
                            case MedicineStatusFilter.all:
                              return strings.all;
                            case MedicineStatusFilter.active:
                              return strings.active;
                            case MedicineStatusFilter.inactive:
                              return strings.inactive;
                            case MedicineStatusFilter.lowStock:
                              return strings.lowStockCount;
                            case MedicineStatusFilter.nearExpiry:
                              return 'Near Expiry';
                          }
                        },
                        onSelected: (val) =>
                            setState(() => _statusFilter = val),
                      ),
                      const SizedBox(height: 10),

                      // Dedicated Add Medicine full-width button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.matchaDeep,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Add Medicine',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AddEditMedicineScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilterChipsRow<MedicineStatusFilter>(
                              items: MedicineStatusFilter.values,
                              selectedItem: _statusFilter,
                              labelBuilder: (f) {
                                switch (f) {
                                  case MedicineStatusFilter.all:
                                    return strings.all;
                                  case MedicineStatusFilter.active:
                                    return strings.active;
                                  case MedicineStatusFilter.inactive:
                                    return strings.inactive;
                                  case MedicineStatusFilter.lowStock:
                                    return strings.lowStockCount;
                                  case MedicineStatusFilter.nearExpiry:
                                    return 'Near Expiry';
                                }
                              },
                              onSelected: (val) =>
                                  setState(() => _statusFilter = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.matchaDeep,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'Add Medicine',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AddEditMedicineScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        // Category dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isDense: true,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                size: 18,
                                color: AppColors.inkSoft,
                              ),
                              items: categories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(
                                    c == 'All' ? 'All Categories' : c,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        ),

                        // Sort dropdown
                        PopupMenuButton<MedicineSort>(
                          initialValue: _currentSort,
                          onSelected: (sort) =>
                              setState(() => _currentSort = sort),
                          color: AppColors.surface,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sort_rounded,
                                  size: 14,
                                  color: AppColors.matchaDeep,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getSortLabel(_currentSort),
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: MedicineSort.nameAsc,
                              child: Text('Name: A → Z'),
                            ),
                            const PopupMenuItem(
                              value: MedicineSort.nameDesc,
                              child: Text('Name: Z → A'),
                            ),
                            const PopupMenuItem(
                              value: MedicineSort.stockDesc,
                              child: Text('Stock: High → Low'),
                            ),
                            const PopupMenuItem(
                              value: MedicineSort.stockAsc,
                              child: Text('Stock: Low → High'),
                            ),
                            const PopupMenuItem(
                              value: MedicineSort.idAsc,
                              child: Text('Product ID: Ascending'),
                            ),
                          ],
                        ),

                        if (hasActiveFilters)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                            ),
                            icon: const Icon(
                              Icons.clear,
                              size: 14,
                              color: AppColors.inkSoft,
                            ),
                            label: Text(
                              strings.clearFilters,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.matchaDeep,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _clearFilters,
                          )
                        else
                          Text(
                            '${medicines.length} products',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 4. MEDICINES LIST
                    Expanded(
                      child: medicines.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_off_rounded,
                                    size: 44,
                                    color: AppColors.inkSoft,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    hasActiveFilters
                                        ? 'No matching medicines found'
                                        : 'No medicines in catalogue',
                                    style: AppTypography.bodyStrong,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    hasActiveFilters
                                        ? 'Try checking spelling or resetting your filters.'
                                        : 'Add products to start building your catalogue.',
                                    style: AppTypography.caption,
                                  ),
                                  const SizedBox(height: 14),
                                  if (hasActiveFilters)
                                    OutlinedButton(
                                      onPressed: _clearFilters,
                                      child: Text(strings.clearFilters),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Add Medicine'),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AddEditMedicineScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: medicines.length,
                              itemBuilder: (context, index) {
                                final med = medicines[index];
                                return _buildExpandableMedicineCard(
                                  context,
                                  med,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildExpandableMedicineCard(BuildContext context, Medicine med) {
    final safeUnitsPerPack = med.unitsPerPack > 0 ? med.unitsPerPack : 1;
    final packEquivalent = (med.currentStock / safeUnitsPerPack)
        .toStringAsFixed(1);

    return ExpandableCard(
      borderColor: med.isLowStock ? AppColors.dangerFg : null,
      header: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: med.isLowStock ? AppColors.dangerBg : AppColors.vanilla,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.medication_rounded,
              size: 20,
              color: med.isLowStock ? AppColors.dangerFg : AppColors.carob,
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
                        style: AppTypography.bodyStrong.copyWith(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.almond,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        med.productId,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${med.genericName} • ${med.manufacturer}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${med.category} • Form: ${med.form} • 1 ${med.packUnit} = ${med.unitsPerPack} ${med.saleUnit}s',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${med.currentStock} ${med.saleUnit}s',
                style: AppTypography.tabularNumbers.copyWith(
                  fontWeight: FontWeight.bold,
                  color: med.isLowStock ? AppColors.dangerFg : AppColors.ink,
                ),
              ),
              Text(
                '≈ $packEquivalent ${med.packUnit}s',
                style: AppTypography.caption.copyWith(fontSize: 10.5),
              ),
              const SizedBox(height: 4),
              if (!med.isActive)
                const StatusChip(
                  status: StatusType.inactive,
                  customLabel: 'Inactive',
                )
              else if (med.isLowStock)
                const StatusChip(
                  status: StatusType.failed,
                  customLabel: 'Low Stock',
                )
              else if (med.hasExpiringBatches)
                const StatusChip(
                  status: StatusType.pending,
                  customLabel: 'Near Expiry',
                )
              else
                const StatusChip(status: StatusType.active),
            ],
          ),
        ],
      ),
      expandedContent: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MedicineDetailScreen(productId: med.productId),
                  ),
                );
              },
              child: const Text(
                'View Details',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditMedicineScreen(medicineToEdit: med),
                  ),
                );
              },
              child: const Text(
                'Edit Medicine',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                StockCountSheet.show(context, medicine: med);
              },
              child: const Text(
                'Count Stock',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(MedicineSort sort) {
    switch (sort) {
      case MedicineSort.nameAsc:
        return 'Name: A → Z';
      case MedicineSort.nameDesc:
        return 'Name: Z → A';
      case MedicineSort.stockDesc:
        return 'Stock: High → Low';
      case MedicineSort.stockAsc:
        return 'Stock: Low → High';
      case MedicineSort.idAsc:
        return 'Product ID';
    }
  }
}
