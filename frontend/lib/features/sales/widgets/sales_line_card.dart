import 'package:flutter/material.dart';

import '../../../core/services/mock_data_service.dart';
import '../../../core/theme/colors.dart';
import '../models/sales_report.dart';

/// Minimalistic, aesthetic card for reviewing and editing extracted sales lines.
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
        ? (isUnmatched ? const Color(0xFFFECACA) : (isUnitUnclear ? const Color(0xFFFDE68A) : const Color(0xFFFDE68A)))
        : const Color(0xFFE2E8F0);

    final String genericTitle = line.genericName.isNotEmpty
        ? line.genericName
        : (line.matchedProductName.isNotEmpty ? line.matchedProductName : line.originalOcrText);

    final bool isStrip = line.unit.toLowerCase().contains('strip');
    final bool isTablet = line.unit.toLowerCase().contains('tab');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: needsAttention ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Minimal Bar: Scanned Quote + Match Indicator + Delete
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_outlined,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '"${line.originalOcrText}"',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildConfidenceBadge(line.confidenceScore),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: widget.onDelete,
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Medicine Header: Icon + Title/Tags + Action Buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal icon container
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isUnmatched
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isUnmatched
                        ? Icons.warning_amber_rounded
                        : Icons.medication_outlined,
                    color: isUnmatched
                        ? AppColors.dangerFg
                        : AppColors.matchaDeep,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        genericTitle,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (line.isMatched) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'GENERIC',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: combinedStock >= line.calculatedLooseUnits
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Available: $combinedStock tabs',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                  color: combinedStock >= line.calculatedLooseUnits
                                      ? const Color(0xFF059669)
                                      : AppColors.dangerFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (brandNames.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Brands: ${brandNames.take(2).join(', ')}${brandNames.length > 2 ? '...' : ''} • ${line.unitsPerPack} tabs/strip',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ] else ...[
                        const Text(
                          'Unmatched medicine • Please map with catalogue',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.dangerFg,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Action Buttons (Change & Edit)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: widget.onSelectCatalogue,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUnmatched ? Icons.search_rounded : Icons.swap_horiz_rounded,
                              size: 13,
                              color: const Color(0xFF334155),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isUnmatched ? 'Match' : 'Change',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: widget.onEditNameManually,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                        child: Text(
                          'Edit name',
                          style: TextStyle(
                            color: AppColors.matchaDeep,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Unit Unclear Alert Prompt (If needed)
            if (isUnitUnclear) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Confirm unit:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    _buildQuickUnitButton('Strip', () => widget.onUnitChanged('strip')),
                    const SizedBox(width: 6),
                    _buildQuickUnitButton('Tablet', () => widget.onUnitChanged('tablet')),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom Minimal Tray: Qty Input + Unit Toggle + Deduction Readout
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 370;

                final qtyAndUnitRow = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Qty',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 48,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 7),
                          border: InputBorder.none,
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

                    // Unit Toggle (Strip | Tablet)
                    Container(
                      height: 32,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(7),
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
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '-${line.calculatedLooseUnits} tabs to deduct',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    Text(
                      isStrip
                          ? '(${line.quantity} strips × ${line.unitsPerPack} tabs)'
                          : (isTablet ? '(${line.quantity} loose tablets)' : 'Unit unconfirmed'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                );

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            qtyAndUnitRow,
                            const SizedBox(height: 6),
                            deductionInfo,
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            qtyAndUnitRow,
                            const SizedBox(width: 8),
                            Flexible(child: deductionInfo),
                          ],
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(double score) {
    final bool isHigh = score >= 0.85;
    final bool isMed = score >= 0.60;

    final Color bg = isHigh
        ? const Color(0xFFECFDF5)
        : (isMed ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2));
    final Color fg = isHigh
        ? const Color(0xFF059669)
        : (isMed ? const Color(0xFFD97706) : AppColors.dangerFg);
    final String label = isHigh ? 'High match' : (isMed ? 'Medium match' : 'Unmatched');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHigh ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 11,
            color: fg,
          ),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickUnitButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFFD97706),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
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
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.matchaDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
