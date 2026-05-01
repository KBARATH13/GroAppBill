import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/shop_info.dart';

class BillPreviewDialog extends StatelessWidget {
  final List<CartItem> cart;
  final double grandTotal;
  final String operatorName;
  final ShopInfo shopInfo;
  final VoidCallback onPrint;

  const BillPreviewDialog({
    super.key,
    required this.cart,
    required this.grandTotal,
    required this.operatorName,
    required this.shopInfo,
    required this.onPrint,
  });

  String _formatItemLine(String name, double price, double quantity, String unit, double total) {
    // Columns: Name(17) Price(13) Qty(8) Total(5) = 43 characters — matches printer
    final nameStr = name.length > 16 ? name.substring(0, 16) : name;
    final priceStr = 'Rs.${price.toStringAsFixed(2)}';

    String qtyFormatted;
    if (quantity == quantity.toInt()) {
      qtyFormatted = quantity.toInt().toString();
    } else {
      qtyFormatted = quantity.toStringAsFixed(2);
      if (qtyFormatted.endsWith('0')) {
        qtyFormatted = qtyFormatted.substring(0, qtyFormatted.length - 1);
      }
    }
    final qtyStr = '$qtyFormatted$unit';
    final totalStr = 'Rs.${total.toStringAsFixed(2)}';

    return nameStr.padRight(17) +
        priceStr.padRight(13) +
        qtyStr.padRight(8) +
        totalStr.padRight(5);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Center(
        child: Text(
          'Bill Preview',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                shopInfo.shopName.isEmpty ? 'My Shop' : shopInfo.shopName,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              if (shopInfo.address.isNotEmpty)
                ...shopInfo.address.split('\n').map((line) => Text(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                )),
              if (shopInfo.phone.isNotEmpty)
                Text('PH: ${shopInfo.phone}', style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              const Text('----------------------------------------', style: TextStyle(fontFamily: 'monospace')),
              
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bill #: PREVIEW', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    Text('Date  : ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}  Time: ${DateTime.now().hour}:${DateTime.now().minute}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    Text('Operator    : $operatorName', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    const Text('Type        : Walk-in', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                  ],
                ),
              ),
              
              const Text('------------------------------------------------', style: TextStyle(fontFamily: 'monospace')),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Item             Price        Qty     Total', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
              const Text('------------------------------------------------', style: TextStyle(fontFamily: 'monospace')),
              
              Column(
                children: cart.map((item) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatItemLine(
                        item.product.name,
                        item.product.price,
                        item.quantity,
                        item.product.unit,
                        item.total,
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
              
              const Text('------------------------------------------------', style: TextStyle(fontFamily: 'monospace')),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total Items: ${cart.length}',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Grand Total: Rs.${grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'monospace', 
                    fontWeight: FontWeight.bold, 
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Payment : Cash', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
              const SizedBox(height: 10),
              Text(shopInfo.greeting, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              if (shopInfo.extraInfo.isNotEmpty)
                Text(shopInfo.extraInfo, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              const Text('========================================', style: TextStyle(fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    ),
    actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
          ),
          child: const Text('Close'),
        ),
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onPrint();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm & Print'),
            );
          },
        ),
      ],
    );
  }
}
