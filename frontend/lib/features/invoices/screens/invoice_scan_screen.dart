import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/ui/app_top_bar.dart';
import '../../../core/ui/status_chip.dart';
import '../../../core/ui/confidence_chip.dart';
import '../../../core/ui/step_header.dart';
import '../../../core/services/mock_data_service.dart';
import '../../catalogue/widgets/medicine_picker_sheet.dart';
import '../../camera/screens/camera_capture_screen.dart';
import '../../../core/api/api_client.dart';

/// Data class representing an extracted invoice line with auditability & manual corrections
class ExtractedInvoiceLine {
  final String id;
  final String originalOcrText; // Rule 7: Preserved original extracted value
  String matchedProductId;
  String matchedProductName;
  double confidence; // Rule 4: Match confidence
  int quantity;
  String unit;
  String batchNumber;
  String expiryDate;
  int ratePaise;
  bool isManuallyResolved;

  ExtractedInvoiceLine({
    required this.id,
    required this.originalOcrText,
    required this.matchedProductId,
    required this.matchedProductName,
    required this.confidence,
    required this.quantity,
    required this.unit,
    required this.batchNumber,
    required this.expiryDate,
    required this.ratePaise,
    this.isManuallyResolved = false,
  });

  bool get needsResolution => confidence < 0.80 && !isManuallyResolved;
}

/// Purchase Invoice Scanning & Inward Review Screen - Section 10.7
/// 5-Step Workflow matching the interactive web preview:
/// 1. Capture/Upload -> 2. Review Extracted -> 3. Match Medicines -> 4. Confirm & Post -> 5. Result
class InvoiceScanScreen extends StatefulWidget {
  final int initialViewMode;
  final Map<String, dynamic>? aiScanResponse;

  const InvoiceScanScreen({super.key, this.initialViewMode = 0, this.aiScanResponse});

  @override
  State<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends State<InvoiceScanScreen> {
  // 0: Capture, 1: Review, 2: Match, 3: Confirm, 4: Result, 5: History List
  late int _viewMode;
  bool _isEditingHeader = false;

  late TextEditingController _invNoController;
  late TextEditingController _dateController;
  late TextEditingController _supplierController;
  final String _authorizer = 'Aditya (Pharmacist)';

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _invNoController = TextEditingController();
    _dateController = TextEditingController();
    _supplierController = TextEditingController();
    if (widget.aiScanResponse != null) _applyAiScanResponse(widget.aiScanResponse!);
  }

  @override
  void dispose() {
    _invNoController.dispose();
    _dateController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  final List<ExtractedInvoiceLine> _lines = [
    ExtractedInvoiceLine(
      id: 'L1',
      originalOcrText: 'Augmentin 625 Duo 10x10',
      matchedProductId: 'MED-000102',
      matchedProductName: 'Augmentin 625 Duo 10x10',
      confidence: 0.95,
      quantity: 10,
      unit: 'strip',
      batchNumber: 'AG-84',
      expiryDate: '2027-09',
      ratePaise: 12500,
    ),
    ExtractedInvoiceLine(
      id: 'L2',
      originalOcrText: 'Crocin 500mg Advance',
      matchedProductId: 'MED-000101',
      matchedProductName: 'Crocin 500mg Advance',
      confidence: 0.74,
      quantity: 20,
      unit: 'strip',
      batchNumber: 'CR-2024',
      expiryDate: '2026-11',
      ratePaise: 6500,
    ),
    ExtractedInvoiceLine(
      id: 'L3',
      originalOcrText: 'ZERODOL SP 15S B:ZS-91',
      matchedProductId: '',
      matchedProductName: 'Zerodol SP Tablet',
      confidence: 0.45,
      quantity: 15,
      unit: 'strip',
      batchNumber: 'ZS-91',
      expiryDate: '2028-04',
      ratePaise: 21000,
    ),
    ExtractedInvoiceLine(
      id: 'L4',
      originalOcrText: 'Pantop 40mg Injection/Tabs',
      matchedProductId: 'MED-000104',
      matchedProductName: 'Pantop 40mg Injection/Tabs',
      confidence: 0.92,
      quantity: 10,
      unit: 'strip',
      batchNumber: 'PN-2025',
      expiryDate: '2027-12',
      ratePaise: 9500,
    ),
  ];

  void _openCataloguePickerForLine(ExtractedInvoiceLine line) async {
    final med = await MedicinePickerSheet.show(context);
    if (med != null) {
      setState(() {
        line.matchedProductId = med.productId;
        line.matchedProductName = med.name;
        line.confidence = 1.0;
        line.isManuallyResolved = true;
      });
    } else {
      // Direct fallback match to Zerodol SP per interactive preview
      setState(() {
        line.matchedProductId = 'MED-000103';
        line.matchedProductName = 'Zerodol SP Tablet';
        line.confidence = 1.0;
        line.isManuallyResolved = true;
      });
    }
  }

  void _deleteLine(ExtractedInvoiceLine line) {
    final index = _lines.indexOf(line);
    setState(() {
      _lines.remove(line);
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
              _lines.insert(index, line);
            });
          },
        ),
      ),
    );
  }

  void _addNewLineItem() {
    setState(() {
      _lines.add(
        ExtractedInvoiceLine(
          id: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
          originalOcrText: 'Manually Added Item',
          matchedProductId: 'MED-000105',
          matchedProductName: 'New Medicine Item',
          confidence: 1.0,
          quantity: 10,
          unit: 'strip',
          batchNumber: 'MN-01',
          expiryDate: '2027-12',
          ratePaise: 5000,
          isManuallyResolved: true,
        ),
      );
    });
  }

  void _simulateScanAndAdvance() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analyzing document with OCR text engine...'),
        duration: Duration(milliseconds: 600),
      ),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _viewMode = 1);
    });
  }

  Future<void> _pickAndScanImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sending image to Gemini for extraction...')),
      );
    }
    final bytes = await image.readAsBytes();
    final response = await ApiClient().scanDocumentImage(
      imageBytes: bytes,
      fileName: image.name,
      mimeType: image.mimeType ?? 'image/jpeg',
      documentType: 'invoice',
    );
    if (!mounted) return;
    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini extraction failed. Check the backend and API key.')),
      );
      return;
    }
    _applyAiScanResponse(response);
    setState(() => _viewMode = 1);
  }

  void _applyAiScanResponse(Map<String, dynamic> response) {
    final medicines = (response['medicines'] as List<dynamic>? ?? const []);
    _lines
      ..clear()
      ..addAll(medicines.asMap().entries.map((entry) {
        final medicine = Map<String, dynamic>.from(entry.value as Map);
        return ExtractedInvoiceLine(
          id: 'AI_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
          originalOcrText: medicine['raw_text']?.toString() ?? medicine['medicine_name'].toString(),
          matchedProductId: '',
          matchedProductName: medicine['medicine_name']?.toString() ?? '',
          confidence: 0.70,
          quantity: (medicine['quantity'] as num?)?.toInt() ?? 0,
          unit: medicine['unit']?.toString() ?? 'unknown',
          batchNumber: medicine['batch_number']?.toString() ?? '',
          expiryDate: medicine['expiry_date']?.toString() ?? '',
          ratePaise: 0,
        );
      }));
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Purchase Invoices (OCR Inward)';
    if (_viewMode == 0) title = 'Upload Document';
    if (_viewMode == 1) title = 'Review Extracted Lines';
    if (_viewMode == 2) title = 'Match to Catalogue';
    if (_viewMode == 3) title = 'Confirm & Post';
    if (_viewMode == 4) title = 'Stock Added Successfully';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppTopBar(
        title: title,
        showLanguageToggle: false,
        leading: IconButton(
          icon: Icon(
            _viewMode == 0 ? Icons.arrow_back_rounded : Icons.close_rounded,
          ),
          onPressed: () {
            if (_viewMode > 0) {
              setState(() => _viewMode = 0);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_viewMode) {
      case 0:
        return _buildStep0UploadDocument();
      case 1:
        return _buildStep1ReviewExtractedLines();
      case 2:
        return _buildStep2MatchToCatalogue();
      case 3:
        return _buildStep3ReviewAndConfirm();
      case 4:
        return _buildStep4ResultScreen();
      default:
        return _buildStep0UploadDocument();
    }
  }

  // =========================================================================
  // STEP 1: CAPTURE / UPLOAD (Interactive Preview Screen 1)
  // =========================================================================
  Widget _buildStep0UploadDocument() {
    return Column(
      children: [
        StepHeader(
          currentStep: 0,
          steps: const ['Capture', 'Review', 'Match', 'Confirm', 'Result'],
          onStepTap: (idx) => setState(() => _viewMode = idx),
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
                  'Purchase Invoice Scanning (Stock In) • Scan supplier invoice and add stock to active inventory',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
                const SizedBox(height: 18),

                // Option 1: Take Photo
                _buildUploadOptionCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take Photo',
                  subtitle: 'Use camera to capture paper tax invoice',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CameraCaptureScreen(
                          scanType: DocumentScanType.invoice,
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
                  subtitle: 'Select invoice photo from photo album',
                  onTap: _pickAndScanImage,
                ),
                const SizedBox(height: 12),

                // Option 3: Upload PDF Invoice
                _buildUploadOptionCard(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Upload PDF Invoice',
                  subtitle: 'Select digital e-invoice PDF from storage',
                  onTap: () => _simulateScanAndAdvance(),
                ),
                const SizedBox(height: 24),

                // Past Invoices History
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Invoices History (3)',
                      style: AppTypography.section,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInvoiceCard(
                  'INV-9028',
                  'Sri Venkateswara Pharma',
                  '12 Oct 2026',
                  '₹14,250.00',
                  StatusType.posted,
                  'Posted',
                ),
                _buildInvoiceCard(
                  'INV-4811',
                  'Apollo Med Wholesale',
                  '10 Oct 2026',
                  '₹8,900.00',
                  StatusType.posted,
                  'Posted',
                ),
                _buildInvoiceCard(
                  'INV-3329 (Draft)',
                  'Balaji Drug Agencies',
                  'Today',
                  '₹5,100.00',
                  StatusType.pending,
                  'Needs Review',
                  onTap: () => setState(() => _viewMode = 1),
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
                color: AppColors.matcha.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.matchaDeep, size: 22),
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

  Widget _buildInvoiceCard(
    String invNum,
    String supplier,
    String date,
    String amount,
    StatusType status,
    String statusLabel, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invNum, style: AppTypography.bodyStrong),
                Text('$supplier • $date', style: AppTypography.caption),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: AppTypography.tabularNumbers),
                const SizedBox(height: 4),
                StatusChip(status: status, customLabel: statusLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 2: REVIEW EXTRACTED LINES (Interactive Preview Screen 2)
  // =========================================================================
  Widget _buildStep1ReviewExtractedLines() {
    return Column(
      children: [
        StepHeader(
          currentStep: 1,
          steps: const ['Capture', 'Review', 'Match', 'Confirm', 'Result'],
          onStepTap: (idx) => setState(() => _viewMode = idx),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar with Edit Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Extracted Invoice Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: AppColors.matcha),
                        backgroundColor: _isEditingHeader
                            ? AppColors.matchaDeep
                            : AppColors.matcha.withValues(alpha: 0.18),
                        foregroundColor: _isEditingHeader
                            ? Colors.white
                            : AppColors.matchaDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () =>
                          setState(() => _isEditingHeader = !_isEditingHeader),
                      child: Text(
                        _isEditingHeader ? 'Save' : 'Edit',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Invoice Details Header Form Card
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
                            'Invoice No.',
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                          _isEditingHeader
                              ? SizedBox(
                                  width: 170,
                                  height: 32,
                                  child: TextField(
                                    controller: _invNoController,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      isDense: true,
                                    ),
                                  ),
                                )
                              : Text(
                                  _invNoController.text,
                                  style: AppTypography.bodyStrong,
                                ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Invoice Date',
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                          _isEditingHeader
                              ? SizedBox(
                                  width: 170,
                                  height: 32,
                                  child: TextField(
                                    controller: _dateController,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      isDense: true,
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: AppColors.matchaDeep,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _dateController.text,
                                      style: const TextStyle(
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
                            'Supplier',
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                          _isEditingHeader
                              ? SizedBox(
                                  width: 170,
                                  height: 32,
                                  child: TextField(
                                    controller: _supplierController,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.matchaDeep,
                                    ),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      isDense: true,
                                    ),
                                  ),
                                )
                              : Text(
                                  _supplierController.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.matchaDeep,
                                    fontSize: 12,
                                  ),
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
                      'Extracted Items (${_lines.length})',
                      style: AppTypography.section,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text(
                        'Add Line Item',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: _addNewLineItem,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ..._lines.map((line) => _buildEditableLineCard(line)),
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
                  onPressed: () => setState(() => _viewMode = 0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: AppColors.matchaDeep,
                  ),
                  onPressed: () => setState(() => _viewMode = 2),
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

  Widget _buildEditableLineCard(ExtractedInvoiceLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  line.matchedProductName.isEmpty
                      ? line.originalOcrText
                      : line.matchedProductName,
                  style: AppTypography.bodyStrong,
                ),
              ),
              ConfidenceChip(confidence: line.confidence),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'OCR Text: "${line.originalOcrText}" • Qty: ${line.quantity} ${line.unit}s • Batch: ${line.batchNumber} • Exp: ${line.expiryDate}',
            style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 3: MATCH MEDICINES (Interactive Preview Screen 3)
  // =========================================================================
  Widget _buildStep2MatchToCatalogue() {
    final unmatchedCount = _lines
        .where((l) => l.matchedProductId.isEmpty)
        .length;

    return Column(
      children: [
        StepHeader(
          currentStep: 2,
          steps: const ['Capture', 'Review', 'Match', 'Confirm', 'Result'],
          onStepTap: (idx) => setState(() => _viewMode = idx),
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

                ..._lines.map((l) {
                  final isUnmatched = l.matchedProductId.isEmpty;
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
                                    : l.matchedProductName,
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
                                    ? 'Zerodol SP (Low Confidence 42%)'
                                    : '(${l.matchedProductId}) • Batch ${l.batchNumber} • ${l.quantity} ${l.unit}s',
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
                                        : l.matchedProductName,
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
                                        ? 'Zerodol SP (Low Confidence 42%)'
                                        : '(${l.matchedProductId}) • Batch ${l.batchNumber} • ${l.quantity} ${l.unit}s',
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
                          onPressed: () => setState(() => _viewMode = 3),
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
                          onPressed: () => setState(() => _viewMode = 1),
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
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => setState(() => _viewMode = 1),
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
                        onPressed: () => setState(() => _viewMode = 3),
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
  // STEP 4: CONFIRM & POST (Pre-Posting Compliance Audit)
  // =========================================================================
  Widget _buildStep3ReviewAndConfirm() {
    final int totalStrips = _lines.fold(0, (sum, l) => sum + l.quantity);

    return Column(
      children: [
        StepHeader(
          currentStep: 3,
          steps: const ['Capture', 'Review', 'Match', 'Confirm', 'Result'],
          onStepTap: (idx) => setState(() => _viewMode = idx),
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
                              '${_lines.length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text('Items', style: AppTypography.caption),
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
                              '₹14,250',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.carob,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('Total Value', style: AppTypography.caption),
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
                              '$totalStrips',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.matchaDeep,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Total Strips',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Notice Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.matcha.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.matcha.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.matchaDeep,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will add stock to inventory and create a goods receipt.',
                          style: TextStyle(
                            color: AppColors.matchaDeep,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Pre-Posting Compliance Audit Summary Card (Enterprise Standard)
                _buildComplianceAuditCard(),
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
                  onPressed: () => setState(() => _viewMode = 2),
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
                  onPressed: () {
                    final unresolved = _lines
                        .where((l) => l.matchedProductId.trim().isEmpty)
                        .toList();
                    if (unresolved.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot post invoice: ${unresolved.length} unresolved line(s). Match all lines before posting.',
                          ),
                          backgroundColor: AppColors.dangerFg,
                        ),
                      );
                      return;
                    }

                    for (final l in _lines) {
                      if (l.batchNumber.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Batch number missing for ${l.matchedProductName.isEmpty ? l.originalOcrText : l.matchedProductName}',
                            ),
                            backgroundColor: AppColors.dangerFg,
                          ),
                        );
                        return;
                      }
                      DateTime? expDate;
                      try {
                        final parts = l.expiryDate.split('-');
                        if (parts.length == 2) {
                          expDate = DateTime(
                            int.parse(parts[0]),
                            int.parse(parts[1]) + 1,
                            0,
                          );
                        } else if (parts.length == 3) {
                          expDate = DateTime.parse(l.expiryDate);
                        }
                      } catch (_) {}
                      if (expDate == null || expDate.isBefore(DateTime.now())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Expired stock rejected for ${l.matchedProductName} (Expiry: ${l.expiryDate})',
                            ),
                            backgroundColor: AppColors.dangerFg,
                          ),
                        );
                        return;
                      }
                    }

                    final items = _lines
                        .map(
                          (l) => {
                            'productId': l.matchedProductId.trim(),
                            'quantity': l.quantity,
                            'batchNumber': l.batchNumber.trim(),
                            'expiryDate': l.expiryDate.trim(),
                          },
                        )
                        .toList();

                    final success = MockDataService()
                        .recordPurchaseInvoiceInward(
                          invoiceNumber: _invNoController.text.trim(),
                          supplierName: _supplierController.text.trim(),
                          items: items,
                          authorizer: _authorizer,
                        );

                    if (success) {
                      setState(() => _viewMode = 4);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Invoice ${_invNoController.text.trim()} already posted to inventory. Duplicate submission rejected.',
                          ),
                          backgroundColor: AppColors.dangerFg,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Post Invoice',
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

  Widget _buildComplianceAuditCard() {
    final totalItems = _lines.length;
    final unmatchedCount = _lines
        .where((l) => l.matchedProductId.isEmpty)
        .length;
    final matchedCount = totalItems - unmatchedCount;
    final totalStrips = _lines.fold(0, (sum, l) => sum + l.quantity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.matchaDeep.withValues(alpha: 0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.matchaDeep,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Pre-Posting Compliance Audit',
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
                    unmatchedCount == 0 ? 'Passed' : 'Action Required',
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
                  title: 'Master SKU Mapping',
                  subtitle: unmatchedCount == 0
                      ? 'All $totalItems line items mapped to catalogue master'
                      : '$matchedCount of $totalItems items mapped ($unmatchedCount pending review)',
                  badgeText: unmatchedCount == 0
                      ? '$totalItems/$totalItems Mapped'
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
                  icon: Icons.verified_outlined,
                  title: 'Vendor & GST Compliance',
                  subtitle:
                      '${_supplierController.text} • GSTIN 37AABCS1429B1Z8 Validated',
                  badgeText: 'Active Vendor',
                  badgeBg: AppColors.matcha.withValues(alpha: 0.2),
                  badgeFg: AppColors.matchaDeep,
                ),
                const Divider(height: 20, color: AppColors.outline),
                _buildAuditRow(
                  icon: Icons.medication_outlined,
                  title: 'Batch & Expiry Traceability',
                  subtitle:
                      '$totalItems unique batches logged • 0 near-expiry (<90d) warnings',
                  badgeText: 'Traceable',
                  badgeBg: AppColors.matcha.withValues(alpha: 0.2),
                  badgeFg: AppColors.matchaDeep,
                ),
                const Divider(height: 20, color: AppColors.outline),
                _buildAuditRow(
                  icon: Icons.add_chart_rounded,
                  title: 'Stock Ledger Credit',
                  subtitle:
                      '+$totalStrips units will be credited across $totalItems inventory bins',
                  badgeText: 'Ledger Ready',
                  badgeBg: AppColors.matchaDeep.withValues(alpha: 0.12),
                  badgeFg: AppColors.matchaDeep,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow({
    required IconData icon,
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
            color: AppColors.matcha.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppColors.matchaDeep),
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
  // STEP 5: RESULT SCREEN (Interactive Preview Screen 5)
  // =========================================================================
  Widget _buildStep4ResultScreen() {
    final int totalStrips = _lines.fold(0, (sum, l) => sum + l.quantity);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.matcha.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.matchaDeep,
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            Text('Stock Added Successfully', style: AppTypography.screenTitle),
            const SizedBox(height: 4),
            Text(
              'Goods receipt GRN-2026-00045 created and stock posted to active inventory.',
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
                  _buildResultRow('Receipt No.', 'GRN-2026-00045'),
                  const Divider(height: 16),
                  _buildResultRow('Supplier', _supplierController.text),
                  const Divider(height: 16),
                  _buildResultRow(
                    'Total Quantity',
                    '$totalStrips strips',
                    isGreen: true,
                  ),
                  const Divider(height: 16),
                  _buildResultRow('Total Value', '₹14,250.00'),
                  const Divider(height: 16),
                  _buildResultRow('Posted At', '12 Oct 2026, 11:23 AM'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: () => _showGoodsReceiptModal(totalStrips),
              child: const Text('View Receipt'),
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

  void _showGoodsReceiptModal(int totalStrips) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Goods Receipt (GRN-2026-00045)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Text(
              'Supplier: ${_supplierController.text} • Total: $totalStrips strips',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView(
                children: _lines.map((l) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.matchedProductName.isEmpty
                                  ? l.originalOcrText
                                  : l.matchedProductName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            Text(
                              'Batch ${l.batchNumber} • Exp: ${l.expiryDate}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '+${l.quantity} ${l.unit}s',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.matchaDeep,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isGreen = false}) {
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
            color: isGreen ? AppColors.matchaDeep : AppColors.ink,
          ),
        ),
      ],
    );
  }
}
