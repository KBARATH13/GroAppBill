String formatBillShareItemLine({
  required String name,
  required double price,
  required String quantity,
  required String unit,
  required double total,
}) {
  final itemName = name.length > 14 ? name.substring(0, 14) : name;
  final itemPrice = '₹${price.toStringAsFixed(2)}';
  final itemQuantity = '$quantity$unit';
  final itemTotal = '₹${total.toStringAsFixed(2)}';

  return '${itemName.padRight(14)} ${itemPrice.padRight(10)} ${itemQuantity.padRight(8)} $itemTotal';
}