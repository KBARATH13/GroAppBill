/// Represents the shop's metadata used for bill headers and footers.
class ShopInfo {
  final String shopName;
  final String address;
  final String phone;
  final String greeting;
  final String extraInfo; // For discounts or additional notes

  const ShopInfo({
    this.shopName = '',
    this.address = '',
    this.phone = '',
    this.greeting = 'Thank You!',
    this.extraInfo = '',
  });

  factory ShopInfo.fromMap(Map<String, dynamic> data) {
    return ShopInfo(
      shopName: data['shopName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      greeting: data['greeting'] as String? ?? 'Thank You!',
      extraInfo: data['extraInfo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopName': shopName,
      'address': address,
      'phone': phone,
      'greeting': greeting,
      'extraInfo': extraInfo,
    };
  }
}
