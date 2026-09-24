import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groappbill/models/index.dart';
import 'package:groappbill/providers/cart_provider.dart';
import 'package:groappbill/providers/inventory_providers.dart';

void main() {
  test('updateItemPrice keeps the cart item with an overridden price', () {
    final container = ProviderContainer();
    final notifier = container.read(cartProvider.notifier);

    final product = Product(
      id: 'p1',
      name: 'Milk',
      price: 45,
      unit: 'pc',
      category: 'Dairy',
    );

    notifier.addItem(product, 2);
    notifier.updateItemPrice(0, 55);

    final item = container.read(cartProvider).activeCart.first;
    expect(item.product.price, 55);
    expect(item.isPriceOverridden, isTrue);
    expect(item.total, 110);
  });
}
