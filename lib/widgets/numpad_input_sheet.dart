import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'glass_container.dart';

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
      barrierDismissible: false,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: scheme.primary, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Unit Price',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Changing price for ${widget.productName} in this cart only.',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _priceController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Text('₹', style: TextStyle(color: Colors.white70, fontSize: 28)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final newPrice = double.tryParse(_priceController.text);
                          if (newPrice != null && newPrice > 0) {
                            setState(() {
                              _price = newPrice.toStringAsFixed(2);
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('✓ Unit price updated'),
                                  backgroundColor: scheme.secondary,
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Update',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: row.map((key) {
                    final isClear = key == 'C';
                    final isDecimal = key == '.';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _NumpadButton(
                          label: key,
                          color: isClear
                              ? Colors.redAccent
                              : (isDecimal ? Colors.amber : Colors.white),
                          onTap: () => _tap(key),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),

            // Backspace + Done row
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _NumpadButton(
                      icon: Icons.backspace_outlined,
                      color: Colors.orangeAccent,
                      onTap: () => _tap('⌫'),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _NumpadButton(
                      label: 'DONE',
                      color: Colors.greenAccent,
                      isPrimary: true,
                      onTap: _done,
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

class _NumpadButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _NumpadButton({
    this.label,
    this.icon,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_NumpadButton> createState() => _NumpadButtonState();
}

class _NumpadButtonState extends State<_NumpadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        widget.onTap();
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 60),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: widget.isPrimary 
                ? (widget.color.withOpacity(_isPressed ? 0.9 : 0.8))
                : widget.color.withOpacity(_isPressed ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withOpacity(_isPressed ? 0.4 : 0.2),
              width: _isPressed ? 2.5 : 1.5,
            ),
            boxShadow: widget.isPrimary && !_isPressed ? [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, color: widget.color, size: 28)
                : Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: widget.label == 'DONE' ? 18 : 28,
                      fontWeight: FontWeight.bold,
                      color: widget.isPrimary ? Colors.black : widget.color,
                      letterSpacing: widget.label == 'DONE' ? 1.5 : 0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
