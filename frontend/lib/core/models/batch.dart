/// Batch data model for medicine inventory per PART 10.5 and PART 9.
class MedicineBatch {
  final String batchNumber; // e.g. "DL-91"
  final DateTime expiryDate;
  final int quantity; // In smallest sale units (e.g. tablets/capsules)
  final String? supplierName;
  final String? purchaseReceiptRef; // e.g. "GRN-2026-000001"
  final double? purchaseRate;
  final bool isQuarantined;

  const MedicineBatch({
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    this.supplierName,
    this.purchaseReceiptRef,
    this.purchaseRate,
    this.isQuarantined = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;

  bool get isCriticalExpiry => !isExpired && daysUntilExpiry <= 30;

  bool get isNearExpiry => !isExpired && daysUntilExpiry <= 90;

  String get expiryFormatted {
    final m = expiryDate.month.toString().padLeft(2, '0');
    return '${expiryDate.year}-$m';
  }

  MedicineBatch copyWith({
    String? batchNumber,
    DateTime? expiryDate,
    int? quantity,
    String? supplierName,
    String? purchaseReceiptRef,
    double? purchaseRate,
    bool? isQuarantined,
  }) {
    return MedicineBatch(
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      supplierName: supplierName ?? this.supplierName,
      purchaseReceiptRef: purchaseReceiptRef ?? this.purchaseReceiptRef,
      purchaseRate: purchaseRate ?? this.purchaseRate,
      isQuarantined: isQuarantined ?? this.isQuarantined,
    );
  }
}
