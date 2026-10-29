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

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id']?.toString() ?? '',
      supplierCode: json['supplier_code']?.toString() ??
          json['code']?.toString() ??
          'SUP-000000',
      name: json['name']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString() ??
          json['contactPerson']?.toString(),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      notes: json['notes']?.toString(),
      gstNumber: json['gst_number']?.toString() ??
          json['gstNumber']?.toString(),
      paymentTerms: json['payment_terms']?.toString() ??
          json['paymentTerms']?.toString() ??
          'Net 30',
      isActive: json['is_active'] is bool
          ? json['is_active'] as bool
          : (json['active'] is bool
              ? json['active'] as bool
              : (json['isActive'] as bool? ?? true)),
      openPurchaseOrderCount: json['open_purchase_order_count'] is num
          ? (json['open_purchase_order_count'] as num).toInt()
          : (json['openPurchaseOrderCount'] is num
              ? (json['openPurchaseOrderCount'] as num).toInt()
              : 0),
      totalOrderValue: json['total_order_value'] is num
          ? (json['total_order_value'] as num).toDouble()
          : (json['totalOrderValue'] is num
              ? (json['totalOrderValue'] as num).toDouble()
              : 0.0),
      outstandingUnits: json['outstanding_units'] is num
          ? (json['outstanding_units'] as num).toInt()
          : (json['outstandingUnits'] is num
              ? (json['outstandingUnits'] as num).toInt()
              : 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier_code': supplierCode,
      'name': name,
      if (contactPerson != null) 'contact_person': contactPerson,
      'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (notes != null) 'notes': notes,
      if (gstNumber != null) 'gst_number': gstNumber,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      'is_active': isActive,
    };
  }
}
