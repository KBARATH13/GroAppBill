import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/index.dart';
import '../providers/app_providers.dart';
import '../widgets/numpad_input_sheet.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/glass_container.dart';
import '../widgets/cart_selection_tabs.dart';
import '../widgets/delivery_info_card.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  String _searchTerm = '';
  String _selectedCategory = 'All';
  String _sortBy = 'Name (A-Z)';
  late TextEditingController _searchController;
  late TextEditingController _quantityController;
  late TextEditingController _operatorController;
  late TextEditingController _apartmentController;
  late TextEditingController _blockDoorController;
  Product? _selectedProduct;
  late ScrollController _scrollController;
  bool _isProcessingScan = false;
  final GlobalKey _searchBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _quantityController = TextEditingController();
    
    final delivery = ref.read(deliveryInfoProvider);
    _apartmentController = TextEditingController(text: delivery.apartmentName);
    _blockDoorController = TextEditingController(text: delivery.blockAndDoor);
    
    _operatorController = TextEditingController(
      text: ref.read(userProvider) ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _quantityController.dispose();
    _operatorController.dispose();
    _apartmentController.dispose();
    _blockDoorController.dispose();
    super.dispose();
  }

  void _addToCart({Product? overriddenProduct}) {
    if (_operatorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠ Please enter the operator\'s name first'),
        ),
      );
      return;
    }

    if (_selectedProduct == null || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter weight')));
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    final product = overriddenProduct ?? _selectedProduct;
    if (product == null) return;
    
    final productName = product.name;
    // Safely get original product id even if overridden
    final productId = _selectedProduct?.id ?? product.id;
    
    ref.read(productsProvider.notifier).incrementUsage(productId);
    ref.read(cartProvider.notifier).addItem(
      product, 
      quantity, 
      isPriceOverridden: overriddenProduct != null,
    );
    _quantityController.clear();
    setState(() => _selectedProduct = null);

    if (mounted) {
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $productName added to cart'),
          backgroundColor: scheme.secondary,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Feature #2 — large in-app numpad replaces system keyboard for weight entry.
  Future<void> _showWeightInputSheet() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedProduct == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a product first')),
      );
      return;
    }

    final product = _selectedProduct;
    if (product == null) return;

    final isAdmin = ref.read(appUserProvider).valueOrNull?.isAdmin ?? false;

    // Capture context-dependent state before async gap
    final result = await showNumpadInputSheet(
      context,
      productName: product.name,
      unit: product.unit,
      price: product.price.toStringAsFixed(2),
      productId: product.id,
      isAdmin: isAdmin,
    );

    if (result != null && mounted) {
      _quantityController.text = result['quantity'] ?? '1';
      final newPriceStr = result['price'];
      
      if (newPriceStr != null) {
        final newPrice = double.tryParse(newPriceStr);
        if (newPrice != null && newPrice != product.price) {
          _addToCart(overriddenProduct: product.copyWith(price: newPrice));
          return;
        }
      }
      
      _addToCart();
    }
  }

  Future<void> _onBarcodeScanned(String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final productsNotifier = ref.read(productsProvider.notifier);
    final product = productsNotifier.findByBarcode(code.trim());

    if (product != null) {
      setState(() => _selectedProduct = product);
      
      final cartState = ref.read(cartProvider);
      final isInCart = cartState.activeCart.any((item) => item.product.id == product.id);

      // Display numpad ONLY when the same product is scanned again (i.e., already in cart)
      if (isInCart) {
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
        await _showWeightInputSheet();
      } else {
        // For the first scan, add 1 immediately (default)
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.lightImpact();
        ref.read(productsProvider.notifier).incrementUsage(product.id);
        ref.read(cartProvider.notifier).addItem(product, 1.0);
        
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('✓ ${product.name} added to cart'),
              backgroundColor: scheme.secondary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
        setState(() => _selectedProduct = null);
      }
    } else {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user?.isAdmin != true && user?.canAddInventory != true) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Product not found in inventory')),
          );
        }
        return;
      }
      
      final shouldAdd = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Product Not Found'),
            ],
          ),
          content: Text('Product with barcode "$code" was not found in inventory. Would you like to add it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(backgroundColor: scheme.secondary),
            ),
          ],
        ),
      );

      if (shouldAdd == true && mounted) {
        await _showAddProductDialog(barcode: code);
      }
    }
  }

  void _openBarcodeScanner() {
    setState(() => _isProcessingScan = false);
    final MobileScannerController dialogController = MobileScannerController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Scan Barcode'),
            Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.secondary),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MobileScanner(
              controller: dialogController,
              onDetect: (capture) async {
                if (_isProcessingScan) return;
                
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _isProcessingScan = true;

                    
                    // Handle scan (might show a dialog)
                    await _onBarcodeScanned(barcode.rawValue!);
                    
                    // Small delay to prevent immediate re-detection of the same barcode
                    await Future.delayed(const Duration(milliseconds: 1500));
                    
                    // Reset flag for next scan
                    _isProcessingScan = false;
                    break;
                  }
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              dialogController.dispose();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    ).then((_) {
      // Ensure controller is disposed even if dismissed via gesture
      dialogController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    final filteredProducts = products.where((p) {
      final matchesSearch =
          p.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchTerm.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Apply Sorting
    if (_sortBy == 'Name (A-Z)') {
      filteredProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortBy == 'Price: Low to High') {
      filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'Price: High to Low') {
      filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    }

    // Listen to user changes (e.g., when SharedPreferences finishes loading)
    ref.listen<String?>(userProvider, (previous, next) {
      if (next != null && next.isNotEmpty && _operatorController.text.isEmpty) {
        _operatorController.text = next;
      }
    });

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === Cart Selection Tabs ===
                const CartSelectionTabs(),
                const SizedBox(height: 12),

                // === Operator & Customer Info Card ===
                DeliveryInfoCard(
                  operatorController: _operatorController,
                  apartmentController: _apartmentController,
                  blockDoorController: _blockDoorController,
                ),
                const SizedBox(height: 20),

                // === Search Bar ===
                Container(
                  key: _searchBarKey,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchTerm = value.trim());
                    },
                    onTap: () {
                      if (_searchBarKey.currentContext != null) {
                        Scrollable.ensureVisible(
                          _searchBarKey.currentContext!,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          alignment: 0.0,
                        );
                      }
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white70),
                        onPressed: () {
                          if (_searchBarKey.currentContext != null) {
                            Scrollable.ensureVisible(
                              _searchBarKey.currentContext!,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: 0.0,
                            );
                          }
                        },
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchTerm.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchTerm = '');
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                            onPressed: _openBarcodeScanner,
                          ),
                        ],
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // === Most Used Items ===
                if (_searchTerm.isEmpty) ...[
                  () {
                    final sortedUsage = List<Product>.from(ref.read(productsProvider))
                      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
                    final mostUsed = sortedUsage.where((p) => p.usageCount > 0).take(5).toList();

                    if (mostUsed.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Most Used Items',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: mostUsed.length,
                              itemBuilder: (context, index) {
                                final product = mostUsed[index];
                                return GestureDetector(
                                  onTap: () {
                                    if (_operatorController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('⚠ Please enter Operator Name')),
                                      );
                                      return;
                                    }
                                    setState(() => _selectedProduct = product);
                                    _showWeightInputSheet();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: GlassContainer(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: 12,
                                      child: Container(
                                        width: 110,
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('₹${product.price}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                                Text('per ${product.unit}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }(),
                ],

                // === Category Filters ===
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    itemBuilder: (context, index) {
                      final category = index == 0 ? 'All' : categories[index - 1];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = category),
                          child: GlassContainer(
                            color: isSelected ? scheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.12),
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Center(
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // === Products Grid Header ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Product', style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: scheme.surfaceContainer,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          value: _sortBy,
                          isDense: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white),
                            ),
                            labelText: 'Sort',
                            labelStyle: const TextStyle(color: Colors.white70),
                          ),
                          items: ['Name (A-Z)', 'Price: Low to High', 'Price: High to Low']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _sortBy = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final user = ref.watch(appUserProvider).valueOrNull;
                final canAdd = user?.isAdmin == true || user?.canAddInventory == true;

                if (canAdd && index == filteredProducts.length) {
                  return GestureDetector(
                    onTap: _showAddProductDialog,
                    child: GlassContainer(
                      color: scheme.secondary.withOpacity(0.7),
                      borderRadius: 12,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, size: 40, color: Colors.white),
                          SizedBox(height: 4),
                          Text('Add New',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                final product = filteredProducts[index];
                return GestureDetector(
                  onTap: () {
                    if (_operatorController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠ Please enter Operator Name')),
                      );
                      return;
                    }
                    _selectedProduct = product;
                    _showWeightInputSheet();
                  },
                  child: GlassContainer(
                    color: Colors.white.withOpacity(0.12),
                    padding: const EdgeInsets.all(12.0),
                    borderRadius: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('₹${product.price}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('per ${product.unit}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: filteredProducts.length + ((ref.watch(appUserProvider).valueOrNull?.isAdmin == true || ref.watch(appUserProvider).valueOrNull?.canAddInventory == true) ? 1 : 0),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Future<void> _showAddProductDialog({String? barcode}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductFormDialog(initialBarcode: barcode),
    );
  }
}

