enum UdhaarEntryType { credit, payment }

class UdhaarEntry {
  final String id;
  final UdhaarEntryType type;
  final int amountPaise;
  final DateTime date;
  final String note;
  final String? paymentMethod; // "CASH", "UPI", "CARD"
  final String? invoiceRef;
  final String recordedBy;

  const UdhaarEntry({
    required this.id,
    required this.type,
    required this.amountPaise,
    required this.date,
    required this.note,
    this.paymentMethod,
    this.invoiceRef,
    this.recordedBy = 'Staff',
  });
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String? refillDueMedicine;
  final DateTime? refillDueDate;
  final int prescriptionsCount;
  final List<UdhaarEntry> entries;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.refillDueMedicine,
    this.refillDueDate,
    this.prescriptionsCount = 0,
    this.entries = const [],
  });

  /// Authoritative balance derived strictly from immutable credit and payment entries
  int get balancePaise {
    int total = 0;
    for (final e in entries) {
      if (e.type == UdhaarEntryType.credit) {
        total += e.amountPaise;
      } else if (e.type == UdhaarEntryType.payment) {
        total -= e.amountPaise;
      }
    }
    return total;
  }

  bool get hasOutstandingBalance => balancePaise > 0;

  bool get isRefillOverdue {
    if (refillDueDate == null) return false;
    return DateTime.now().isAfter(refillDueDate!);
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? refillDueMedicine,
    DateTime? refillDueDate,
    int? prescriptionsCount,
    List<UdhaarEntry>? entries,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      refillDueMedicine: refillDueMedicine ?? this.refillDueMedicine,
      refillDueDate: refillDueDate ?? this.refillDueDate,
      prescriptionsCount: prescriptionsCount ?? this.prescriptionsCount,
      entries: entries ?? this.entries,
    );
  }
}
