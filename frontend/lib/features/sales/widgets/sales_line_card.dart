import 'package:flutter/material.dart';

import '../../../core/services/mock_data_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/ui/confidence_chip.dart';
import '../models/sales_report.dart';

/// Reusable card for reviewing and editing extracted sales lines.
/// Implements Generic Grouping, Unit Auto-Identification, and Pack-Size Conversion.
class SalesLineCard extends StatefulWidget {
  final SalesLineItem line;
  final VoidCallback onSelectCatalogue;
  final VoidCallback onEditNameManually;
  final VoidCallback onDelete;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<String> onUnitChanged;

  const SalesLineCard({
    super.key,
    required this.line,
    required this.onSelectCatalogue,
    required this.onEditNameManually,
    required this.onDelete,
    required this.onQuantityChanged,
    required this.onUnitChanged,
  });

  @override
  State<SalesLineCard> createState() => _SalesLineCardState();
}

class _SalesLineCardState extends State<SalesLineCard> {
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.line.quantity > 0 ? widget.line.quantity.toString() : '',
    );
  }

  @override
  void didUpdateWidget(covariant SalesLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.quantity != widget.line.quantity) {
      if (widget.line.quantity > 0) {
        _qtyController.text = widget.line.quantity.toString();
      } else {
        _qtyController.clear();
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final bool isUnmatched = !line.isMatched;
    final bool isUnitUnclear = line.isUnitUnclear;
    final bool needsAttention = line.needsResolution || isUnmatched || isUnitUnclear;

    final mockData = MockDataService();
    final combinedStock = mockData.getCombinedStockForGeneric(
      line.genericName,
      fallbackProductId: line.matchedProductId,
    );
    final matchedMeds = mockData.getMedicinesForGeneric(
      line.genericName,
      fallbackProductId: line.matchedProductId,
    );
    final brandNames = matchedMeds.map((m) => m.name).toSet().toList();

    final Color borderColor = needsAttention
        ? (isUnmatched ? AppColors.dangerFg : (isUnitUnclear ? const Color(0xFFD97706) : AppColors.chai))
        : AppColors.outline;

    final String genericTitle = line.genericName.isNotEmpty
        ? line.genericName
        : (line.matchedProductName.isNotEmpty ? line.matchedProductName : line.originalOcrText);

    final bool isStrip = line.unit.toLowerCase().contains('strip');
    final bool isTablet = line.unit.toLowerCase().contains('tab');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: needsAttention ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar: Raw OCR Snippet + Confidence Chip + Delete
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: needsAttention
                  ? AppColors.vanilla.withOpacity(0.4)
                  : AppColors.canvas,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.outline.withOpacity(0.6)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RAW SCANNED TEXT:',
                        style: AppTypography.caption.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '"${line.originalOcrText}"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConfidenceChip(confidence: line.confidenceScore),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.dangerFg,
                    size: 18,
                  ),
                  tooltip: 'Delete row',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),

          // Main Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Generic Medicine Identification & Brand Grouping
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isUnmatched
                            ? AppColors.dangerBg
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isUnmatched ? AppColors.dangerFg : const Color(0xFF81C784),
                        ),
                      ),
                      child: Icon(
                        isUnmatched
                            ? Icons.warning_amber_rounded
                            : Icons.science_outlined,
                        color: isUnmatched
                            ? AppColors.dangerFg
                            : const Color(0xFF2E7D32),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (line.isMatched) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFBAE6FD)),
                                  ),
                                  child: const Text(
                                    'GENERIC GROUP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9.5,
                                      color: Color(0xFF0369A1),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: combinedStock >= line.calculatedLooseUnits
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Available: $combinedStock tabs',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      color: combinedStock >= line.calculatedLooseUnits
                                          ? const Color(0xFF047857)
                                          : AppColors.dangerFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              genericTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (brandNames.isNotEmpty)
                              Text(
                                'Brands: ${brandNames.join(', ')} • Pack: ${line.unitsPerPack} tabs/strip',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                          ] else ...[
                            const Text(
                              'UNMATCHED MEDICINE',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.dangerFg,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Please match with catalogue generic medicine',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.dangerFg,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Action Buttons for Matching & Editing
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.search_rounded, size: 14),
                          label: Text(
                            isUnmatched ? 'Match' : 'Change',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: widget.onSelectCatalogue,
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: widget.onEditNameManually,
                          child: const Text(
                            'Edit name',
                            style: TextStyle(
                              color: AppColors.matchaDeep,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Unit Confirmation Prompt (If unclear from scan)
                if (isUnitUnclear) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Unit unclear! Confirm unit:',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => widget.onUnitChanged('strip'),
                          child: const Text(
                            'Strip',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => widget.onUnitChanged('tablet'),
                          child: const Text(
                            'Tablet',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                const Divider(height: 16),

                // Quantity & Unit Controls + Deduction Calculation
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrowCard = constraints.maxWidth < 360;

                    final qtyAndUnitRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Qty',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed >= 0) {
                                widget.onQuantityChanged(parsed);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildUnitOption(
                                label: 'Strip',
                                isSelected: isStrip,
                                onTap: () => widget.onUnitChanged('strip'),
                              ),
                              _buildUnitOption(
                                label: 'Tablet',
                                isSelected: isTablet,
                                onTap: () => widget.onUnitChanged('tablet'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final deductionInfo = Column(
                      crossAxisAlignment: isNarrowCard
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Text(
                          '-${line.calculatedLooseUnits} tabs to deduct',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: isUnitUnclear
                                ? const Color(0xFFD97706)
                                : AppColors.dangerFg,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isStrip
                              ? '(${line.quantity} strips × ${line.unitsPerPack} tabs)'
                              : (isTablet ? '(${line.quantity} loose tablets)' : 'Unit unconfirmed'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isUnitUnclear ? const Color(0xFFD97706) : AppColors.inkSoft,
                          ),
                        ),
                      ],
                    );

                    if (isNarrowCard) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          qtyAndUnitRow,
                          const SizedBox(height: 8),
                          deductionInfo,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        qtyAndUnitRow,
                        const SizedBox(width: 8),
                        Flexible(child: deductionInfo),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.matchaDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
