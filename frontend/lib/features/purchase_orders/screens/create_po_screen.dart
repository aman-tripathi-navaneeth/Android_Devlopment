import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/medicine.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../../core/ui/line_item_tile.dart';
import '../../../core/ui/quantity_stepper.dart';
import '../../../core/ui/confirm_sheet.dart';
import '../../suppliers/widgets/supplier_picker_sheet.dart';
import '../../catalogue/widgets/medicine_picker_sheet.dart';
import 'po_review_screen.dart';

/// S5: CREATE / EDIT DRAFT PURCHASE ORDER SCREEN - Section 10.4.3
class CreatePOScreen extends StatefulWidget {
  final Supplier? preselectedSupplier;

  const CreatePOScreen({super.key, this.preselectedSupplier});

  @override
  State<CreatePOScreen> createState() => _CreatePOScreenState();
}

class _CreatePOScreenState extends State<CreatePOScreen> {
  Supplier? _selectedSupplier;
  final List<POLineItem> _items = [];
  final TextEditingController _notesController = TextEditingController();
  DateTime? _expectedDeliveryDate;

  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _selectedSupplier = widget.preselectedSupplier;
    _notesController.addListener(() {
      if (!_isDirty) setState(() => _isDirty = true);
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _runningTotal =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  Future<bool> _onWillPop() async {
    if (!_isDirty && _items.isEmpty) return true;
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Discard Order Draft?',
      message: 'You have un-saved items in this draft order. Are you sure you want to discard them?',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      isDestructive: true,
    );
    return confirmed == true;
  }

  void _addOrEditMedicine(Medicine med) {
    // Check for duplicate medicine line
    final existingIndex = _items.indexWhere(
      (item) => item.productId == med.productId,
    );
    if (existingIndex != -1) {
      _showLineEditDialog(_items[existingIndex], existingIndex);
      return;
    }

    _showLineAddDialog(med);
  }

  void _showLineAddDialog(Medicine med) {
    int quantity = 10;
    double rate = 50.0;
    final rateController = TextEditingController(text: '50.00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Line Item',
                    style: AppTypography.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${med.name} (${med.strength}) • ${med.productId}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity (${med.packUnit})',
                        style: AppTypography.label,
                      ),
                      QuantityStepper(
                        value: quantity,
                        min: 1,
                        unitLabel: med.packUnit,
                        onChanged: (val) => setModalState(() => quantity = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expected Rate per ${med.packUnit} (₹)',
                    style: AppTypography.label,
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(prefixText: '₹ '),
                    onChanged: (val) {
                      rate = double.tryParse(val) ?? 0.0;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Line Total:', style: AppTypography.label),
                      Text(
                        '₹${(quantity * rate).toStringAsFixed(2)}',
                        style: AppTypography.tabularNumbersLarge.copyWith(
                          color: AppColors.matchaDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (quantity <= 0 || rate < 0) return;
                      setState(() {
                        _items.add(
                          POLineItem(
                            lineId:
                                'line-${DateTime.now().millisecondsSinceEpoch}',
                            productId: med.productId,
                            productName: '${med.name} ${med.strength}',
                            unitOfPurchase: med.packUnit,
                            orderedQuantity: quantity,
                            expectedUnitRate: rate,
                            lineTotal: quantity * rate,
                          ),
                        );
                        _isDirty = true;
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Add to Order'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLineEditDialog(POLineItem line, int index) {
    int quantity = line.orderedQuantity;
    double rate = line.expectedUnitRate;
    final rateController = TextEditingController(text: rate.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Line Item',
                    style: AppTypography.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${line.productName} • ${line.productId}',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity (${line.unitOfPurchase})',
                        style: AppTypography.label,
                      ),
                      QuantityStepper(
                        value: quantity,
                        min: 1,
                        unitLabel: line.unitOfPurchase,
                        onChanged: (val) => setModalState(() => quantity = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expected Rate per ${line.unitOfPurchase} (₹)',
                    style: AppTypography.label,
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(prefixText: '₹ '),
                    onChanged: (val) {
                      rate = double.tryParse(val) ?? 0.0;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _items[index] = line.copyWith(
                          orderedQuantity: quantity,
                          expectedUnitRate: rate,
                          lineTotal: quantity * rate,
                        );
                        _isDirty = true;
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Update Line Item'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _goToReview() {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier first')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medicine item')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => POReviewScreen(
          supplier: _selectedSupplier!,
          items: List.from(_items),
          orderDate: DateTime.now(),
          expectedDeliveryDate: _expectedDeliveryDate,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      ),
    );
  }

  void _saveDraft() {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier first')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medicine item')),
      );
      return;
    }

    final service = MockDataService();
    final newPoNumber = 'PO-2026-${(service.purchaseOrders.length + 100001)}';

    final po = PurchaseOrder(
      id: 'po-${DateTime.now().millisecondsSinceEpoch}',
      purchaseOrderNumber: newPoNumber,
      supplierId: _selectedSupplier!.id,
      supplierName: _selectedSupplier!.name,
      orderDate: DateTime.now(),
      expectedDeliveryDate: _expectedDeliveryDate,
      status: POStatus.draft,
      items: _items,
      totalAmount: _runningTotal,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    service.createPurchaseOrder(po);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Draft order $newPoNumber created successfully! Stock is unchanged.',
        ),
        backgroundColor: AppColors.matchaDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppTopBar(
          title: strings.createDraftPO,
          showLanguageToggle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
        ),
        bottomNavigationBar: StickyActionBar(
          primaryLabel: strings.reviewOrder,
          secondaryLabel: strings.saveAsDraft,
          runningTotal: _runningTotal,
          totalLabel: strings.estimatedTotalLabel,
          onPrimaryPressed: _items.isNotEmpty && _selectedSupplier != null
              ? _goToReview
              : null,
          onSecondaryPressed: _items.isNotEmpty && _selectedSupplier != null
              ? _saveDraft
              : null,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SUPPLIER SELECTOR
              Text(
                '1. ${strings.selectSupplier} *',
                style: AppTypography.section,
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline, width: 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  leading: const Icon(
                    Icons.store_rounded,
                    color: AppColors.matchaDeep,
                  ),
                  title: Text(
                    _selectedSupplier?.name ?? 'Choose an active supplier…',
                    style: _selectedSupplier != null
                        ? AppTypography.bodyStrong
                        : AppTypography.body.copyWith(color: AppColors.inkSoft),
                  ),
                  subtitle: _selectedSupplier != null
                      ? Text(
                          '${_selectedSupplier!.supplierCode} • Terms: ${_selectedSupplier!.paymentTerms ?? 'Net 30'}',
                          style: AppTypography.caption,
                        )
                      : null,
                  trailing: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.ink,
                  ),
                  onTap: () async {
                    final chosen = await SupplierPickerSheet.show(context);
                    if (chosen != null) {
                      setState(() {
                        _selectedSupplier = chosen;
                        _isDirty = true;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),

              // 2. MEDICINE ITEMS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '2. Order Lines (${_items.length})',
                    style: AppTypography.section,
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(strings.addLineItem),
                    onPressed: () async {
                      final med = await MedicinePickerSheet.show(context);
                      if (med != null) {
                        _addOrEditMedicine(med);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline, width: 1),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 32,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No medicines added yet',
                          style: AppTypography.bodyStrong,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "+ Add Medicine" to pick from the catalogue',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: LineItemTile(
                      productName: item.productName,
                      productId: item.productId,
                      unit: item.unitOfPurchase,
                      quantity: item.orderedQuantity,
                      rate: item.expectedUnitRate,
                      onEdit: () => _showLineEditDialog(item, index),
                      onRemove: () {
                        setState(() {
                          _items.removeAt(index);
                          _isDirty = true;
                        });
                      },
                    ),
                  );
                }).toList(),

              const SizedBox(height: 20),

              // 3. EXPECTED DELIVERY DATE
              Text(
                '3. ${strings.expectedDeliveryDate} (Optional)',
                style: AppTypography.section,
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outline, width: 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  leading: const Icon(
                    Icons.event_outlined,
                    color: AppColors.matchaDeep,
                  ),
                  title: Text(
                    _expectedDeliveryDate != null
                        ? '${_expectedDeliveryDate!.day}/${_expectedDeliveryDate!.month}/${_expectedDeliveryDate!.year}'
                        : 'Choose estimated delivery date…',
                    style: _expectedDeliveryDate != null
                        ? AppTypography.bodyStrong
                        : AppTypography.body.copyWith(color: AppColors.inkSoft),
                  ),
                  trailing: _expectedDeliveryDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => _expectedDeliveryDate = null),
                        )
                      : const Icon(Icons.arrow_drop_down, color: AppColors.ink),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _expectedDeliveryDate ??
                          now.add(const Duration(days: 3)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _expectedDeliveryDate = picked;
                        _isDirty = true;
                      });
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 4. NOTES
              Text(
                '4. ${strings.notes} (Optional)',
                style: AppTypography.section,
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'e.g. Urgent stock needed, deliver before Friday',
                ),
              ),

              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.vanilla.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outline, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      size: 18,
                      color: AppColors.carob,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Golden Rule G2: Creating or saving a purchase order never modifies stock balances.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.carob,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
