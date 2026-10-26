import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/sticky_action_bar.dart';

/// First-run shop setup (OWNER only) - Section 10.1
class ShopSetupScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const ShopSetupScreen({super.key, required this.onSaved});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController(
    text: 'Sri Balaji Medical Store',
  );
  final _ownerNameController = TextEditingController(text: 'Aditya Pakki');
  final _phoneController = TextEditingController(text: '9848012345');
  final _addressController = TextEditingController(
    text: 'Shop 14, Main Road, Governorpet, Vijayawada',
  );
  final _gstController = TextEditingController(text: '37AAAAA0000A1Z5');
  final _licenceController = TextEditingController(
    text: 'AP-VJA-2024-DL-10928',
  );
  final _nearExpiryController = TextEditingController(text: '90');

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _licenceController.dispose();
    _nearExpiryController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: strings.shopSetupTitle,
        showLanguageToggle: true,
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
              Text(
                'Configure your pharmacy store profile and operational thresholds:',
                style: AppTypography.body.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('${strings.shopName} *'),
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Sri Balaji Medical Store',
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Shop name is required'
                    : null,
              ),
              const SizedBox(height: 14),

              _buildFieldLabel('${strings.ownerName} *'),
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Aditya Pakki',
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Owner name is required'
                    : null,
              ),
              const SizedBox(height: 14),

              _buildFieldLabel('${strings.phone} *'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'e.g. 9848012345'),
                validator: (val) => val == null || val.trim().length < 10
                    ? 'Enter valid 10-digit phone'
                    : null,
              ),
              const SizedBox(height: 14),

              _buildFieldLabel(strings.address),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Store street address & locality',
                ),
              ),
              const SizedBox(height: 14),

              _buildFieldLabel('${strings.gstNumber} (Optional)'),
              TextFormField(
                controller: _gstController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: '15-digit GSTIN'),
              ),
              const SizedBox(height: 14),

              _buildFieldLabel('${strings.drugLicence} (Optional)'),
              TextFormField(
                controller: _licenceController,
                decoration: const InputDecoration(
                  hintText: 'e.g. 20B/21B Pharmacy Licence',
                ),
              ),
              const SizedBox(height: 14),

              _buildFieldLabel('${strings.nearExpiryWindow} (Default 90 days)'),
              TextFormField(
                controller: _nearExpiryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '90'),
              ),
              const SizedBox(height: 32),
            ],
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
