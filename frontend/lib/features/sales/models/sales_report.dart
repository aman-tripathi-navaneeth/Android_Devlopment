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

  /// Parse a line from backend inventory deduction records.
  factory SalesLineItem.fromBackendJson(Map<String, dynamic> json, int index) {
    final qty = json['quantity_deducted'] is num
        ? (json['quantity_deducted'] as num).toInt()
        : (json['converted_base_quantity'] is num
            ? (json['converted_base_quantity'] as num).toInt()
            : (json['quantity_entered'] is num
                ? (json['quantity_entered'] as num).toInt()
                : (json['quantity'] is num ? (json['quantity'] as num).toInt() : 1)));
    final unit = json['base_unit']?.toString() ??
        json['unit_entered']?.toString() ??
        'tablets';
    final productId = json['product_id']?.toString() ??
        json['matched_product_id']?.toString() ??
        'PROD-$index';
    final productName = json['product_name']?.toString() ??
        json['medicine_name']?.toString() ??
        json['matched_brand_name']?.toString() ??
        'Medicine';
    final batch = json['batch_number']?.toString() ??
        json['batch_allocated']?.toString() ??
        json['batch_preference']?.toString();

    return SalesLineItem(
      id: '${json['id']?.toString() ?? 'line'}-$index',
      originalOcrText: json['original_text']?.toString() ??
          json['raw_text']?.toString() ??
          '$productName $qty $unit',
      matchedProductId: productId,
      matchedProductName: productName,
      genericName: json['generic_name']?.toString() ?? productName,
      confidenceScore: 1.0,
      quantity: qty,
      unit: unit,
      batchNumber: batch,
      batchAllocationRule: batch != null ? 'FEFO (Batch $batch)' : 'FEFO',
      unitsPerPack: json['units_per_pack'] is num
          ? (json['units_per_pack'] as num).toInt()
          : 1,
      packUnit: json['pack_unit']?.toString() ?? unit,
      reviewStatus: SalesLineReviewStatus.accepted,
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
  /// True when this report was loaded from the backend (counter sale)
  final bool isCounterSale;

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
    this.isCounterSale = false,
  }) : importTimestamp = importTimestamp ?? DateTime.now();

  int get totalLines => lines.length;

  int get unresolvedLinesCount => lines.where((l) => l.needsResolution).length;

  int get resolvedLinesCount => lines.where((l) => !l.needsResolution).length;

  int get totalLooseUnitsDeducted =>
      lines.fold<int>(0, (sum, l) => sum + l.calculatedLooseUnits);

  bool get isReadyToPost => lines.isNotEmpty && unresolvedLinesCount == 0;

  /// Parse a backend salesReport document from JSONB.
  factory SalesReport.fromBackendJson(Map<String, dynamic> json) {
    // Status mapping
    SalesReportStatus parseStatus(String? s) {
      switch (s?.toLowerCase()) {
        case 'posted':
          return SalesReportStatus.posted;
        case 'pending_review':
          return SalesReportStatus.pendingReview;
        case 'ready_to_post':
          return SalesReportStatus.readyToPost;
        case 'rejected':
          return SalesReportStatus.rejected;
        case 'failed':
          return SalesReportStatus.failed;
        default:
          return SalesReportStatus.posted; // counter sales are posted immediately
      }
    }

    final rawLines = json['lines'];
    final List<SalesLineItem> parsedLines = [];
    if (rawLines is List) {
      for (int i = 0; i < rawLines.length; i++) {
        final l = rawLines[i];
        if (l is Map<String, dynamic>) {
          parsedLines.add(SalesLineItem.fromBackendJson(l, i));
        }
      }
    }

    DateTime parseDate(String? s) {
      if (s == null) return DateTime.now();
      try {
        return DateTime.parse(s).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }

    final reportDateStr = json['report_date']?.toString() ?? json['sale_date']?.toString();
    final createdAtStr = json['created_at']?.toString() ?? json['posted_at']?.toString();
    final reportId = json['id']?.toString() ?? json['report_id']?.toString() ?? 'unknown';
    final ref = json['report_reference']?.toString() ??
        json['source_id']?.toString() ??
        'COUNTER-$reportId';
    final status = parseStatus(json['status']?.toString());
    final txnRef = json['transaction_reference']?.toString() ??
        json['transaction_id']?.toString() ??
        json['source_number']?.toString() ??
        json['source_id']?.toString() ??
        (status == SalesReportStatus.posted ? ref : null);
    final isCounterSale = json['source_type']?.toString() == 'COUNTER_SALE' ||
        json['source_type']?.toString() == 'MANUAL_TRANSACTION' ||
        json['file_name']?.toString() == 'Manual Counter Transaction' ||
        json['file_name']?.toString() == 'Counter Sale' ||
        json['report_type']?.toString() == 'counter_sale';

    return SalesReport(
      id: reportId,
      reportReference: ref,
      reportDate: parseDate(reportDateStr),
      importTimestamp: parseDate(createdAtStr),
      status: status,
      selectedFileName: json['file_name']?.toString() ?? 'Counter Sale',
      selectedFileSize: '—',
      lines: parsedLines,
      authorizer: json['verified_by']?.toString() ??
          json['posted_by']?.toString() ??
          'Pharmacist',
      transactionReference: txnRef,
      isSimulated: false,
      notes: json['notes']?.toString(),
      isCounterSale: isCounterSale,
    );
  }

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
    bool? isCounterSale,
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
      isCounterSale: isCounterSale ?? this.isCounterSale,
    );
  }
}

