import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_app/core/models/goods_receipt.dart';
import 'package:pharmacy_app/core/models/medicine.dart';
import 'package:pharmacy_app/core/models/batch.dart';
import 'package:pharmacy_app/core/models/purchase_order.dart';
import 'package:pharmacy_app/core/services/mock_data_service.dart';
import 'package:pharmacy_app/features/sales/models/sales_report.dart';

void main() {
  group('Members 2, 3, 7 Frontend Inventory Integrity Tests', () {
    late MockDataService service;

    setUp(() {
      service = MockDataService();
      service.addMedicine(
        Medicine(
          productId: 'MED-000101',
          name: 'Dolo 650mg',
          genericName: 'Paracetamol',
          strength: '650mg',
          form: 'Tablet',
          category: 'Analgesics',
          manufacturer: 'Micro Labs',
          packUnit: 'strip',
          saleUnit: 'tablet',
          unitsPerPack: 15,
          currentStock: 100,
          lowStockThreshold: 20,
          batches: [
            MedicineBatch(
              batchNumber: 'DL-91',
              expiryDate: DateTime(2028, 12, 31),
              quantity: 100,
            ),
          ],
        ),
      );
      if (service.purchaseOrders.isEmpty) {
        service.addPurchaseOrder(
          PurchaseOrder(
            id: 'po-test-01',
            purchaseOrderNumber: 'PO-2026-TEST',
            supplierId: 'SUP-000001',
            supplierName: 'Test Supplier',
            status: POStatus.sent,
            items: [
              const POLineItem(
                lineId: 'line-1',
                productId: 'MED-000101',
                productName: 'Dolo 650mg',
                unitOfPurchase: 'strip',
                orderedQuantity: 10,
              ),
            ],
          ),
        );
      }
    });

    test('Member 2: Medicine unit conversion calculation', () {
      final med = service.medicines.firstWhere((m) => m.productId == 'MED-000101');
      expect(med.unitsPerPack, equals(15));
      // 5 packs = 75 base units
      expect(5 * med.unitsPerPack, equals(75));
    });

    test('Member 3: Goods receipt converts pack quantity to base units upon posting', () {
      final medBefore = service.medicines.firstWhere((m) => m.productId == 'MED-000101');
      final initialStock = medBefore.currentStock;

      final po = service.purchaseOrders.first;
      final grn = service.recordGoodsReceipt(
        poId: po.id,
        receivedItems: [
          GRNLineItem(
            lineId: 'grn-line-test-1',
            productId: 'MED-000101',
            productName: 'Dolo 650mg',
            unitOfPurchase: 'strip',
            quantityReceived: 2,
            quantityAccepted: 2,
            batchNumber: 'TEST-BATCH-01',
            expiryDate: '2028-12-31',
          ),
        ],
      );

      expect(grn.inventoryPostingStatus, equals(InventoryPostingStatus.posted));

      final medAfter = service.medicines.firstWhere((m) => m.productId == 'MED-000101');
      // 2 strips * 15 tablets/strip = 30 tablets
      expect(medAfter.currentStock, equals(initialStock + 30));

      final testBatch = medAfter.batches.firstWhere((b) => b.batchNumber == 'TEST-BATCH-01');
      expect(testBatch.quantity, equals(30));
    });

    test('Member 3: Inward invoice converts pack quantity and rejects duplicate submission', () {
      final medBefore = service.medicines.firstWhere((m) => m.productId == 'MED-000101');
      final initialStock = medBefore.currentStock;

      final success1 = service.recordPurchaseInvoiceInward(
        invoiceNumber: 'INV-TEST-UNIQUE-99',
        supplierName: 'Test Supplier',
        items: [
          {
            'productId': 'MED-000101',
            'quantity': 3, // 3 strips = 45 tablets
            'batchNumber': 'INV-BATCH-99',
            'expiryDate': '2028-10-10',
          }
        ],
      );
      expect(success1, isTrue);

      final medAfter = service.medicines.firstWhere((m) => m.productId == 'MED-000101');
      expect(medAfter.currentStock, equals(initialStock + 45));

      // Attempt duplicate submission with the same invoice number
      final success2 = service.recordPurchaseInvoiceInward(
        invoiceNumber: 'INV-TEST-UNIQUE-99',
        supplierName: 'Test Supplier',
        items: [
          {
            'productId': 'MED-000101',
            'quantity': 3,
            'batchNumber': 'INV-BATCH-99',
            'expiryDate': '2028-10-10',
          }
        ],
      );
      // Must be rejected without adding duplicate stock
      expect(success2, isFalse);

      final medAfterDuplicate = service.medicines.firstWhere((m) => m.productId == 'MED-000101');
      expect(medAfterDuplicate.currentStock, equals(initialStock + 45));
    });

    test('Member 7: Sales deduction rejects insufficient stock with zero partial deductions', () {
      final medBefore = service.medicines.firstWhere((m) => m.productId == 'MED-000101');
      final currentStock = medBefore.currentStock;

      final excessiveReport = SalesReport(
        id: 'report-excessive-test',
        reportReference: 'REP-EXCESSIVE-01',
        reportDate: DateTime.now(),
        importTimestamp: DateTime.now(),
        status: SalesReportStatus.draft,
        lines: [
          SalesLineItem(
            id: 'line-excessive-1',
            originalOcrText: 'Dolo 650mg excessive',
            matchedProductId: 'MED-000101',
            matchedProductName: 'Dolo 650mg',
            genericName: 'Paracetamol',
            confidenceScore: 1.0,
            quantity: currentStock + 500, // Demands 500 more than available
            unit: 'tablets',
            unitsPerPack: 15,
            packUnit: 'strip',
            batchAllocationRule: 'FEFO',
            reviewStatus: SalesLineReviewStatus.manuallyResolved,
          ),
        ],
      );

      final result = service.recordSalesDeductions(excessiveReport);
      expect(result, isFalse); // Rejected!

      final medAfter = service.medicines.firstWhere((m) => m.productId == 'MED-000101');
      // Stock must be completely unchanged
      expect(medAfter.currentStock, equals(currentStock));
    });
  });
}
