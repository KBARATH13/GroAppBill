import 'product.dart';

class CartItem {
  final Product product;
  final double quantity; // Weight or number of pieces
  final bool isPriceOverridden;

  CartItem({
    required this.product,
    required this.quantity,
    this.isPriceOverridden = false,
  });

  // Calculate total for this item
  double get total => (product.price * quantity * 100).round() / 100;

  // Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': product.id,
    'name': product.name,
    'weight': quantity,
    'unit': product.unit,
    'price': product.price,
    'category': product.category,
    'barcode': product.barcode,
    'total': total,
    'isPriceOverridden': isPriceOverridden,
  };

  // Create from JSON
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product: Product(
      id: json['id'] ?? '',
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      category: json['category'] ?? 'General',
      barcode: json['barcode'] as String?,
    ),
    quantity: (json['weight'] as num).toDouble(),
    isPriceOverridden: json['isPriceOverridden'] as bool? ?? false,
  );
}
