/// Match confidence classification per Section 5.
enum MatchConfidence {
  high, // >= 0.90
  medium, // 0.70 - 0.89
  low, // < 0.70
}

extension MatchConfidenceExtension on MatchConfidence {
  String get label {
    switch (this) {
      case MatchConfidence.high:
        return 'HIGH';
      case MatchConfidence.medium:
        return 'MEDIUM';
      case MatchConfidence.low:
        return 'LOW';
    }
  }

  static MatchConfidence fromScore(double score) {
    if (score >= 0.90) return MatchConfidence.high;
    if (score >= 0.70) return MatchConfidence.medium;
    return MatchConfidence.low;
  }
}

/// Status of individual extracted row review.
enum SalesLineReviewStatus { unresolved, manuallyResolved, accepted, rejected }

/// Status of the sales report import workflow.
enum SalesReportStatus {
  draft,
  pendingReview,
  readyToPost,
  posted,
  rejected,
  failed,
}

extension SalesReportStatusExtension on SalesReportStatus {
  String get label {
    switch (this) {
      case SalesReportStatus.draft:
        return 'Draft';
      case SalesReportStatus.pendingReview:
        return 'Pending Review';
      case SalesReportStatus.readyToPost:
        return 'Ready to Post';
      case SalesReportStatus.posted:
        return 'Posted';
      case SalesReportStatus.rejected:
        return 'Rejected';
      case SalesReportStatus.failed:
        return 'Posting Failed';
    }
  }
}

/// Extracted sales line with auditability & manual corrections
class SalesLineItem {
  final String id;
  final String originalOcrText; // Rule 7: Preserved original extracted value
  String matchedProductId; // e.g. MED-000101
  String matchedProductName;
  String genericName;
  double confidenceScore; // [0.0 - 1.0]
  int quantity;
  String unit; // e.g. tablets, strips, ml
  String? batchNumber; // specific batch if supplied on register
  String batchAllocationRule; // e.g. FEFO (Batch DL-91)
  int unitsPerPack; // from catalogue
  String packUnit; // from catalogue
  SalesLineReviewStatus reviewStatus;
  DateTime saleDate;
  String? validationError;

  SalesLineItem({
    required this.id,
    required this.originalOcrText,
    this.matchedProductId = '',
    this.matchedProductName = '',
    this.genericName = '',
    required this.confidenceScore,
    required this.quantity,
    required this.unit,
    this.batchNumber,
    this.batchAllocationRule = 'FEFO (First Expiry, First Out)',
    this.unitsPerPack = 10,
    this.packUnit = 'strip',
    this.reviewStatus = SalesLineReviewStatus.unresolved,
    DateTime? saleDate,
    this.validationError,
  }) : saleDate = saleDate ?? DateTime.now();

  MatchConfidence get confidence =>
      MatchConfidenceExtension.fromScore(confidenceScore);

  bool get isMatched =>
      matchedProductId.isNotEmpty && matchedProductId != 'MANUAL_UNMATCHED';

  bool get isUnitUnclear =>
      unit.toLowerCase().trim() == 'unknown' || unit.trim().isEmpty;

  bool get needsResolution {
    if (!isMatched) return true;
    if (isUnitUnclear) return true;
    if (reviewStatus == SalesLineReviewStatus.unresolved &&
        confidence == MatchConfidence.low) {
      return true;
    }
    if (quantity <= 0) return true;
    return false;
  }

  /// Calculates quantity in loose base units (e.g. tablets) using per-medicine pack-size conversion.
  int get calculatedLooseUnits {
    final cleanUnit = unit.toLowerCase().trim();
    if (cleanUnit.contains('strip')) {
      final factor = unitsPerPack > 0 ? unitsPerPack : 10;
      return quantity * factor;
    }
    return quantity;
  }

  /// Display string for quantity sold with pack-size explanation.
  String get unitExplanation {
    final cleanUnit = unit.toLowerCase().trim();
    if (cleanUnit.contains('strip')) {
      final factor = unitsPerPack > 0 ? unitsPerPack : 10;
      return '$quantity strips ($factor tabs/strip = $calculatedLooseUnits tablets)';
    } else if (cleanUnit.contains('tab')) {
      return '$quantity tablets';
    } else {
      return '$quantity (Unit unconfirmed)';
    }
  }

  SalesLineItem copyWith({
    String? id,
    String? originalOcrText,
    String? matchedProductId,
    String? matchedProductName,
    String? genericName,
    double? confidenceScore,
    int? quantity,
    String? unit,
    String? batchNumber,
    String? batchAllocationRule,
    int? unitsPerPack,
    String? packUnit,
    SalesLineReviewStatus? reviewStatus,
    DateTime? saleDate,
    String? validationError,
  }) {
    return SalesLineItem(
      id: id ?? this.id,
      originalOcrText: originalOcrText ?? this.originalOcrText,
      matchedProductId: matchedProductId ?? this.matchedProductId,
      matchedProductName: matchedProductName ?? this.matchedProductName,
      genericName: genericName ?? this.genericName,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      batchNumber: batchNumber ?? this.batchNumber,
      batchAllocationRule: batchAllocationRule ?? this.batchAllocationRule,
      unitsPerPack: unitsPerPack ?? this.unitsPerPack,
      packUnit: packUnit ?? this.packUnit,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      saleDate: saleDate ?? this.saleDate,
      validationError: validationError ?? this.validationError,
    );
  }
}

/// Outward Sales Report Model
class SalesReport {
  final String id;
  final String reportReference; // e.g. REPORT-2026-10-13
  final DateTime reportDate;
  final DateTime importTimestamp;
  SalesReportStatus status;
  final String selectedFileName;
  final String selectedFileSize;
  final List<SalesLineItem> lines;
  final String authorizer;
  String? transactionReference; // e.g. TXN-OUT-2026-1013-01
  final bool isSimulated;
  final String? notes;

  SalesReport({
    required this.id,
    required this.reportReference,
    required this.reportDate,
    DateTime? importTimestamp,
    this.status = SalesReportStatus.draft,
    this.selectedFileName = 'EOD_Register_Scan.jpg',
    this.selectedFileSize = '2.4 MB',
    required this.lines,
    this.authorizer = 'Aditya (Pharmacist)',
    this.transactionReference,
    this.isSimulated = true,
    this.notes,
  }) : importTimestamp = importTimestamp ?? DateTime.now();

  int get totalLines => lines.length;

  int get unresolvedLinesCount => lines.where((l) => l.needsResolution).length;

  int get resolvedLinesCount => lines.where((l) => !l.needsResolution).length;

  int get totalLooseUnitsDeducted =>
      lines.fold<int>(0, (sum, l) => sum + l.calculatedLooseUnits);

  bool get isReadyToPost => lines.isNotEmpty && unresolvedLinesCount == 0;

  SalesReport copyWith({
    String? id,
    String? reportReference,
    DateTime? reportDate,
    DateTime? importTimestamp,
    SalesReportStatus? status,
    String? selectedFileName,
    String? selectedFileSize,
    List<SalesLineItem>? lines,
    String? authorizer,
    String? transactionReference,
    bool? isSimulated,
    String? notes,
  }) {
    return SalesReport(
      id: id ?? this.id,
      reportReference: reportReference ?? this.reportReference,
      reportDate: reportDate ?? this.reportDate,
      importTimestamp: importTimestamp ?? this.importTimestamp,
      status: status ?? this.status,
      selectedFileName: selectedFileName ?? this.selectedFileName,
      selectedFileSize: selectedFileSize ?? this.selectedFileSize,
      lines: lines ?? this.lines,
      authorizer: authorizer ?? this.authorizer,
      transactionReference: transactionReference ?? this.transactionReference,
      isSimulated: isSimulated ?? this.isSimulated,
      notes: notes ?? this.notes,
    );
  }
}
