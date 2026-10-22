/// Represents the shop's metadata used for bill headers and footers.
class ShopInfo {
  final String shopName;
  final String address;
  final String phone;
  final String greeting;
  final String extraInfo; // For discounts or additional notes
  final List<String> categories;
  final List<String> deletedCategories;
  final List<String> units;

  const ShopInfo({
    this.shopName = '',
    this.address = '',
    this.phone = '',
    this.greeting = 'Thank You!',
    this.extraInfo = '',
    this.categories = const ['Vegetables', 'Fruits', 'Dhall', 'Groceries'],
    this.deletedCategories = const [],
    this.units = const ['kg', 'pc'],
  });

  factory ShopInfo.fromMap(Map<String, dynamic> data) {
    return ShopInfo(
      shopName: data['shopName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      greeting: data['greeting'] as String? ?? 'Thank You!',
      extraInfo: data['extraInfo'] as String? ?? '',
      categories:
          (data['categories'] as List?)?.cast<String>() ??
          const ['Vegetables', 'Fruits', 'Dhall', 'Groceries'],
      deletedCategories:
          (data['deletedCategories'] as List?)?.cast<String>() ?? const [],
      units: (data['units'] as List?)?.cast<String>() ?? const ['kg', 'pc'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopName': shopName,
      'address': address,
      'phone': phone,
      'greeting': greeting,
      'extraInfo': extraInfo,
      'categories': categories,
      'deletedCategories': deletedCategories,
      'units': units,
    };
  }

  ShopInfo copyWith({
    String? shopName,
    String? address,
    String? phone,
    String? greeting,
    String? extraInfo,
    List<String>? categories,
    List<String>? deletedCategories,
    List<String>? units,
  }) {
    return ShopInfo(
      shopName: shopName ?? this.shopName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      greeting: greeting ?? this.greeting,
      extraInfo: extraInfo ?? this.extraInfo,
      categories: categories ?? this.categories,
      deletedCategories: deletedCategories ?? this.deletedCategories,
      units: units ?? this.units,
    );
  }
}
