import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'glass_container.dart';

class CartSelectionTabs extends ConsumerWidget {
  const CartSelectionTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        final isSelected = cartState.activeIndex == index;
        final cartItems = cartState.carts[index];
        final cartLabel = 'Cart ${index + 1}';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => ref.read(cartProvider.notifier).setActiveCart(index),
              child: GlassContainer(
                color: isSelected
                    ? scheme.primary.withOpacity(0.4)
                    : Colors.white.withOpacity(0.12),
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    cartItems.isNotEmpty
                        ? '$cartLabel (${cartItems.length})'
                        : cartLabel,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
