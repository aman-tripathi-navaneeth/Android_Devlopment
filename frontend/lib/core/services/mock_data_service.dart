import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/supplier.dart';
import '../models/medicine.dart';
import '../models/batch.dart';
import '../models/purchase_order.dart';
import '../models/goods_receipt.dart';
import '../models/customer.dart';
import '../../features/sales/models/sales_report.dart';

/// Central state repository and service for offline testing & live API binding.
/// Contains realistic Indian pharmacy data per PART 4.10.
class MockDataService extends ChangeNotifier {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal() {
    // Synchronize catalogue from the backend database so medicines persist across browser reloads
    syncFromBackend();
  }

  bool _isLoadingFromBackend = false;
  bool get isLoadingFromBackend => _isLoadingFromBackend;

  Future<void> syncFromBackend() async {
    if (_isLoadingFromBackend) return;
    _isLoadingFromBackend = true;
    try {
      final api = ApiClient();
      final products = await api.getProducts(limit: 200);
      if (products.isNotEmpty) {
        final List<Medicine> loaded = [];
        for (final p in products) {
          final id = p['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final brandName = p['brand_name']?.toString() ?? '';
          final genericName = p['generic_name']?.toString() ?? brandName;
          final manufacturer = p['manufacturer']?.toString() ?? '';
          final form = p['form']?.toString() ?? 'tablet';
          final category = p['category']?.toString() ?? 'medicine';
          final baseUnit = p['base_unit']?.toString() ?? 'tablet';
          final strengthVal = p['strength_value'] != null ? '${p['strength_value']}' : '';
          final strengthUnit = p['strength_unit']?.toString() ?? 'mg';
          final strength = strengthVal.isNotEmpty ? '$strengthVal$strengthUnit' : '';

          String packUnit = 'strip';
          int unitsPerPack = 10;
          final conversions = p['unit_conversions'];
          if (conversions is List && conversions.isNotEmpty) {
            final first = conversions.first;
            if (first is Map) {
              packUnit = first['pack_unit']?.toString() ?? 'strip';
              unitsPerPack = int.tryParse(first['factor']?.toString() ?? '10') ?? 10;
            }
          }

          // Fetch real stock balance & batches for this product from the backend
          int currentStock = 0;
          List<MedicineBatch> batches = [];
          try {
            final balance = await api.getStockBalance(storeId: 'main_store', productId: id);
            if (balance != null) {
              currentStock = (balance['current_stock'] as num?)?.toInt() ?? 0;
              final bList = balance['batches'];
              if (bList is List) {
                for (final b in bList) {
                  if (b is Map) {
                    final bNum = b['batch_number']?.toString() ?? 'OPENING-$id';
                    final bQty = (b['quantity'] as num?)?.toInt() ?? 0;
                    DateTime expDate = DateTime.now().add(const Duration(days: 365 * 2));
                    final expStr = b['expiry_date']?.toString();
                    if (expStr != null && expStr.isNotEmpty) {
                      try {
                        if (expStr.contains('-') && expStr.length == 7) {
                          final parts = expStr.split('-');
                          expDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), 28);
                        } else {
                          expDate = DateTime.parse(expStr);
                        }
                      } catch (_) {}
                    }
                    batches.add(
                      MedicineBatch(
                        batchNumber: bNum,
                        expiryDate: expDate,
                        quantity: bQty,
                        supplierName: b['supplier_name']?.toString(),
                        purchaseRate: (b['purchase_rate_paise'] as num?) != null
                            ? (b['purchase_rate_paise'] as num) / 100.0
                            : null,
                      ),
                    );
                  }
                }
              }
            }
          } catch (_) {}

          loaded.add(
            Medicine(
              productId: id,
              name: brandName,
              genericName: genericName,
              strength: strength,
              form: form,
              category: category,
              manufacturer: manufacturer,
              packUnit: packUnit,
              saleUnit: baseUnit,
              unitsPerPack: unitsPerPack,
              currentStock: currentStock,
              lowStockThreshold: 20,
              isActive: p['status']?.toString().toLowerCase() != 'inactive',
              batches: batches,
            ),
          );
        }

        if (loaded.isNotEmpty) {
          _medicines.clear();
          _medicines.addAll(loaded);
          notifyListeners();
        }
      }
    } catch (_) {
      // Gracefully continue if backend offline
    } finally {
      _isLoadingFromBackend = false;
    }
  }

  // Collections
  final List<Supplier> _suppliers = [];
  final List<Medicine> _medicines = [];
  final List<PurchaseOrder> _purchaseOrders = [];
  final List<Customer> _customers = [];
  final List<Map<String, dynamic>> _stockMovements = [];

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  List<Medicine> get medicines => List.unmodifiable(_medicines);
  List<PurchaseOrder> get purchaseOrders => List.unmodifiable(_purchaseOrders);
  List<Customer> get customers => List.unmodifiable(_customers);
  List<Map<String, dynamic>> get stockMovements =>
      List.unmodifiable(_stockMovements);

  void _initSeedData() {
    // 1. SEED SUPPLIERS
    _suppliers.addAll([
      const Supplier(
        id: 'sup-1',
        supplierCode: 'SUP-000001',
        name: 'Sri Venkateswara Pharma Distributors',
        contactPerson: 'K. Ramesh',
        phone: '9848012345',
        email: 'ramesh@venkateswarapharma.in',
        address: 'Shop 14, Main Road, Governorpet, Vijayawada, AP',
        gstNumber: '37AAAAA0000A1Z5',
        paymentTerms: 'Net 30',
        isActive: true,
        openPurchaseOrderCount: 2,
        totalOrderValue: 145000.00,
        outstandingUnits: 120,
      ),
      const Supplier(
        id: 'sup-2',
        supplierCode: 'SUP-000002',
        name: 'Apollo Med Wholesale Agency',
        contactPerson: 'V. Suresh Kumar',
        phone: '9440167890',
        email: 'orders@apollomedwholesale.com',
        address: 'Plot 42, IDA Mallapur, Hyderabad, TS',
        gstNumber: '36BBBBB1111B2Z4',
        paymentTerms: 'Net 15',
        isActive: true,
        openPurchaseOrderCount: 1,
        totalOrderValue: 88500.00,
        outstandingUnits: 45,
      ),
      const Supplier(
        id: 'sup-3',
        supplierCode: 'SUP-000003',
        name: 'Balaji Drug Agencies',
        contactPerson: 'M. Srinivas',
        phone: '9885054321',
        email: 'balajidrugs@gmail.com',
        address: 'Brodipet 4th Lane, Guntur, AP',
        gstNumber: '37CCCCC2222C3Z3',
        paymentTerms: 'Net 21',
        isActive: true,
        openPurchaseOrderCount: 0,
        totalOrderValue: 32000.00,
        outstandingUnits: 0,
      ),
      const Supplier(
        id: 'sup-4',
        supplierCode: 'SUP-000004',
        name: 'Reddy & Sons Pharmaceuticals',
        contactPerson: 'P. Venkat Reddy',
        phone: '9700098765',
        email: 'reddysons@pharma.biz',
        address: 'Daba Gardens, Visakhapatnam, AP',
        gstNumber: '37DDDDD3333D4Z2',
        paymentTerms: 'Immediate',
        isActive: false, // Inactive test case
        openPurchaseOrderCount: 0,
        totalOrderValue: 54000.00,
        outstandingUnits: 0,
      ),
    ]);

    // 2. SEED MEDICINES WITH BATCH BREAKDOWNS (Catalogue & Inventory)
    final now = DateTime.now();
    _medicines.addAll([
      Medicine(
        productId: 'MED-000101',
        name: 'Dolo 650mg',
        genericName: 'Paracetamol',
        strength: '650mg',
        form: 'Tablet',
        category: 'Analgesic & Antipyretic',
        manufacturer: 'Micro Labs Ltd',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 15,
        currentStock: 180,
        lowStockThreshold: 50,
        batches: [
          MedicineBatch(
            batchNumber: 'DL-91',
            expiryDate: DateTime(now.year + 2, 12, 31),
            quantity: 120,
            supplierName: 'Sri Venkateswara Pharma',
            purchaseReceiptRef: 'GRN-2026-000001',
            purchaseRate: 32.50,
          ),
          MedicineBatch(
            batchNumber: 'DL-84',
            expiryDate: now.add(
              const Duration(days: 35),
            ), // Near Expiry (< 90 days)
            quantity: 60,
            supplierName: 'Balaji Drug Agencies',
            purchaseReceiptRef: 'GRN-2026-000002',
            purchaseRate: 31.00,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000102',
        name: 'Augmentin 625 Duo',
        genericName: 'Amoxicillin & Potassium Clavulanate',
        strength: '625mg',
        form: 'Tablet',
        category: 'Antibiotic',
        manufacturer: 'GSK Pharmaceuticals',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 10,
        currentStock: 25, // Low stock test case
        lowStockThreshold: 30,
        batches: [
          MedicineBatch(
            batchNumber: 'AG-84',
            expiryDate: DateTime(now.year + 1, 9, 30),
            quantity: 25,
            supplierName: 'Apollo Med Wholesale',
            purchaseReceiptRef: 'GRN-2026-000003',
            purchaseRate: 175.00,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000103',
        name: 'Pan 40',
        genericName: 'Pantoprazole Gastro-resistant',
        strength: '40mg',
        form: 'Tablet',
        category: 'Antacid / PPI',
        manufacturer: 'Alkem Laboratories',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 15,
        currentStock: 95,
        lowStockThreshold: 20,
        batches: [
          MedicineBatch(
            batchNumber: 'PN-2024-8',
            expiryDate: DateTime(now.year + 2, 6, 30),
            quantity: 95,
            supplierName: 'Sri Venkateswara Pharma',
            purchaseReceiptRef: 'GRN-2026-000001',
            purchaseRate: 64.00,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000104',
        name: 'Azee 500',
        genericName: 'Azithromycin',
        strength: '500mg',
        form: 'Tablet',
        category: 'Antibiotic',
        manufacturer: 'Cipla Ltd',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 5,
        currentStock: 12, // Low stock test case
        lowStockThreshold: 25,
        batches: [
          MedicineBatch(
            batchNumber: 'AZ-12',
            expiryDate: now.add(
              const Duration(days: 15),
            ), // Critical Expiry (< 30 days)
            quantity: 12,
            supplierName: 'Apollo Med Wholesale',
            purchaseReceiptRef: 'GRN-2026-000004',
            purchaseRate: 95.00,
          ),
          MedicineBatch(
            batchNumber: 'AZ-09',
            expiryDate: now.subtract(const Duration(days: 45)), // Expired batch
            quantity: 0,
            supplierName: 'Apollo Med Wholesale',
            purchaseReceiptRef: 'GRN-2025-000892',
            purchaseRate: 92.00,
            isQuarantined: true,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000105',
        name: 'Glycomet 500',
        genericName: 'Metformin Hydrochloride',
        strength: '500mg',
        form: 'Tablet',
        category: 'Anti-diabetic',
        manufacturer: 'USV Ltd',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 20,
        currentStock: 240,
        lowStockThreshold: 40,
        batches: [
          MedicineBatch(
            batchNumber: 'GL-2025',
            expiryDate: DateTime(now.year + 3, 3, 31),
            quantity: 240,
            supplierName: 'Balaji Drug Agencies',
            purchaseReceiptRef: 'GRN-2026-000005',
            purchaseRate: 28.00,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000106',
        name: 'Telma 40',
        genericName: 'Telmisartan',
        strength: '40mg',
        form: 'Tablet',
        category: 'Anti-hypertensive',
        manufacturer: 'Glenmark Pharmaceuticals',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 15,
        currentStock: 60,
        lowStockThreshold: 30,
        batches: [
          MedicineBatch(
            batchNumber: 'TL-401',
            expiryDate: DateTime(now.year + 1, 11, 30),
            quantity: 60,
            supplierName: 'Sri Venkateswara Pharma',
            purchaseReceiptRef: 'GRN-2026-000001',
            purchaseRate: 85.00,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000107',
        name: 'Cotton roll',
        genericName: 'Absorbent Surgical Cotton',
        strength: '500g',
        form: MedicineForms.other,
        category: MedicineCategories.clinic,
        manufacturer: 'Sample Surgicals',
        packUnit: 'pack',
        saleUnit: 'piece',
        unitsPerPack: 1,
        currentStock: 40,
        lowStockThreshold: 10,
        batches: [
          MedicineBatch(
            batchNumber: 'CR-24',
            expiryDate: DateTime(now.year + 3, 1, 1),
            quantity: 40,
            supplierName: 'Balaji Drug Agencies',
            purchaseReceiptRef: 'GRN-2026-000006',
            purchaseRate: 95.00,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000108',
        name: 'Betadine 10%',
        genericName: 'Povidone Iodine',
        strength: '10%',
        form: MedicineForms.tube,
        category: MedicineCategories.derma,
        manufacturer: 'Win-Medicare',
        packUnit: 'box',
        saleUnit: 'tube',
        unitsPerPack: 1,
        currentStock: 0,
        lowStockThreshold: 15,
        isActive: false, // Inactive deactivation test case matching other team's seeds
      ),
      Medicine(
        productId: 'MED-000109',
        name: 'Dettol Antiseptic Liquid',
        genericName: 'Chloroxylenol',
        strength: '250ml',
        form: MedicineForms.bottle,
        category: MedicineCategories.personalCare,
        manufacturer: 'Reckitt Benckiser',
        packUnit: 'case',
        saleUnit: 'bottle',
        unitsPerPack: 12,
        currentStock: 36,
        lowStockThreshold: 12,
      ),
      Medicine(
        productId: 'MED-000110',
        name: 'Ensure Diabetes Care',
        genericName: 'Nutritional Powder',
        strength: '400g',
        form: MedicineForms.bottle,
        category: MedicineCategories.food,
        manufacturer: 'Abbott Healthcare',
        packUnit: 'carton',
        saleUnit: 'tin',
        unitsPerPack: 6,
        currentStock: 18,
        lowStockThreshold: 6,
      ),
      Medicine(
        productId: 'MED-000111',
        name: 'Stayfree Secure Cottony',
        genericName: 'Sanitary Napkins',
        strength: 'Extra Large',
        form: MedicineForms.other,
        category: MedicineCategories.sanitary,
        manufacturer: 'Johnson & Johnson',
        packUnit: 'case',
        saleUnit: 'pack',
        unitsPerPack: 24,
        currentStock: 48,
        lowStockThreshold: 12,
      ),
      Medicine(
        productId: 'MED-000456',
        name: 'Crocin 500 Advance',
        genericName: 'Paracetamol',
        strength: '500mg',
        form: MedicineForms.tablet,
        category: MedicineCategories.medicine,
        manufacturer: 'GlaxoSmithKline',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 15,
        currentStock: 60,
        lowStockThreshold: 20,
        batches: [
          MedicineBatch(
            batchNumber: 'CR-2024',
            expiryDate: DateTime(now.year + 2, 8, 31),
            quantity: 60,
            supplierName: 'Balaji Drug Agencies',
            purchaseReceiptRef: 'GRN-2026-000007',
            purchaseRate: 29.50,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000112',
        name: 'Amoxil 500',
        genericName: 'Amoxicillin',
        strength: '500mg',
        form: MedicineForms.tablet,
        category: MedicineCategories.medicine,
        manufacturer: 'GSK',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 10,
        currentStock: 80,
        lowStockThreshold: 25,
        batches: [
          MedicineBatch(
            batchNumber: 'AM-01',
            expiryDate: DateTime(now.year + 2, 5, 31),
            quantity: 80,
            supplierName: 'Apollo Med Wholesale',
            purchaseReceiptRef: 'GRN-2026-000008',
            purchaseRate: 85.00,
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000113',
        name: 'Cetzine 10mg',
        genericName: 'Cetirizine',
        strength: '10mg',
        form: MedicineForms.tablet,
        category: MedicineCategories.medicine,
        manufacturer: 'Dr Reddy',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 10,
        currentStock: 100,
        lowStockThreshold: 30,
        batches: [
          MedicineBatch(
            batchNumber: 'CT-01',
            expiryDate: DateTime(now.year + 2, 10, 31),
            quantity: 100,
            supplierName: 'Sri Venkateswara Pharma',
            purchaseReceiptRef: 'GRN-2026-000009',
            purchaseRate: 42.00,
          ),
        ],
      ),
    ]);

    // 3. SEED PURCHASE ORDERS
    _purchaseOrders.addAll([
      PurchaseOrder(
        id: 'po-1',
        purchaseOrderNumber: 'PO-2026-000101',
        supplierId: 'sup-1',
        supplierName: 'Sri Venkateswara Pharma Distributors',
        createdAt: now.subtract(const Duration(days: 3)),
        status: POStatus.sent,
        sentAt: now.subtract(const Duration(days: 3)),
        items: const [
          POLineItem(
            lineId: 'line-1',
            productId: 'MED-000101',
            productName: 'Dolo 650mg',
            unitOfPurchase: 'strip',
            orderedQuantity: 200,
            expectedRate: 30.50,
            receivedQuantity: 0,
          ),
          POLineItem(
            lineId: 'line-2',
            productId: 'MED-000103',
            productName: 'Pan 40',
            unitOfPurchase: 'strip',
            orderedQuantity: 50,
            expectedRate: 62.00,
            receivedQuantity: 0,
          ),
        ],
      ),
      PurchaseOrder(
        id: 'po-2',
        purchaseOrderNumber: 'PO-2026-000102',
        supplierId: 'sup-2',
        supplierName: 'Apollo Med Wholesale Agency',
        createdAt: now.subtract(const Duration(days: 6)),
        status: POStatus.partiallyReceived,
        sentAt: now.subtract(const Duration(days: 5)),
        items: const [
          POLineItem(
            lineId: 'line-3',
            productId: 'MED-000102',
            productName: 'Augmentin 625 Duo',
            unitOfPurchase: 'strip',
            orderedQuantity: 100,
            expectedRate: 170.00,
            receivedQuantity: 60,
          ),
          POLineItem(
            lineId: 'line-4',
            productId: 'MED-000104',
            productName: 'Azee 500',
            unitOfPurchase: 'strip',
            orderedQuantity: 50,
            expectedRate: 90.00,
            receivedQuantity: 20,
          ),
        ],
      ),
      PurchaseOrder(
        id: 'po-3',
        purchaseOrderNumber: 'PO-2026-000103',
        supplierId: 'sup-3',
        supplierName: 'Balaji Drug Agencies',
        createdAt: now.subtract(const Duration(hours: 4)),
        status: POStatus.draft,
        items: const [
          POLineItem(
            lineId: 'line-5',
            productId: 'MED-000105',
            productName: 'Glycomet 500',
            unitOfPurchase: 'strip',
            orderedQuantity: 150,
            expectedRate: 26.00,
            receivedQuantity: 0,
          ),
        ],
      ),
    ]);

    // 4. SEED CUSTOMERS & UDHAAR LEDGERS
    _customers.addAll([
      Customer(
        id: 'cust-1',
        name: 'G. Satyanarayana',
        phone: '9848123456',
        address: 'Main Road, Governorpet',
        refillDueMedicine: 'Telma 40',
        refillDueDate: now.add(const Duration(days: 3)),
        prescriptionsCount: 2,
        entries: [
          UdhaarEntry(
            id: 'ent-1',
            type: UdhaarEntryType.credit,
            amountPaise: 45000, // ₹450.00
            date: now.subtract(const Duration(days: 3)),
            note: 'Antibiotic course (Augmentin & Dolo)',
            recordedBy: 'Aditya (Pharmacist)',
          ),
        ],
      ),
      Customer(
        id: 'cust-2',
        name: 'K. Lakshmi Devi',
        phone: '9440987654',
        address: 'Brodipet, Guntur',
        refillDueMedicine: 'Glycomet 500',
        refillDueDate: now.subtract(const Duration(days: 2)), // Overdue
        prescriptionsCount: 1,
        entries: [
          UdhaarEntry(
            id: 'ent-2',
            type: UdhaarEntryType.credit,
            amountPaise: 150000, // ₹1,500.00
            date: now.subtract(const Duration(days: 12)),
            note: 'Monthly BP & Diabetes medicines',
            recordedBy: 'Staff',
          ),
          UdhaarEntry(
            id: 'ent-3',
            type: UdhaarEntryType.payment,
            amountPaise: 30000, // ₹300.00 paid
            date: now.subtract(const Duration(days: 5)),
            note: 'Cash payment at counter',
            paymentMethod: 'CASH',
            recordedBy: 'Aditya (Pharmacist)',
          ),
        ],
      ),
      Customer(
        id: 'cust-3',
        name: 'P. Srinivasa Rao',
        phone: '9988776655',
        address: 'Ring Road, Vijayawada',
        prescriptionsCount: 3,
        entries: const [],
      ),
    ]);

    // 5. SEED INITIAL STOCK MOVEMENTS
    _stockMovements.addAll([
      {
        'movementId': 'SM-1001',
        'productId': 'MED-000101',
        'productName': 'Dolo 650mg',
        'batchNumber': 'DL-91',
        'type': 'GOODS_RECEIPT',
        'quantity': 120,
        'resultingBalance': 180,
        'sourceRef': 'GRN-2026-000001',
        'authorizedBy': 'Aditya (Pharmacist)',
        'timestamp': now.subtract(const Duration(days: 1)),
      },
      {
        'movementId': 'SM-1002',
        'productId': 'MED-000101',
        'productName': 'Dolo 650mg',
        'batchNumber': 'DL-91',
        'type': 'SALES_DEDUCT',
        'quantity': 5,
        'resultingBalance': 175,
        'sourceRef': 'REPORT-2026-10-12',
        'authorizedBy': 'Staff',
        'timestamp': now.subtract(const Duration(hours: 18)),
      },
    ]);
  }

  // --- SUPPLIER OPERATIONS ---
  void addSupplier(Supplier supplier) {
    _suppliers.insert(0, supplier);
    notifyListeners();
  }

  void updateSupplier(Supplier updated) {
    final index = _suppliers.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _suppliers[index] = updated;
      notifyListeners();
    }
  }

  // --- MEDICINE OPERATIONS ---
  void addMedicine(Medicine medicine) {
    _medicines.insert(0, medicine);
    notifyListeners();
  }

  void updateMedicine(Medicine updated) {
    final index = _medicines.indexWhere(
      (m) => m.productId == updated.productId,
    );
    if (index != -1) {
      _medicines[index] = updated;
      notifyListeners();
    }
  }

  void toggleMedicineActive(String productId, bool isActive) {
    final index = _medicines.indexWhere((m) => m.productId == productId);
    if (index != -1) {
      _medicines[index] = _medicines[index].copyWith(isActive: isActive);
      notifyListeners();
    }
  }

  // --- STOCK RECONCILIATION & ADJUSTMENT (Rule 6: Append-only ledger) ---
  void recordStockAdjustment({
    required String productId,
    required String batchNumber,
    required int countedQuantity,
    required int difference,
    required String reason,
    required String authorizedBy,
  }) {
    final medIndex = _medicines.indexWhere((m) => m.productId == productId);
    if (medIndex == -1) return;

    final med = _medicines[medIndex];
    final updatedBatches = med.batches.map((b) {
      if (b.batchNumber == batchNumber) {
        return b.copyWith(quantity: countedQuantity);
      }
      return b;
    }).toList();

    final newTotalStock = updatedBatches.fold(0, (sum, b) => sum + b.quantity);

    _medicines[medIndex] = med.copyWith(
      batches: updatedBatches,
      currentStock: newTotalStock,
    );

    // Append to stock movements ledger
    _stockMovements.insert(0, {
      'movementId': 'SM-${DateTime.now().millisecondsSinceEpoch}',
      'productId': productId,
      'productName': med.name,
      'batchNumber': batchNumber,
      'type': difference > 0 ? 'ADJUST_IN' : 'ADJUST_OUT',
      'quantity': difference.abs(),
      'resultingBalance': newTotalStock,
      'reason': reason,
      'authorizedBy': authorizedBy,
      'timestamp': DateTime.now(),
    });

    notifyListeners();
  }

  // --- CUSTOMER & UDHAAR OPERATIONS (Rule G7) ---
  void recordCustomerPayment({
    required String customerId,
    required int amountPaise,
    required String paymentMethod,
    String? note,
    String authorizedBy = 'Aditya (Pharmacist)',
  }) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index == -1) return;

    final cust = _customers[index];
    if (amountPaise <= 0 || amountPaise > cust.balancePaise) {
      throw Exception(
        'Payment amount must be greater than zero and cannot exceed outstanding balance.',
      );
    }

    final newEntry = UdhaarEntry(
      id: 'ent-${DateTime.now().millisecondsSinceEpoch}',
      type: UdhaarEntryType.payment,
      amountPaise: amountPaise,
      date: DateTime.now(),
      note: note ?? 'Counter Payment',
      paymentMethod: paymentMethod,
      recordedBy: authorizedBy,
    );

    final updatedEntries = List<UdhaarEntry>.from(cust.entries)..add(newEntry);
    _customers[index] = cust.copyWith(entries: updatedEntries);
    notifyListeners();
  }

  void recordCustomerCredit({
    required String customerId,
    required int amountPaise,
    required String note,
    String? invoiceRef,
    String authorizedBy = 'Staff',
  }) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index == -1) return;

    final cust = _customers[index];
    final newEntry = UdhaarEntry(
      id: 'ent-${DateTime.now().millisecondsSinceEpoch}',
      type: UdhaarEntryType.credit,
      amountPaise: amountPaise,
      date: DateTime.now(),
      note: note,
      invoiceRef: invoiceRef,
      recordedBy: authorizedBy,
    );

    final updatedEntries = List<UdhaarEntry>.from(cust.entries)..add(newEntry);
    _customers[index] = cust.copyWith(entries: updatedEntries);
    notifyListeners();
  }

  // --- PURCHASE ORDER OPERATIONS ---
  void addPurchaseOrder(PurchaseOrder po) {
    _purchaseOrders.insert(0, po);
    notifyListeners();
  }

  void sendOrder(String poId) {
    final index = _purchaseOrders.indexWhere((p) => p.id == poId);
    if (index != -1) {
      final po = _purchaseOrders[index];
      if (po.status == POStatus.draft) {
        _purchaseOrders[index] = po.copyWith(
          status: POStatus.sent,
          sentAt: DateTime.now(),
        );
        notifyListeners();
      }
    }
  }

  void cancelOrder(String poId, String reason) {
    final index = _purchaseOrders.indexWhere((p) => p.id == poId);
    if (index != -1) {
      final po = _purchaseOrders[index];
      _purchaseOrders[index] = po.copyWith(
        status: POStatus.cancelled,
        cancelledAt: DateTime.now(),
        cancelReason: reason,
      );
      notifyListeners();
    }
  }

  // --- GOODS RECEIPT OPERATION (Atomic transition) ---
  GoodsReceipt recordGoodsReceipt({
    required String poId,
    required List<GRNLineItem> receivedItems,
    String? notes,
  }) {
    final poIndex = _purchaseOrders.indexWhere((p) => p.id == poId);
    if (poIndex == -1) {
      throw Exception('Purchase order not found');
    }

    final po = _purchaseOrders[poIndex];
    final grnNumber = 'GRN-2026-${(po.receipts.length + 100001)}';

    final grn = GoodsReceipt(
      id: 'grn-${DateTime.now().millisecondsSinceEpoch}',
      receiptNumber: grnNumber,
      purchaseOrderId: po.id,
      purchaseOrderNumber: po.purchaseOrderNumber,
      supplierId: po.supplierId,
      receivedAt: DateTime.now(),
      items: receivedItems,
      notes: notes,
      inventoryPostingStatus: InventoryPostingStatus.posted,
    );

    // Update PO line items atomically
    final updatedLines = po.items.map((line) {
      final match = receivedItems.firstWhere(
        (ri) => ri.lineId == line.lineId,
        orElse: () => GRNLineItem(
          lineId: line.lineId,
          productId: line.productId,
          productName: line.productName,
          unitOfPurchase: line.unitOfPurchase,
          quantityReceived: 0,
          quantityAccepted: 0,
        ),
      );

      final newReceived = line.receivedQuantity + match.quantityAccepted;
      final newDamaged = line.damagedQuantity + match.quantityDamaged;

      return line.copyWith(
        receivedQuantity: newReceived,
        damagedQuantity: newDamaged,
      );
    }).toList();

    // Check if fully received
    final allComplete = updatedLines.every(
      (l) => l.receivedQuantity >= l.orderedQuantity,
    );
    final newStatus = allComplete
        ? POStatus.received
        : POStatus.partiallyReceived;

    final updatedReceipts = List<GoodsReceipt>.from(po.receipts)..add(grn);

    _purchaseOrders[poIndex] = po.copyWith(
      status: newStatus,
      items: updatedLines,
      receipts: updatedReceipts,
    );

    // Update batch stock in medicine catalogue with normalized base units
    for (final item in receivedItems) {
      if (item.quantityAccepted > 0) {
        final medIdx = _medicines.indexWhere(
          (m) => m.productId == item.productId,
        );
        if (medIdx != -1) {
          final med = _medicines[medIdx];
          final factor = med.unitsPerPack > 0 ? med.unitsPerPack : 1;
          final baseUnits = item.quantityAccepted * factor;
          final batchNum =
              (item.batchNumber != null && item.batchNumber!.trim().isNotEmpty)
              ? item.batchNumber!.trim()
              : 'BAT-2026';

          DateTime parsedExp;
          try {
            parsedExp = DateTime.parse(item.expiryDate ?? '');
          } catch (_) {
            parsedExp = DateTime.now().add(const Duration(days: 730));
          }

          final existingBatchIdx = med.batches.indexWhere(
            (b) => b.batchNumber == batchNum,
          );

          List<MedicineBatch> newBatches;
          if (existingBatchIdx != -1) {
            final oldBatch = med.batches[existingBatchIdx];
            newBatches = List<MedicineBatch>.from(med.batches);
            newBatches[existingBatchIdx] = oldBatch.copyWith(
              quantity: oldBatch.quantity + baseUnits,
            );
          } else {
            newBatches = List<MedicineBatch>.from(med.batches)
              ..add(
                MedicineBatch(
                  batchNumber: batchNum,
                  expiryDate: parsedExp,
                  quantity: baseUnits,
                  supplierName: po.supplierName,
                  purchaseReceiptRef: grnNumber,
                ),
              );
          }

          final newStock = med.currentStock + baseUnits;
          _medicines[medIdx] = med.copyWith(
            currentStock: newStock,
            batches: newBatches,
          );

          // Append to stock movements ledger
          _stockMovements.insert(0, {
            'movementId': 'SM-${DateTime.now().millisecondsSinceEpoch}',
            'productId': med.productId,
            'productName': med.name,
            'batchNumber': batchNum,
            'type': 'GOODS_RECEIPT',
            'quantity': baseUnits,
            'resultingBalance': newStock,
            'sourceRef': grnNumber,
            'authorizedBy': 'Aditya (Pharmacist)',
            'timestamp': DateTime.now(),
          });
        }
      }
    }

    notifyListeners();
    return grn;
  }

  /// Returns the combined available stock across all products sharing the generic medicine name.
  int getCombinedStockForGeneric(String genericName, {String fallbackProductId = ''}) {
    final clean = genericName.trim().toLowerCase();
    final matching = _medicines.where((m) {
      final mGen = m.genericName.trim().toLowerCase();
      if (clean.isNotEmpty && (mGen == clean || mGen.contains(clean) || clean.contains(mGen))) {
        return true;
      }
      return fallbackProductId.isNotEmpty && m.productId == fallbackProductId;
    }).toList();
    return matching.fold<int>(0, (sum, m) => sum + m.currentStock);
  }

  /// Returns all medicines belonging to a generic medicine group.
  List<Medicine> getMedicinesForGeneric(String genericName, {String fallbackProductId = ''}) {
    final clean = genericName.trim().toLowerCase();
    return _medicines.where((m) {
      final mGen = m.genericName.trim().toLowerCase();
      if (clean.isNotEmpty && (mGen == clean || mGen.contains(clean) || clean.contains(mGen))) {
        return true;
      }
      return fallbackProductId.isNotEmpty && m.productId == fallbackProductId;
    }).toList();
  }

  // --- OUTWARD SALES DEDUCTIONS (Generic-first FEFO batch deduction upon confirmed post) ---
  bool recordSalesDeductions(SalesReport report) {
    // 1. Upfront stock validation across all lines - all or nothing!
    for (final line in report.lines) {
      final looseUnits = line.calculatedLooseUnits;
      if (looseUnits <= 0) continue;

      final matching = getMedicinesForGeneric(
        line.genericName,
        fallbackProductId: line.matchedProductId,
      );
      if (matching.isEmpty) {
        return false; // Medicine not found in catalogue
      }
      final totalAvail = matching.fold<int>(0, (sum, m) => sum + m.currentStock);
      if (totalAvail < looseUnits) {
        // Insufficient combined stock - Reject immediately without modifying any batch or ledger!
        return false;
      }
    }

    // 2. Perform FEFO deductions from the pooled batches of each generic medicine group
    for (final line in report.lines) {
      final looseUnits = line.calculatedLooseUnits;
      if (looseUnits <= 0) continue;

      final matching = getMedicinesForGeneric(
        line.genericName,
        fallbackProductId: line.matchedProductId,
      );
      if (matching.isEmpty) continue;

      int remainingToDeduct = looseUnits;

      // Pool batches across all matching brand products, sorted by expiry date (FEFO)
      // Map batch -> parent medicine ID
      for (final med in matching) {
        if (remainingToDeduct <= 0) break;
        final medIdx = _medicines.indexWhere((m) => m.productId == med.productId);
        if (medIdx == -1) continue;

        final currentMed = _medicines[medIdx];
        final sortedBatches = List<MedicineBatch>.from(currentMed.batches)
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

        final updatedBatches = <MedicineBatch>[];
        int medDeducted = 0;

        for (final b in sortedBatches) {
          if (remainingToDeduct > 0 && b.quantity > 0) {
            final deductFromThis = remainingToDeduct > b.quantity
                ? b.quantity
                : remainingToDeduct;
            remainingToDeduct -= deductFromThis;
            medDeducted += deductFromThis;
            updatedBatches.add(
              b.copyWith(quantity: b.quantity - deductFromThis),
            );

            _stockMovements.insert(0, {
              'movementId':
                  'SM-${DateTime.now().millisecondsSinceEpoch}-${b.batchNumber}',
              'productId': currentMed.productId,
              'productName': currentMed.name,
              'genericName': currentMed.genericName,
              'batchNumber': b.batchNumber,
              'type': 'SALE_OUT',
              'quantity': -deductFromThis,
              'unit': currentMed.saleUnit,
              'sourceRef': report.reportReference,
              'authorizedBy': report.authorizer,
              'reason':
                  'Outward sales report confirmed (${currentMed.genericName} FEFO generic group)',
              'timestamp': DateTime.now(),
            });
          } else {
            updatedBatches.add(b);
          }
        }

        final newStock = currentMed.currentStock - medDeducted;
        _medicines[medIdx] = currentMed.copyWith(
          currentStock: newStock,
          batches: updatedBatches,
        );
      }
    }
    notifyListeners();
    return true;
  }

  /// Applies a confirmed manual stock-out to the local catalogue mirror.
  /// The backend remains authoritative; this keeps the existing catalogue UI
  /// current after a successful API response and preserves all-or-nothing
  /// validation for offline/widget-test data.
  bool recordManualStockOut({
    required Map<String, int> quantitiesByProductId,
    required String sourceReference,
  }) {
    if (quantitiesByProductId.isEmpty) return false;
    for (final entry in quantitiesByProductId.entries) {
      final index = _medicines.indexWhere((m) => m.productId == entry.key);
      if (index == -1 ||
          entry.value < 1 ||
          _medicines[index].currentStock < entry.value) {
        return false;
      }
    }
    for (final entry in quantitiesByProductId.entries) {
      final index = _medicines.indexWhere((m) => m.productId == entry.key);
      final med = _medicines[index];
      var remaining = entry.value;
      final batches = List<MedicineBatch>.from(med.batches)
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      for (var i = 0; i < batches.length && remaining > 0; i++) {
        final take = remaining > batches[i].quantity
            ? batches[i].quantity
            : remaining;
        remaining -= take;
        batches[i] = batches[i].copyWith(quantity: batches[i].quantity - take);
        if (take > 0) {
          _stockMovements.insert(0, {
            'movementId':
                'SM-${DateTime.now().microsecondsSinceEpoch}-${batches[i].batchNumber}',
            'productId': med.productId,
            'productName': med.name,
            'batchNumber': batches[i].batchNumber,
            'type': 'MANUAL_TRANSACTION_OUT',
            'quantity': -take,
            'unit': med.saleUnit,
            'sourceRef': sourceReference,
            'authorizedBy': 'pharmacist_operator',
            'timestamp': DateTime.now(),
          });
        }
      }
      _medicines[index] = med.copyWith(
        currentStock: med.currentStock - entry.value,
        batches: batches,
      );
    }
    notifyListeners();
    return true;
  }

  // Set of already posted invoice numbers to prevent duplicate inward stock
  final Set<String> _postedInvoices = {};

  // --- INWARD INVOICE STOCK RECORDING ---
  bool recordPurchaseInvoiceInward({
    required String invoiceNumber,
    required String supplierName,
    required List<Map<String, dynamic>> items,
    String authorizer = 'Aditya (Pharmacist)',
  }) {
    // Duplicate submission protection
    if (_postedInvoices.contains(invoiceNumber)) {
      return false; // Already posted, skip double insertion
    }
    _postedInvoices.add(invoiceNumber);

    for (final item in items) {
      final productId = item['productId'] as String? ?? '';
      final packQty = (item['quantity'] as num?)?.toInt() ?? 0;
      final batchNum = (item['batchNumber'] as String? ?? 'BAT-2026').trim();
      final exp = item['expiryDate'] as String? ?? '2028-12-31';

      if (packQty <= 0 || productId.isEmpty) continue;

      final medIdx = _medicines.indexWhere((m) => m.productId == productId);
      if (medIdx != -1) {
        final med = _medicines[medIdx];
        final factor = med.unitsPerPack > 0 ? med.unitsPerPack : 1;
        final baseUnits = packQty * factor;
        final existingBatchIdx = med.batches.indexWhere(
          (b) => b.batchNumber == batchNum,
        );
        List<MedicineBatch> newBatches;

        if (existingBatchIdx != -1) {
          final oldBatch = med.batches[existingBatchIdx];
          newBatches = List<MedicineBatch>.from(med.batches);
          newBatches[existingBatchIdx] = oldBatch.copyWith(
            quantity: oldBatch.quantity + baseUnits,
          );
        } else {
          DateTime parsedExp;
          try {
            parsedExp = DateTime.parse(exp);
          } catch (_) {
            parsedExp = DateTime.now().add(const Duration(days: 730));
          }
          newBatches = List<MedicineBatch>.from(med.batches)
            ..add(
              MedicineBatch(
                batchNumber: batchNum,
                expiryDate: parsedExp,
                quantity: baseUnits,
                supplierName: supplierName,
                purchaseReceiptRef: 'INV-$invoiceNumber',
              ),
            );
        }

        final newStock = med.currentStock + baseUnits;
        _medicines[medIdx] = med.copyWith(
          currentStock: newStock,
          batches: newBatches,
        );

        _stockMovements.insert(0, {
          'movementId': 'SM-${DateTime.now().millisecondsSinceEpoch}',
          'productId': med.productId,
          'productName': med.name,
          'batchNumber': batchNum,
          'type': 'INVOICE_IN',
          'quantity': baseUnits,
          'resultingBalance': newStock,
          'sourceRef': 'INV-$invoiceNumber',
          'authorizer': authorizer,
          'timestamp': DateTime.now(),
        });
      }
    }

    notifyListeners();
    return true;
  }

  // --- SUPPLIER MUTATIONS ---
  void toggleSupplierStatus(String supplierId) {
    final idx = _suppliers.indexWhere((s) => s.id == supplierId);
    if (idx != -1) {
      final s = _suppliers[idx];
      _suppliers[idx] = s.copyWith(isActive: !s.isActive);
      notifyListeners();
    }
  }

  // --- PURCHASE ORDER CREATION & ACTIONS ---
  void createPurchaseOrder(PurchaseOrder po) => addPurchaseOrder(po);

  void markOrderAsSent(String poId) => sendOrder(poId);
}
