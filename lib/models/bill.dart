import 'cart_item.dart';

class Bill {
  final String billNumber;
  final String date;
  final String time;
  final String operatorName;
  final String customerType;
  final List<CartItem> cartItems;

  // Delivery details (only for Home Delivery)
  final String? apartmentName;
  final String? blockAndDoor;

  // Payment details
  final String paymentMode; // 'Cash', 'UPI', 'Mix-Payment'
  final double cashAmount;
  final double upiAmount;
  
  // Shop metadata at the time of billing
  final String? shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? billGreeting;
  final String? billExtraInfo;
  final String? firestoreId;

  const Bill({
    required this.billNumber,
    required this.date,
    required this.time,
    required this.operatorName,
    required this.customerType,
    required this.cartItems,
    required this.paymentMode,
    this.apartmentName,
    this.blockAndDoor,
    this.cashAmount = 0,
    this.upiAmount = 0,
    this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.billGreeting,
    this.billExtraInfo,
    this.firestoreId,
  });

  // Calculate subtotal
  double get subtotal {
    return cartItems.fold(0, (sum, item) => sum + item.total);
  }

  // Calculate tax (removed GST)
  double get tax => 0.0;

  // Calculate grand total (rounded: .1–.4 rounds down, .5–.9 rounds up)
  double get grandTotal => subtotal.round().toDouble();

  // Convert to JSON for storage/export
  Map<String, dynamic> toJson() => {
    'shopName': shopName ?? '',
    'shopAddress': shopAddress ?? '',
    'shopPhone': shopPhone ?? '',
    'billGreeting': billGreeting ?? 'Thank You!',
    'billExtraInfo': billExtraInfo ?? '',
    'cartItems': cartItems.map((item) => item.toJson()).toList(),
    'grandTotal': grandTotal,
    'customerType': customerType,
    'operatorName': operatorName,
    'billNumber': billNumber,
    'date': date,
    'time': time,
    'paymentMode': paymentMode,
    'cashAmount': cashAmount,
    'upiAmount': upiAmount,
    if (apartmentName != null) 'apartmentName': apartmentName,
    if (blockAndDoor != null) 'blockAndDoor': blockAndDoor,
    if (firestoreId != null) 'firestoreId': firestoreId,
  };
}
