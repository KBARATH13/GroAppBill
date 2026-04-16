class Product {
  final String id;
  final String name;
  final double price;
  final String unit;
  final String? barcode;
  final String category;
  final int usageCount;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.category,
    this.barcode,
    this.usageCount = 0,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'unit': unit,
    'category': category,
    'barcode': barcode,
    'usageCount': usageCount,
  };

  // Create from JSON
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    price: (json['price'] as num).toDouble(),
    unit: json['unit'],
    category: json['category'],
    barcode: json['barcode'],
    usageCount: json['usageCount'] ?? 0,
  );

  // Copy with method for updates
  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? unit,
    String? category,
    String? barcode,
    int? usageCount,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        category: category ?? this.category,
        barcode: barcode ?? this.barcode,
        usageCount: usageCount ?? this.usageCount,
      );
}
