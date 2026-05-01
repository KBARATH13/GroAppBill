import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/index.dart';
import '../providers/app_providers.dart';
import 'glass_container.dart';

/// A reusable dialog for adding and editing products.
/// Handles custom category entry and persistence.
class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;
  final String? initialBarcode;

  const ProductFormDialog({
    super.key,
    this.product,
    this.initialBarcode,
  });

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();

  /// A unified "Product Not Found" dialog that encourages adding the product to inventory.
  static Future<void> showProductNotFoundDialog(BuildContext context, String barcode) async {
    final scheme = Theme.of(context).colorScheme;
    
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
        content: Text('Product with barcode "$barcode" was not found in inventory. Would you like to add it now?'),
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

    if (shouldAdd == true && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ProductFormDialog(initialBarcode: barcode),
      );
    }
  }
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _barcodeController;
  late TextEditingController _customCategoryController;
  late TextEditingController _customUnitController;
  late FocusNode _customCategoryFocus;
  late FocusNode _customUnitFocus;
  
  String _selectedUnit = 'kg';
  String _selectedCategory = 'Vegetables';
  bool _isCustomCategory = false;
  bool _isCustomUnit = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.product?.barcode ?? widget.initialBarcode ?? '',
    );
    _customCategoryController = TextEditingController();
    _customUnitController = TextEditingController();
    _customCategoryFocus = FocusNode();
    _customUnitFocus = FocusNode();

    if (widget.product != null) {
      _selectedUnit = widget.product!.unit;
      _selectedCategory = widget.product!.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    _customCategoryController.dispose();
    _customUnitController.dispose();
    _customCategoryFocus.dispose();
    _customUnitFocus.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final barcode = _barcodeController.text.trim();
    
    if (name.isEmpty || priceStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and price')),
      );
      return;
    }

    final price = double.tryParse(priceStr);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    String category = _selectedCategory;
    if (_isCustomCategory) {
      final customCat = _customCategoryController.text.trim();
      if (customCat.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a custom category name')),
        );
        return;
      }
      category = customCat;
      // Add to global categories list
      ref.read(categoriesProvider.notifier).addCategory(category);
    }

    String unit = _selectedUnit;
    if (_isCustomUnit) {
      final customUnit = _customUnitController.text.trim();
      if (customUnit.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a custom unit name')),
        );
        return;
      }
      unit = customUnit;
      // Add to global units list
      ref.read(unitsProvider.notifier).addUnit(unit);
    }

    if (widget.product != null) {
      // Edit mode
      final updatedProduct = widget.product!.copyWith(
        name: name,
        price: price,
        unit: unit,
        category: category,
        barcode: barcode.isNotEmpty ? barcode : null,
      );
      ref.read(productsProvider.notifier).updateProduct(widget.product!.id, updatedProduct);
    } else {
      // Add mode
      final newProduct = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        price: price,
        unit: unit,
        category: category,
        barcode: barcode.isNotEmpty ? barcode : null,
      );
      ref.read(productsProvider.notifier).addProduct(newProduct);
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final units = ref.watch(unitsProvider);
    
    // Ensure selected category is in the list or it's custom
    if (!categories.contains(_selectedCategory) && !_isCustomCategory) {
      _selectedCategory = categories.isNotEmpty ? categories.first : 'Vegetables';
    }

    // Ensure selected unit is in the list or it's custom
    if (!units.contains(_selectedUnit) && !_isCustomUnit) {
      _selectedUnit = units.isNotEmpty ? units.first : 'kg';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product != null ? 'Edit Product' : 'Add New Product',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      maxLength: 15,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        counterStyle: const TextStyle(color: Colors.white38),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Price (₹)',
                              labelStyle: const TextStyle(color: Colors.white70),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final scheme = Theme.of(context).colorScheme;
                              return !_isCustomUnit
                                  ? DropdownButtonFormField<String>(
                                      dropdownColor: Colors.blueGrey[900],
                                      style: const TextStyle(color: Colors.white),
                                      value: _selectedUnit,
                                      onChanged: (v) {
                                        if (v == 'ADD_NEW') {
                                          setState(() => _isCustomUnit = true);
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            _customUnitFocus.requestFocus();
                                          });
                                        } else {
                                          setState(() => _selectedUnit = v!);
                                        }
                                      },
                                      items: [
                                        ...units.map((u) => DropdownMenuItem(value: u, child: Text(u))),
                                        DropdownMenuItem(
                                          value: 'ADD_NEW',
                                          child: Text('+ New...', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Unit',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.white),
                                        ),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _customUnitController,
                                            focusNode: _customUnitFocus,
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              labelText: 'Custom Unit',
                                              labelStyle: const TextStyle(color: Colors.white70),
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
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white54),
                                          onPressed: () => setState(() => _isCustomUnit = false),
                                        ),
                                      ],
                                    );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!_isCustomCategory)
                      DropdownButtonFormField<String>(
                        dropdownColor: Colors.blueGrey[900],
                        style: const TextStyle(color: Colors.white),
                        value: _selectedCategory,
                        onChanged: (v) {
                          if (v == 'ADD_NEW') {
                            setState(() => _isCustomCategory = true);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _customCategoryFocus.requestFocus();
                            });
                          } else {
                            setState(() => _selectedCategory = v!);
                          }
                        },
                        items: [
                          ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                          const DropdownMenuItem(
                            value: 'ADD_NEW',
                            child: Text('+ Other (Custom)...', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customCategoryController,
                              focusNode: _customCategoryFocus,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Custom Category',
                                labelStyle: const TextStyle(color: Colors.white70),
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
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => setState(() => _isCustomCategory = false),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _barcodeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Barcode (Optional)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _handleSave,
                  child: GlassContainer(
                    color: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    borderRadius: 12,
                    child: Text(
                      widget.product != null ? 'Update' : 'Save',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
