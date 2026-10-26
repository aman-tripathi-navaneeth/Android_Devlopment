import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/colors.dart';
import '../../../core/api/api_client.dart';
import '../../invoices/screens/invoice_scan_screen.dart';
import '../../sales/screens/sales_report_scan_screen.dart';

enum DocumentScanType { invoice, salesReport }

/// Camera Viewfinder Screen matching Screen 3 of the Workflow Board & user viewfinder image.
/// Displays corner brackets, document preview mockup, "Position the document within the frame",
/// PHOTO | DOCUMENT mode toggle, Upload button, and circular white shutter button.
class CameraCaptureScreen extends StatefulWidget {
  final DocumentScanType scanType;

  const CameraCaptureScreen({
    super.key,
    this.scanType = DocumentScanType.invoice,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  bool _isDocumentMode = true;
  bool _flashOn = false;
  bool _isFlashing = false;

  Future<void> _onCapture({required ImageSource source}) async {
    final image = await ImagePicker().pickImage(source: source, imageQuality: 95);
    if (image == null) return;
    setState(() => _isFlashing = true);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() => _isFlashing = false);
    final bytes = await image.readAsBytes();
    final response = await ApiClient().scanDocumentImage(
      imageBytes: bytes,
      fileName: image.name,
      mimeType: image.mimeType ?? 'image/jpeg',
      documentType: widget.scanType == DocumentScanType.invoice
          ? 'invoice'
          : 'sales_report',
    );
    if (!mounted) return;
    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini extraction failed. Check the backend and API key.')),
      );
      return;
    }
    if (widget.scanType == DocumentScanType.invoice) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => InvoiceScanScreen(
          initialViewMode: 1,
          aiScanResponse: response,
        )),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SalesReportScanScreen(
          aiScanResponse: response,
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInvoice = widget.scanType == DocumentScanType.invoice;

    return Scaffold(
      backgroundColor: const Color(0xFF111317),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 640;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 520 : double.infinity,
                  maxHeight: isDesktop ? 800 : double.infinity,
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // Top Camera Controls Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                tooltip: 'Close camera',
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isInvoice
                                          ? Icons.receipt_long_rounded
                                          : Icons.point_of_sale_rounded,
                                      size: 14,
                                      color: AppColors.matcha,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isInvoice
                                          ? 'Invoice Scanner (Mock)'
                                          : 'Sales Scanner (Mock)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _flashOn
                                          ? Icons.flash_on_rounded
                                          : Icons.flash_off_rounded,
                                      color: _flashOn
                                          ? Colors.amber
                                          : Colors.white70,
                                      size: 22,
                                    ),
                                    tooltip: _flashOn
                                        ? 'Flash on'
                                        : 'Flash off',
                                    onPressed: () =>
                                        setState(() => _flashOn = !_flashOn),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.grid_on_rounded,
                                      color: Colors.white70,
                                      size: 22,
                                    ),
                                    tooltip: 'Toggle Grid',
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Viewfinder Area with Corner Brackets
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 8.0,
                              ),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: 320,
                                  height: 444,
                                  child: Stack(
                                    children: [
                                      // Outer Border Frame
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.35,
                                            ),
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),

                                      // 4 Corner Brackets
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: _buildCorner(
                                          isTop: true,
                                          isLeft: true,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: _buildCorner(
                                          isTop: true,
                                          isLeft: false,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: _buildCorner(
                                          isTop: false,
                                          isLeft: true,
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: _buildCorner(
                                          isTop: false,
                                          isLeft: false,
                                        ),
                                      ),

                                      // Document Mockup inside Viewfinder
                                      Center(
                                        child: FractionallySizedBox(
                                          widthFactor: 0.82,
                                          heightFactor: 0.75,
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.4),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        isInvoice
                                                            ? 'TAX INVOICE / CHALLAN'
                                                            : 'DAILY SALES REGISTER (POS)',
                                                        style: const TextStyle(
                                                          color: Colors.black87,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 8.5,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isInvoice
                                                          ? 'INV-9032'
                                                          : 'SR-1012',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        fontSize: 7.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Divider(
                                                  height: 8,
                                                  thickness: 0.8,
                                                ),
                                                const SizedBox(height: 4),
                                                if (isInvoice) ...[
                                                  _buildDocRow(
                                                    'Augmentin 625 Duo 10x10',
                                                    '10 strips',
                                                  ),
                                                  _buildDocRow(
                                                    'Crocin 500mg Advance',
                                                    '20 strips',
                                                  ),
                                                  _buildDocRow(
                                                    'Zerodol SP Tablet',
                                                    '15 strips',
                                                  ),
                                                  _buildDocRow(
                                                    'Pantop 40mg Injection/Tabs',
                                                    '10 strips',
                                                  ),
                                                ] else ...[
                                                  _buildDocRow(
                                                    'Augmentin 625 Duo',
                                                    '5 tabs',
                                                  ),
                                                  _buildDocRow(
                                                    'Crocin 500mg Advance',
                                                    '8 tabs',
                                                  ),
                                                  _buildDocRow(
                                                    'Unknown / Low Conf Item',
                                                    '10 tabs',
                                                  ),
                                                  _buildDocRow(
                                                    'Pantop 40mg Tabs',
                                                    '6 tabs',
                                                  ),
                                                ],
                                                const Spacer(),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      top: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade400,
                                                        style:
                                                            BorderStyle.solid,
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Expanded(
                                                        child: Text(
                                                          'TOTAL VALUE',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontSize: 8,
                                                            color: Colors.black,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        isInvoice
                                                            ? '₹14,250.00'
                                                            : '22 units sold',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 8,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Alignment Pill Banner
                                      Positioned(
                                        bottom: 16,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.65,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'Position the document within the frame',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Mode Selector: PHOTO | DOCUMENT
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _isDocumentMode = false),
                                child: Text(
                                  'PHOTO',
                                  style: TextStyle(
                                    color: !_isDocumentMode
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _isDocumentMode = true),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'DOCUMENT',
                                      style: TextStyle(
                                        color: _isDocumentMode
                                            ? AppColors.matcha
                                            : Colors.white54,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (_isDocumentMode)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        width: 36,
                                        height: 2,
                                        color: AppColors.matcha,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottom Shutter Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Upload from file/gallery
                              InkWell(
                                onTap: () => _onCapture(source: ImageSource.gallery),
                                borderRadius: BorderRadius.circular(8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.upload_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Upload',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Large White Circular Shutter Button
                              GestureDetector(
                                onTap: () => _onCapture(source: ImageSource.camera),
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 44), // Balances layout
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Flash effect overlay
                    if (_isFlashing) Container(color: Colors.white),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDocRow(String title, String qty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 7.5,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            qty,
            style: TextStyle(fontSize: 7.5, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Colors.white, width: 3.5)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Colors.white, width: 3.5)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Colors.white, width: 3.5)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Colors.white, width: 3.5)
              : BorderSide.none,
        ),
      ),
    );
  }
}
