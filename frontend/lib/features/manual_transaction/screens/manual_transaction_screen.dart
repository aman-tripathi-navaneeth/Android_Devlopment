import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/medicine.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../sales/models/sales_report.dart';
import '../../sales/services/mock_sales_ocr_adapter.dart';

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
  final Map<String, TextEditingController> _stripControllers = <String, TextEditingController>{};
  final Map<String, TextEditingController> _tabletControllers = <String, TextEditingController>{};
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
    for (final c in _stripControllers.values) {
      c.dispose();
    }
    for (final c in _tabletControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggle(Medicine medicine) {
    setState(() {
      if (_quantities.containsKey(medicine.productId)) {
        _quantities.remove(medicine.productId);
        _stripControllers.remove(medicine.productId)?.dispose();
        _tabletControllers.remove(medicine.productId)?.dispose();
      } else {
        _quantities[medicine.productId] = 1;
        final factor = medicine.unitsPerPack > 0 ? medicine.unitsPerPack : 1;
        _stripControllers[medicine.productId] =
            TextEditingController(text: '${1 ~/ factor}');
        _tabletControllers[medicine.productId] =
            TextEditingController(text: '${1 % factor}');
      }
    });
  }

  void _onQuantityFieldChanged(Medicine medicine) {
    final stripText = _stripControllers[medicine.productId]?.text.trim() ?? '';
    final tabletText = _tabletControllers[medicine.productId]?.text.trim() ?? '';
    final strips = int.tryParse(stripText) ?? 0;
    final tablets = int.tryParse(tabletText) ?? 0;
    final factor = medicine.unitsPerPack > 0 ? medicine.unitsPerPack : 1;
    final total = (strips * factor) + tablets;

    setState(() {
      _quantities[medicine.productId] = total;
      if (total > medicine.currentStock) {
        _error = 'Requested $total ${medicine.saleUnit}s exceeds available stock of ${medicine.currentStock} for ${medicine.name}.';
      } else {
        _error = null;
      }
    });
  }

  void _next() {
    if (_selected.isEmpty) return;

    for (final medicine in _selected) {
      final current = _quantities[medicine.productId] ?? 1;
      final factor = medicine.unitsPerPack > 0 ? medicine.unitsPerPack : 1;
      _stripControllers.putIfAbsent(
        medicine.productId,
        () => TextEditingController(text: '${current ~/ factor}'),
      );
      _tabletControllers.putIfAbsent(
        medicine.productId,
        () => TextEditingController(text: '${current % factor}'),
      );
    }

    if (_step == 1) {
      for (final medicine in _selected) {
        final total = _quantities[medicine.productId] ?? 0;
        if (total <= 0) {
          setState(() => _error = 'Enter a valid quantity greater than 0 for ${medicine.name}.');
          return;
        }
        if (total > medicine.currentStock) {
          setState(() => _error = 'Requested $total ${medicine.saleUnit}s exceeds available stock (${medicine.currentStock}) for ${medicine.name}.');
          return;
        }
      }
    }

    setState(() {
      _step++;
      _error = null;
    });
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
      final result = await ApiClient().postSalesDeductionStrict(
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

      // Register the counter sale in the Sales Hub so it appears in reports
      final txId = result['transaction_id']?.toString() ?? result['id']?.toString() ?? _idempotencyKey;
      final saleId = txId.startsWith('SR-') ? txId : 'SR-$txId';
      final saleReport = SalesReport(
        id: saleId,
        reportReference: _idempotencyKey,
        reportDate: DateTime.now(),
        status: SalesReportStatus.posted,
        selectedFileName: 'Counter Sale',
        selectedFileSize: '—',
        authorizer: 'pharmacist_operator',
        transactionReference: txId,
        isSimulated: false,
        isCounterSale: true,
        lines: _selected.map((m) {
          final qty = _quantities[m.productId] ?? 0;
          return SalesLineItem(
            id: '$saleId-${m.productId}',
            originalOcrText: '${m.name} $qty ${m.saleUnit}',
            matchedProductId: m.productId,
            matchedProductName: m.name,
            genericName: m.genericName,
            confidenceScore: 1.0,
            quantity: qty,
            unit: m.saleUnit,
            unitsPerPack: m.unitsPerPack,
            packUnit: m.packUnit,
            reviewStatus: SalesLineReviewStatus.accepted,
          );
        }).toList(),
      );
      MockSalesOcrAdapter().addCounterSaleReport(saleReport);
      try {
        await MockSalesOcrAdapter().syncReportsFromBackend();
        await MockDataService().syncFromBackend();
      } catch (_) {}

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
    final grandTotalUnits = _selected.fold<int>(
      0,
      (sum, m) => sum + (_quantities[m.productId] ?? 0),
    );

    return Column(
      children: [
        // Refined summary header card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.matchaDeep.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: AppColors.matchaDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selected.length} ${_selected.length == 1 ? 'Medicine' : 'Medicines'} Selected',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Adjust strips and tablets to deduct from inventory',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.matchaDeep,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$grandTotalUnits units',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: _selected.map(_medicineQuantityCard).toList(),
          ),
        ),
        if (_error != null) _errorBanner(),
        _bottomButton('Review Transaction', _selected.isEmpty ? null : _next),
      ],
    );
  }

  void _adjustQuantity(Medicine medicine, {required bool isPack, required int delta}) {
    final sCtrl = _stripControllers[medicine.productId];
    final tCtrl = _tabletControllers[medicine.productId];
    int strips = int.tryParse(sCtrl?.text.trim() ?? '0') ?? 0;
    int tablets = int.tryParse(tCtrl?.text.trim() ?? '0') ?? 0;

    if (isPack) {
      strips = (strips + delta).clamp(0, 9999);
      sCtrl?.text = '$strips';
    } else {
      tablets = (tablets + delta).clamp(0, 9999);
      tCtrl?.text = '$tablets';
    }
    _onQuantityFieldChanged(medicine);
  }

  Widget _buildUnitStepperBox({
    required String label,
    required String unitLabel,
    required IconData icon,
    required TextEditingController controller,
    required bool canDecrement,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.inkSoft),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Minus button
              Material(
                color: canDecrement
                    ? AppColors.surface
                    : AppColors.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: canDecrement ? onMinus : null,
                  child: Container(
                    width: 30,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: canDecrement
                            ? AppColors.outline
                            : AppColors.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 16,
                      color: canDecrement
                          ? AppColors.ink
                          : AppColors.inkSoft.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Center TextField
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: AppColors.inkSoft.withValues(alpha: 0.4),
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 4),
              // Plus button
              Material(
                color: AppColors.matchaDeep.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onPlus,
                  child: Container(
                    width: 30,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.matchaDeep.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: AppColors.matchaDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              unitLabel,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicineQuantityCard(Medicine m) {
    final factor = m.unitsPerPack > 0 ? m.unitsPerPack : 1;
    final currentTotal = _quantities[m.productId] ?? 1;

    final stripController = _stripControllers.putIfAbsent(
      m.productId,
      () => TextEditingController(text: '${currentTotal ~/ factor}'),
    );
    final tabletController = _tabletControllers.putIfAbsent(
      m.productId,
      () => TextEditingController(text: '${currentTotal % factor}'),
    );

    final total = _quantities[m.productId] ?? 0;
    final isExceeded = total > m.currentStock;
    final isZero = total <= 0;
    final packLabel = m.packUnit.isNotEmpty ? m.packUnit : 'strip';
    final saleLabel = m.saleUnit.isNotEmpty ? m.saleUnit : 'tablet';

    final stripsVal = int.tryParse(stripController.text.trim()) ?? 0;
    final tabletsVal = int.tryParse(tabletController.text.trim()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExceeded ? AppColors.dangerFg : AppColors.outline,
          width: isExceeded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isExceeded
                      ? AppColors.dangerBg
                      : AppColors.vanilla.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  size: 20,
                  color: isExceeded ? AppColors.dangerFg : AppColors.carob,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: AppTypography.bodyStrong.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _pill(m.strength, AppColors.chai.withValues(alpha: 0.35)),
                        _pill(m.form, AppColors.pistache.withValues(alpha: 0.45)),
                        _pill(
                          'Stock: ${m.currentStock} ${m.saleUnit}s',
                          isExceeded
                              ? AppColors.dangerBg
                              : AppColors.almond.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.sync_alt_rounded,
                          size: 11,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '1 $packLabel = $factor $saleLabel${factor > 1 ? 's' : ''}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.inkSoft,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: AppColors.dangerFg.withValues(alpha: 0.08),
                shape: const CircleBorder(),
                child: Tooltip(
                  message: 'Remove',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        _quantities.remove(m.productId);
                        _stripControllers.remove(m.productId)?.dispose();
                        _tabletControllers.remove(m.productId)?.dispose();
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.dangerFg,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Two separate editable stepper boxes: Strips & Tablets
          Row(
            children: [
              // 1. Strips / Packs Field
              Expanded(
                child: _buildUnitStepperBox(
                  label: '${packLabel[0].toUpperCase()}${packLabel.substring(1)}s',
                  unitLabel: packLabel,
                  icon: Icons.inventory_2_outlined,
                  controller: stripController,
                  canDecrement: stripsVal > 0,
                  onMinus: () => _adjustQuantity(m, isPack: true, delta: -1),
                  onPlus: () => _adjustQuantity(m, isPack: true, delta: 1),
                  onChanged: (_) => _onQuantityFieldChanged(m),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Tablets / Loose Field
              Expanded(
                child: _buildUnitStepperBox(
                  label: '${saleLabel[0].toUpperCase()}${saleLabel.substring(1)}s',
                  unitLabel: saleLabel,
                  icon: Icons.circle_outlined,
                  controller: tabletController,
                  canDecrement: tabletsVal > 0,
                  onMinus: () => _adjustQuantity(m, isPack: false, delta: -1),
                  onPlus: () => _adjustQuantity(m, isPack: false, delta: 1),
                  onChanged: (_) => _onQuantityFieldChanged(m),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Total display row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isExceeded
                  ? AppColors.dangerBg.withValues(alpha: 0.5)
                  : isZero
                      ? AppColors.chai.withValues(alpha: 0.15)
                      : AppColors.successBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExceeded
                    ? AppColors.dangerFg.withValues(alpha: 0.4)
                    : isZero
                        ? AppColors.chai.withValues(alpha: 0.4)
                        : AppColors.matchaDeep.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExceeded
                      ? Icons.error_outline_rounded
                      : isZero
                          ? Icons.info_outline_rounded
                          : Icons.check_circle_rounded,
                  size: 16,
                  color: isExceeded
                      ? AppColors.dangerFg
                      : isZero
                          ? AppColors.carob
                          : AppColors.successFg,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isExceeded
                        ? 'Total: $total $saleLabel${total == 1 ? '' : 's'} (Exceeds stock of ${m.currentStock})'
                        : isZero
                            ? 'Enter strips or tablets (Current total: 0)'
                            : stripsVal > 0 && tabletsVal > 0
                                ? 'Total: ($stripsVal × $factor) + $tabletsVal = $total $saleLabel${total == 1 ? '' : 's'}'
                                : 'Total: $total $saleLabel${total == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isExceeded
                          ? AppColors.dangerFg
                          : isZero
                              ? AppColors.carob
                              : AppColors.successFg,
                    ),
                  ),
                ),
                if (!isExceeded && !isZero)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${m.currentStock - total} left',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              // Compact summary card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.successBg.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.matchaDeep,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Manual Counter Sale',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.matchaDeep)),
                          Text('$dateStr • ${_selected.length} medicine${_selected.length == 1 ? '' : 's'} • ${totals.entries.map((e) => '${e.value} ${e.key}').join(', ')}',
                              style: AppTypography.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Medicines', style: AppTypography.section.copyWith(fontSize: 15)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _step = 1),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: EdgeInsets.zero),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ..._selected.map(_compactMedicineRow),
              const SizedBox(height: 4),
              // Info notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.chai.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.chai.withOpacity(0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.carob, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stock will be reduced on confirmation. Please verify quantities.',
                      style: AppTypography.caption.copyWith(color: AppColors.carob),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
        if (_error != null) _errorBanner(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : () => setState(() => _step = 1),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _confirm,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(_submitting ? 'Posting…' : 'Confirm Stock Out'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _compactMedicineRow(Medicine medicine) {
    final quantity = _quantities[medicine.productId] ?? 0;
    final remaining = medicine.currentStock - quantity;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.name,
                    style: AppTypography.bodyStrong.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  children: [
                    _pill('${medicine.strength}', AppColors.chai),
                    _pill(medicine.form, AppColors.matcha.withOpacity(0.5)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Remaining after: $remaining ${medicine.saleUnit}',
                    style: AppTypography.caption.copyWith(
                        color: remaining < 5
                            ? AppColors.dangerFg
                            : AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.matchaDeep,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$quantity ${medicine.saleUnit}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.carob)),
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
  Widget _bottomButton(String label, VoidCallback? onPressed) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: const Border(
        top: BorderSide(color: AppColors.outline, width: 1.0),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.matchaDeep,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}
