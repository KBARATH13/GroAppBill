import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'glass_container.dart';
import '../providers/app_providers.dart';

/// A full-screen-friendly bottom sheet with a large number pad for weight/quantity entry.
/// Returns the entered value as a String when "Done" is tapped, or null if cancelled.
Future<Map<String, String>?> showNumpadInputSheet(
  BuildContext context, {
  required String productName,
  required String unit,
  required String price,
  String? productId,
  String initialValue = '',
  bool isAdmin = false,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (_) => _NumpadSheet(
      productName: productName,
      unit: unit,
      price: price,
      productId: productId,
      initialValue: initialValue,
      isAdmin: isAdmin,
    ),
  );
}

class _NumpadSheet extends ConsumerStatefulWidget {
  final String productName;
  final String unit;
  final String price;
  final String? productId;
  final String initialValue;
  final bool isAdmin;

  const _NumpadSheet({
    required this.productName,
    required this.unit,
    required this.price,
    this.productId,
    required this.initialValue,
    required this.isAdmin,
  });

  @override
  ConsumerState<_NumpadSheet> createState() => _NumpadSheetState();
}

class _NumpadSheetState extends ConsumerState<_NumpadSheet> {
  late String _value;
  late String _price;
  final TextEditingController _displayController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _price = widget.price.replaceAll(RegExp(r'[^0-9.]'), '');
    _displayController.text = _value;
    _priceController.text = _price;
  }

  @override
  void dispose() {
    _displayController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _showEditPriceDialog() async {
    if (!widget.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admin users can edit product price'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _priceController.text = _price;
    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surface,
          title: Text('Edit Price', style: TextStyle(color: scheme.onSurface)),
          content: TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Enter new price',
              hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
              labelText: 'Price (₹)',
              labelStyle: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scheme.onSurface.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: scheme.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: scheme.onSurface.withOpacity(0.7))),
            ),
            TextButton(
              onPressed: () async {
                final newPrice = double.tryParse(_priceController.text);
                if (newPrice != null && newPrice > 0) {
                  // Update local state for immediate feedback in the sheet
                  setState(() {
                    _price = newPrice.toStringAsFixed(2);
                  });

                  // If we have the productId, update the actual product in the provider
                  if (widget.productId != null) {
                    // Temporarily modify for Cart, do NOT permanently modify inventory here
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Price updated successfully'),
                        backgroundColor: scheme.tertiary,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid price'),
                      backgroundColor: Color(0xFFFF6B6B),
                    ),
                  );
                }
              },
              child: Text('Update', style: TextStyle(color: scheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _tap(String key) {
    // Immediate haptic feedback
    HapticFeedback.lightImpact();
    
    String newValue = _value;
    
    if (key == '⌫') {
      if (newValue.isNotEmpty) {
        newValue = newValue.substring(0, newValue.length - 1);
      }
    } else if (key == '.') {
      if (!newValue.contains('.')) {
        newValue = newValue.isEmpty ? '0.' : newValue + '.';
      }
    } else if (key == 'C') {
      newValue = '';
    } else {
      // Prevent typing more than 3 decimal places
      if (newValue.contains('.')) {
        final parts = newValue.split('.');
        if (parts.length > 1 && parts[1].length >= 3) {
          HapticFeedback.heavyImpact();
          return; // Reject the input
        }
      }

      // Prevent leading zero (except for "0." case)
      if (newValue == '0' && key != '.') {
        newValue = key;
      } else {
        newValue += key;
      }
    }

    setState(() {
      _value = newValue;
      _displayController.text = newValue;
    });
  }

  void _done() {
    if (!mounted) return;
    
    final v = double.tryParse(_value);
    if (_value.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a quantity')),
      );
      return;
    }
    
    if (v == null || v <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity (greater than 0)')),
      );
      return;
    }
    
    HapticFeedback.heavyImpact();
    Navigator.pop(context, {
      'quantity': _value,
      'price': _price,
    });
  }

  // Display total as user types
  String get _liveTotal {
    try {
      if (_value.isEmpty) return '₹0.00';
      
      final qty = double.tryParse(_value);
      final prc = double.tryParse(_price);
      
      if (qty == null || prc == null) return '₹0.00';
      
      final total = qty * prc;
      if (total.isInfinite || total.isNaN) return '₹0.00';
      
      return '₹${total.toStringAsFixed(2)}';
    } catch (e) {
      debugPrint('Error calculating live total: $e');
      return '₹0.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['0', '.', 'C'],
    ];

    return SingleChildScrollView(
      child: GlassContainer(
        color: Colors.black,
        borderRadius: 24,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Product info header
            Text(
              widget.productName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Builder(
              builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                return GestureDetector(
                  onTap: _showEditPriceDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isAdmin ? scheme.primary.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isAdmin ? scheme.primary.withOpacity(0.3) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹$_price per ${widget.unit}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: widget.isAdmin ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (widget.isAdmin) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.edit, color: scheme.primary, size: 14),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Display area
            Builder(
              builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quantity (${widget.unit})',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                          ),
                          Text(
                            _value.isEmpty ? '0' : _value,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                          ),
                          Text(
                            _liveTotal,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: scheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Number grid
            ...keys.map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: row.map((key) {
                    final isClear = key == 'C';
                    final isDecimal = key == '.';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTapDown: (details) {
                            _tap(key);
                          },
                          child: Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: isClear
                                  ? Colors.red.withOpacity(0.1)
                                  : (isDecimal ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.06)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isClear
                                    ? Colors.red.withOpacity(0.3)
                                    : (isDecimal ? Colors.amber.withOpacity(0.3) : Colors.white.withOpacity(0.15)),
                                width: 2,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _tap(key),
                                borderRadius: BorderRadius.circular(14),
                                highlightColor: Colors.white.withOpacity(0.1),
                                splashColor: Colors.white.withOpacity(0.15),
                                child: Center(
                                  child: Text(
                                    key,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: isClear ? Colors.redAccent : (isDecimal ? Colors.amber : Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),

            // Backspace + Done row
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTapDown: (details) {
                        _tap('⌫');
                      },
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _tap('⌫'),
                            borderRadius: BorderRadius.circular(14),
                            highlightColor: Colors.orange.withOpacity(0.2),
                            splashColor: Colors.orange.withOpacity(0.25),
                            child: const Center(
                              child: Icon(Icons.backspace_outlined, size: 28, color: Colors.orangeAccent),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTapDown: (details) {
                        _done();
                      },
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _done,
                            borderRadius: BorderRadius.circular(14),
                            highlightColor: Colors.white.withOpacity(0.15),
                            splashColor: Colors.white.withOpacity(0.2),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'DONE',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
