import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill.dart';

class PrinterService {
  static const String defaultPrinterHost = '192.168.1.8';
  static const int defaultPrinterPort = 9100;
  static const int defaultTimeout = 5000;

  // Helper to get configuration
  static Future<Map<String, dynamic>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'printerHost': prefs.getString('printer_host') ?? defaultPrinterHost,
      'printerPort': prefs.getInt('printer_port') ?? defaultPrinterPort,
      'timeout': prefs.getInt('timeout') ?? defaultTimeout,
    };
  }

  // Helper to save configuration
  static Future<void> saveConfig({
    String? printerHost,
    int? printerPort,
    int? timeout,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (printerHost != null) await prefs.setString('printer_host', printerHost);
    if (printerPort != null) await prefs.setInt('printer_port', printerPort);
    if (timeout != null) await prefs.setInt('timeout', timeout);
  }

  // Test printer connection directly
  static Future<Map<String, dynamic>> testPrinterConnection() async {
    try {
      final config = await getConfig();
      final printerHost = config['printerHost'];
      final printerPort = config['printerPort'];
      final timeout = config['timeout'];

      final socket = await Socket.connect(
        printerHost,
        printerPort,
        timeout: Duration(milliseconds: timeout),
      );
      await socket.close();

      return {
        'success': true,
        'message':
            '✓ Successfully connected to printer at $printerHost:$printerPort\nReady to print!',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            '✗ Could not connect to printer.\n\nPossible reasons:\n1. Incorrect IP Address or Port.\n2. Printer is not turned ON.\n3. Phone is not on the SAME Wi-Fi as the printer.',
      };
    }
  }

  /// Scans the local WiFi subnet for devices with port 9100 open.
  static Future<List<String>> discoverPrinters({
    void Function(int scanned, int total)? onProgress,
  }) async {
    final found = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      String? subnet;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!ip.startsWith('169.') && !ip.startsWith('127.')) {
            final parts = ip.split('.');
            subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            break;
          }
        }
        if (subnet != null) break;
      }

      if (subnet == null) return [];

      const total = 254;
      int scanned = 0;
      final batchSize = 30;
      for (int start = 1; start <= total; start += batchSize) {
        final end = (start + batchSize - 1).clamp(1, total);
        final batch = <Future<void>>[];
        for (int i = start; i <= end; i++) {
          final ip = '$subnet.$i';
          batch.add(
            Socket.connect(ip, 9100, timeout: const Duration(milliseconds: 400))
                .then((socket) {
                  socket.destroy();
                  found.add(ip);
                })
                .catchError((_) {})
                .whenComplete(() {
                  scanned++;
                  onProgress?.call(scanned, total);
                }),
          );
        }
        await Future.wait(batch);
      }
    } catch (_) {}
    return found;
  }

  // Send bill to thermal printer via backend
  static Future<Map<String, dynamic>> sendBillToPrinter(Bill bill) async {
    try {
      final escposData = formatBillAsESCPOS(bill);
      final success = await sendDirectToPrinter(escposData);
      if (success) {
        return {'success': true, 'message': '✓ Bill sent to thermal printer!'};
      } else {
        return {
          'success': false,
          'message': '✗ Error: Could not connect to printer.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': '✗ Error: ${e.toString()}'};
    }
  }

  // Direct printer connection
  static Future<bool> sendDirectToPrinter(List<int> data) async {
    try {
      final config = await getConfig();
      final printerHost = config['printerHost'];
      final printerPort = config['printerPort'];
      final timeout = config['timeout'];

      final socket = await Socket.connect(
        printerHost,
        printerPort,
        timeout: Duration(milliseconds: timeout),
      );
      socket.add(data);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 1500));
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Format bill as ESC/POS commands
  static List<int> formatBillAsESCPOS(Bill bill) {
    final bytes = <int>[];
    const ESC = 0x1B;
    const GS = 0x1D;
    const LF = 0x0A;
    const CR = 0x0D;

    // === PRINTER INITIALIZATION ===
    bytes.addAll([ESC, 0x40]); 
    // Two empty lines at the top
    bytes.addAll([LF, LF]); 

    // === HEADER SECTION ===
    bytes.addAll([ESC, 0x61, 0x01]); // Center alignment
    bytes.addAll([ESC, 0x45, 0x01]); // Bold ON
    bytes.addAll(_stringToBytes(bill.shopName ?? ''));
    bytes.addAll([CR, LF]);
    if (bill.shopAddress != null && bill.shopAddress!.isNotEmpty) {
      final addressLines = bill.shopAddress!.split('\n');
      for (var line in addressLines) {
        if (line.trim().isNotEmpty) {
          bytes.addAll(_stringToBytes(line.trim()));
          bytes.addAll([CR, LF]);
        }
      }
    }
    bytes.addAll([ESC, 0x45, 0x00]); // Bold OFF

    if (bill.shopPhone != null && bill.shopPhone!.isNotEmpty) {
      bytes.addAll(_stringToBytes('PHONE: ${bill.shopPhone}'));
      bytes.addAll([CR, LF, LF]);
    } else {
      bytes.addAll([LF]);
    }

    bytes.addAll([ESC, 0x61, 0x00]); // Left alignment
    bytes.addAll(_stringToBytes('Bill No: ${bill.billNumber}'));
    bytes.addAll([CR, LF]);
    bytes.addAll(_stringToBytes('Date: ${bill.date}  Time: ${bill.time}'));
    bytes.addAll([CR, LF]);
    bytes.addAll(_stringToBytes('Operator: ${bill.operatorName}'));
    bytes.addAll([CR, LF]);
    bytes.addAll(_stringToBytes('Type: ${bill.customerType}'));
    bytes.addAll([CR, LF]);

    if (bill.apartmentName != null) {
      bytes.addAll(_stringToBytes('Apt: ${bill.apartmentName}'));
      bytes.addAll([CR, LF]);
      if (bill.blockAndDoor != null && bill.blockAndDoor!.isNotEmpty) {
        bytes.addAll(_stringToBytes('Door: ${bill.blockAndDoor}'));
        bytes.addAll([CR, LF]);
      }
    }

    // === ITEMS SECTION ===
    bytes.addAll(_stringToBytes('------------------------------------------------'));
    bytes.addAll([CR, LF]);
    bytes.addAll(_stringToBytes('Item             Price        Qty     Total'));
    bytes.addAll([CR, LF]);
    bytes.addAll(_stringToBytes('------------------------------------------------'));
    bytes.addAll([CR, LF]);

    for (var item in bill.cartItems) {
      final itemLine = _formatItemLine(
        item.product.name,
        item.product.price,
        item.quantity,
        item.product.unit,
        item.total,
      );
      bytes.addAll(_stringToBytes(itemLine));
      bytes.addAll([CR, LF]);
    }

    // === TOTALS SECTION ===
    bytes.addAll(_stringToBytes('------------------------------------------------'));
    bytes.addAll([CR, LF]);
    bytes.addAll([ESC, 0x61, 0x02]); // Right alignment
    bytes.addAll(_stringToBytes('Total Items: ${bill.cartItems.length}'));
    bytes.addAll([CR, LF, LF]);

    bytes.addAll([ESC, 0x61, 0x02]); // Right alignment
    bytes.addAll([GS, 0x21, 0x01]); // Select double height size
    bytes.addAll([ESC, 0x45, 0x01]); // Bold ON
    bytes.addAll(_stringToBytes('Grand Total: Rs.${bill.grandTotal.toStringAsFixed(2)}'));
    bytes.addAll([ESC, 0x45, 0x00]); // Bold OFF
    bytes.addAll([GS, 0x21, 0x00]); // Reset character size to normal
    bytes.addAll([CR, LF]);

    bytes.addAll([ESC, 0x61, 0x00]); // Left alignment
    bytes.addAll(_stringToBytes('Payment : ${bill.paymentMode}'));
    bytes.addAll([CR, LF]);
    if (bill.paymentMode == 'Mix-Payment') {
      bytes.addAll(_stringToBytes('  Cash  : Rs.${bill.cashAmount.toStringAsFixed(2)}'));
      bytes.addAll([CR, LF]);
      bytes.addAll(_stringToBytes('  UPI   : Rs.${bill.upiAmount.toStringAsFixed(2)}'));
      bytes.addAll([CR, LF]);
    }
    bytes.addAll([LF]);

    // === FOOTER ===
    bytes.addAll([ESC, 0x61, 0x01]); // Center alignment
    bytes.addAll(_stringToBytes(bill.billGreeting ?? 'Thank You! Please visit again'));
    bytes.addAll([CR, LF]);
    if (bill.billExtraInfo != null && bill.billExtraInfo!.isNotEmpty) {
      bytes.addAll(_stringToBytes(bill.billExtraInfo!));
      bytes.addAll([CR, LF]);
    }
    bytes.addAll(_stringToBytes('================================================'));
    // Three empty lines at the bottom before cut
    bytes.addAll([LF, LF, LF, LF]); 

    // === CUT ===
    bytes.addAll([GS, 0x56, 0x42, 0x00]); // Full cut
    return bytes;
  }

  static List<int> _stringToBytes(String text) {
    return utf8.encode(text);
  }

  static String _formatItemLine(String name, double price, double quantity, String unit, double total) {
    final nameStr = name.length > 19 ? name.substring(0, 19) : name;
    final priceStr = 'Rs.${price.toStringAsFixed(2)}';
    String qtyFormatted = (quantity == quantity.toInt()) ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
    final qtyStr = '$qtyFormatted$unit';
    final totalStr = 'Rs.${total.toStringAsFixed(2)}';
    return nameStr.padRight(17) + priceStr.padRight(13) + qtyStr.padRight(8) + totalStr.padRight(5);
  }
}
