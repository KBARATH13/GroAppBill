import 'dart:convert';

/// Represents a single saved bill record for history.
class BillingHistoryRecord {
  final String billNumber;
  final String date; // 'yyyy-MM-dd' format for grouping
  final String time;
  final String operatorName;
  final String customerType;
  final String? apartmentName;
  final String? blockAndDoor;
  final String paymentMode;
  final double cashAmount;
  final double upiAmount;
  final double grandTotal;
  final List<Map<String, dynamic>> itemsJson;
  final String? firestoreId;

  BillingHistoryRecord({
    required this.billNumber,
    required this.date,
    required this.time,
    required this.operatorName,
    required this.customerType,
    required this.paymentMode,
    required this.grandTotal,
    required this.itemsJson,
    this.apartmentName,
    this.blockAndDoor,
    this.cashAmount = 0,
    this.upiAmount = 0,
    this.firestoreId,
  });

  Map<String, dynamic> toJson() => {
    'billNumber': billNumber,
    'date': date,
    'time': time,
    'operatorName': operatorName,
    'customerType': customerType,
    'paymentMode': paymentMode,
    'grandTotal': grandTotal,
    'cashAmount': cashAmount,
    'upiAmount': upiAmount,
    'items': itemsJson,
    if (apartmentName != null) 'apartmentName': apartmentName,
    if (blockAndDoor != null) 'blockAndDoor': blockAndDoor,
    if (firestoreId != null) 'firestoreId': firestoreId,
  };

  BillingHistoryRecord copyWith({
    String? billNumber,
    String? date,
    String? time,
    String? operatorName,
    String? customerType,
    String? apartmentName,
    String? blockAndDoor,
    String? paymentMode,
    double? cashAmount,
    double? upiAmount,
    double? grandTotal,
    List<Map<String, dynamic>>? itemsJson,
    String? firestoreId,
  }) {
    return BillingHistoryRecord(
      billNumber: billNumber ?? this.billNumber,
      date: date ?? this.date,
      time: time ?? this.time,
      operatorName: operatorName ?? this.operatorName,
      customerType: customerType ?? this.customerType,
      apartmentName: apartmentName ?? this.apartmentName,
      blockAndDoor: blockAndDoor ?? this.blockAndDoor,
      paymentMode: paymentMode ?? this.paymentMode,
      cashAmount: cashAmount ?? this.cashAmount,
      upiAmount: upiAmount ?? this.upiAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      itemsJson: itemsJson ?? this.itemsJson,
      firestoreId: firestoreId ?? this.firestoreId,
    );
  }

  factory BillingHistoryRecord.fromJson(Map<String, dynamic> json, [String? docId]) {
    return BillingHistoryRecord(
      billNumber: json['billNumber'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      operatorName: json['operatorName'] as String,
      customerType: json['customerType'] as String,
      paymentMode: json['paymentMode'] as String? ?? 'Cash',
      grandTotal: (json['grandTotal'] as num).toDouble(),
      cashAmount: (json['cashAmount'] as num?)?.toDouble() ?? 0,
      upiAmount: (json['upiAmount'] as num?)?.toDouble() ?? 0,
      itemsJson: List<Map<String, dynamic>>.from(json['items'] as List),
      apartmentName: json['apartmentName'] as String?,
      blockAndDoor: json['blockAndDoor'] as String?,
      firestoreId: docId ?? json['firestoreId'] as String?,
    );
  }

  static String encodeList(List<BillingHistoryRecord> records) {
    return jsonEncode(records.map((r) => r.toJson()).toList());
  }

  static List<BillingHistoryRecord> decodeList(String json) {
    final decoded = jsonDecode(json) as List;
    return decoded
        .map((e) => BillingHistoryRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
