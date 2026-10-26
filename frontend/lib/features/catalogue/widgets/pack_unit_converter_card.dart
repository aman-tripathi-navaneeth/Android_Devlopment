import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';

/// Screen 4 — Pack and Unit Configuration & Interactive Converter
/// Demonstrates bidirectional conversion between pack unit (e.g. strip)
/// and smallest sale unit (e.g. tablet), enforcing immutable conversion rules.
class PackUnitConverterCard extends StatefulWidget {
  final String packUnit;
  final String saleUnit;
  final int unitsPerPack;
  final bool isInteractive;

  const PackUnitConverterCard({
    super.key,
    required this.packUnit,
    required this.saleUnit,
    required this.unitsPerPack,
    this.isInteractive = true,
  });

  @override
  State<PackUnitConverterCard> createState() => _PackUnitConverterCardState();
}

class _PackUnitConverterCardState extends State<PackUnitConverterCard> {
  final TextEditingController _packsInputController = TextEditingController(
    text: '3',
  );
  final TextEditingController _looseInputController = TextEditingController();

  int _calculatedSaleUnits = 0;
  String _calculatedPacksSummary = '';

  @override
  void initState() {
    super.initState();
    _calculateFromPacks('3');
  }

  @override
  void didUpdateWidget(covariant PackUnitConverterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unitsPerPack != widget.unitsPerPack ||
        oldWidget.packUnit != widget.packUnit ||
        oldWidget.saleUnit != widget.saleUnit) {
      _calculateFromPacks(_packsInputController.text);
    }
  }

  @override
  void dispose() {
    _packsInputController.dispose();
    _looseInputController.dispose();
    super.dispose();
  }

  void _calculateFromPacks(String val) {
    final packs = int.tryParse(val.trim()) ?? 0;
    setState(() {
      _calculatedSaleUnits = packs * widget.unitsPerPack;
    });
  }

  void _calculateFromLoose(String val) {
    final loose = int.tryParse(val.trim()) ?? 0;
    if (widget.unitsPerPack <= 0) return;
    final wholePacks = loose ~/ widget.unitsPerPack;
    final remainder = loose % widget.unitsPerPack;

    setState(() {
      if (remainder == 0) {
        _calculatedPacksSummary = '$wholePacks ${widget.packUnit}s';
      } else {
        _calculatedPacksSummary =
            '$wholePacks ${widget.packUnit}s + $remainder ${widget.saleUnit}s';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeUnitsPerPack = widget.unitsPerPack > 0 ? widget.unitsPerPack : 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.vanilla.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plain language rule
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.almond,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  size: 18,
                  color: AppColors.carob,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit Conversion Rule',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '1 ${widget.packUnit} = $safeUnitsPerPack ${widget.saleUnit}s',
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.carob,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            'Stock is always tracked in smallest sale units (${widget.saleUnit}s). Pack sizes govern inward purchasing and outward whole-pack dispensing.',
            style: AppTypography.caption.copyWith(color: AppColors.inkSoft),
          ),

          if (widget.isInteractive) ...[
            const Divider(height: 20),
            Text(
              'Interactive Conversion Calculator',
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),

            // Mode 1: Packs to loose sale units
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _packsInputController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity (${widget.packUnit}s)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _calculateFromPacks,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.carob,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Text(
                      '$_calculatedSaleUnits ${widget.saleUnit}s',
                      style: AppTypography.tabularNumbers.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.matchaDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Mode 2: Loose sale units to packs equivalent
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _looseInputController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Loose (${widget.saleUnit}s)',
                      hintText: 'e.g. 25',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onChanged: _calculateFromLoose,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.carob,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Text(
                      _calculatedPacksSummary.isEmpty
                          ? 'Equivalent packs…'
                          : _calculatedPacksSummary,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _calculatedPacksSummary.isEmpty
                            ? AppColors.inkSoft
                            : AppColors.carob,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
