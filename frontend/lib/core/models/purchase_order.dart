import 'goods_receipt.dart';

enum POStatus { draft, sent, partiallyReceived, received, cancelled }

class POLineItem {
  final String lineId;
  final String productId;
  final String productName;
  final String unitOfPurchase;
  final int orderedQuantity;
  final double expectedUnitRate;
  final double lineTotal;
  final int receivedQuantity;
  final int damagedQuantity;
  const POLineItem({
    required this.lineId,
    required this.productId,
    required this.productName,
    required this.unitOfPurchase,
    required this.orderedQuantity,
    double? expectedUnitRate,
    double? expectedRate,
    double? lineTotal,
    this.receivedQuantity = 0,
    this.damagedQuantity = 0,
  }) : expectedUnitRate = expectedUnitRate ?? expectedRate ?? 0.0,
       lineTotal =
           lineTotal ??
           ((orderedQuantity * (expectedUnitRate ?? expectedRate ?? 0.0)));

  int get remainingQuantity =>
      (orderedQuantity - receivedQuantity).clamp(0, orderedQuantity);

  POLineItem copyWith({
    String? lineId,
    String? productId,
    String? productName,
    String? unitOfPurchase,
    int? orderedQuantity,
    double? expectedUnitRate,
    double? lineTotal,
    int? receivedQuantity,
    int? damagedQuantity,
  }) {
    return POLineItem(
      lineId: lineId ?? this.lineId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitOfPurchase: unitOfPurchase ?? this.unitOfPurchase,
      orderedQuantity: orderedQuantity ?? this.orderedQuantity,
      expectedUnitRate: expectedUnitRate ?? this.expectedUnitRate,
      lineTotal: lineTotal ?? this.lineTotal,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      damagedQuantity: damagedQuantity ?? this.damagedQuantity,
    );
  }
}

class PurchaseOrder {
  final String id;
  final String purchaseOrderNumber; // e.g. "PO-2026-000101"
  final String supplierId;
  final String supplierName;
  final DateTime orderDate;
  final POStatus status;
  final List<POLineItem> items;
  final double totalAmount;
  final String? notes;
  final DateTime? expectedDeliveryDate;
  final DateTime? sentAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final List<GoodsReceipt> receipts;

  PurchaseOrder({
    required this.id,
    required this.purchaseOrderNumber,
    required this.supplierId,
    required this.supplierName,
    DateTime? orderDate,
    DateTime? createdAt,
    required this.status,
    required this.items,
    double? totalAmount,
    this.notes,
    this.expectedDeliveryDate,
    this.sentAt,
    this.cancelledAt,
    this.cancelReason,
    this.receipts = const [],
  }) : orderDate = orderDate ?? createdAt ?? DateTime.now(),
       totalAmount =
           totalAmount ?? items.fold(0.0, (sum, i) => sum + i.lineTotal);

  int get totalOrderedQuantity =>
      items.fold(0, (sum, item) => sum + item.orderedQuantity);
  int get totalReceivedQuantity =>
      items.fold(0, (sum, item) => sum + item.receivedQuantity);
  int get totalRemainingQuantity =>
      items.fold(0, (sum, item) => sum + item.remainingQuantity);

  PurchaseOrder copyWith({
    String? id,
    String? purchaseOrderNumber,
    String? supplierId,
    String? supplierName,
    DateTime? orderDate,
    POStatus? status,
    List<POLineItem>? items,
    double? totalAmount,
    String? notes,
    DateTime? expectedDeliveryDate,
    DateTime? sentAt,
    DateTime? cancelledAt,
    String? cancelReason,
    List<GoodsReceipt>? receipts,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      purchaseOrderNumber: purchaseOrderNumber ?? this.purchaseOrderNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      orderDate: orderDate ?? this.orderDate,
      status: status ?? this.status,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      sentAt: sentAt ?? this.sentAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      receipts: receipts ?? this.receipts,
    );
  }
}
