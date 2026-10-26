import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/medicine.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/ui/confirm_sheet.dart';
import '../../../core/ui/inline_banner.dart';

/// Design tokens specifically conforming to the Pixel-Precise reference specification.
abstract class _AddMedicineTokens {
  static const Color pageBg = Color(0xFFF8F5EF);
  static const Color surface = Color(0xFFFCFAF6);
  static const Color primary = Color(0xFF285A46);
  static const Color primaryHover = Color(0xFF214A3A);
  static const Color secondaryGreen = Color(0xFF52765A);
  static const Color sage = Color(0xFFE9EEDF);
  static const Color sageBorder = Color(0xFFDDE5D3);
  static const Color textPrimary = Color(0xFF25231F);
  static const Color textSecondary = Color(0xFF898781);
  static const Color labelBrown = Color(0xFF55412B);
  static const Color border = Color(0xFFDEDAD1);
  static const Color requiredColor = Color(0xFFE84C3D);
  static const Color white = Color(0xFFFFFFFF);
  static const Color iconTintBg = Color(0xFFF0EDE5);
  static const Color sageSubText = Color(0xFF65735F);
}

/// Mobile-first Pixel-Precise Add/Edit Medicine Screen matching the design reference.
class AddEditMedicineScreen extends StatefulWidget {
  final Medicine? medicineToEdit;
  const AddEditMedicineScreen({super.key, this.medicineToEdit});

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _generic;
  late final TextEditingController _strength;
  late final TextEditingController _category;
  late final TextEditingController _manufacturer;
  late final TextEditingController _form;
  late final TextEditingController _packUnit;
  late final TextEditingController _saleUnit;
  late final TextEditingController _unitsPerPack;
  late final TextEditingController _openingQuantity;
  late final TextEditingController _threshold;
  late bool _active;
  bool _dirty = false;
  bool _saving = false;
  String? _duplicateWarning;

  bool get _isEdit => widget.medicineToEdit != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medicineToEdit;
    _name = TextEditingController(text: m?.name ?? '');
    _generic = TextEditingController(text: m?.genericName ?? '');
    _strength = TextEditingController(
      text: m?.strength.replaceAll(RegExp(r'[^\d.]'), '') ?? '650',
    );
    _category = TextEditingController(
      text: m?.category.isNotEmpty == true ? m!.category : MedicineCategories.medicine,
    );
    _manufacturer = TextEditingController(text: m?.manufacturer ?? '');
    _form = TextEditingController(
      text: m?.form.isNotEmpty == true ? m!.form : MedicineForms.tablet,
    );
    _packUnit = TextEditingController(
      text: m?.packUnit.isNotEmpty == true ? m!.packUnit : 'Strip',
    );
    _saleUnit = TextEditingController(
      text: m?.saleUnit.isNotEmpty == true ? m!.saleUnit : 'tablet',
    );
    _unitsPerPack = TextEditingController(text: '${m?.unitsPerPack ?? 10}');
    _openingQuantity = TextEditingController(text: '${m?.currentStock ?? 0}');
    _threshold = TextEditingController(text: '${m?.lowStockThreshold ?? 20}');
    _active = m?.isActive ?? true;

    for (final c in [
      _name,
      _generic,
      _strength,
      _category,
      _manufacturer,
      _form,
      _packUnit,
      _saleUnit,
      _unitsPerPack,
      _openingQuantity,
      _threshold,
    ]) {
      c.addListener(() {
        if (mounted && !_dirty) setState(() => _dirty = true);
      });
    }

    _name.addListener(_checkDuplicates);
    _strength.addListener(_checkDuplicates);
    _form.addListener(_checkDuplicates);
  }

  void _checkDuplicates() {
    final name = _name.text.trim().toLowerCase();
    final strength = _strength.text.trim().toLowerCase();
    final form = _form.text.trim().toLowerCase();
    if (name.isEmpty || strength.isEmpty) {
      if (_duplicateWarning != null && mounted) {
        setState(() => _duplicateWarning = null);
      }
      return;
    }
    final exists = MockDataService().medicines.any((medicine) {
      if (!medicine.isActive) return false;
      if (_isEdit && medicine.productId == widget.medicineToEdit!.productId) return false;
      final sameForm =
          medicine.form.trim().toLowerCase() == (form.isEmpty ? 'tablet' : form);
      final medStrNum = medicine.strength.replaceAll(RegExp(r'[^\d.]'), '').trim().toLowerCase();
      final curStrNum = strength.replaceAll(RegExp(r'[^\d.]'), '').trim().toLowerCase();
      final sameStrength =
          medicine.strength.trim().toLowerCase() == strength ||
          (medStrNum.isNotEmpty && medStrNum == curStrNum);
      return medicine.name.trim().toLowerCase() == name &&
          sameStrength &&
          (sameForm || medicine.form.trim().isEmpty);
    });
    final warning = exists
        ? 'An active medicine with the same name, strength, and dosage form already exists.'
        : null;
    if (mounted && warning != _duplicateWarning) {
      setState(() => _duplicateWarning = warning);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _generic,
      _strength,
      _category,
      _manufacturer,
      _form,
      _packUnit,
      _saleUnit,
      _unitsPerPack,
      _openingQuantity,
      _threshold,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_duplicateWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_duplicateWarning!),
          backgroundColor: AppColors.dangerFg,
        ),
      );
      return;
    }

    final units = int.tryParse(_unitsPerPack.text.trim()) ?? 0;
    final openingQuantity = int.tryParse(_openingQuantity.text.trim()) ?? 0;
    final threshold = int.tryParse(_threshold.text.trim()) ?? 0;
    if (units < 1 || openingQuantity < 0 || threshold < 0) return;

    setState(() => _saving = true);
    try {
      final api = ApiClient();
      final strength = _strengthParts();
      final fullStrengthStr = '${_strength.text.trim()}mg';
      final genericValue =
          _generic.text.trim().isNotEmpty ? _generic.text.trim() : _name.text.trim();
      final currentSaleUnit = _saleUnit.text.trim().isNotEmpty
          ? _saleUnit.text.trim().toLowerCase()
          : 'tablet';

      final payload = {
        'catalogue_scope': 'shared',
        'brand_name': _name.text.trim(),
        'generic_name': genericValue,
        'manufacturer': _manufacturer.text.trim(),
        'strength_value': strength.$1,
        'strength_unit': strength.$2 ?? 'mg',
        'form': _form.text.trim().toLowerCase(),
        'category': _categoryValue(),
        'base_unit': currentSaleUnit,
        'unit_conversions': [
          {'pack_unit': _packUnit.text.trim().toLowerCase(), 'factor': units},
        ],
      };

      final service = MockDataService();
      if (_isEdit) {
        await api.updateMedicineStrict(
          productId: widget.medicineToEdit!.productId,
          payload: payload,
        );
        final updated = widget.medicineToEdit!.copyWith(
          name: _name.text.trim(),
          genericName: genericValue,
          strength: fullStrengthStr,
          category: _category.text.trim(),
          manufacturer: _manufacturer.text.trim(),
          form: _form.text.trim(),
          packUnit: _packUnit.text.trim(),
          saleUnit: currentSaleUnit,
          unitsPerPack: units,
          lowStockThreshold: threshold,
          isActive: _active,
        );
        service.updateMedicine(updated);
        _showSaved('${updated.name} updated. Product ID ${updated.productId} was preserved.');
      } else {
        final created = await api.createMedicineStrict(payload);
        final id = created['id']?.toString();
        if (id == null || id.isEmpty) {
          throw const ApiException('The backend did not return the new medicine ID.');
        }

        if (openingQuantity > 0) {
          final openingKey = 'OPENING-$id-${DateTime.now().microsecondsSinceEpoch}';
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
                  'product_id': id,
                  'product_name': _name.text.trim(),
                  'batch_number': 'OPENING-$id',
                  'expiry_date': '2099-12',
                  'quantity_entered': openingQuantity,
                  'unit_entered': currentSaleUnit,
                },
              ],
            },
          );
        }

        final medicine = Medicine(
          productId: id,
          name: _name.text.trim(),
          genericName: genericValue,
          strength: fullStrengthStr,
          category: _category.text.trim(),
          manufacturer: _manufacturer.text.trim(),
          form: _form.text.trim(),
          packUnit: _packUnit.text.trim(),
          saleUnit: currentSaleUnit,
          unitsPerPack: units,
          currentStock: openingQuantity,
          lowStockThreshold: threshold,
          isActive: _active,
        );
        service.addMedicine(medicine);
        _showSaved('${medicine.name} added to the catalogue and database.');
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.dangerFg,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save medicine: $error'),
            backgroundColor: AppColors.dangerFg,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  (double?, String?) _strengthParts() {
    final raw = _strength.text.trim();
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z%]+)?').firstMatch(raw);
    final val = double.tryParse(match?.group(1) ?? raw);
    final unit = match?.group(2)?.toLowerCase() ?? 'mg';
    return (val, unit);
  }

  String _categoryValue() {
    switch (_category.text.trim().toLowerCase()) {
      case 'derma and skin care':
      case 'derma':
        return 'derma';
      case 'clinic item':
      case 'clinic':
        return 'clinic';
      case 'personal care':
      case 'personal_care':
        return 'personal_care';
      case 'sanitary':
        return 'sanitary';
      case 'food':
        return 'food';
      default:
        return 'medicine';
    }
  }

  void _showSaved(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _AddMedicineTokens.primary,
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final result = await ConfirmSheet.show(
      context,
      title: 'Discard Changes?',
      message:
          'You have unsaved changes in this medicine record. Are you sure you want to discard them?',
      confirmLabel: 'Discard',
      isDestructive: true,
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: _AddMedicineTokens.pageBg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final maxContentWidth = constraints.maxWidth > 480 ? 480.0 : constraints.maxWidth;

              return Center(
                child: SizedBox(
                  width: maxContentWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isNarrow),
                          const SizedBox(height: 20),

                          if (_isEdit) ...[
                            _buildProductBanner(),
                            const SizedBox(height: 18),
                          ],

                          if (_duplicateWarning != null) ...[
                            InlineBanner(
                              message: _duplicateWarning!,
                              type: BannerType.warning,
                            ),
                            const SizedBox(height: 18),
                          ],

                          // SECTION 1: MEDICINE DETAILS
                          _buildMedicineDetailsSection(isNarrow),
                          const SizedBox(height: 20),

                          // SECTION 2: PACK & UNIT CONFIGURATION CARD
                          _buildPackUnitConfigCard(isNarrow),
                          const SizedBox(height: 20),

                          // SECTION 3: OPENING QUANTITY
                          _buildOpeningQuantitySection(),
                          const SizedBox(height: 18),

                          // SECTION 4: LOW STOCK THRESHOLD & STATUS
                          _buildThresholdAndStatusSection(isNarrow),
                          const SizedBox(height: 22),

                          // SECTION 5: PRIMARY ACTION BUTTON
                          _buildAddMedicineButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. REFINED MOBILE HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader(bool isNarrow) {
    final titleFontSize = isNarrow ? 22.0 : 25.0;
    final illustrationSize = isNarrow ? 56.0 : 76.0;

    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular warm-beige back button
          InkWell(
            onTap: () async {
              if (await _confirmExit() && mounted) Navigator.of(context).pop();
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFE8DB),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _AddMedicineTokens.border, width: 1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 22,
                color: _AddMedicineTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Medicine' : 'Add Medicine',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: _AddMedicineTokens.textPrimary,
                    height: 31 / 25,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? 'Update medicine details in your inventory'
                      : 'Add medicine details to your inventory',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _AddMedicineTokens.textSecondary,
                    height: 19 / 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Header Capsule Medical Illustration
          Container(
            width: illustrationSize,
            height: illustrationSize,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EBDD),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -0.6,
                  child: Container(
                    width: isNarrow ? 36 : 46,
                    height: isNarrow ? 20 : 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _AddMedicineTokens.secondaryGreen,
                        width: 2.2,
                      ),
                      color: _AddMedicineTokens.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: _AddMedicineTokens.secondaryGreen,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(9),
                                bottomLeft: Radius.circular(9),
                              ),
                            ),
                          ),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: isNarrow ? 6 : 8,
                  bottom: isNarrow ? 6 : 8,
                  child: Container(
                    width: isNarrow ? 12 : 14,
                    height: isNarrow ? 12 : 14,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDFD4C0),
                      shape: BoxShape.circle,
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

  // ---------------------------------------------------------------------------
  // PRODUCT ID BANNER (For Edit Mode)
  // ---------------------------------------------------------------------------
  Widget _buildProductBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AddMedicineTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AddMedicineTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _AddMedicineTokens.sage,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.view_in_ar_outlined,
              size: 24,
              color: _AddMedicineTokens.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product ID',
                  style: TextStyle(
                    fontSize: 12,
                    color: _AddMedicineTokens.textSecondary,
                  ),
                ),
                Text(
                  widget.medicineToEdit!.productId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _AddMedicineTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EDE4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Permanent',
              style: TextStyle(
                color: _AddMedicineTokens.labelBrown,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. MEDICINE DETAILS SECTION
  // ---------------------------------------------------------------------------
  Widget _buildMedicineDetailsSection(bool isNarrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field 1: Name (Required, Full width, single field)
        _buildInputField(
          label: 'Name',
          isRequired: true,
          controller: _name,
          hint: 'e.g. Paracetamol',
          leadingIcon: Icons.medication_outlined,
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Medicine name is required' : null,
        ),
        const SizedBox(height: 18),

        // Fields 2 and 3: Strength / Dosage Form (2-column grid)
        _buildTwoColumnPair(
          isNarrow: isNarrow,
          first: _buildInputField(
            label: 'Strength',
            isRequired: true,
            controller: _strength,
            hint: 'e.g. 650',
            trailingText: 'mg',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Strength is required' : null,
          ),
          second: _buildDropdownField(
            label: 'Dosage Form',
            isRequired: true,
            controller: _form,
            items: MedicineForms.all,
          ),
        ),
        const SizedBox(height: 18),

        // Fields 4 and 5: Category / Manufacturer (2-column grid)
        _buildTwoColumnPair(
          isNarrow: isNarrow,
          first: _buildDropdownField(
            label: 'Category',
            isRequired: true,
            controller: _category,
            items: MedicineCategories.all,
            leadingIcon: Icons.folder_outlined,
          ),
          second: _buildInputField(
            label: 'Manufacturer',
            isRequired: true,
            controller: _manufacturer,
            hint: 'e.g. GSK Pharmaceuticals',
            leadingIcon: Icons.local_pharmacy_outlined,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Manufacturer is required' : null,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. PACK & UNIT CONFIGURATION CARD
  // ---------------------------------------------------------------------------
  Widget _buildPackUnitConfigCard(bool isNarrow) {
    final packUnitsList = const ['Strip', 'Bottle', 'Box', 'Packet', 'Tube', 'Vial'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AddMedicineTokens.sage,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AddMedicineTokens.sageBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(57, 49, 34, 0.035),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE4CF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 24,
                  color: _AddMedicineTokens.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Pack & Unit Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _AddMedicineTokens.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Define how the medicine is packed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _AddMedicineTokens.sageSubText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Two fields: Pack Unit and Units per Pack (Sale Unit completely removed)
          _buildTwoColumnPair(
            isNarrow: isNarrow,
            first: _buildDropdownField(
              label: 'Pack Unit',
              isRequired: true,
              controller: _packUnit,
              items: packUnitsList,
              leadingIcon: Icons.all_inbox_outlined,
            ),
            second: _buildInputField(
              label: 'Units per Pack',
              isRequired: true,
              controller: _unitsPerPack,
              hint: '10',
              leadingIcon: Icons.grid_view_rounded,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1) return 'Must be >= 1';
                return null;
              },
            ),
          ),
          const SizedBox(height: 14),

          // Informational Message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: _AddMedicineTokens.secondaryGreen,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stock is always tracked in smallest sale units. Inward purchasing uses pack units.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _AddMedicineTokens.textPrimary,
                      height: 18 / 12,
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

  // ---------------------------------------------------------------------------
  // 4. OPENING QUANTITY SECTION
  // ---------------------------------------------------------------------------
  Widget _buildOpeningQuantitySection() {
    final saleUnitDisplay = _saleUnit.text.trim().isNotEmpty
        ? _saleUnit.text.trim().toLowerCase()
        : 'tablet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _AddMedicineTokens.iconTintBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.layers_outlined,
                size: 22,
                color: _AddMedicineTokens.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Opening Quantity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _AddMedicineTokens.labelBrown,
                height: 1.25,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Input
        TextFormField(
          controller: _openingQuantity,
          readOnly: _isEdit,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: _AddMedicineTokens.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: _AddMedicineTokens.textSecondary,
            ),
            suffixText: saleUnitDisplay,
            suffixStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _AddMedicineTokens.textSecondary,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            fillColor: _AddMedicineTokens.surface,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AddMedicineTokens.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AddMedicineTokens.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _AddMedicineTokens.secondaryGreen,
                width: 1.5,
              ),
            ),
          ),
          validator: (v) {
            final n = int.tryParse(v?.trim() ?? '');
            if (n == null || n < 0) return 'Quantity must be 0 or greater';
            return null;
          },
        ),
        const SizedBox(height: 6),
        Text(
          _isEdit
              ? 'Use Purchase Invoice or Receive Stock to change inventory.'
              : 'Initial stock in the smallest sale unit.',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _AddMedicineTokens.textSecondary,
            height: 18 / 12,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. LOW STOCK THRESHOLD & STATUS SECTION
  // ---------------------------------------------------------------------------
  Widget _buildThresholdAndStatusSection(bool isNarrow) {
    final saleUnitDisplay = _saleUnit.text.trim().isNotEmpty
        ? _saleUnit.text.trim().toLowerCase()
        : 'tablet';

    return _buildTwoColumnPair(
      isNarrow: isNarrow,
      first: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Low Stock Threshold', false),
          const SizedBox(height: 8),
          TextFormField(
            controller: _threshold,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: _AddMedicineTokens.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '20',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: _AddMedicineTokens.textSecondary,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(7),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _AddMedicineTokens.iconTintBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 18,
                  color: _AddMedicineTokens.primary,
                ),
              ),
              suffixText: saleUnitDisplay,
              suffixStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _AddMedicineTokens.textSecondary,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              fillColor: _AddMedicineTokens.surface,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _AddMedicineTokens.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _AddMedicineTokens.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: _AddMedicineTokens.secondaryGreen,
                  width: 1.5,
                ),
              ),
            ),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              if (n == null || n < 0) return 'Must be >= 0';
              return null;
            },
          ),
        ],
      ),
      second: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Status', false),
          const SizedBox(height: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _AddMedicineTokens.sageBorder, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _AddMedicineTokens.iconTintBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    size: 18,
                    color: _AddMedicineTokens.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _active ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _AddMedicineTokens.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: _active,
                  activeColor: _AddMedicineTokens.white,
                  activeTrackColor: _AddMedicineTokens.primary,
                  inactiveThumbColor: _AddMedicineTokens.textSecondary,
                  inactiveTrackColor: const Color(0xFFDEDAD1),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) {
                    setState(() {
                      _active = val;
                      _dirty = true;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. PRIMARY ACTION BUTTON
  // ---------------------------------------------------------------------------
  Widget _buildAddMedicineButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: _AddMedicineTokens.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(40, 90, 70, 0.25),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : _save,
          borderRadius: BorderRadius.circular(16),
          splashColor: _AddMedicineTokens.primaryHover,
          highlightColor: _AddMedicineTokens.primaryHover,
          child: Center(
            child: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: _AddMedicineTokens.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _isEdit ? Icons.check_rounded : Icons.add_rounded,
                          size: 20,
                          color: _AddMedicineTokens.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isEdit ? 'Update Medicine' : 'Add Medicine',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _AddMedicineTokens.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REUSABLE FIELD BUILDERS
  // ---------------------------------------------------------------------------
  Widget _buildFieldLabel(String text, bool isRequired) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _AddMedicineTokens.labelBrown,
            height: 20 / 14,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _AddMedicineTokens.requiredColor,
              height: 20 / 14,
            ),
          ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required bool isRequired,
    required TextEditingController controller,
    required String hint,
    IconData? leadingIcon,
    String? trailingText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: _AddMedicineTokens.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: _AddMedicineTokens.textSecondary,
            ),
            prefixIcon: leadingIcon != null
                ? Container(
                    margin: const EdgeInsets.all(7),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _AddMedicineTokens.iconTintBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      leadingIcon,
                      size: 18,
                      color: _AddMedicineTokens.primary,
                    ),
                  )
                : null,
            suffixText: trailingText,
            suffixStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _AddMedicineTokens.textSecondary,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            fillColor: _AddMedicineTokens.surface,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AddMedicineTokens.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AddMedicineTokens.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _AddMedicineTokens.secondaryGreen,
                width: 1.5,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required bool isRequired,
    required TextEditingController controller,
    required List<String> items,
    IconData? leadingIcon,
  }) {
    final value = items.contains(controller.text) ? controller.text : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label, isRequired),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: _AddMedicineTokens.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _AddMedicineTokens.textPrimary,
          ),
          dropdownColor: _AddMedicineTokens.surface,
          decoration: InputDecoration(
            prefixIcon: leadingIcon != null
                ? Container(
                    margin: const EdgeInsets.all(7),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _AddMedicineTokens.iconTintBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      leadingIcon,
                      size: 18,
                      color: _AddMedicineTokens.primary,
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            fillColor: _AddMedicineTokens.surface,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AddMedicineTokens.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AddMedicineTokens.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _AddMedicineTokens.secondaryGreen,
                width: 1.5,
              ),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _AddMedicineTokens.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (newVal) {
            if (newVal != null) {
              setState(() {
                controller.text = newVal;
                _dirty = true;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildTwoColumnPair({
    required bool isNarrow,
    required Widget first,
    required Widget second,
  }) {
    if (isNarrow) {
      return Column(
        children: [
          first,
          const SizedBox(height: 18),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }
}
