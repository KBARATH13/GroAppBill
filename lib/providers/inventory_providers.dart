import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/index.dart';
import '../services/sync_service.dart';
import 'auth_providers.dart';

// Inventory provider - streams all products for the current shop
final inventoryStreamProvider = StreamProvider<List<Product>>((ref) {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  if (appUser == null) return Stream.value([]);
  return SyncService.productsStream(appUser.adminEmail);
});

// Categories provider - manages product categories
final categoriesProvider = StateNotifierProvider<CategoriesNotifier, List<String>>((ref) {
  return CategoriesNotifier();
});

class CategoriesNotifier extends StateNotifier<List<String>> {
  static const List<String> _defaultCategories = [
    'Vegetables',
    'Fruits',
    'Dhall',
    'Groceries',
  ];

  CategoriesNotifier() : super(_defaultCategories) {
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getString('grocery-categories');
    if (categoriesJson != null) {
      try {
        final decoded = jsonDecode(categoriesJson) as List;
        state = decoded.cast<String>();
      } catch (e) {
        state = _defaultCategories;
      }
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('grocery-categories', jsonEncode(state));
  }

  void addCategory(String category) {
    if (category.trim().isEmpty) return;
    final trimmed = category.trim();
    if (!state.contains(trimmed)) {
      state = [...state, trimmed];
      _saveCategories();
    }
  }

  void resetToDefaults() {
    state = _defaultCategories;
    _saveCategories();
  }
}

// Units provider - manages product units
final unitsProvider = StateNotifierProvider<UnitsNotifier, List<String>>((ref) {
  return UnitsNotifier();
});

class UnitsNotifier extends StateNotifier<List<String>> {
  static const List<String> _defaultUnits = ['kg', 'pc'];

  UnitsNotifier() : super(_defaultUnits) {
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final unitsJson = prefs.getString('grocery-units');
    if (unitsJson != null) {
      try {
        final decoded = jsonDecode(unitsJson) as List;
        state = decoded.cast<String>();
      } catch (e) {
        state = _defaultUnits;
      }
    }
  }

  Future<void> _saveUnits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('grocery-units', jsonEncode(state));
  }

  void addUnit(String unit) {
    if (unit.trim().isEmpty) return;
    final trimmed = unit.trim();
    if (!state.contains(trimmed)) {
      state = [...state, trimmed];
      _saveUnits();
    }
  }

  void resetToDefaults() {
    state = _defaultUnits;
    _saveUnits();
  }
}

// Products provider - manages inventory
final productsProvider = StateNotifierProvider<ProductsNotifier, List<Product>>(
  (ref) {
    final notifier = ProductsNotifier(ref);
    // Automatically keep the local state in sync with the Firestore stream
    ref.listen(inventoryStreamProvider, (previous, next) {
      if (next is AsyncData<List<Product>>) {
        notifier.updateFromStream(next.value);
      }
    });
    return notifier;
  },
);

class ProductsNotifier extends StateNotifier<List<Product>> {
  final Ref _ref;
  Map<String, Product>? _barcodeCache;

  ProductsNotifier(this._ref) : super([]) {
    _loadProducts();
  }

  void _invalidateCache() => _barcodeCache = null;

  /// O(1) lookup for barcode scanning. 
  /// Optimized for scaling to large inventories.
  Product? findByBarcode(String barcode) {
    if (barcode.trim().isEmpty) return null;
    final b = barcode.trim();
    
    _barcodeCache ??= {
      for (final p in state)
        if (p.barcode != null && p.barcode!.trim().isNotEmpty)
          p.barcode!.trim(): p
    };
    return _barcodeCache![b];
  }

  Future<void> _loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check keys in order of priority (newest to oldest)
    String? jsonStr = prefs.getString('grocery-products');
    jsonStr ??= prefs.getString('grocery-products-v2');
    jsonStr ??= prefs.getString('products');

    if (jsonStr != null) {
      try {
        final List decoded = jsonDecode(jsonStr);
        state = decoded.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
        
        // If we found data in an old key, save it to the new key immediately
        if (prefs.getString('grocery-products') == null) {
          await _saveProducts();
        }
      } catch (e) {
        debugPrint('Error loading local products: $e');
        state = [];
      }
    }
  }

  Future<void> _saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson = jsonEncode(state.map((p) => p.toJson()).toList());
    await prefs.setString('grocery-products', productsJson);
  }

  Future<void> addProduct(Product product) async {
    _invalidateCache();
    state = [...state, product];
    await _saveProducts();
    
    // Cloud push
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      await SyncService.updateProduct(user.adminEmail, product);
    }
  }

  Future<void> updateProduct(String id, Product updatedProduct) async {
    _invalidateCache();
    state = state.map((p) => p.id == id ? updatedProduct : p).toList();
    await _saveProducts();

    // Cloud push
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      await SyncService.updateProduct(user.adminEmail, updatedProduct);
    }
  }

  Future<void> deleteProduct(String id) async {
    _invalidateCache();
    state = state.where((p) => p.id != id).toList();
    await _saveProducts();

    // Cloud push
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      await SyncService.deleteProduct(user.adminEmail, id);
    }
  }

  void incrementUsage(String id) {
    _invalidateCache();
    // Update local state for immediate UI feedback.
    // Structural changes (Add/Update/Delete) will trigger a persistent save later.
    state = state.map((p) => p.id == id ? p.copyWith(usageCount: p.usageCount + 1) : p).toList();
  }

  /// Called automatically by the provider listener when the stream updates.
  void updateFromStream(List<Product> synced) {
    // SAFETY GUARD: If the cloud sync returns an empty list but we HAVE local items,
    // do NOT overwrite yet. This prevents a "New Shop" cloud sync from wiping
    // out recovered/legacy local items before the user hits "Publish".
    if (synced.isEmpty && state.isNotEmpty) {
      debugPrint('Sync: Cloud is empty but local has items. Skipping wipeout.');
      return;
    }

    _invalidateCache();
    state = synced;
    _saveProducts();
  }
}
