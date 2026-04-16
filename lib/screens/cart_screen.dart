import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/index.dart';
import '../providers/app_providers.dart';
import '../providers/billing_controller.dart';
import '../widgets/bill_preview_dialog.dart';
import '../widgets/numpad_input_sheet.dart';
import '../widgets/glass_container.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isPrinting = false;
  String _printerMessage = '';

  // ─── Bill Preview ───────────────────────────────────────────────────────────

  void _showViewBillDialog(
    List<CartItem> cart,
    double grandTotal,
    String operatorName,
    ShopInfo shopInfo,
  ) {
    showDialog(
      context: context,
      builder: (_) => BillPreviewDialog(
        cart: cart,
        grandTotal: grandTotal,
        operatorName: operatorName,
        shopInfo: shopInfo,
        onPrint: () => _handlePrint(),
      ),
    );
  }

  // ─── Edit weight / quantity ──────────────────────────────────────────────────

  Future<void> _showEditWeightDialog(
    CartItem item,
    int index,
    CartNotifier cartNotifier,
    bool isAdmin,
  ) async {
    final result = await showNumpadInputSheet(
      context,
      productName: item.product.name,
      unit: item.product.unit,
      price: item.product.price.toStringAsFixed(2),
      productId: item.product.id,
      initialValue: item.quantity.toString(),
      isAdmin: isAdmin,
    );

    if (result != null) {
      final qtyStr = result['quantity'];
      final priceStr = result['price'];
      final qty = double.tryParse(qtyStr ?? '');
      
      if (qty != null && qty > 0) {
        final newPrice = double.tryParse(priceStr ?? '');
        Product? newProduct;
        
        if (newPrice != null && newPrice != item.product.price) {
          newProduct = item.product.copyWith(price: newPrice);
        }
        
        cartNotifier.updateItemQuantity(index, qty, newProduct: newProduct);
      }
    }
  }

  // ─── Payment Dialog ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _showPaymentDialog(
    double grandTotal, {
    bool isPrint = false,
  }) async {
    String paymentMode = 'Cash';
    final cashCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    final cashReceivedCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final received = double.tryParse(cashReceivedCtrl.text) ?? 0;
          final change = received - grandTotal;
          final scheme = Theme.of(ctx).colorScheme;

          return AlertDialog(
            title: const Text('Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grand Total display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: scheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scheme.secondary.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Grand Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          'Rs.${grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: scheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment mode dropdown
                  DropdownButtonFormField<String>(
                    value: paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Cash', 'UPI', 'Mix-Payment']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      paymentMode = v!;
                      cashReceivedCtrl.clear();
                    }),
                  ),

                  // Cash fields
                  if (paymentMode == 'Cash') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: cashReceivedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cash Received (Rs.)',
                        prefixIcon: Icon(Icons.payments_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (cashReceivedCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: change >= 0 ? Colors.blue[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: change >= 0
                                ? Colors.blue.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              change >= 0 ? 'Change to Return:' : 'Amount Short:',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Rs.${change.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: change >= 0 ? Colors.blue[700] : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // Mix-Payment fields
                  if (paymentMode == 'Mix-Payment') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: cashCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cash Amount (Rs.)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: upiCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'UPI Amount (Rs.)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              Builder(
                builder: (btnCtx) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      double cash = 0;
                      double upi = 0;
                      if (paymentMode == 'Mix-Payment') {
                        cash = double.tryParse(cashCtrl.text) ?? 0;
                        upi = double.tryParse(upiCtrl.text) ?? 0;
                      } else if (paymentMode == 'Cash') {
                        cash = grandTotal;
                      } else {
                        upi = grandTotal;
                      }
                      Navigator.pop(btnCtx, {
                        'paymentMode': paymentMode,
                        'cashAmount': cash,
                        'upiAmount': upi,
                      });
                    },
                    child: Text(isPrint ? 'Confirm & Print' : 'Confirm & Save'),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Handle Save Bill ────────────────────────────────────────────────────────

  Future<void> _handleSaveBill() async {
    final cartState = ref.read(cartProvider);
    final cart = cartState.activeCart;
    if (cart.isEmpty) return;

    final subtotal = cart.fold<double>(0, (sum, item) => sum + item.total);
    final paymentDetails = await _showPaymentDialog(subtotal);
    if (paymentDetails == null) return;

    setState(() => _printerMessage = 'Saving bill...');

    final billingController = ref.read(billingControllerProvider);
    final result = await billingController.checkout(
      paymentDetails: paymentDetails,
      isPrint: false,
    );

    if (result['success'] == true) {
      if (mounted) {
        setState(() => _printerMessage = '✓ Bill saved!');
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill saved to history')),
        );
      }
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _printerMessage = '');
    } else {
      if (mounted) {
        setState(() => _printerMessage = '✗ Error: ${result['message']}');
      }
    }
  }

  // ─── Handle Print Bill ───────────────────────────────────────────────────────

  Future<void> _handlePrint() async {
    final cartState = ref.read(cartProvider);
    final cart = cartState.activeCart;
    if (cart.isEmpty) return;

    final subtotal = cart.fold<double>(0, (sum, item) => sum + item.total);
    final paymentDetails = await _showPaymentDialog(subtotal, isPrint: true);
    if (paymentDetails == null) return;

    setState(() {
      _isPrinting = true;
      _printerMessage = 'Sending...';
    });

    final billingController = ref.read(billingControllerProvider);
    final result = await billingController.checkout(
      paymentDetails: paymentDetails,
      isPrint: true,
    );

    if (result['success'] == true) {
      if (mounted) {
        setState(() => _printerMessage = '✓ Bill printed!');
        if (Navigator.canPop(context)) Navigator.pop(context);
        
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          setState(() {
            _printerMessage = '';
            _isPrinting = false;
          });
          _offerShareReceipt(result['bill'] as Bill);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _printerMessage = '⚠ ${result['message'] ?? 'Print failed'}';
          _isPrinting = false;
        });
      }
    }
  }

  // ─── Share Receipt ───────────────────────────────────────────────────────────

  void _offerShareReceipt(Bill bill) {
    final sb = StringBuffer();
    sb.writeln('🛒 BILLING RECEIPT');
    sb.writeln('─────────────────────────');
    sb.writeln('Bill #  : ${bill.billNumber}');
    sb.writeln('Date    : ${bill.date}   ${bill.time}');
    sb.writeln('Total   : ₹${bill.grandTotal.toStringAsFixed(2)}');
    sb.writeln('─────────────────────────');
    sb.writeln('Thank You!');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Receipt'),
        content: const Text('Share this bill via WhatsApp?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Share.share(sb.toString());
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final products = ref.watch(productsProvider);
    
    // Sync prices in real-time for display
    final cart = cartState.activeCart.map((item) {
      if (item.isPriceOverridden) return item;
      final latestProduct = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => item.product,
      );
      if (latestProduct.price != item.product.price) {
        return CartItem(product: latestProduct, quantity: item.quantity);
      }
      return item;
    }).toList();

    final cartNotifier = ref.read(cartProvider.notifier);
    final operatorName = ref.watch(userProvider) ?? 'NA';
    final isAdmin = ref.watch(appUserProvider).valueOrNull?.isAdmin ?? false;

    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: GlassContainer(
        borderRadius: 32,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (cart.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${cart.length} items',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (cart.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined,
                              color: Colors.white70),
                          tooltip: 'Clear Cart',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: Colors.blueGrey[900],
                                title: const Text('Clear Cart?',
                                    style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  'Do you want to remove all items?',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      cartNotifier.clearCart();
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Clear',
                                        style:
                                            TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: cart.isEmpty
                            ? null
                            : () => _showViewBillDialog(
                                  cart,
                                  cartNotifier.grandTotal,
                                  operatorName,
                                  ref.read(shopInfoProvider),
                                ),
                        child: GlassContainer(
                          color: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          borderRadius: 12,
                          child: const Row(
                            children: [
                              Icon(Icons.receipt_long,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Receipt',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Cart Items ──
            Expanded(
              child: cart.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text('Your cart is empty',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GlassContainer(
                            borderRadius: 16,
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: Colors.white70),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${item.product.price.toStringAsFixed(2)} per ${item.product.unit}',
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${item.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (item.product.unit == 'pc')
                                          Row(
                                            children: [
                                              _IconButton(
                                                icon: Icons.remove,
                                                onTap: () => cartNotifier
                                                    .updateItemQuantity(
                                                        index,
                                                        item.quantity - 1),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                item.quantity
                                                    .toStringAsFixed(0),
                                                style: const TextStyle(
                                                  color: Colors.orangeAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              _IconButton(
                                                icon: Icons.add,
                                                onTap: () => cartNotifier
                                                    .updateItemQuantity(
                                                        index,
                                                        item.quantity + 1),
                                              ),
                                            ],
                                          )
                                        else
                                          GestureDetector(
                                            onTap: () =>
                                                _showEditWeightDialog(
                                              item,
                                              index,
                                              cartNotifier,
                                              isAdmin,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.blue
                                                        .withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                '${item.quantity.toStringAsFixed(3)} ${item.product.unit}',
                                                style: const TextStyle(
                                                  color: Colors.orangeAccent,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        _IconButton(
                                          icon: Icons.delete_outline,
                                          color:
                                              Colors.redAccent.withOpacity(0.2),
                                          iconColor: Colors.redAccent,
                                          onTap: () {
                                            cartNotifier.removeItem(index);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content:
                                                      Text('Item removed')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── Footer / Action Buttons ──
            GlassContainer(
              borderRadius: 0,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                children: [
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)),
                      Text(
                        '₹${cart.fold<double>(0, (sum, item) => sum + item.total).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save Bill / Print Bill buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isPrinting || cart.isEmpty
                              ? null
                              : _handleSaveBill,
                          child: GlassContainer(
                            color: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            borderRadius: 16,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'SAVE BILL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final scheme = Theme.of(context).colorScheme;
                            return GestureDetector(
                              onTap: _isPrinting || cart.isEmpty
                                  ? null
                                  : _handlePrint,
                              child: GlassContainer(
                                color: scheme.secondary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                borderRadius: 16,
                                child: Center(
                                  child: _isPrinting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.print_outlined,
                                                color: Colors.white, size: 18),
                                            SizedBox(width: 4),
                                            Text(
                                              'PRINT BILL',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: 16,
                      child: const Center(
                        child: Text('Close',
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                  // Printer status message
                  if (_printerMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Builder(
                        builder: (context) {
                          final scheme = Theme.of(context).colorScheme;
                          final isSuccess = _printerMessage.contains('✓');
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isSuccess
                                  ? scheme.secondary.withOpacity(0.1)
                                  : scheme.tertiary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSuccess
                                    ? scheme.secondary.withOpacity(0.3)
                                    : scheme.tertiary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color: isSuccess
                                      ? scheme.secondary
                                      : scheme.tertiary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _printerMessage,
                                    style: TextStyle(
                                      color: isSuccess
                                          ? scheme.secondary
                                          : scheme.tertiary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small icon button ────────────────────────────────────────────────────────

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color ?? Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? Colors.white70, size: 20),
      ),
    );
  }
}
