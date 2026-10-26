import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sales_report.dart';

/// Pre-configured mock OCR scenarios per Section 12.
enum MockOcrScenario {
  standardMixed, // Default: has 1 low-confidence unmatched line
  allMatchedClean, // All lines high confidence
  withExplicitBatches, // Has specific batch numbers printed
  duplicateWarning, // Uses existing report reference
  simulatedFailure, // Simulates a ledger posting failure
}

extension MockOcrScenarioExtension on MockOcrScenario {
  String get displayName {
    switch (this) {
      case MockOcrScenario.standardMixed:
        return 'Standard Register (Mixed Confidence + Unmatched Item)';
      case MockOcrScenario.allMatchedClean:
        return 'Clean Register (100% High Confidence Matches)';
      case MockOcrScenario.withExplicitBatches:
        return 'Batch-Specific Register (Printed Batch Numbers)';
      case MockOcrScenario.duplicateWarning:
        return 'Duplicate Test (Re-importing Existing Reference)';
      case MockOcrScenario.simulatedFailure:
        return 'Failure Test (Simulate Posting Network Rejection)';
    }
  }
}

/// Abstract OCR Adapter Interface
abstract class SalesOcrAdapter {
  Future<SalesReport> extractSalesReport({
    required String fileName,
    required String reportReference,
    required DateTime reportDate,
    MockOcrScenario scenario = MockOcrScenario.standardMixed,
  });

  Future<bool> postSalesReportDeductions(SalesReport report);
}

/// Clearly labelled MOCK OCR Implementation (Section 4 & 12).
/// Does not claim to be a real OCR provider; demonstrates full UI review & confirmation.
class MockSalesOcrAdapter extends ChangeNotifier implements SalesOcrAdapter {
  static final MockSalesOcrAdapter _instance = MockSalesOcrAdapter._internal();
  factory MockSalesOcrAdapter() => _instance;
  MockSalesOcrAdapter._internal();

  final List<SalesReport> _history = [];
  List<SalesReport> get history => List.unmodifiable(_history);

  void _initHistory() {
    final now = DateTime.now();

    // 1. Seeded Posted Report 1 (Yesterday)
    _history.add(
      SalesReport(
        id: 'rep-hist-1',
        reportReference: 'REPORT-2026-10-12',
        reportDate: now.subtract(const Duration(days: 1)),
        importTimestamp: now.subtract(const Duration(days: 1, hours: 2)),
        status: SalesReportStatus.posted,
        selectedFileName: 'EOD_Sales_12Oct2026.pdf',
        selectedFileSize: '1.8 MB',
        authorizer: 'Aditya (Pharmacist)',
        transactionReference: 'TXN-OUT-2026-1012-01',
        isSimulated: true,
        notes: 'End-of-day register printout from counter billing terminal.',
        lines: [
          SalesLineItem(
            id: 'H1-L1',
            originalOcrText: 'DOLO 650MG STRIP 10 (REGULAR COUNTER)',
            matchedProductId: 'MED-000101',
            matchedProductName: 'Dolo 650mg',
            genericName: 'Paracetamol',
            confidenceScore: 0.96,
            quantity: 10,
            unit: 'strips',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch DL-91)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
          SalesLineItem(
            id: 'H1-L2',
            originalOcrText: 'PAN 40MG STRIP 5 (PRESCRIBED)',
            matchedProductId: 'MED-000103',
            matchedProductName: 'Pan 40',
            genericName: 'Pantoprazole',
            confidenceScore: 0.92,
            quantity: 5,
            unit: 'strips',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch PN-2024-8)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
          SalesLineItem(
            id: 'H1-L3',
            originalOcrText: 'GLYCOMET 500 LOOSE 20T',
            matchedProductId: 'MED-000105',
            matchedProductName: 'Glycomet 500',
            genericName: 'Metformin HCl',
            confidenceScore: 0.95,
            quantity: 20,
            unit: 'tablets',
            unitsPerPack: 20,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch GL-2025)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
        ],
      ),
    );

    // 2. Seeded Posted Report 2 (2 Days Ago)
    _history.add(
      SalesReport(
        id: 'rep-hist-2',
        reportReference: 'REPORT-2026-10-11',
        reportDate: now.subtract(const Duration(days: 2)),
        importTimestamp: now.subtract(const Duration(days: 2, hours: 1)),
        status: SalesReportStatus.posted,
        selectedFileName: 'Manual_Daybook_11Oct.jpg',
        selectedFileSize: '3.1 MB',
        authorizer: 'Aditya (Pharmacist)',
        transactionReference: 'TXN-OUT-2026-1011-01',
        isSimulated: true,
        notes: 'Manual register photo imported at close of shift.',
        lines: [
          SalesLineItem(
            id: 'H2-L1',
            originalOcrText: 'AUGMENTIN 625 DUO STRIP 2',
            matchedProductId: 'MED-000102',
            matchedProductName: 'Augmentin 625 Duo',
            genericName: 'Amoxicillin & Clavulanate',
            confidenceScore: 0.94,
            quantity: 2,
            unit: 'strips',
            unitsPerPack: 10,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch AG-84)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
          SalesLineItem(
            id: 'H2-L2',
            originalOcrText: 'TELMA 40MG 1 STRIP (REGULAR)',
            matchedProductId: 'MED-000106',
            matchedProductName: 'Telma 40',
            genericName: 'Telmisartan',
            confidenceScore: 0.91,
            quantity: 1,
            unit: 'strips',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch TL-401)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
        ],
      ),
    );
  }

  /// Checks if a report reference already exists in history.
  bool isDuplicateReference(String reference) {
    final cleanRef = reference.trim().toLowerCase();
    return _history.any(
      (r) => r.reportReference.trim().toLowerCase() == cleanRef,
    );
  }

  @override
  Future<SalesReport> extractSalesReport({
    required String fileName,
    required String reportReference,
    required DateTime reportDate,
    MockOcrScenario scenario = MockOcrScenario.standardMixed,
  }) async {
    // Simulate optical character recognition processing delay (150-300ms)
    await Future.delayed(const Duration(milliseconds: 350));

    final reportId = 'rep-${DateTime.now().millisecondsSinceEpoch}';
    final lines = <SalesLineItem>[];

    switch (scenario) {
      case MockOcrScenario.allMatchedClean:
        lines.addAll([
          SalesLineItem(
            id: '$reportId-L1',
            originalOcrText: 'DOLO 650MG STRIP 3 (COUNTER)',
            matchedProductId: 'MED-000101',
            matchedProductName: 'Dolo 650mg',
            genericName: 'Paracetamol',
            confidenceScore: 0.95,
            quantity: 3,
            unit: 'strips',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch DL-91)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
          SalesLineItem(
            id: '$reportId-L2',
            originalOcrText: 'PAN 40MG TABLETS 15 LOOSE',
            matchedProductId: 'MED-000103',
            matchedProductName: 'Pan 40',
            genericName: 'Pantoprazole',
            confidenceScore: 0.93,
            quantity: 15,
            unit: 'tablets',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch PN-2024-8)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
          SalesLineItem(
            id: '$reportId-L3',
            originalOcrText: 'TELMA 40MG STRIP 1',
            matchedProductId: 'MED-000106',
            matchedProductName: 'Telma 40',
            genericName: 'Telmisartan',
            confidenceScore: 0.91,
            quantity: 1,
            unit: 'strips',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch TL-401)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
        ]);
        break;

      case MockOcrScenario.withExplicitBatches:
        lines.addAll([
          SalesLineItem(
            id: '$reportId-L1',
            originalOcrText: 'DOLO 650 (B: DL-91) 5 TABLETS',
            matchedProductId: 'MED-000101',
            matchedProductName: 'Dolo 650mg',
            genericName: 'Paracetamol',
            confidenceScore: 0.92,
            quantity: 5,
            unit: 'tablets',
            batchNumber: 'DL-91',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'Specific Batch DL-91 (Printed)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
          SalesLineItem(
            id: '$reportId-L2',
            originalOcrText: 'AUGMENTIN 625 (B: AG-84) 1 STRIP',
            matchedProductId: 'MED-000102',
            matchedProductName: 'Augmentin 625 Duo',
            genericName: 'Amoxicillin & Clavulanate',
            confidenceScore: 0.90,
            quantity: 1,
            unit: 'strips',
            batchNumber: 'AG-84',
            unitsPerPack: 10,
            packUnit: 'strip',
            batchAllocationRule: 'Specific Batch AG-84 (Printed)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
        ]);
        break;

      case MockOcrScenario.duplicateWarning:
      case MockOcrScenario.simulatedFailure:
      case MockOcrScenario.standardMixed:
      default:
        lines.addAll([
          SalesLineItem(
            id: '$reportId-L1',
            originalOcrText: 'DOLO 650 LOOSE 5T (COUNTER SALE)',
            matchedProductId: 'MED-000101',
            matchedProductName: 'Dolo 650mg',
            genericName: 'Paracetamol',
            confidenceScore: 0.94, // HIGH
            quantity: 5,
            unit: 'tablets',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch DL-91)',
            reviewStatus: SalesLineReviewStatus.accepted,
          ),
          SalesLineItem(
            id: '$reportId-L2',
            originalOcrText: 'PAN 40 STRIP 2 (EVENING BILLED)',
            matchedProductId: 'MED-000103',
            matchedProductName: 'Pan 40',
            genericName: 'Pantoprazole',
            confidenceScore: 0.84, // MEDIUM
            quantity: 2,
            unit: 'strips',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO (Batch PN-2024-8)',
            reviewStatus: SalesLineReviewStatus.unresolved,
          ),
          SalesLineItem(
            id: '$reportId-L3',
            originalOcrText: 'CETRIZINE 10MG 10T UNKNOWN BRAND',
            matchedProductId: '', // UNMATCHED
            matchedProductName: 'Unmatched Medicine',
            genericName: 'Cetirizine HCl',
            confidenceScore: 0.45, // LOW (<0.70)
            quantity: 10,
            unit: 'tablets',
            unitsPerPack: 10,
            packUnit: 'strip',
            batchAllocationRule: 'Unassigned',
            reviewStatus: SalesLineReviewStatus.unresolved,
            validationError: 'Match required before stock review',
          ),
        ]);
        break;
    }

    final draft = SalesReport(
      id: reportId,
      reportReference: scenario == MockOcrScenario.duplicateWarning
          ? 'REPORT-2026-10-12'
          : reportReference,
      reportDate: reportDate,
      importTimestamp: DateTime.now(),
      status: SalesReportStatus.draft,
      selectedFileName: fileName,
      selectedFileSize: '2.4 MB',
      lines: lines,
      authorizer: 'Aditya (Pharmacist)',
      isSimulated: true,
      notes: 'Imported via Mock OCR Adapter [${scenario.displayName}]',
    );

    return draft;
  }

  @override
  Future<bool> postSalesReportDeductions(SalesReport report) async {
    // Simulate server communication latency
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulated failure test scenario
    if (report.notes?.contains('Failure Test') ?? false) {
      report.status = SalesReportStatus.failed;
      notifyListeners();
      return false;
    }

    // Assign realistic simulated transaction reference
    final txnRef =
        'TXN-OUT-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${(_history.length + 1).toString().padLeft(2, '0')}';

    report.status = SalesReportStatus.posted;
    report.transactionReference = txnRef;

    // Add to history
    _history.insert(0, report);
    notifyListeners();

    return true;
  }
}
