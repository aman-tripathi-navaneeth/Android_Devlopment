enum InventoryPostingStatus {
  draft,
  needsReview,
  pendingPosting,
  pending,
  posted,
  failed,
}

class GRNLineItem {
  final String lineId;
  final String productId;
  final String productName;
  final String unitOfPurchase;
  final int originalOrderedQuantity;
  final int quantityReceived;
  final int quantityDamaged;
  final int quantityAccepted; // received - damaged
  final String? damageReason;
  final String? batchNumber;
  final String? expiryDate;

  const GRNLineItem({
    required this.lineId,
    required this.productId,
    required this.productName,
    required this.unitOfPurchase,
    this.originalOrderedQuantity = 0,
    required this.quantityReceived,
    this.quantityDamaged = 0,
    required this.quantityAccepted,
    this.damageReason,
    this.batchNumber,
    this.expiryDate,
  });
}

class GoodsReceipt {
  final String id;
  final String receiptNumber; // e.g. "GRN-2026-000001"
  final String purchaseOrderId;
  final String purchaseOrderNumber;
  final String supplierId;
  final DateTime receivedAt;
  final List<GRNLineItem> items;
  final String? notes;
  final String verifiedBy;
  final InventoryPostingStatus inventoryPostingStatus;

  const GoodsReceipt({
    required this.id,
    required this.receiptNumber,
    required this.purchaseOrderId,
    required this.purchaseOrderNumber,
    required this.supplierId,
    required this.receivedAt,
    required this.items,
    this.notes,
    this.verifiedBy = 'Aditya (Pharmacist)',
    this.inventoryPostingStatus = InventoryPostingStatus.posted,
  });

  int get totalAcceptedQuantity =>
      items.fold(0, (sum, i) => sum + i.quantityAccepted);
}
