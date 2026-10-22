import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/index.dart';
import '../services/sync_service.dart';
import 'auth_providers.dart';
import 'shop_provider.dart';

// --- Notifiers ---

String normalizeCategoryName(String category) {
  final words = category
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(_normalizeCategoryWord);
  return words.join(' ');
}

String _normalizeCategoryWord(String word) {
  if (word == 'series' || word == 'species') return word;

  if (word.length > 3 && word.endsWith('ies')) {
    const ieEndingPlurals = {
      'brownies',
      'cookies',
      'movies',
      'pies',
      'rookies',
      'smoothies',
      'veggies',
    };
    if (ieEndingPlurals.contains(word)) {
      return word.substring(0, word.length - 1);
    }
    return '${word.substring(0, word.length - 3)}y';
  }
  if (word.length > 4 &&
      (word.endsWith('sses') ||
          word.endsWith('ches') ||
          word.endsWith('shes') ||
          word.endsWith('xes') ||
          word.endsWith('zes'))) {
    return word.substring(0, word.length - 2);
  }
  if (word.length > 3 &&
      word != 'news' &&
      word != 'lens' &&
      word.endsWith('s') &&
      !word.endsWith('ss') &&
      !word.endsWith('us') &&
      !word.endsWith('is')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

Map<String, int> categoryProductCounts(List<Product> products) {
  final counts = <String, int>{};
  for (final product in products) {
    final key = normalizeCategoryName(product.category);
    if (key.isEmpty) continue;
    counts.update(key, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

class CategoriesNotifier extends StateNotifier<List<String>> {
  static const defaultCategories = [
    'Vegetables',
    'Fruits',
    'Dhall',
    'Groceries',
  ];

  final Ref _ref;

  CategoriesNotifier(this._ref) : super([]) {
    // Initialize state from current shop info
    state = _ref.read(shopInfoProvider).categories;

    // Keep in sync with shopInfoProvider changes
    _ref.listen<ShopInfo>(shopInfoProvider, (previous, next) {
      state = next.categories;
    });
  }

  String addCategory(String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return trimmed;

    final shopInfo = _ref.read(shopInfoProvider);
    final categoryKey = normalizeCategoryName(trimmed);
    final deletedKeys = shopInfo.deletedCategories
        .map(normalizeCategoryName)
        .toSet();
    final candidates = [
      ...shopInfo.categories,
      ..._ref.read(productsProvider).map((product) => product.category),
    ];
    String? existingCategory;
    for (final candidate in candidates) {
      if (normalizeCategoryName(candidate) == categoryKey &&
          !deletedKeys.contains(normalizeCategoryName(candidate))) {
        existingCategory = candidate.trim();
        break;
      }
    }
    final canonicalCategory = existingCategory ?? trimmed;

    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      final newCategories = [...shopInfo.categories];
      if (!newCategories.any(
        (item) => normalizeCategoryName(item) == categoryKey,
      )) {
        newCategories.add(canonicalCategory);
      }
      final deletedCategories = shopInfo.deletedCategories
          .where((item) => normalizeCategoryName(item) != categoryKey)
          .toList();
      if (newCategories.length != shopInfo.categories.length ||
          deletedCategories.length != shopInfo.deletedCategories.length) {
        _ref
            .read(shopInfoProvider.notifier)
            .updateShopInfo(
              user.adminEmail,
              shopInfo.copyWith(
                categories: newCategories,
                deletedCategories: deletedCategories,
              ),
            );
      }
    }
    return canonicalCategory;
  }

  Future<void> deleteCategory(String category) async {
    final categoryKey = normalizeCategoryName(category);
    if (defaultCategories.any(
      (item) => normalizeCategoryName(item) == categoryKey,
    )) {
      return;
    }

    final shopInfo = _ref.read(shopInfoProvider);
    final hasProductsInCategory = _ref
        .read(productsProvider)
        .any(
          (product) => normalizeCategoryName(product.category) == categoryKey,
        );
    if (!shopInfo.categories.any(
          (item) => normalizeCategoryName(item) == categoryKey,
        ) &&
        !hasProductsInCategory) {
      return;
    }

    final user = _ref.read(appUserProvider).valueOrNull;
    if (user == null || !user.isAdmin) return;

    final categories = shopInfo.categories
        .where((item) => normalizeCategoryName(item) != categoryKey)
        .toList();
    final deletedCategories = {
      ...shopInfo.deletedCategories.where(
        (item) => normalizeCategoryName(item) != categoryKey,
      ),
      category,
    }.toList();

    await _ref
        .read(shopInfoProvider.notifier)
        .updateShopInfo(
          user.adminEmail,
          shopInfo.copyWith(
            categories: categories,
            deletedCategories: deletedCategories,
          ),
        );
  }

  void resetToDefaults() {
    final shopInfo = _ref.read(shopInfoProvider);
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      _ref
          .read(shopInfoProvider.notifier)
          .updateShopInfo(
            user.adminEmail,
            shopInfo.copyWith(categories: defaultCategories),
          );
    }
  }
}

class UnitsNotifier extends StateNotifier<List<String>> {
  final Ref _ref;

  UnitsNotifier(this._ref) : super([]) {
    // Initialize state from current shop info
    state = _ref.read(shopInfoProvider).units;

    // Keep in sync with shopInfoProvider changes
    _ref.listen<ShopInfo>(shopInfoProvider, (previous, next) {
      state = next.units;
    });
  }

  void addUnit(String unit) {
    if (unit.trim().isEmpty) return;
    final trimmed = unit.trim();
    if (!state.contains(trimmed)) {
      final shopInfo = _ref.read(shopInfoProvider);
      final user = _ref.read(appUserProvider).valueOrNull;
      if (user != null) {
        final newUnits = [...shopInfo.units, trimmed];
        _ref
            .read(shopInfoProvider.notifier)
            .updateShopInfo(
              user.adminEmail,
              shopInfo.copyWith(units: newUnits),
            );
      }
    }
  }

  void resetToDefaults() {
    final shopInfo = _ref.read(shopInfoProvider);
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      _ref
          .read(shopInfoProvider.notifier)
          .updateShopInfo(
            user.adminEmail,
            shopInfo.copyWith(units: const ['kg', 'pc']),
          );
    }
  }
}

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
          p.barcode!.trim(): p,
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
        state = decoded
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList();

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
    state = state
        .map((p) => p.id == id ? p.copyWith(usageCount: p.usageCount + 1) : p)
        .toList();
  }

  void updateFromStream(List<Product> synced) {
    if (synced.isEmpty && state.isNotEmpty) {
      debugPrint('Sync: Cloud is empty but local has items. Skipping wipeout.');
      return;
    }

    _invalidateCache();
    state = synced;
    _saveProducts();
  }
}

List<String> sortCategoriesForDisplay(
  List<String> categories,
  List<Product> products, {
  bool alphabetical = false,
  List<String> excludedCategories = const [],
}) {
  final excluded = excludedCategories.map(normalizeCategoryName).toSet();
  final uniqueCategories = <String, String>{};
  for (final category in [
    ...categories,
    ...products.map((product) => product.category),
  ]) {
    final key = normalizeCategoryName(category);
    if (key.isEmpty || category == 'All' || excluded.contains(key)) continue;
    uniqueCategories.putIfAbsent(key, () => category.trim());
  }
  final baseCategories = uniqueCategories.values.toList();
  if (baseCategories.isEmpty) return const ['All'];

  final productCounts = categoryProductCounts(products);
  final sorted = [...baseCategories]
    ..sort((a, b) {
      final nameComparison = a.toLowerCase().compareTo(b.toLowerCase());
      if (alphabetical) {
        return nameComparison != 0 ? nameComparison : a.compareTo(b);
      }

      final keyA = normalizeCategoryName(a);
      final keyB = normalizeCategoryName(b);
      final countA = productCounts[keyA] ?? 0;
      final countB = productCounts[keyB] ?? 0;
      if (countB != countA) {
        return countB.compareTo(countA);
      }
      return nameComparison != 0 ? nameComparison : a.compareTo(b);
    });

  return sorted;
}

// --- Providers ---

// Inventory provider - streams all products for the current shop
final inventoryStreamProvider = StreamProvider<List<Product>>((ref) {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  if (appUser == null) return Stream.value([]);
  return SyncService.productsStream(appUser.adminEmail);
});

// Categories provider - manages product categories with cloud sync via shopInfoProvider
final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<String>>((ref) {
      return CategoriesNotifier(ref);
    });

// Units provider - manages product units with cloud sync via shopInfoProvider
final unitsProvider = StateNotifierProvider<UnitsNotifier, List<String>>((ref) {
  return UnitsNotifier(ref);
});

// Products provider - manages inventory
final productsProvider = StateNotifierProvider<ProductsNotifier, List<Product>>(
  (ref) {
    final notifier = ProductsNotifier(ref);
    // Automatically keep the local state in sync with the Firestore stream
    ref.listen(inventoryStreamProvider, (previous, next) {
      if (next.hasValue) {
        notifier.updateFromStream(next.requireValue);
      }
    });
    return notifier;
  },
);
