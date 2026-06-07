import 'dart:convert';

/// Represents a payment entry for a salesman/company.
class SalesmanPayment {
  final String id;
  final String company;
  final double amountGiven; // Money Given
  final double balanceOwed; // Money Needed to be Given
  final String createdAt; // Date and time when the record was created
  final String addedBy; // Operator name who added this entry
  final bool isDeleted; // Soft delete flag
  final String? deletedAt; // Timestamp when soft-deleted
  final String? notes;

  const SalesmanPayment({
    required this.id,
    required this.company,
    required this.amountGiven,
    required this.balanceOwed,
    required this.createdAt,
    required this.addedBy,
    this.isDeleted = false,
    this.deletedAt,
    this.notes,
  });

  SalesmanPayment copyWith({
    String? id,
    String? company,
    double? amountGiven,
    double? balanceOwed,
    String? createdAt,
    String? addedBy,
    bool? isDeleted,
    String? deletedAt,
    String? notes,
  }) {
    return SalesmanPayment(
      id: id ?? this.id,
      company: company ?? this.company,
      amountGiven: amountGiven ?? this.amountGiven,
      balanceOwed: balanceOwed ?? this.balanceOwed,
      createdAt: createdAt ?? this.createdAt,
      addedBy: addedBy ?? this.addedBy,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'company': company,
    'amountGiven': amountGiven,
    'balanceOwed': balanceOwed,
    'createdAt': createdAt,
    'addedBy': addedBy,
    'isDeleted': isDeleted,
    if (deletedAt != null) 'deletedAt': deletedAt,
    if (notes != null) 'notes': notes,
  };

  factory SalesmanPayment.fromJson(Map<String, dynamic> json) {
    return SalesmanPayment(
      id: json['id'] as String,
      company: json['company'] as String,
      amountGiven: (json['amountGiven'] as num).toDouble(),
      balanceOwed: (json['balanceOwed'] as num).toDouble(),
      createdAt: json['createdAt'] as String,
      addedBy: json['addedBy'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] as String?,
      notes: json['notes'] as String?,
    );
  }

  static String encodeList(List<SalesmanPayment> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<SalesmanPayment> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => SalesmanPayment.fromJson(e as Map<String, dynamic>)).toList();
  }
}
