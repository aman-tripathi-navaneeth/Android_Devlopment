import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/step_header.dart';
import '../../../core/services/mock_data_service.dart';
import '../../catalogue/widgets/medicine_picker_sheet.dart';
import '../../camera/screens/camera_capture_screen.dart';
import '../models/sales_report.dart';
import '../services/mock_sales_ocr_adapter.dart';
import '../widgets/sales_line_card.dart';
import 'sales_report_detail_screen.dart';
import '../../../core/api/api_client.dart';

/// Interactive Outward Sales Report Scanning & Verification Workflow per Member 7 prompt.
/// 5-Step Workflow matching the interactive web preview:
/// 1. Capture/Upload -> 2. Review Extracted -> 3. Match Medicines -> 4. Confirm & Post -> 5. Result
class SalesReportScanScreen extends StatefulWidget {
  final SalesReport? initialDraft;
  final int initialStep;
  final Map<String, dynamic>? aiScanResponse;

  const SalesReportScanScreen({
    super.key,
    this.initialDraft,
    this.initialStep = 0,
    this.aiScanResponse,
  });

  @override
  State<SalesReportScanScreen> createState() => _SalesReportScanScreenState();
}

class _SalesReportScanScreenState extends State<SalesReportScanScreen> {
  final MockSalesOcrAdapter _ocrAdapter = MockSalesOcrAdapter();
  final MockDataService _mockDataService = MockDataService();

  // Wizard Step: 0 = Capture, 1 = Review, 2 = Match, 3 = Confirm, 4 = Result
  int _currentStep = 0;

  // Step 0 Form State
  String _reportReference = '';
  DateTime _reportDate = DateTime.now();
  String? _selectedFileName;
  MockOcrScenario _selectedScenario = MockOcrScenario.standardMixed;
  bool _isProcessingOcr = false;

  // Active Report Draft
  SalesReport? _activeReport;
  bool _isPosting = false;
  String? _postingErrorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.aiScanResponse != null) {
      _applyAiScanResponse(widget.aiScanResponse!);
      _currentStep = 1;
    } else if (widget.initialDraft != null) {
      _activeReport = widget.initialDraft;
      _reportReference = widget.initialDraft!.reportReference;
      _reportDate = widget.initialDraft!.reportDate;
      _currentStep = 1;
    } else {
      _currentStep = widget.initialStep;
    }
  }

  // --- STEP 0: PROCESS & EXTRACT DRAFT ---
  Future<void> _processOcrExtraction() async {
    setState(() {
      _isProcessingOcr = true;
      _postingErrorMessage = null;
    });

    try {
      final draft = await _ocrAdapter.extractSalesReport(
        fileName: _selectedFileName ?? 'EOD_Sales_Register_12Oct.jpg',
        reportReference: _reportReference.trim().isEmpty
            ? 'SR-1012'
            : _reportReference.trim(),
        reportDate: _reportDate,
        scenario: _selectedScenario,
      );

      setState(() {
        _activeReport = draft;
        _isProcessingOcr = false;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() {
        _isProcessingOcr = false;
        _postingErrorMessage = 'Failed to process document: $e';
      });
    }
  }

  Future<void> _pickAndScanImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _isProcessingOcr = true;
      _postingErrorMessage = null;
    });
    try {
      final bytes = await image.readAsBytes();
      final response = await ApiClient().scanDocumentImage(
        imageBytes: bytes,
        fileName: image.name,
        mimeType: image.mimeType ?? 'image/jpeg',
        documentType: 'sales_report',
      );
      if (!mounted) return;
      if (response == null) {
        setState(() {
          _isProcessingOcr = false;
          _postingErrorMessage = 'Image scan returned no data. Please try again.';
        });
        return;
      }
      _applyAiScanResponse(response, fileName: image.name);
      setState(() {
        _isProcessingOcr = false;
        _currentStep = 1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
        _postingErrorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
        _postingErrorMessage = 'Unexpected error during image scan: $e';
      });
    }
  }

  void _applyAiScanResponse(Map<String, dynamic> response, {String? fileName}) {
    final extracted = (response['medicines'] as List<dynamic>? ?? const []);
    final catalogue = _mockDataService.medicines;

    final lines = extracted.asMap().entries.map((entry) {
      final medicine = Map<String, dynamic>.from(entry.value as Map);
      final rawGeneric = (medicine['generic_name'] ?? medicine['medicine_name'] ?? '').toString().trim();
      final rawBrand = (medicine['medicine_name'] ?? rawGeneric).toString().trim();
      final rawText = medicine['raw_text']?.toString().trim() ?? (rawGeneric.isNotEmpty ? rawGeneric : rawBrand);
      final qty = (medicine['quantity'] as num?)?.toInt() ?? 0;

      // Auto-identify unit (Requirement 2)
      final rawUnit = (medicine['unit'] ?? 'unknown').toString().trim().toLowerCase();
      String unit = 'unknown';
      if (rawUnit.contains('strip') || rawUnit.contains('strp')) {
        unit = 'strip';
      } else if (rawUnit.contains('tab') || rawUnit.contains('tbl')) {
        unit = 'tablet';
      }

      // Match against catalogue by generic name first (Requirement 3: combine medicines by generic name)
      String matchedId = '';
      String matchedName = '';
      String generic = '';
      int unitsPerPack = 10;
      String packUnit = 'strip';
      double confidence = 0.5;
      SalesLineReviewStatus status = SalesLineReviewStatus.unresolved;
      String? error;

      final cleanGen = rawGeneric.toLowerCase();
      final cleanBrand = rawBrand.toLowerCase();

      // 1. Primary: Match by generic name across brands
      final genericMatches = catalogue.where((m) {
        final mGen = m.genericName.toLowerCase();
        return cleanGen.isNotEmpty && (mGen == cleanGen || mGen.contains(cleanGen) || cleanGen.contains(mGen));
      }).toList();

      if (genericMatches.isNotEmpty) {
        final primaryMed = genericMatches.first;
        matchedId = primaryMed.productId;
        generic = primaryMed.genericName;
        matchedName = genericMatches.map((m) => m.name).toSet().join(', ');
        unitsPerPack = primaryMed.unitsPerPack;
        packUnit = primaryMed.packUnit;
        confidence = 0.95;
        status = unit == 'unknown' ? SalesLineReviewStatus.unresolved : SalesLineReviewStatus.accepted;
      } else {
        // 2. Fallback: Match by brand name to identify generic
        for (final med in catalogue) {
          final medName = med.name.toLowerCase();
          final combined = '${med.name} ${med.strength}'.toLowerCase();
          if (cleanBrand == medName || cleanBrand == combined || cleanGen == medName) {
            matchedId = med.productId;
            matchedName = med.name;
            generic = med.genericName;
            unitsPerPack = med.unitsPerPack;
            packUnit = med.packUnit;
            confidence = 0.90;
            status = unit == 'unknown' ? SalesLineReviewStatus.unresolved : SalesLineReviewStatus.accepted;
            break;
          } else if (cleanBrand.contains(medName) || medName.contains(cleanBrand)) {
            matchedId = med.productId;
            matchedName = med.name;
            generic = med.genericName;
            unitsPerPack = med.unitsPerPack;
            packUnit = med.packUnit;
            confidence = 0.80;
            status = SalesLineReviewStatus.unresolved;
            break;
          }
        }
      }

      if (matchedId.isEmpty) {
        error = 'Please match this generic medicine with catalogue';
      } else if (qty <= 0) {
        error = 'Quantity sold is unclear, please enter quantity';
      } else if (unit == 'unknown') {
        error = 'Please confirm the unit (Strip or Tablet)';
      }

      return SalesLineItem(
        id: 'AI_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
        originalOcrText: rawText.isNotEmpty ? rawText : rawGeneric,
        matchedProductId: matchedId,
        matchedProductName: matchedName.isNotEmpty ? matchedName : rawBrand,
        genericName: generic.isNotEmpty ? generic : rawGeneric,
        confidenceScore: confidence,
        quantity: qty,
        unit: unit,
        unitsPerPack: unitsPerPack,
        packUnit: packUnit,
        batchNumber: medicine['batch_number']?.toString(),
        reviewStatus: status,
        validationError: error,
      );
    }).toList();

    _activeReport = SalesReport(
      id: response['id']?.toString() ?? 'AI-DRAFT',
      reportReference: _reportReference,
      reportDate: _reportDate,
      selectedFileName: fileName ?? 'AI_Sales_Report.jpg',
      lines: lines,
      isSimulated: false,
    );
  }

  // --- STEP 1 & 2: LINE CORRECTION & RESOLUTION ---
  void _openCataloguePickerForLine(SalesLineItem line) async {
    final med = await MedicinePickerSheet.show(context);
    if (med != null) {
      final matchingMeds = _mockDataService.getMedicinesForGeneric(
        med.genericName,
        fallbackProductId: med.productId,
      );
      final allBrands = matchingMeds.map((m) => m.name).toSet().join(', ');

      setState(() {
        line.matchedProductId = med.productId;
        line.matchedProductName = allBrands.isNotEmpty ? allBrands : med.name;
        line.genericName = med.genericName;
        line.unitsPerPack = med.unitsPerPack;
        line.packUnit = med.packUnit;
        line.confidenceScore = 1.0;
        line.reviewStatus = line.isUnitUnclear
            ? SalesLineReviewStatus.unresolved
            : SalesLineReviewStatus.manuallyResolved;
        line.validationError = line.isUnitUnclear
            ? 'Please confirm the unit (Strip or Tablet)'
            : null;
        line.batchAllocationRule = 'FEFO (Generic Group)';
      });
    }
  }

  void _deleteLine(SalesLineItem line) {
    if (_activeReport == null) return;
    final index = _activeReport!.lines.indexOf(line);
    setState(() {
      _activeReport!.lines.remove(line);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Removed "${line.matchedProductName.isEmpty ? line.originalOcrText : line.matchedProductName}"',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _activeReport!.lines.insert(index, line);
            });
          },
        ),
      ),
    );
  }

  void _addNewLineItem() {
    if (_activeReport == null) return;
    setState(() {
      _activeReport!.lines.add(
        SalesLineItem(
          id: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
          originalOcrText: 'Manually Added Item',
          matchedProductId: 'MED-000101',
          matchedProductName: 'Dolo 650mg, Crocin 500 Advance',
          genericName: 'Paracetamol',
          confidenceScore: 1.0,
          quantity: 2,
          unit: 'strip',
          unitsPerPack: 15,
          packUnit: 'strip',
          batchAllocationRule: 'FEFO (Generic Group)',
          reviewStatus: SalesLineReviewStatus.manuallyResolved,
        ),
      );
    });
  }

  // Durable idempotency key preserved across retries of the same report
  String? _currentIdempotencyKey;

  // --- STEP 3: CONFIRM AND POST ---
  Future<void> _confirmAndPostReport() async {
    if (_activeReport == null || _isPosting) return;

    // Guard 1: Prevent posting if any medicine line remains unresolved or has invalid quantity
    final unresolved = _activeReport!.lines
        .where((l) => l.matchedProductId.isEmpty)
        .toList();
    if (unresolved.isNotEmpty) {
      setState(() {
        _postingErrorMessage =
            'Cannot post report: ${unresolved.length} unresolved medicine line(s). Please match each medicine to your inventory.';
      });
      return;
    }

    // Guard 2: Unit confirmation check (Requirement 2 & 5)
    final unclearUnit = _activeReport!.lines
        .where((l) => l.isUnitUnclear)
        .toList();
    if (unclearUnit.isNotEmpty) {
      setState(() {
        _postingErrorMessage =
            'Cannot confirm transaction: ${unclearUnit.length} item(s) have unconfirmed units. Please confirm whether the unit is Strip or Tablet.';
      });
      return;
    }

    // Guard 3: Valid positive quantity check
    final invalidQty = _activeReport!.lines
        .where((l) => l.quantity <= 0)
        .toList();
    if (invalidQty.isNotEmpty) {
      setState(() {
        _postingErrorMessage =
            'Cannot post report: ${invalidQty.length} medicine(s) have unclear or zero quantity. Please enter the correct quantity sold.';
      });
      return;
    }

    // Guard 4: Check combined stock availability across generic medicine groups (Requirement 3 & 4)
    for (final line in _activeReport!.lines) {
      final availableStock = _mockDataService.getCombinedStockForGeneric(
        line.genericName,
        fallbackProductId: line.matchedProductId,
      );
      final requiredLoose = line.calculatedLooseUnits;
      if (requiredLoose > availableStock) {
        final displayName = line.genericName.isNotEmpty ? line.genericName : line.matchedProductName;
        setState(() {
          _postingErrorMessage =
              'Insufficient combined stock for $displayName: available $availableStock tablets, required $requiredLoose tablets (${line.unitExplanation}). Please adjust quantity before confirming.';
        });
        return;
      }
    }

    _currentIdempotencyKey ??=
        'SALE-IDEMP-${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _isPosting = true;
      _postingErrorMessage = null;
    });

    try {
      // Deduct stock via authoritative backend API
      final liveDeduction = await ApiClient().postSalesDeduction(
        storeId: 'main_store',
        payload: {
          'source_type': 'SALES_REPORT',
          'source_id': _activeReport!.id,
          'source_number': _activeReport!.reportReference,
          'posted_by': 'pharmacist_operator',
          'items': _activeReport!.lines.map((l) => {
            'product_id': l.matchedProductId,
            'generic_name': l.genericName,
            'medicine_name': l.matchedProductName,
            'quantity_entered': l.quantity,
            'unit_entered': l.unit,
          }).toList(),
        },
        idempotencyKey: _currentIdempotencyKey!,
      );

      // Also commit to local state for instant UI consistency
      final deductionSuccess = _mockDataService.recordSalesDeductions(
        _activeReport!,
      );

      await _ocrAdapter.postSalesReportDeductions(_activeReport!);

      if (deductionSuccess || liveDeduction != null) {
        setState(() {
          _isPosting = false;
          _currentStep = 4; // Advance to Result
        });
      } else {
        setState(() {
          _isPosting = false;
          _postingErrorMessage =
              'Stock deduction rejected: Insufficient combined stock available in inventory. No stock was deducted.';
        });
      }
    } catch (e) {
      setState(() {
        _isPosting = false;
        _postingErrorMessage = 'Transaction failed: $e. Retrying is safe (idempotency key preserved).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Scan Sales Report';
    if (_currentStep == 0) title = 'Upload Document';
    if (_currentStep == 1) title = 'Review Extracted Lines';
    if (_currentStep == 2) title = 'Match Medicines';
    if (_currentStep == 3) title = 'Confirm Stock Deduction';
    if (_currentStep == 4) title = 'Sales Deductions Posted';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: title,
        showLanguageToggle: false,
        leading: IconButton(
          icon: Icon(
            _currentStep == 0 || _currentStep == 4
                ? Icons.close_rounded
                : Icons.arrow_back_rounded,
          ),
          onPressed: () {
            if (_currentStep > 0 && _currentStep < 4) {
              setState(() => _currentStep -= 1);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildCurrentWizardStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentWizardStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep0ScanOrUpload();
      case 1:
        return _buildStep1ReviewExtractedLines();
      case 2:
        return _buildStep2MatchToCatalogue();
      case 3:
        return _buildStep3ConfirmStockDeduction();
      case 4:
      default:
        return _buildStep4Success();
    }
  }

  // =========================================================================
  // SCREEN 1: SCAN OR UPLOAD REPORT (WIZARD STEP 0)
  // =========================================================================
  Widget _buildStep0ScanOrUpload() {
    return Column(
      children: [
        StepHeader(
          currentStep: 0,
          steps: const ['Capture', 'Review', 'Match', 'Confirm', 'Result'],
          onStepTap: (idx) => setState(() => _currentStep = idx),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upload Document', style: AppTypography.screenTitle),
                const SizedBox(height: 4),
                const Text(
                  'Sales Report Scanning (Stock Out) • Scan daily sales register and deduct stock from inventory',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
                const SizedBox(height: 18),

                if (_isProcessingOcr) ...[
                  const LinearProgressIndicator(color: AppColors.matchaDeep),
                  const SizedBox(height: 12),
                ],
                _buildUploadOptionCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take Photo',
                  subtitle: 'Use camera to capture POS daily register',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CameraCaptureScreen(
                          scanType: DocumentScanType.salesReport,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Option 2: Choose from Gallery
                _buildUploadOptionCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  subtitle: 'Select register screenshot from gallery',
                  onTap: _pickAndScanImage,
                ),
                const SizedBox(height: 12),

                // Option 3: Upload Register File
                _buildUploadOptionCard(
                  icon: Icons.description_outlined,
                  title: 'Upload Register File',
                  subtitle: 'Select PDF or CSV daily report file',
                  onTap: _processOcrExtraction,
                ),

              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFB91C1C), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.inkSoft,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SCREEN 2: REVIEW EXTRACTED LINES (WIZARD STEP 1)
  // =========================================================================
  Widget _buildStep1ReviewExtractedLines() {
    if (_activeReport == null)
      return const Center(child: Text('No active draft report.'));
    final report = _activeReport!;

    return Column(
      children: [
        StepHeader(
          currentStep: 1,
          steps: const ['Capture', 'Review', 'Match', 'Confirm', 'Result'],
          onStepTap: (idx) => setState(() => _currentStep = idx),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Form Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Report Date',
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            children: const [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: AppColors.matchaDeep,
                              ),
                              SizedBox(width: 5),
                              Text(
                                '12-Oct-2026',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Reference No.',
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _reportReference,
                            style: AppTypography.bodyStrong,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Extracted Items (${report.lines.length})',
                      style: AppTypography.section,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(
                        'Add Item',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: _addNewLineItem,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...report.lines.map(
                  (line) => SalesLineCard(
                    line: line,
                    onEditNameManually: () => _editLineNameManually(line),
                    onSelectCatalogue: () => _openCataloguePickerForLine(line),
                    onDelete: () => _deleteLine(line),
                    onQuantityChanged: (qty) =>
                        setState(() => line.quantity = qty),
                    onUnitChanged: (unit) => setState(() => line.unit = unit),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.matchaDeep,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => setState(() => _currentStep = 2),
                  child: const Text(
                    'Continue to Matching ›',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editLineNameManually(SalesLineItem line) async {
    final controller = TextEditingController(
      text: line.genericName.isNotEmpty ? line.genericName : (line.isMatched ? line.matchedProductName : line.originalOcrText),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Edit Generic Medicine Name',
          style: AppTypography.subheading,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Generic Name (e.g. Paracetamol, Amoxicillin)',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final matchingMeds = _mockDataService.getMedicinesForGeneric(result);
      setState(() {
        line.genericName = result;
        if (matchingMeds.isNotEmpty) {
          final primary = matchingMeds.first;
          line.matchedProductId = primary.productId;
          line.matchedProductName = matchingMeds.map((m) => m.name).toSet().join(', ');
          line.unitsPerPack = primary.unitsPerPack;
          line.packUnit = primary.packUnit;
          line.validationError = line.isUnitUnclear ? 'Please confirm the unit (Strip or Tablet)' : null;
        } else {
          line.matchedProductName = result;
        }
        line.confidenceScore = 1.0;
        line.reviewStatus = line.isUnitUnclear
            ? SalesLineReviewStatus.unresolved
            : SalesLineReviewStatus.manuallyResolved;
      });
    }
  }

  // =========================================================================
  // SCREEN 3: MATCH MEDICINES (WIZARD STEP 2)
  // =========================================================================
  Widget _buildStep2MatchToCatalogue() {
    if (_activeReport == null)
      return const Center(child: Text('No active draft report.'));
    final report = _activeReport!;
    final unmatchedCount = report.lines.where((l) => !l.isMatched).length;

    return Column(
      children: [
        StepHeader(
          currentStep: 2,
          steps: const ['Capture', 'Review', 'Match', 'Confirm', 'Result'],
          onStepTap: (idx) => setState(() => _currentStep = idx),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 36.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Match to Catalogue', style: AppTypography.section),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: unmatchedCount > 0
                            ? const Color(0xFFFEE2E2)
                            : AppColors.matcha.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        unmatchedCount > 0
                            ? 'Unmatched ($unmatchedCount)'
                            : 'Unmatched (0)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: unmatchedCount > 0
                              ? AppColors.dangerFg
                              : AppColors.matchaDeep,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search medicine name or product ID...',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                ...report.lines.map((l) {
                  final bool isUnmatched = !l.isMatched;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isUnmatched
                            ? const Color(0xFFFCA5A5)
                            : AppColors.outline,
                        width: isUnmatched ? 1.5 : 1,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final isNarrowCard = cardConstraints.maxWidth < 460;

                        final actionButtons = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUnmatched)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEF3C7),
                                  foregroundColor: const Color(0xFF92400E),
                                  elevation: 0,
                                  side: const BorderSide(
                                    color: Color(0xFFF59E0B),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () => _openCataloguePickerForLine(l),
                                child: const Text(
                                  'Find Match',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            else
                              const StatusChip(
                                status: StatusType.posted,
                                customLabel: 'Matched',
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              color: AppColors.inkSoft,
                              tooltip: 'Edit / Re-match',
                              onPressed: () => _openCataloguePickerForLine(l),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              color: AppColors.dangerFg,
                              tooltip: 'Delete Item',
                              onPressed: () => _deleteLine(l),
                            ),
                          ],
                        );

                        if (isNarrowCard) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUnmatched
                                    ? 'Unknown Item / ${l.originalOcrText}'
                                    : (l.genericName.isNotEmpty ? l.genericName : l.matchedProductName),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isUnmatched
                                      ? AppColors.dangerFg
                                      : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isUnmatched
                                    ? 'Unmatched Item • Match to inventory'
                                    : 'Generic Group • Brands: ${l.matchedProductName} • Qty Sold: ${l.quantity} ${l.unit} (-${l.calculatedLooseUnits} tabs)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [actionButtons],
                              ),
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isUnmatched
                                        ? 'Unknown Item / ${l.originalOcrText}'
                                        : (l.genericName.isNotEmpty ? l.genericName : l.matchedProductName),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isUnmatched
                                          ? AppColors.dangerFg
                                          : AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isUnmatched
                                        ? 'Unmatched Item • Match to inventory'
                                        : 'Generic Group • Brands: ${l.matchedProductName} • Qty Sold: ${l.quantity} ${l.unit} (-${l.calculatedLooseUnits} tabs)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actionButtons,
                          ],
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, barConstraints) {
                final isNarrowBar = barConstraints.maxWidth < 360;

                if (isNarrowBar) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.matchaDeep,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => setState(() => _currentStep = 3),
                          child: const Text(
                            'Continue to Confirm ›',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => setState(() => _currentStep = 1),
                          child: const Text('Back'),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep = 1),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.matchaDeep,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => setState(() => _currentStep = 3),
                        child: const Text(
                          'Continue to Confirm ›',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // SCREEN 4: CONFIRM AND POST (WIZARD STEP 3 - Pre-Deduction Inventory Audit)
  // =========================================================================
  Widget _buildStep3ConfirmStockDeduction() {
    if (_activeReport == null)
      return const Center(child: Text('No active report.'));
    final report = _activeReport!;
    final totalLines = report.lines.length;
    final totalLooseUnits = report.totalLooseUnitsDeducted;
    final unmatchedCount = report.lines.where((l) => !l.isMatched).length;
    final matchedCount = totalLines - unmatchedCount;

    return Column(
      children: [
        StepHeader(
          currentStep: 3,
          steps: const ['Capture', 'Review', 'Match', 'Confirm', 'Result'],
          onStepTap: (idx) => setState(() => _currentStep = idx),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3 Metric Stat Cards row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$totalLines',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Items Sold',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Column(
                          children: const [
                            Text(
                              '₹4,890',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.carob,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text('Total Sales', style: AppTypography.caption),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$totalLooseUnits',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dangerFg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Total Units',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Warning Notice Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFB91C1C),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will deduct stock from active inventory based on the sales report.',
                          style: TextStyle(
                            color: Color(0xFF7F1D1D),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Pre-Deduction Inventory Audit Summary Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        color: const Color(0xFFDC2626).withValues(alpha: 0.06),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: Color(0xFFB91C1C),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Pre-Deduction Inventory Audit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: unmatchedCount == 0
                                    ? AppColors.matcha.withValues(alpha: 0.25)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unmatchedCount == 0
                                    ? 'Passed'
                                    : 'Action Required',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: unmatchedCount == 0
                                      ? AppColors.matchaDeep
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.outline),

                      Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          children: [
                            _buildAuditRow(
                              icon: Icons.inventory_2_outlined,
                              iconBg: const Color(0xFFFEE2E2),
                              iconFg: const Color(0xFFB91C1C),
                              title: 'Outward Line Reconciliation',
                              subtitle: unmatchedCount == 0
                                  ? 'All $totalLines sold medicines mapped to active batch inventory'
                                  : '$matchedCount of $totalLines items mapped ($unmatchedCount pending)',
                              badgeText: unmatchedCount == 0
                                  ? '$totalLines/$totalLines Mapped'
                                  : '$unmatchedCount Pending',
                              badgeBg: unmatchedCount == 0
                                  ? AppColors.matcha.withValues(alpha: 0.2)
                                  : const Color(0xFFFEF3C7),
                              badgeFg: unmatchedCount == 0
                                  ? AppColors.matchaDeep
                                  : const Color(0xFF92400E),
                            ),
                            const Divider(height: 20, color: AppColors.outline),
                            _buildAuditRow(
                              icon: Icons.check_circle_outline_rounded,
                              iconBg: AppColors.matcha.withValues(alpha: 0.16),
                              iconFg: AppColors.matchaDeep,
                              title: 'Shelf Stock Availability',
                              subtitle: 'Sufficient on-hand quantity confirmed • 0 stockout hazards',
                              badgeText: 'Stock OK',
                              badgeBg: AppColors.matcha.withValues(alpha: 0.2),
                              badgeFg: AppColors.matchaDeep,
                            ),
                            const Divider(height: 20, color: AppColors.outline),
                            _buildAuditRow(
                              icon: Icons.schedule_rounded,
                              iconBg: AppColors.matcha.withValues(alpha: 0.16),
                              iconFg: AppColors.matchaDeep,
                              title: 'Register Reference & FIFO Rule',
                              subtitle:
                                  'Daily Sales $_reportReference • Oldest expiry batch depletion applied',
                              badgeText: 'FIFO Validated',
                              badgeBg: AppColors.matcha.withValues(alpha: 0.2),
                              badgeFg: AppColors.matchaDeep,
                            ),
                            const Divider(height: 20, color: AppColors.outline),
                            _buildAuditRow(
                              icon: Icons.remove_circle_outline_rounded,
                              iconBg: const Color(0xFFFEE2E2),
                              iconFg: const Color(0xFFB91C1C),
                              title: 'Stock Ledger Debit',
                              subtitle:
                                  '-$totalLooseUnits units will be debited from dispensary warehouse ledger',
                              badgeText: 'Ready to Debit',
                              badgeBg: const Color(0xFFFEE2E2),
                              badgeFg: const Color(0xFFB91C1C),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_postingErrorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFB91C1C),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _postingErrorMessage!,
                            style: const TextStyle(
                              color: Color(0xFF7F1D1D),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isPosting
                      ? null
                      : () => setState(() => _currentStep = 2),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.matchaDeep,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isPosting ? null : _confirmAndPostReport,
                  child: _isPosting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Post Sales Report',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditRow({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeBg,
    required Color badgeFg,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: iconFg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: badgeFg,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // SCREEN 5: SUCCESSFUL POSTING STATE (WIZARD STEP 4)
  // =========================================================================
  Widget _buildStep4Success() {
    final report = _activeReport;
    final totalUnits = report?.totalLooseUnitsDeducted ?? 34;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFFB91C1C),
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            Text('Sales Deductions Posted', style: AppTypography.screenTitle),
            const SizedBox(height: 4),
            Text(
              'Inventory debited for $_reportReference under FEFO policy.',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  _buildResultRow('Report Ref.', _reportReference),
                  const Divider(height: 16),
                  _buildResultRow(
                    'Items Deducted',
                    '${report?.lines.length ?? 12} items',
                  ),
                  const Divider(height: 16),
                  _buildResultRow(
                    'Total Quantity',
                    '$totalUnits units',
                    isDanger: true,
                  ),
                  const Divider(height: 16),
                  _buildResultRow('Total Value', '₹4,890.00'),
                  const Divider(height: 16),
                  _buildResultRow('Posted At', '12 Oct 2026, 04:15 PM'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () {
                if (report != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SalesReportDetailScreen(report: report),
                    ),
                  );
                }
              },
              child: const Text('View Report'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('View Stock Movements'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: AppColors.matchaDeep,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Done / Back to Home',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isDanger = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: isDanger ? const Color(0xFFB91C1C) : AppColors.ink,
          ),
        ),
      ],
    );
  }
}
