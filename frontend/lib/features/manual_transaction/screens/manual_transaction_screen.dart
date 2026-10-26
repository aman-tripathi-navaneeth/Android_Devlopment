import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/medicine.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';

/// Manual stock-out workflow: catalogue selection -> quantities -> review.
/// Selection is keyed by the catalogue product ID, never by the display name.
class ManualTransactionScreen extends StatefulWidget {
  const ManualTransactionScreen({super.key});

  @override
  State<ManualTransactionScreen> createState() =>
      _ManualTransactionScreenState();
}

class _ManualTransactionScreenState extends State<ManualTransactionScreen> {
  final MockDataService _catalogue = MockDataService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _quantities = <String, int>{};
  String _query = '';
  int _step = 0;
  bool _submitting = false;
  String? _error;
  late final String _idempotencyKey =
      'MANUAL-${DateTime.now().microsecondsSinceEpoch}';

  List<Medicine> get _selected => _catalogue.medicines
      .where((m) => _quantities.containsKey(m.productId))
      .toList();

  List<Medicine> get _filtered {
    final q = _query.trim().toLowerCase();
    return _catalogue.medicines.where((m) {
      if (!m.isActive) return false;
      if (q.isEmpty) return true;
      final searchable =
          '${m.name} ${m.genericName} ${m.productId} ${m.strength} ${m.form} ${m.category} ${m.manufacturer}'
              .toLowerCase();
      return q.split(RegExp(r'\s+')).every(searchable.contains);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(Medicine medicine) {
    setState(() {
      if (_quantities.containsKey(medicine.productId)) {
        _quantities.remove(medicine.productId);
      } else {
        _quantities[medicine.productId] = 1;
      }
    });
  }

  void _next() {
    if (_selected.isEmpty) return;
    setState(() {
      for (final medicine in _selected) {
        _quantities.putIfAbsent(medicine.productId, () => 1);
      }
      _step++;
      _error = null;
    });
  }

  void _changeQuantity(Medicine medicine, int delta) {
    final current = _quantities[medicine.productId] ?? 1;
    final next = current + delta;
    if (next < 1 || next > medicine.currentStock) return;
    setState(() => _quantities[medicine.productId] = next);
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    if (_selected.isEmpty || _quantities.values.any((q) => q < 1)) {
      setState(() => _error = 'Select at least one medicine and enter a valid quantity.');
      return;
    }
    // The catalogue screen may still contain locally seeded/demo quantities.
    // Always verify the authoritative PostgreSQL balance before confirming a sale.
    final backendStock = <String, int>{};
    try {
      final api = ApiClient();
      for (final medicine in List<Medicine>.from(_selected)) {
        Map<String, dynamic> balance;
        try {
          balance = await api.getStockBalanceStrict(
            storeId: 'main_store',
            productId: medicine.productId,
          );
        } on ApiException catch (error) {
          // Older demo medicines were stored only in the Flutter mock
          // catalogue. Migrate that selected record once, using its local
          // opening quantity, so the first real transaction is not lost.
          if (error.statusCode != 404) rethrow;
          final created = await api.createMedicineStrict(_backendPayload(medicine));
          final serverProductId = created['id']?.toString();
          if (serverProductId == null || serverProductId.isEmpty) {
            throw const ApiException('The backend did not return a product ID.');
          }
          if (medicine.currentStock > 0) {
            final openingKey =
                'MIGRATION-$serverProductId-${DateTime.now().microsecondsSinceEpoch}';
            await api.postGoodsReceiptStrict(
              storeId: 'main_store',
              idempotencyKey: openingKey,
              payload: {
                'source_type': 'GOODS_RECEIPT',
                'source_id': openingKey,
                'source_number': openingKey,
                'verified_by': 'pharmacist_operator',
                'items': [
                  {
                    'product_id': serverProductId,
                    'product_name': medicine.name,
                    'batch_number': 'MIGRATION-$serverProductId',
                    'expiry_date': '2099-12',
                    'quantity_entered': medicine.currentStock,
                    'unit_entered': medicine.saleUnit.toLowerCase(),
                  },
                ],
              },
            );
          }
          final migrated = medicine.copyWith(productId: serverProductId);
          _catalogue.updateMedicine(migrated);
          final quantity = _quantities.remove(medicine.productId) ?? 1;
          _quantities[serverProductId] = quantity;
          balance = await api.getStockBalanceStrict(
            storeId: 'main_store',
            productId: serverProductId,
          );
        }
        backendStock[medicine.productId] =
            int.tryParse('${balance['current_stock']}') ?? 0;
        final effectiveId = balance['product_id']?.toString() ?? medicine.productId;
        backendStock[effectiveId] =
            int.tryParse('${balance['current_stock']}') ?? 0;
        if (backendStock[effectiveId] != medicine.currentStock &&
            effectiveId == medicine.productId) {
          _catalogue.updateMedicine(
            medicine.copyWith(currentStock: backendStock[effectiveId]),
          );
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error =
            'This medicine is not connected to the backend catalogue yet. '
            'Add it through Add Medicine or receive its opening stock first. '
            '${error.message}');
      }
      return;
    }

    final invalidStock = _selected.where((m) {
      final available = backendStock[m.productId] ?? 0;
      return (_quantities[m.productId] ?? 0) > available;
    }).toList();
    if (invalidStock.isNotEmpty) {
      final medicine = invalidStock.first;
      final available = backendStock[medicine.productId] ?? 0;
      setState(() => _error =
          'Insufficient backend stock for ${medicine.name}: available '
          '$available ${medicine.saleUnit}, required ${_quantities[medicine.productId]}. '
          'Receive stock before recording a sale.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Manual Stock Out'),
        content: Text(
          'Record a stock-out transaction for ${_selected.length} medicine ${_selected.length == 1 ? 'entry' : 'entries'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient().postSalesDeductionStrict(
        storeId: 'main_store',
        idempotencyKey: _idempotencyKey,
        payload: {
          'source_type': 'MANUAL_TRANSACTION',
          'source_id': _idempotencyKey,
          'source_number': _idempotencyKey,
          'posted_by': 'pharmacist_operator',
          'items': _selected.map((m) => {
            'product_id': m.productId,
            'medicine_name': m.name,
            'quantity_entered': _quantities[m.productId],
            'unit_entered': m.saleUnit,
          }).toList(),
        },
      );
      if (!mounted) return;
      _catalogue.recordManualStockOut(
        quantitiesByProductId: {for (final medicine in _selected) medicine.productId: _quantities[medicine.productId] ?? 0},
        sourceReference: _idempotencyKey,
      );
      setState(() => _step = 3);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Transaction failed: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, dynamic> _backendPayload(Medicine medicine) {
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z%]+)?')
        .firstMatch(medicine.strength.trim());
    final category = switch (medicine.category.trim().toLowerCase()) {
      'derma and skin care' => 'derma',
      'clinic item' => 'clinic',
      'personal care' => 'personal_care',
      'sanitary' => 'sanitary',
      'food' => 'food',
      _ => 'medicine',
    };
    return {
      'catalogue_scope': 'shared',
      'brand_name': medicine.name,
      'generic_name': medicine.genericName,
      'manufacturer': medicine.manufacturer,
      'strength_value': double.tryParse(match?.group(1) ?? ''),
      'strength_unit': match?.group(2)?.toLowerCase(),
      'form': medicine.form.toLowerCase(),
      'category': category,
      'base_unit': medicine.saleUnit.toLowerCase(),
      'unit_conversions': [
        {'pack_unit': medicine.packUnit.toLowerCase(), 'factor': medicine.unitsPerPack},
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          _step == 0
              ? 'Select Medicines'
              : _step == 1
              ? 'Enter Quantities'
              : _step == 2
              ? 'Review Transaction'
              : 'Transaction Posted',
        ),
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        leading: IconButton(
          icon: Icon(_step == 0 || _step == 3 ? Icons.close : Icons.arrow_back),
          onPressed: () => _step == 0 || _step == 3
              ? Navigator.pop(context)
              : setState(() => _step--),
        ),
      ),
      body: AnimatedBuilder(
        animation: _catalogue,
        builder: (context, _) => _step == 0
            ? _selection()
            : _step == 1
            ? _quantityStep()
            : _step == 2
            ? _review()
            : _success(),
      ),
    );
  }

  Widget _selection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search medicine, generic, ID or strength',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_selected.length} selected',
              style: AppTypography.bodyStrong,
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No medicines found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final m = _filtered[index];
                    final selected = _quantities.containsKey(m.productId);
                    return Card(
                      color: AppColors.surface,
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggle(m),
                        activeColor: AppColors.matchaDeep,
                        title: Text(
                          '${m.name} ${m.strength}',
                          style: AppTypography.bodyStrong,
                        ),
                        subtitle: Text(
                          '${m.genericName} • ${m.form} • ${m.currentStock} ${m.saleUnit}s\n'
                          '1 ${m.packUnit} = ${m.unitsPerPack} ${m.saleUnit}s',
                        ),
                        secondary: Text(
                          m.productId,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  },
                ),
        ),
        _bottomButton('Next', _selected.isEmpty ? null : _next),
      ],
    );
  }

  Widget _quantityStep() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _selected
                .map(
                  (m) => Card(
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: AppTypography.bodyStrong),
                                Text(
                                  '${m.strength} • ${m.form} • Stock ${m.currentStock} ${m.saleUnit}s',
                                  style: AppTypography.caption,
                                ),
                                Text(
                                  'Unit: ${m.saleUnit}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _changeQuantity(m, -1),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${_quantities[m.productId]}',
                            style: AppTypography.bodyStrong,
                          ),
                          IconButton(
                            onPressed: () => _changeQuantity(m, 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () =>
                                setState(() => _quantities.remove(m.productId)),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.dangerFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (_error != null) _errorBanner(),
        _bottomButton('Review Transaction', _selected.isEmpty ? null : _next),
      ],
    );
  }

  Widget _review() {
    return _modernReview();
  }
  /* Legacy review layout retained below for reference.
    final totalByUnit = <String, int>{};
    for (final m in _selected)
      totalByUnit[m.saleUnit] =
          (totalByUnit[m.saleUnit] ?? 0) + (_quantities[m.productId] ?? 0);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppColors.surface,
                child: ListTile(
                  title: const Text(
                    'Stock Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Date: ${MaterialLocalizations.of(context).formatMediumDate(DateTime.now())}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._selected.map(
                (m) => ListTile(
                  title: Text(m.name),
                  subtitle: Text(
                    '${m.strength} • ${_quantities[m.productId]} ${m.saleUnit}s',
                  ),
                  trailing: Text('Stock ${m.currentStock}'),
                ),
              ),
              const Divider(),
              Text(
                'Distinct medicines: ${_selected.length}',
                style: AppTypography.bodyStrong,
              ),
              ...totalByUnit.entries.map(
                (e) => Text('Total ${e.key}s: ${e.value}'),
              ),
            ],
          ),
        ),
        if (_error != null) _errorBanner(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Edit Quantities'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _submitting ? null : _confirm,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm Transaction'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  */

  Widget _modernReview() {
    final totals = <String, int>{};
    for (final medicine in _selected) {
      totals[medicine.saleUnit] =
          (totals[medicine.saleUnit] ?? 0) +
          (_quantities[medicine.productId] ?? 0);
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text('Review Transaction', style: AppTypography.screenTitle),
              const SizedBox(height: 4),
              Text('Please verify the details before confirming', style: AppTypography.body.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: 18),
              _modernTransactionBanner(),
              const SizedBox(height: 22),
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.chai.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.medication_outlined, color: AppColors.carob),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Medicines (${_selected.length})', style: AppTypography.section.copyWith(fontSize: 24))),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _step = 1),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ]),
              const SizedBox(height: 12),
              ..._selected.map(_modernMedicineCard),
              const SizedBox(height: 8),
              _modernSummary(totals),
              const SizedBox(height: 16),
              _modernNotice(),
            ],
          ),
        ),
        if (_error != null) _errorBanner(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _step = 1),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Quantities'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _confirm,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: const Text('Confirm Transaction'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _modernTransactionBanner() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.successBg.withOpacity(0.32),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.inventory_2_outlined, size: 34, color: AppColors.matchaDeep),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Stock Out', style: AppTypography.section.copyWith(color: AppColors.matchaDeep)),
            const SizedBox(height: 4),
            Text('Date: ${MaterialLocalizations.of(context).formatMediumDate(DateTime.now())}', style: AppTypography.body.copyWith(color: AppColors.inkSoft)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: AppColors.vanilla, borderRadius: BorderRadius.circular(18)),
            child: const Text('Manual Transaction', style: TextStyle(color: AppColors.carob, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
      );

  Widget _modernMedicineCard(Medicine medicine) {
    final quantity = _quantities[medicine.productId] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outline)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.medication_outlined, size: 34, color: AppColors.matchaDeep),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(medicine.name, style: AppTypography.title.copyWith(fontSize: 21)),
            const SizedBox(height: 4),
            Text('${medicine.strength} • ${medicine.form}', style: AppTypography.body.copyWith(color: AppColors.inkSoft)),
          ])),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.vanilla.withOpacity(0.65), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Current Stock', style: AppTypography.caption.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: 3),
              Text('${medicine.currentStock}', style: AppTypography.title.copyWith(color: AppColors.matchaDeep, fontSize: 22)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.chai.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.grid_view_rounded, color: AppColors.carob),
            const SizedBox(width: 12),
            Text('Quantity', style: AppTypography.bodyStrong),
            const Spacer(),
            Text('$quantity ${medicine.saleUnit}${quantity == 1 ? '' : 's'}', style: AppTypography.bodyStrong.copyWith(color: AppColors.carob)),
          ]),
        ),
      ]),
    );
  }

  Widget _modernSummary(Map<String, int> totals) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.outline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.carob, size: 30),
            const SizedBox(width: 10),
            Text('Transaction Summary', style: AppTypography.section.copyWith(fontSize: 22)),
          ]),
          const SizedBox(height: 14),
          _modernSummaryRow('Distinct medicines', '${_selected.length}', Icons.medication_outlined),
          ...totals.entries.map((entry) => _modernSummaryRow('Total ${entry.key}${entry.value == 1 ? '' : 's'}', '${entry.value}', Icons.inventory_2_outlined)),
        ]),
      );

  Widget _modernSummaryRow(String label, String value, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, color: AppColors.matchaDeep, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTypography.body)),
          Text(value, style: AppTypography.title.copyWith(color: AppColors.matchaDeep, fontSize: 22)),
        ]),
      );

  Widget _modernNotice() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.chai.withOpacity(0.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.chai.withOpacity(0.35))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.carob, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text('This will reduce stock for the selected medicines. Please confirm the quantities are correct before proceeding.', style: AppTypography.body.copyWith(color: AppColors.carob))),
        ]),
      );

  Widget _success() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppColors.successFg, size: 64),
          const SizedBox(height: 12),
          Text(
            'Transaction posted successfully',
            style: AppTypography.screenTitle,
          ),
          const SizedBox(height: 8),
          Text(
            '${_selected.length} medicine entries were recorded in the stock ledger.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
  Widget _errorBanner() => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(_error!, style: const TextStyle(color: AppColors.dangerFg)),
  );
  Widget _bottomButton(String label, VoidCallback? onPressed) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: onPressed, child: Text(label)),
      ),
    ),
  );
}
