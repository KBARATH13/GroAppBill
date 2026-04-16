import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/billing_history.dart';
import '../models/bill.dart';
import '../models/cart_item.dart';
import '../services/history_service.dart';
import '../services/printer_service.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_container.dart';
import '../widgets/vibrant_background.dart';
import 'package:share_plus/share_plus.dart';
import 'calculator_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late List<String> _windowKeys;
  late String _selectedDateKey;
  final TextEditingController _searchController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final GlobalKey _searchBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _windowKeys = HistoryService.rollingWindowKeys();
    _selectedDateKey = _windowKeys[0]; // default → today
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _labelFor(String key) {
    final today = _windowKeys[0];
    final yesterday = _windowKeys[1];
    final parts = key.split('-');
    final display = '${parts[2]}-${parts[1]}-${parts[0]}';
    if (key == today) return 'Today  ($display)';
    if (key == yesterday) return 'Yesterday  ($display)';
    return 'Day Before Yesterday  ($display)';
  }

  bool _isWithinTimeRange(String billTimeStr) {
    if (_startTime == null && _endTime == null) return true;

    try {
      // billTimeStr format: "09:30 PM"
      final parts = billTimeStr.split(' ');
      final tParts = parts[0].split(':');
      int hour = int.parse(tParts[0]);
      int minute = int.parse(tParts[1]);
      final isPm = parts[1].toUpperCase() == 'PM';

      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      final billTime = TimeOfDay(hour: hour, minute: minute);
      final billMinutes = billTime.hour * 60 + billTime.minute;

      if (_startTime != null) {
        final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
        if (billMinutes < startMinutes) return false;
      }

      if (_endTime != null) {
        final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
        if (billMinutes > endMinutes) return false;
      }
      
      return true;
    } catch (e) {
      return true; // Fallback if parsing fails
    }
  }

  Future<void> _selectTimeRange() async {
    final start = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 0, minute: 0),
      helpText: 'Select Start Time',
    );
    if (start == null) return;

    final end = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 23, minute: 59),
      helpText: 'Select End Time',
    );
    if (end == null) return;

    setState(() {
      _startTime = start;
      _endTime = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(billHistoryStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Bill History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_startTime != null || _endTime != null)
            IconButton(
              icon: const Icon(Icons.history_toggle_off),
              tooltip: 'Clear Time Filter',
              onPressed: () => setState(() {
                _startTime = null;
                _endTime = null;
              }),
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: VibrantBackground(
        child: SafeArea(
          child: historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (history) {
              final rawBills = history[_selectedDateKey] ?? [];
              
              // Apply Filters
              final query = _searchController.text.trim();
              final filteredBills = rawBills.where((b) {
                // 1. Text Filter (Bill # or Price)
                bool matchesSearch = true;
                if (query.isNotEmpty) {
                  final bNum = b.billNumber.replaceAll(RegExp(r'[^0-9]'), '');
                  final price = b.grandTotal.toStringAsFixed(0);
                  matchesSearch = bNum.contains(query) || price.contains(query);
                }

                // 2. Time Filter
                bool matchesTime = _isWithinTimeRange(b.time);

                return matchesSearch && matchesTime;
              }).toList();

              final totalSales = filteredBills.fold<double>(0, (sum, b) => sum + b.grandTotal);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedDateKey,
                                dropdownColor: const Color(0xFF1A1A1A),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Day',
                                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: _windowKeys.map((key) {
                                  return DropdownMenuItem(
                                    value: key,
                                    child: Text(_labelFor(key).split(' ')[0]),
                                  );
                                }).toList(),
                                onChanged: (v) => v != null ? setState(() => _selectedDateKey = v) : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                key: _searchBarKey,
                                controller: _searchController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                onChanged: (value) {
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  hintText: 'Bill # / Price',
                                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                  prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_searchController.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                        ),
                                      IconButton(
                                        icon: Icon(Icons.access_time, 
                                          color: (_startTime != null || _endTime != null) ? Colors.orange : Colors.white70, 
                                          size: 18),
                                        onPressed: _selectTimeRange,
                                      ),
                                    ],
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_startTime != null && _endTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                            child: Text(
                              'Filter: ${_startTime!.format(context)} to ${_endTime!.format(context)}',
                              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _SummaryCard(
                              label: 'Count',
                              value: '${filteredBills.length}',
                              icon: Icons.receipt_long,
                              color: const Color(0xFF2ECC71),
                            ),
                            const SizedBox(width: 12),
                            _SummaryCard(
                              label: 'Total',
                              value: 'Rs.${totalSales.toStringAsFixed(0)}',
                              icon: Icons.currency_rupee,
                              color: const Color(0xFF2ECC71),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredBills.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 56, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  'No matching bills found.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            itemCount: filteredBills.length,
                            itemBuilder: (context, i) {
                              final bill = filteredBills[i];
                              final isCalculation = bill.customerType == 'Calculator';
                              final badgeColor = isCalculation ? Colors.purple : const Color(0xFF2ECC71);
                              final badgeBgColor = isCalculation ? Colors.purple.withOpacity(0.2) : const Color(0xFF2ECC71).withOpacity(0.2);
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: GlassContainer(
                                  color: isCalculation ? Colors.purple : Colors.transparent,
                                  borderRadius: 12,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: badgeBgColor,
                                      child: Icon(
                                        isCalculation ? Icons.calculate_outlined : Icons.receipt_long_outlined,
                                        color: badgeColor,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      isCalculation
                                          ? '📊 Calculated • ${bill.operatorName}'
                                          : '${bill.billNumber} — ${bill.operatorName}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${bill.time} · ${isCalculation ? "Calculation" : bill.customerType}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                        if (isCalculation && bill.itemsJson.isNotEmpty)
                                          Text(
                                            'Expression: ${bill.itemsJson.first['value'] ?? ""}',
                                            style: const TextStyle(fontSize: 11, color: Colors.white60),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (!isCalculation)
                                          Text(
                                            'Payment: ${bill.paymentMode}',
                                            style: const TextStyle(fontSize: 12, color: Colors.white60),
                                          ),
                                        if (!isCalculation && bill.apartmentName != null)
                                          Text(
                                            '${bill.apartmentName}, ${bill.blockAndDoor ?? ""}',
                                            style: const TextStyle(fontSize: 12, color: Colors.white60),
                                          ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Rs.${bill.grandTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (isCalculation)
                                          Text(
                                            'Calculated',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: badgeColor.withOpacity(0.7),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    onTap: () => _showBillDetail(context, bill),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showBillDetail(BuildContext context, BillingHistoryRecord bill) {
    final isCalculation = bill.customerType == 'Calculator';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (_, sc) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCalculation ? '📊 Calculation' : 'Bill ${bill.billNumber}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  '${bill.date}  ${bill.time}  · ${bill.operatorName}',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (isCalculation)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Type: Calculated Amount', style: TextStyle(fontSize: 12, color: Colors.purpleAccent)),
                        if (bill.itemsJson.isNotEmpty)
                          Text(
                            'Expression: ${bill.itemsJson.first['value'] ?? ""}',
                            style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  )
                else ...[
                  if (bill.apartmentName != null)
                    Text('Delivery: ${bill.apartmentName}, ${bill.blockAndDoor ?? ''}', style: const TextStyle(color: Colors.white60)),
                  Text('Payment: ${bill.paymentMode}', style: const TextStyle(color: Colors.white60)),
                ],
                const Divider(height: 32, color: Colors.white10),
                if (!isCalculation)
                  const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                if (isCalculation)
                  const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: sc,
                    itemCount: bill.itemsJson.length,
                    itemBuilder: (_, i) {
                      final item = bill.itemsJson[i];
                      if (isCalculation) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item['name'] as String,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            item['value'] as String,
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: Text(
                            'Rs.${(item['price'] as num?)?.toStringAsFixed(2) ?? "0.00"}',
                            style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                          ),
                        );
                      } else {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          subtitle: Text('${item['weight']} ${item['unit']} × Rs.${item['price']}', style: const TextStyle(color: Colors.white60)),
                          trailing: Text('Rs.${item['total']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        );
                      }
                    },
                  ),
                ),
                const Divider(color: Colors.white10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isCalculation ? 'Result:' : 'Grand Total:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                      Text(
                        'Rs.${bill.grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: isCalculation ? Colors.purpleAccent : const Color(0xFF2ECC71),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCalculation) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _handleReprintBill(context, bill),
                          child: Builder(
                            builder: (context) {
                              final scheme = Theme.of(context).colorScheme;
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: scheme.primary.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.print_outlined, color: scheme.primary, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'REPRINT',
                                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _handleShareBill(context, bill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share_outlined, color: Colors.greenAccent, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'SHARE',
                                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _handleEditBill(context, bill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note_outlined, color: Colors.orange, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'ADD ON',
                                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _handleEditCalculation(context, bill),
                    child: Builder(
                      builder: (context) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.edit_note_outlined, color: Colors.purpleAccent, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'EDIT EXPRESSION',
                                style: TextStyle(
                                  color: Colors.purpleAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleShareBill(BuildContext context, BillingHistoryRecord bill) {
    final buffer = StringBuffer();
    // Use asterisk for WhatsApp bolding
    buffer.writeln('*--- BILL RECEIPT ---*');
    buffer.writeln('Bill #: ${bill.billNumber}');
    buffer.writeln('Date: ${bill.date} ${bill.time}');
    buffer.writeln('Customer: ${bill.customerType}');
    if (bill.apartmentName != null && bill.apartmentName!.isNotEmpty) {
      buffer.writeln('Location: ${bill.apartmentName}, ${bill.blockAndDoor ?? ""}');
    }
    buffer.writeln('--------------------------------');
    
    for (final item in bill.itemsJson) {
      final name = item['name'];
      final weight = item['weight'];
      final unit = item['unit'];
      final price = item['price'];
      final total = item['total'];
      buffer.writeln('*$name*');
      buffer.writeln('  $weight $unit x Rs.$price = Rs.$total');
    }
    
    buffer.writeln('--------------------------------');
    buffer.writeln('*Grand Total: Rs.${bill.grandTotal}*');
    buffer.writeln('Mode: ${bill.paymentMode}');
    buffer.writeln('--------------------------------');
    buffer.writeln('Thank you for shopping with us!');
    
    Share.share(buffer.toString(), subject: 'Bill Receipt ${bill.billNumber}');
  }

  Future<void> _handleReprintBill(BuildContext context, BillingHistoryRecord billRecord) async {
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Reconstruct Bill object from BillingHistoryRecord
      final cartItems = billRecord.itemsJson.map((item) => CartItem.fromJson(item)).toList();
      
      final bill = Bill(
        billNumber: billRecord.billNumber,
        date: billRecord.date,
        time: billRecord.time,
        operatorName: billRecord.operatorName,
        customerType: billRecord.customerType,
        paymentMode: billRecord.paymentMode,
        cartItems: cartItems,
        cashAmount: billRecord.cashAmount,
        upiAmount: billRecord.upiAmount,
        apartmentName: billRecord.apartmentName,
        blockAndDoor: billRecord.blockAndDoor,
        firestoreId: billRecord.firestoreId,
      );

      // Send to printer
      final result = await PrinterService.sendBillToPrinter(bill);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill reprinted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to reprint bill'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reprinting bill: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleEditBill(BuildContext context, BillingHistoryRecord billRecord) {
    // Reconstruct Bill object
    final cartItems = billRecord.itemsJson.map((item) => CartItem.fromJson(item)).toList();
    
    final bill = Bill(
      billNumber: billRecord.billNumber,
      date: billRecord.date,
      time: billRecord.time,
      operatorName: billRecord.operatorName,
      customerType: billRecord.customerType,
      paymentMode: billRecord.paymentMode,
      cartItems: cartItems,
      cashAmount: billRecord.cashAmount,
      upiAmount: billRecord.upiAmount,
      apartmentName: billRecord.apartmentName,
      blockAndDoor: billRecord.blockAndDoor,
      firestoreId: billRecord.firestoreId,
    );

    // Load into cart and switch tab
    ref.read(cartProvider.notifier).loadBillIntoCart(bill);
    ref.read(navigationProvider.notifier).setIndex(0);
    
    // Close modal and history screen
    Navigator.pop(context); // Close detail modal
    Navigator.pop(context); // Close history list screen
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing Bill ${bill.billNumber} in Cart ${ref.read(cartProvider).activeIndex + 1}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _handleEditCalculation(BuildContext context, BillingHistoryRecord billRecord) {
    if (billRecord.itemsJson.isEmpty) return;
    
    // The expression is stored as "12+34=46" in the value field, or just "12+34"
    final rawValue = billRecord.itemsJson.first['value'] as String? ?? '';
    
    // We only want the expression part before the equals sign
    final expression = rawValue.split('=').first;
    
    Navigator.pop(context); // Close detail modal
    Navigator.pop(context); // Close history list screen
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalculatorScreen(
          initialExpression: expression,
          initialBillId: billRecord.billNumber,
          initialFirestoreId: billRecord.firestoreId,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        borderRadius: 12,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
