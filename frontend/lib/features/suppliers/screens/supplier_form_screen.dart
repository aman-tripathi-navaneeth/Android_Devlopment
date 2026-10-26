import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/models/supplier.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../../core/ui/confirm_sheet.dart';

/// S2: ADD / EDIT SUPPLIER SCREEN - Section 10.4.3
class SupplierFormScreen extends StatefulWidget {
  final Supplier? supplierToEdit;

  const SupplierFormScreen({super.key, this.supplierToEdit});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _notesController;
  late final TextEditingController _gstController;
  late final TextEditingController _paymentTermsController;
  late bool _isActive;

  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    final s = widget.supplierToEdit;
    _nameController = TextEditingController(text: s?.name ?? '');
    _contactController = TextEditingController(text: s?.contactPerson ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _cityController = TextEditingController(text: s?.city ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');
    _gstController = TextEditingController(text: s?.gstNumber ?? '');
    _paymentTermsController = TextEditingController(
      text: s?.paymentTerms ?? 'Net 30',
    );
    _isActive = s?.isActive ?? true;

    _nameController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
    _gstController.addListener(_markDirty);
    _cityController.addListener(_markDirty);
    _notesController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _gstController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    final confirmed = await ConfirmSheet.show(
      context,
      title: 'Discard Changes?',
      message:
          'You have unsaved changes. Are you sure you want to discard them?',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      isDestructive: true,
    );
    return confirmed == true;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final service = MockDataService();
    final name = _nameController.text.trim();
    String phone = _phoneController.text.trim();
    if (phone.startsWith('+91')) {
      phone = phone.substring(3).trim();
    }

    if (widget.supplierToEdit != null) {
      final updated = widget.supplierToEdit!.copyWith(
        name: name,
        contactPerson: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        phone: phone,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim().toLowerCase(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        gstNumber: _gstController.text.trim().isEmpty
            ? null
            : _gstController.text.trim().toUpperCase(),
        paymentTerms: _paymentTermsController.text.trim().isEmpty
            ? null
            : _paymentTermsController.text.trim(),
        isActive: _isActive,
      );
      service.updateSupplier(updated);
    } else {
      final newCode = 'SUP-${(service.suppliers.length + 100001).toString()}';
      final newSupplier = Supplier(
        id: 'sup-${DateTime.now().millisecondsSinceEpoch}',
        supplierCode: newCode,
        name: name,
        contactPerson: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        phone: phone,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim().toLowerCase(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        gstNumber: _gstController.text.trim().isEmpty
            ? null
            : _gstController.text.trim().toUpperCase(),
        paymentTerms: _paymentTermsController.text.trim().isEmpty
            ? null
            : _paymentTermsController.text.trim(),
        isActive: true,
      );
      service.addSupplier(newSupplier);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.supplierToEdit != null
              ? 'Supplier updated successfully'
              : 'Supplier created successfully',
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
    final isEdit = widget.supplierToEdit != null;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppTopBar(
          title: isEdit ? strings.editSupplier : strings.addSupplier,
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
          primaryLabel: strings.save,
          onPrimaryPressed: _save,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Supplier / Distributor Name *'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Sri Venkateswara Pharma',
                  ),
                  validator: (val) {
                    if (val == null ||
                        val.trim().length < 2 ||
                        val.trim().length > 120) {
                      return 'Supplier name must be between 2 and 120 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('Phone Number * (10 digits)'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 9848012345',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return 'Phone number is required';
                    String clean = val.trim();
                    if (clean.startsWith('+91'))
                      clean = clean.substring(3).trim();
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(clean)) {
                      return 'Enter a valid 10-digit Indian phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('Contact Person (Optional)'),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(hintText: 'e.g. K. Ramesh'),
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('Email Address (Optional)'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'e.g. sales@venkateswara.in',
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(val.trim())) {
                        return 'Enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('GST Number (15-digit GSTIN, Optional)'),
                TextFormField(
                  controller: _gstController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 37AAAAA0000A1Z5',
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      if (!RegExp(
                        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
                      ).hasMatch(val.trim().toUpperCase())) {
                        return 'Enter a valid 15-character GSTIN format';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('Payment Terms (Optional)'),
                TextFormField(
                  controller: _paymentTermsController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Net 30, Net 15, Advance',
                  ),
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('Store / Office Address (Optional)'),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Shop 14, Main Road',
                  ),
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('City / Location (Optional)'),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Vijayawada, Guntur',
                  ),
                ),
                const SizedBox(height: 14),

                _buildFieldLabel('Notes (Optional)'),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. Primary agency for Cipla and Abbott formulations',
                  ),
                ),
                const SizedBox(height: 16),

                if (isEdit) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Status',
                            style: AppTypography.bodyStrong,
                          ),
                          Text(
                            'Deactivated suppliers cannot be chosen for new POs',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: AppColors.matchaDeep,
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Text(
        label,
        style: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
