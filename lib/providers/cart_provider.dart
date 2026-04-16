import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/index.dart';
import 'inventory_providers.dart';

class CartState {
  final int activeIndex;
  final List<List<CartItem>> carts;
  final String? editingBillId; // The ID of the bill currently being edited
  final String? editingBillDate; // The date of the bill currently being edited
  final String? editingFirestoreId; // The Firestore document ID of the bill currently being edited
  
  CartState({
    required this.activeIndex, 
    required this.carts, 
    this.editingBillId,
    this.editingBillDate,
    this.editingFirestoreId,
  });
  
  List<CartItem> get activeCart => carts[activeIndex];
  
  CartState copyWith({
    int? activeIndex,
    List<List<CartItem>>? carts,
    String? editingBillId,
    String? editingBillDate,
    String? editingFirestoreId,
    bool clearEditing = false,
  }) {
    return CartState(
      activeIndex: activeIndex ?? this.activeIndex,
      carts: carts ?? this.carts,
      editingBillId: clearEditing ? null : (editingBillId ?? this.editingBillId),
      editingBillDate: clearEditing ? null : (editingBillDate ?? this.editingBillDate),
      editingFirestoreId: clearEditing ? null : (editingFirestoreId ?? this.editingFirestoreId),
    );
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref);
});

class CartNotifier extends StateNotifier<CartState> {
  final Ref _ref;

  CartNotifier(this._ref) : super(CartState(activeIndex: 0, carts: [[], [], []])) {
    _loadCart();
    
    // Set up a permanent listener to the product inventory.
    // Whenever products change, we check if any cart items need price updates.
    _ref.listen<List<Product>>(productsProvider, (previous, next) {
      refreshPrices(next);
    });
  }

  /// Synchronizes prices of items in all carts with the provided product list.
  void refreshPrices(List<Product> latestProducts) {
    if (latestProducts.isEmpty) return;

    bool changed = false;
    final List<List<CartItem>> updatedCarts = [];

    for (final cart in state.carts) {
      final List<CartItem> updatedCart = [];
      for (final item in cart) {
        // Find the corresponding product in the latest inventory
        final latestProduct = latestProducts.firstWhere(
          (p) => p.id == item.product.id,
          orElse: () => item.product,
        );

        if (item.isPriceOverridden) {
          updatedCart.add(item);
          continue;
        }

        // If the price has changed, we create a new CartItem with the new product
        if (latestProduct.price != item.product.price) {
          updatedCart.add(CartItem(product: latestProduct, quantity: item.quantity));
          changed = true;
        } else {
          updatedCart.add(item);
        }
      }
      updatedCarts.add(updatedCart);
    }

    if (changed) {
      // Create a brand new state to ensure Riverpod detects the change
      state = state.copyWith(carts: updatedCarts);
      _saveCart();
    }
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('grocery-carts');
    if (cartJson != null) {
      try {
        final decoded = jsonDecode(cartJson) as Map<String, dynamic>;
        final aIndex = decoded['activeIndex'] as int? ?? 0;
        final cList = (decoded['carts'] as List).map((cartList) => 
          (cartList as List).map((item) => CartItem.fromJson(item as Map<String, dynamic>)).toList()
        ).toList();
        state = CartState(activeIndex: aIndex, carts: cList);
      } catch (e) {
        state = CartState(activeIndex: 0, carts: [[], [], []]);
      }
    }
  }

  void loadBillIntoCart(Bill bill) {
    final carts = state.carts;
    
    // Find unused cart index using requested logic
    int targetIndex = -1;
    
    bool c1Empty = carts[0].isEmpty;
    bool c2Empty = carts[1].isEmpty;
    bool c3Empty = carts[2].isEmpty;

    if (c1Empty && c2Empty && c3Empty) {
      targetIndex = 0; // default to 1
    } else if (!c1Empty && !c2Empty) {
      targetIndex = 2; // cart 3
    } else if (!c2Empty && !c3Empty) {
      targetIndex = 0; // cart 1
    } else if (!c1Empty && !c3Empty) {
      targetIndex = 1; // cart 2
    } else {
      // Fallback: first empty
      if (c1Empty) targetIndex = 0;
      else if (c2Empty) targetIndex = 1;
      else if (c3Empty) targetIndex = 2;
      else targetIndex = 0; // overwrite 1 if everything full
    }

    final newCarts = List<List<CartItem>>.from(state.carts);
    newCarts[targetIndex] = List<CartItem>.from(bill.cartItems);
    
    state = state.copyWith(
      activeIndex: targetIndex,
      carts: newCarts,
      editingBillId: bill.billNumber,
      editingBillDate: bill.date,
      editingFirestoreId: bill.firestoreId,
    );
    _saveCart();
  }

  void clearEditingState() {
    state = state.copyWith(clearEditing: true);
    _saveCart();
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = jsonEncode({
      'activeIndex': state.activeIndex,
      'carts': state.carts.map((cart) => cart.map((item) => item.toJson()).toList()).toList(),
    });
    await prefs.setString('grocery-carts', cartJson);
  }

  void setActiveCart(int index) {
    if (index >= 0 && index < state.carts.length) {
      state = state.copyWith(activeIndex: index);
      _saveCart();
    }
  }

  void addItem(Product product, double quantity, {bool isPriceOverridden = false}) {
    final activeCart = List<CartItem>.from(state.activeCart);
    final existingIndex = activeCart.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex >= 0) {
      // Item already exists, update quantity
      final oldItem = activeCart[existingIndex];
      
      // If we are passing a new explicit override, use the new product.
      // Otherwise, if the old item was already overridden, we want to KEEP the old item's overridden product!
      final targetProduct = isPriceOverridden ? product : (oldItem.isPriceOverridden ? oldItem.product : product);

      activeCart[existingIndex] = CartItem(
        product: targetProduct, 
        quantity: oldItem.quantity + quantity,
        isPriceOverridden: isPriceOverridden || oldItem.isPriceOverridden,
      );
    } else {
      // Add new item
      activeCart.add(CartItem(product: product, quantity: quantity, isPriceOverridden: isPriceOverridden));
    }
    
    final newCarts = List<List<CartItem>>.from(state.carts);
    newCarts[state.activeIndex] = activeCart;
    state = state.copyWith(carts: newCarts);
    _saveCart();
  }

  void removeItem(int index) {
    final activeCart = List<CartItem>.from(state.activeCart);
    activeCart.removeAt(index);
    final newCarts = List<List<CartItem>>.from(state.carts);
    newCarts[state.activeIndex] = activeCart;
    state = state.copyWith(carts: newCarts);
    _saveCart();
  }

  void clearCart() {
    final newCarts = List<List<CartItem>>.from(state.carts);
    newCarts[state.activeIndex] = [];
    state = state.copyWith(carts: newCarts);
    _saveCart();
  }

  double get subtotal => state.activeCart.fold(0, (sum, item) => sum + item.total);
  double get tax => 0.0;
  double get grandTotal => subtotal.round().toDouble();

  void updateItemQuantity(int index, double newQuantity, {Product? newProduct}) {
    if (newQuantity <= 0) {
      removeItem(index);
    } else {
      final activeCart = List<CartItem>.from(state.activeCart);
      final item = activeCart[index];
      activeCart[index] = CartItem(
        product: newProduct ?? item.product, 
        quantity: newQuantity,
        isPriceOverridden: newProduct != null ? true : item.isPriceOverridden,
      );
      final newCarts = List<List<CartItem>>.from(state.carts);
      newCarts[state.activeIndex] = activeCart;
      state = state.copyWith(carts: newCarts);
      _saveCart();
    }
  }
}
