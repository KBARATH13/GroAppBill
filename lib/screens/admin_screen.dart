import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/index.dart';
import '../providers/app_providers.dart';
import '../widgets/product_form_dialog.dart';
import '../services/sync_service.dart';
import '../widgets/glass_container.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AdminScreen extends ConsumerStatefulWidget {
  final bool hasPendingSync;
  final Future<void> Function()? onSync;
  final VoidCallback? onChangeMade; // called whenever admin edits inventory
  final VoidCallback? onPublishComplete; // called after pushing to Firestore

  const AdminScreen({
    super.key,
    this.hasPendingSync = false,
    this.onSync,
    this.onChangeMade,
    this.onPublishComplete,
  });

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _searchQuery = '';
  String _filterCategory = 'All';
  String _sortBy = 'Name (A-Z)';
  late TextEditingController _searchController;
  bool _isProcessingScan = false;
  bool _hasLocalChanges = false; // true when admin has unpublished inventory changes

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeScanned(String code) async {
    final products = ref.read(productsProvider);
    final product = products.cast<Product?>().firstWhere(
      (p) => p?.barcode == code,
      orElse: () => null,
    );

    if (product != null) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
      setState(() {
        _searchController.text = product.name;
        _searchQuery = product.name;
      });
    } else {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user?.isAdmin != true && user?.canAddInventory != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access Denied: Inventory clearance required')),
      );
      return;
    }

    final shouldAdd = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  const Text('Product Not Found'),
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
            );
          },
        ),
      );

      if (shouldAdd == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => ProductFormDialog(initialBarcode: code),
        );
      }
    }
  }

  void _openBarcodeScanner() {
    setState(() => _isProcessingScan = false);
    final MobileScannerController dialogController = MobileScannerController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Scan Barcode'),
                Icon(Icons.qr_code_scanner, color: scheme.secondary),
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
                    debugPrint('Barcode detected: ${barcode.rawValue}');
                    
                    await _onBarcodeScanned(barcode.rawValue!);
                    await Future.delayed(const Duration(milliseconds: 1500));
                    
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
          );
        },
      ),
    ).then((_) {
      dialogController.dispose();
    });
  }

  void _openAddForm() {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user?.isAdmin != true && user?.canAddInventory != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access Denied: Inventory clearance required')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ProductFormDialog(),
    ).then((saved) {
      if (saved == true) {
        setState(() => _hasLocalChanges = true);
        widget.onChangeMade?.call();
      }
    });
  }

  void _openEditForm(Product product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductFormDialog(product: product),
    ).then((saved) {
      if (saved == true) {
        setState(() => _hasLocalChanges = true);
        widget.onChangeMade?.call();
      }
    });
  }

  Future<void> _pushToFirestore() async {
    final products = ref.read(productsProvider);
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      await SyncService.pushToFirestore(user.adminEmail, products);
      setState(() => _hasLocalChanges = false);
      widget.onPublishComplete?.call();
    }
  }


  Future<void> _handleSync() async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user?.isAdmin != true && user?.canAddInventory != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access Denied: Admin or Inventory clearance required')),
      );
      return;
    }
    if (_hasLocalChanges) {
      // Admin has unpublished changes — confirm push
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.cloud_upload, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Text('Publish Changes'),
                ],
              ),
              content: const Text(
                'You have unsaved changes to the inventory.\n\n'
                'Would you like to publish them to Firebase now? '
                'All operators and other admin devices will be able to sync the updated inventory.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Discard'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Publish'),
                  style: ElevatedButton.styleFrom(backgroundColor: scheme.secondary),
                ),
              ],
            );
          },
        ),
      );
      if (confirmed == true) {
        await _pushToFirestore();
        if (mounted) {
          final scheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✓ Inventory published to Firebase successfully!'),
              backgroundColor: scheme.secondary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else if (widget.onSync != null) {
      await widget.onSync!();
    } else {
      // Manual pull is no longer strictly needed as we have real-time sync,
      // but we can offer a "Reload" if desired.
      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Inventory is synced automatically in real-time'), backgroundColor: scheme.primary),
        );
      }
    }
  }


  void _handleDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: const Text('Delete Product'),
            content: const Text('Are you sure you want to delete this product?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(productsProvider.notifier).deleteProduct(id);
                  setState(() => _hasLocalChanges = true);
                  widget.onChangeMade?.call();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product deleted (unpublished)')),
                  );
                },
                child: Text('Yes', style: TextStyle(color: scheme.error)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProductOptions(Product product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    product.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                if (ref.read(appUserProvider).valueOrNull?.isAdmin == true) ...[
                  ListTile(
                    leading: Icon(Icons.edit, color: scheme.primary),
                    title: const Text('Edit Product'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openEditForm(product);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete, color: scheme.error),
                    title: Text('Delete Product', style: TextStyle(color: scheme.error)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleDelete(product.id);
                    },
                  ),
                ] else 
                  const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.grey),
                    title: Text('View Only (Admin required to edit)'),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    final filteredProducts = products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _filterCategory == 'All' || product.category == _filterCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    // Sorting Logic
    if (_sortBy == 'Name (A-Z)') {
      filteredProducts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortBy == 'Price: Low to High') {
      filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'Price: High to Low') {
      filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra space for floating nav
        child: Column(
          children: [
            // Header with buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage your products',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _handleSync,
                  icon: Builder(
                    builder: (context) {
                      final scheme = Theme.of(context).colorScheme;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            _hasLocalChanges ? Icons.cloud_upload : Icons.sync,
                            color: _hasLocalChanges ? scheme.error : Colors.white,
                          ),
                          if (widget.hasPendingSync || _hasLocalChanges)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _hasLocalChanges ? scheme.error : scheme.tertiary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  label: Text(
                    _hasLocalChanges
                        ? 'Publish'
                        : (widget.hasPendingSync ? 'Sync!' : 'Sync'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasLocalChanges
                        ? Colors.white.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                if (ref.read(appUserProvider).valueOrNull?.isAdmin == true || ref.read(appUserProvider).valueOrNull?.canAddInventory == true)
                  ElevatedButton.icon(
                    onPressed: _openAddForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71).withOpacity(0.4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        tooltip: 'Clear Search',
                      ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                      onPressed: _openBarcodeScanner,
                      tooltip: 'Scan Barcode',
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
            const SizedBox(height: 12),


            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  final category = index == 0 ? 'All' : categories[index - 1];
                  final isSelected = _filterCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _filterCategory = category),
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
            // Sorting Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: DropdownButtonFormField<String>(
                dropdownColor: Colors.blueGrey[900],
                style: const TextStyle(color: Colors.white),
                value: _sortBy,
                decoration: InputDecoration(
                  labelText: 'Sort By',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: ['Name (A-Z)', 'Price: Low to High', 'Price: High to Low']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _sortBy = v);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Products List (Item Bars)
            if (filteredProducts.isNotEmpty && !_hasLocalChanges && widget.hasPendingSync) ...[
               Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  color: Colors.orange,
                  padding: const EdgeInsets.all(12),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orangeAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: Your inventory is currently local. Publish it to allow other devices to sync.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            filteredProducts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text('No products found', style: TextStyle(color: Colors.white70)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: GlassContainer(
                          borderRadius: 16,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showProductOptions(product),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${product.category} • ${product.unit}',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '₹${product.price}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
    );
  }

}
