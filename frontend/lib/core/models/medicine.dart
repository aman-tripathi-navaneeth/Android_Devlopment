import 'batch.dart';

/// Medicine data model matching PART 10.3 and PART 8.2 catalogue contract.
class Medicine {
  final String productId; // e.g. "MED-000101"
  final String name;
  final String genericName;
  final String strength;
  final String form; // e.g. "Tablet", "Capsule", "Syrup"
  final String category;
  final String manufacturer;
  final String packUnit; // e.g. "strip", "bottle"
  final String saleUnit; // e.g. "tablet", "ml"
  final int unitsPerPack; // integer >= 1
  final int currentStock; // in smallest sale units
  final int lowStockThreshold;
  final bool isActive;
  final List<MedicineBatch> batches;

  const Medicine({
    required this.productId,
    required this.name,
    required this.genericName,
    required this.strength,
    required this.form,
    required this.category,
    required this.manufacturer,
    required this.packUnit,
    required this.saleUnit,
    this.unitsPerPack = 10,
    this.currentStock = 0,
    this.lowStockThreshold = 20,
    this.isActive = true,
    this.batches = const [],
  });

  bool get isLowStock => currentStock <= lowStockThreshold;

  int get totalBatches => batches.length;

  bool get hasExpiringBatches => batches.any((b) => b.isNearExpiry);

  bool get hasExpiredBatches => batches.any((b) => b.isExpired);

  MedicineBatch? get earliestExpiringBatch {
    if (batches.isEmpty) return null;
    final sorted = List<MedicineBatch>.from(batches)
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return sorted.first;
  }

  String get id => productId;
  String get genericComposition => genericName;
  String get conversionSummary =>
      '1 $packUnit = $unitsPerPack $saleUnit${unitsPerPack > 1 ? 's' : ''}';

  Medicine copyWith({
    String? productId,
    String? name,
    String? genericName,
    String? strength,
    String? form,
    String? category,
    String? manufacturer,
    String? packUnit,
    String? saleUnit,
    int? unitsPerPack,
    int? currentStock,
    int? lowStockThreshold,
    bool? isActive,
    List<MedicineBatch>? batches,
  }) {
    return Medicine(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      packUnit: packUnit ?? this.packUnit,
      saleUnit: saleUnit ?? this.saleUnit,
      unitsPerPack: unitsPerPack ?? this.unitsPerPack,
      currentStock: currentStock ?? this.currentStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
      batches: batches ?? this.batches,
    );
  }
}

/// Official Categories matching MongoDB products collection validator enum
abstract class MedicineCategories {
  static const String medicine = 'Medicine';
  static const String derma = 'Derma and skin care';
  static const String clinic = 'Clinic item';
  static const String personalCare = 'Personal care';
  static const String sanitary = 'Sanitary';
  static const String food = 'Food';

  static const List<String> all = [
    medicine,
    derma,
    clinic,
    personalCare,
    sanitary,
    food,
  ];
}

/// Official Forms matching MongoDB products collection validator enum
abstract class MedicineForms {
  static const String tablet = 'Tablet';
  static const String strip = 'Strip';
  static const String bottle = 'Bottle';
  static const String injection = 'Injection';
  static const String tube = 'Tube';
  static const String other = 'Other';

  static const List<String> all = [
    tablet,
    strip,
    bottle,
    injection,
    tube,
    other,
  ];
}
