enum BottleType {
  normal,
  bisleri,
}

extension BottleTypeLabel on BottleType {
  String get label {
    switch (this) {
      case BottleType.bisleri:
        return 'Bisleri 20L Can';
      case BottleType.normal:
        return 'Normal 20L Can';
    }
  }

  double get defaultDeposit {
    switch (this) {
      case BottleType.bisleri:
        return 150.0;
      case BottleType.normal:
        return 180.0;
    }
  }
}

enum PaymentMethod {
  advancePaid,
  emptyBottle,
}

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.emptyBottle:
        return 'Empty Bottle Given';
      case PaymentMethod.advancePaid:
        return 'Advance Paid';
    }
  }
}

class WaterBottlePurchaseItem {
  final BottleType bottleType;
  final PaymentMethod paymentMethod;
  final int quantity;
  final double depositAmount;

  WaterBottlePurchaseItem({
    required this.bottleType,
    required this.paymentMethod,
    required this.quantity,
    required this.depositAmount,
  });

  WaterBottlePurchaseItem copyWith({
    BottleType? bottleType,
    PaymentMethod? paymentMethod,
    int? quantity,
    double? depositAmount,
  }) {
    return WaterBottlePurchaseItem(
      bottleType: bottleType ?? this.bottleType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      quantity: quantity ?? this.quantity,
      depositAmount: depositAmount ?? this.depositAmount,
    );
  }

  Map<String, dynamic> toJson() => {
        'bottleType': bottleType.name,
        'paymentMethod': paymentMethod.name,
        'quantity': quantity,
        'depositAmount': depositAmount,
      };

  factory WaterBottlePurchaseItem.fromJson(Map<String, dynamic> json) {
    final typeString = (json['bottleType'] as String?) ?? BottleType.normal.name;
    final paymentString = (json['paymentMethod'] as String?) ?? PaymentMethod.advancePaid.name;
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final bottleType = BottleType.values.firstWhere(
      (value) => value.name == typeString,
      orElse: () => BottleType.normal,
    );
    final paymentMethod = PaymentMethod.values.firstWhere(
      (value) => value.name == paymentString,
      orElse: () => PaymentMethod.advancePaid,
    );
    final depositAmount = (json['depositAmount'] as num?)?.toDouble() ??
        (paymentMethod == PaymentMethod.advancePaid ? bottleType.defaultDeposit * quantity : 0.0);

    return WaterBottlePurchaseItem(
      bottleType: bottleType,
      paymentMethod: paymentMethod,
      quantity: quantity,
      depositAmount: depositAmount,
    );
  }
}

class WaterBottleRecord {
  final String id;
  final String customerName;
  final String address;
  final List<WaterBottlePurchaseItem> items;

  WaterBottleRecord({
    required this.id,
    required this.customerName,
    required this.address,
    required this.items,
  });

  WaterBottleRecord copyWith({
    String? id,
    String? customerName,
    String? address,
    List<WaterBottlePurchaseItem>? items,
  }) {
    return WaterBottleRecord(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      items: items ?? this.items,
    );
  }

  int get totalBottles => items.fold(0, (sum, item) => sum + item.quantity);

  double get totalDeposit => items.fold(0, (sum, item) => sum + item.depositAmount);

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerName': customerName,
        'address': address,
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory WaterBottleRecord.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>?) ?? <dynamic>[];
    return WaterBottleRecord(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: json['customerName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      items: itemsJson
          .map((item) => WaterBottlePurchaseItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

