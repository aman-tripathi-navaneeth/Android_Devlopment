import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
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
  MockSalesOcrAdapter._internal() {
    // Only load authentic sales reports from the backend
    syncReportsFromBackend();
  }

  final List<SalesReport> _history = [];
  List<SalesReport> get history => List.unmodifiable(_history);
  bool _isSyncing = false;

  /// Sync salesReports from the backend PostgreSQL into local history.
  Future<void> syncReportsFromBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final api = ApiClient();
      final list = await api.getSalesReports();
      final loaded = <SalesReport>[];
      for (final raw in list) {
        try {
          final report = SalesReport.fromBackendJson(raw);
          loaded.add(report);
        } catch (_) {}
      }
      // Preserve any locally recorded reports so newly posted sales don't vanish
      for (final existing in _history) {
        if (!loaded.any((r) => r.id == existing.id || (existing.reportReference.isNotEmpty && r.reportReference == existing.reportReference))) {
          loaded.add(existing);
        }
      }
      _history.clear();
      _history.addAll(loaded);
      notifyListeners();
    } catch (_) {}
    _isSyncing = false;
  }

  /// Called immediately after a counter sale is confirmed so the report
  /// appears in the Sales Hub without waiting for the next sync.
  void addCounterSaleReport(SalesReport report) {
    final existing = _history.indexWhere((r) => r.id == report.id);
    if (existing == -1) {
      _history.insert(0, report);
      notifyListeners();
    }
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
