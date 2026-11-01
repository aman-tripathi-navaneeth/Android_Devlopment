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
    _initSeedData();
    syncFromBackend();
  }

  bool _isLoadingFromBackend = false;
  bool get isLoadingFromBackend => _isLoadingFromBackend;

  Future<void> syncFromBackend() async {
    if (_isLoadingFromBackend) return;
    _isLoadingFromBackend = true;
    try {
      await Future.wait([
        syncProductsFromBackend(),
        syncSuppliersFromBackend(),
      ]);
    } catch (_) {
    } finally {
      _isLoadingFromBackend = false;
      notifyListeners();
    }
  }

  Future<void> syncSuppliersFromBackend() async {
    try {
      final api = ApiClient();
      final list = await api.getSuppliers(storeId: 'main_store');
      if (list.isNotEmpty) {
        final List<Supplier> loaded = [];
        for (final s in list) {
          final id = s['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final code = s['code']?.toString() ?? s['supplier_code']?.toString() ?? 'SUP-000000';
          final name = s['name']?.toString() ?? '';
          final contact = s['contact_person']?.toString() ?? s['contactPerson']?.toString();
          final phone = s['phone']?.toString() ?? '';
          final email = s['email']?.toString();
          final address = s['address']?.toString();
          final city = s['city']?.toString();
          final gst = s['gst_number']?.toString() ?? s['gstNumber']?.toString();
          final paymentTerms = s['payment_terms']?.toString() ?? s['paymentTerms']?.toString() ?? 'Net 30';
          final notes = s['notes']?.toString();
          final active = s['active'] is bool ? s['active'] as bool : (s['isActive'] as bool? ?? true);
          loaded.add(
            Supplier(
              id: id,
              supplierCode: code,
              name: name,
              contactPerson: contact,
              phone: phone,
              email: email,
              address: address,
              city: city,
              gstNumber: gst,
              paymentTerms: paymentTerms,
              notes: notes,
              isActive: active,
            ),
          );
        }
        if (loaded.isNotEmpty) {
          _suppliers.clear();
          _suppliers.addAll(loaded);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> syncProductsFromBackend() async {
    try {
      final api = ApiClient();
      final products = await api.getProducts(limit: 200);
      if (products.isNotEmpty) {
        final loaded = await Future.wait(products.map((p) async {
          final id = p['id']?.toString() ?? '';
          if (id.isEmpty) return null;
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

          return Medicine(
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
          );
        }));

        final validMeds = loaded.whereType<Medicine>().toList();
        if (validMeds.isNotEmpty) {
          _medicines.clear();
          _medicines.addAll(validMeds);
          notifyListeners();
        }
      }
    } catch (_) {}
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
    _suppliers.addAll([
      const Supplier(
        id: 'sup-1',
        supplierCode: 'SUP-000001',
        name: 'Sri Venkateswara Pharma Distributors',
        contactPerson: 'K. Ramesh',
        phone: '9848012345',
        email: 'ramesh@venkateswarapharma.in',
        address: 'Shop 14, Main Road, Governorpet',
        city: 'Vijayawada',
        gstNumber: '37AABCS1429B1Z2',
        paymentTerms: 'Net 30',
        isActive: true,
      ),
      const Supplier(
        id: 'sup-2',
        supplierCode: 'SUP-000002',
        name: 'Apollo Health Logistics',
        contactPerson: 'S. Priya',
        phone: '9876543210',
        email: 'supply@apollohealth.com',
        address: 'Plot 45, Industrial Area',
        city: 'Hyderabad',
        gstNumber: '36AAACA1234A1Z5',
        paymentTerms: 'Net 15',
        isActive: true,
      ),
      const Supplier(
        id: 'sup-3',
        supplierCode: 'SUP-000003',
        name: 'MedPlus Supply Hub',
        contactPerson: 'V. Naidu',
        phone: '9123456780',
        email: 'orders@medplus.co.in',
        address: 'Block B, Logistics Park',
        city: 'Visakhapatnam',
        gstNumber: '37AABCM5678C1Z8',
        paymentTerms: 'Net 30',
        isActive: true,
      ),
    ]);

    _medicines.addAll([
      Medicine(
        productId: 'MED-000101',
        name: 'Dolo 650',
        genericName: 'Paracetamol',
        strength: '650mg',
        form: 'tablet',
        category: 'medicine',
        manufacturer: 'Micro Labs',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 15,
        currentStock: 200,
        lowStockThreshold: 30,
        isActive: true,
        batches: [
          MedicineBatch(
            batchNumber: 'BAT-MAIN-01',
            expiryDate: DateTime.now().add(const Duration(days: 700)),
            quantity: 200,
            supplierName: 'Sri Venkateswara Pharma Distributors',
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000102',
        name: 'Dolo 500',
        genericName: 'Paracetamol',
        strength: '500mg',
        form: 'tablet',
        category: 'medicine',
        manufacturer: 'Micro Labs',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 15,
        currentStock: 150,
        lowStockThreshold: 20,
        isActive: true,
        batches: [
          MedicineBatch(
            batchNumber: 'BAT-MAIN-02',
            expiryDate: DateTime.now().add(const Duration(days: 600)),
            quantity: 150,
            supplierName: 'Sri Venkateswara Pharma Distributors',
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000103',
        name: 'Pan 40',
        genericName: 'Pantoprazole',
        strength: '40mg',
        form: 'tablet',
        category: 'medicine',
        manufacturer: 'Alkem',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 10,
        currentStock: 200,
        lowStockThreshold: 25,
        isActive: true,
        batches: [
          MedicineBatch(
            batchNumber: 'BAT-MAIN-03',
            expiryDate: DateTime.now().add(const Duration(days: 650)),
            quantity: 200,
            supplierName: 'Apollo Health Logistics',
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000104',
        name: 'Cotton roll',
        genericName: 'Absorbent Cotton',
        strength: '500g',
        form: 'other',
        category: 'clinic',
        manufacturer: 'Sample Surgicals',
        packUnit: 'pack',
        saleUnit: 'piece',
        unitsPerPack: 1,
        currentStock: 200,
        lowStockThreshold: 15,
        isActive: true,
        batches: [
          MedicineBatch(
            batchNumber: 'BAT-CR-01',
            expiryDate: DateTime.now().add(const Duration(days: 800)),
            quantity: 200,
            supplierName: 'MedPlus Supply Hub',
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000105',
        name: 'Azithral 500',
        genericName: 'Azithromycin',
        strength: '500mg',
        form: 'tablet',
        category: 'medicine',
        manufacturer: 'Alembic',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 5,
        currentStock: 200,
        lowStockThreshold: 20,
        isActive: true,
        batches: [
          MedicineBatch(
            batchNumber: 'BAT-AZ-01',
            expiryDate: DateTime.now().add(const Duration(days: 550)),
            quantity: 200,
            supplierName: 'Sri Venkateswara Pharma Distributors',
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000123',
        name: 'Augmentin 625 Duo',
        genericName: 'Amoxicillin + Clavulanic Acid',
        strength: '625mg',
        form: 'tablet',
        category: 'medicine',
        manufacturer: 'GSK',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 10,
        currentStock: 200,
        lowStockThreshold: 20,
        isActive: true,
        batches: [
          MedicineBatch(
            batchNumber: 'BAT-AG-84',
            expiryDate: DateTime.now().add(const Duration(days: 720)),
            quantity: 200,
            supplierName: 'Apollo Health Logistics',
          ),
        ],
      ),
      Medicine(
        productId: 'MED-000456',
        name: 'Crocin 500 Advance',
        genericName: 'Paracetamol',
        strength: '500mg',
        form: 'tablet',
        category: 'medicine',
        manufacturer: 'GSK',
        packUnit: 'strip',
        saleUnit: 'tablet',
        unitsPerPack: 15,
        currentStock: 200,
        lowStockThreshold: 25,
        isActive: true,
        batches: [
          MedicineBatch(
            batchNumber: 'BAT-CR-2024',
            expiryDate: DateTime.now().add(const Duration(days: 750)),
            quantity: 200,
            supplierName: 'MedPlus Supply Hub',
          ),
        ],
      ),
    ]);
  }

  // --- SUPPLIER OPERATIONS ---
  void addSupplier(Supplier supplier) {
    final index = _suppliers.indexWhere((s) => s.id == supplier.id || s.supplierCode == supplier.supplierCode);
    if (index != -1) {
      _suppliers[index] = supplier;
    } else {
      _suppliers.insert(0, supplier);
    }
    notifyListeners();
  }

  void updateSupplier(Supplier updated) {
    final index = _suppliers.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _suppliers[index] = updated;
    } else {
      _suppliers.insert(0, updated);
    }
    notifyListeners();
  }

  // --- MEDICINE OPERATIONS ---
  void addMedicine(Medicine medicine) {
    final index = _medicines.indexWhere((m) => m.productId == medicine.productId);
    if (index != -1) {
      _medicines[index] = medicine;
    } else {
      _medicines.insert(0, medicine);
    }
    notifyListeners();
  }

  void updateMedicine(Medicine updated) {
    final index = _medicines.indexWhere(
      (m) => m.productId == updated.productId,
    );
    if (index != -1) {
      _medicines[index] = updated;
    } else {
      _medicines.insert(0, updated);
    }
    notifyListeners();
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
