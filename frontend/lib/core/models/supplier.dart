/// Supplier data model strictly matching PART 10.4.4 schema.
class Supplier {
  final String id;
  final String supplierCode; // e.g. "SUP-000001"
  final String name;
  final String? contactPerson;
  final String phone;
  final String? email;
  final String? address;
  final String? gstNumber;
  final String? paymentTerms;
  final bool isActive;
  final int openPurchaseOrderCount;
  final double totalOrderValue;
  final int outstandingUnits;

  final String? city;
  final String? notes;

  const Supplier({
    required this.id,
    required this.supplierCode,
    required this.name,
    this.contactPerson,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.notes,
    this.gstNumber,
    this.paymentTerms,
    this.isActive = true,
    this.openPurchaseOrderCount = 0,
    this.totalOrderValue = 0.0,
    this.outstandingUnits = 0,
  });

  Supplier copyWith({
    String? id,
    String? supplierCode,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? notes,
    String? gstNumber,
    String? paymentTerms,
    bool? isActive,
    int? openPurchaseOrderCount,
    double? totalOrderValue,
    int? outstandingUnits,
  }) {
    return Supplier(
      id: id ?? this.id,
      supplierCode: supplierCode ?? this.supplierCode,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      notes: notes ?? this.notes,
      gstNumber: gstNumber ?? this.gstNumber,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      isActive: isActive ?? this.isActive,
      openPurchaseOrderCount:
          openPurchaseOrderCount ?? this.openPurchaseOrderCount,
      totalOrderValue: totalOrderValue ?? this.totalOrderValue,
      outstandingUnits: outstandingUnits ?? this.outstandingUnits,
    );
  }
}
