import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery.dart';
import '../providers/delivery_provider.dart';
import '../providers/app_providers.dart';
import 'package:intl/intl.dart';

class DeliveryManagerScreen extends ConsumerStatefulWidget {
  const DeliveryManagerScreen({super.key});
  @override
  ConsumerState<DeliveryManagerScreen> createState() => _DeliveryManagerScreenState();
}

class _DeliveryManagerScreenState extends ConsumerState<DeliveryManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bisleriCtrl = TextEditingController();
  final _normalCtrl = TextEditingController();
  final _groceryAmountCtrl = TextEditingController();
  final _apartmentCtrl = TextEditingController();
  final _blockDoorCtrl = TextEditingController();

  @override
  void dispose() {
    _bisleriCtrl.dispose();
    _normalCtrl.dispose();
    _groceryAmountCtrl.dispose();
    _apartmentCtrl.dispose();
    _blockDoorCtrl.dispose();
    super.dispose();
  }

  void _addDelivery() async {
    debugPrint('🚀 _addDelivery called');
    try {
      final formState = _formKey.currentState;
      if (formState == null || !formState.validate()) {
        return;
      }

      final appUserAsync = ref.read(appUserProvider);
      final uid = appUserAsync.valueOrNull?.uid;
      
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User session not found. Please log in again.')),
          );
        }
        return;
      }
      
      final id = '${DateTime.now().millisecondsSinceEpoch}-$uid';
      final now = DateTime.now();

      final itemsMap = <DeliveryItemType, int>{};
      int bisleriCount = 0;
      int normalCount = 0;

      if (_bisleriCtrl.text.isNotEmpty) {
        bisleriCount = int.tryParse(_bisleriCtrl.text) ?? 0;
        if (bisleriCount > 0) itemsMap[DeliveryItemType.bisleriWater] = bisleriCount;
      }
      if (_normalCtrl.text.isNotEmpty) {
        normalCount = int.tryParse(_normalCtrl.text) ?? 0;
        if (normalCount > 0) itemsMap[DeliveryItemType.normalWater] = normalCount;
      }

      double groceryAmount = double.tryParse(_groceryAmountCtrl.text) ?? 0.0;
      double totalAmount = (bisleriCount * 110.0) + (normalCount * 40.0) + groceryAmount;

      final delivery = Delivery(
        id: id,
        userId: uid,
        apartmentName: _apartmentCtrl.text.trim().isEmpty ? null : _apartmentCtrl.text.trim(),
        blockAndDoor: _blockDoorCtrl.text.trim().isEmpty ? null : _blockDoorCtrl.text.trim(),
        items: itemsMap,
        groceryAmount: groceryAmount,
        totalAmount: totalAmount,
        paidAmount: 0.0,
        isPaid: false,
        alarmAt: now,
      );

      await ref.read(deliveryProvider.notifier).addDelivery(delivery);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery added to Manager! 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      _bisleriCtrl.clear();
      _normalCtrl.clear();
      _groceryAmountCtrl.clear();
      _apartmentCtrl.clear();
      _blockDoorCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('System Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = ref.watch(deliveryProvider).when(
          data: (list) => list,
          loading: () => const <Delivery>[],
          error: (_, __) => const <Delivery>[],
        );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Manager')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==== Form ====
            Card(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _apartmentCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Apartment Name',
                                prefixIcon: Icon(Icons.apartment),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _blockDoorCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Block & Door #',
                                prefixIcon: Icon(Icons.door_front_door),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bisleriCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Bisleri (Qty)',
                                helperText: 'RS 110 each',
                                prefixIcon: Icon(Icons.local_drink),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _normalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Normal (Qty)',
                                helperText: 'RS 40 each',
                                prefixIcon: Icon(Icons.opacity),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _groceryAmountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Groceries Amount (RS)',
                          prefixIcon: Icon(Icons.shopping_cart),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _addDelivery,
                        icon: const Icon(Icons.add_task),
                        label: const Text('Add to Delivery Manager'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ==== Financial Summary ====
            Builder(
              builder: (context) {
                double totalReceived = 0;
                double totalPending = 0;
                for (final d in deliveries) {
                  totalReceived += d.paidAmount;
                  totalPending += (d.totalAmount - d.paidAmount);
                }

                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text('Amount Received', style: TextStyle(fontSize: 12, color: Colors.green)),
                            const SizedBox(height: 4),
                            Text(
                              'RS ${totalReceived.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text('Pending Amount', style: TextStyle(fontSize: 12, color: Colors.orange)),
                            const SizedBox(height: 4),
                            Text(
                              'RS ${totalPending.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            const Text('Active Deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...deliveries.where((d) => !d.isDelivered).map((d) {
              final formatted = DateFormat('dd‑MM HH:mm').format(d.alarmAt);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: d.isPaid ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    child: Icon(
                      d.isPaid ? Icons.check_circle : Icons.pending_actions,
                      color: d.isPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text('${d.apartmentName ?? "N/A"} - ${d.blockAndDoor ?? "N/A"}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_describeDelivery(d)),
                      Text(
                        'Total: RS ${d.totalAmount.toStringAsFixed(0)} • Paid: RS ${d.paidAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (!d.isPaid)
                        Text(
                          'Balance: RS ${(d.totalAmount - d.paidAmount).toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: Text(formatted, style: const TextStyle(fontSize: 12)),
                  onTap: () => _showPaymentActionSheet(d),
                ),
              );
            }),

            const SizedBox(height: 24),

            const Text('Completed Deliveries (Today)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...deliveries.where((d) {
              if (!d.isDelivered || d.deliveredAt == null) return false;
              final dAt = DateTime(d.deliveredAt!.year, d.deliveredAt!.month, d.deliveredAt!.day);
              return dAt.isAtSameMomentAs(today);
            }).map((d) {
              final deliveryDate = d.deliveredAt;
              final delivered = deliveryDate != null ? DateFormat('HH:mm').format(deliveryDate) : '—';
              return ListTile(
                leading: const Icon(Icons.done_all, color: Colors.blue),
                title: Text('${d.apartmentName ?? "N/A"} - ${d.blockAndDoor ?? "N/A"}'),
                subtitle: Text('Delivered at $delivered • RS ${d.totalAmount.toStringAsFixed(0)}'),
                trailing: Icon(
                  d.isPaid ? Icons.verified : Icons.warning_amber_rounded,
                  color: d.isPaid ? Colors.green : Colors.orange,
                  size: 16,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _describeDelivery(Delivery d) {
    final parts = <String>[];
    d.items.forEach((type, qty) {
      final name = type == DeliveryItemType.bisleriWater ? 'Bisleri' : 'Normal';
      parts.add('$qty × $name');
    });
    if (d.groceryAmount > 0) {
      parts.add('Groceries: RS ${d.groceryAmount.toStringAsFixed(0)}');
    }
    return parts.isEmpty ? 'No items' : parts.join(' • ');
  }

  void _showPaymentActionSheet(Delivery d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Payment Management',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Amount: RS ${d.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const Divider(height: 32),
              
              // Action Buttons
              ListTile(
                leading: const Icon(Icons.payments, color: Colors.green),
                title: const Text('Mark as Fully Paid'),
                subtitle: Text('Record payment of RS ${d.totalAmount.toStringAsFixed(0)}'),
                onTap: () async {
                  await ref.read(deliveryProvider.notifier).updatePayment(d.id, d.totalAmount);
                  if (mounted) {
                    Navigator.pop(context);
                    _promptDeliveryStatus(d.id);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.blue),
                title: const Text('Amount Paid'),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomPaymentDialog(d);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showCustomPaymentDialog(Delivery d) {
    final ctrl = TextEditingController(text: d.paidAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount Paid'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter Paid Amount (RS)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                await ref.read(deliveryProvider.notifier).updatePayment(d.id, val);
                if (mounted) {
                  Navigator.pop(context);
                  _promptDeliveryStatus(d.id);
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _promptDeliveryStatus(String deliveryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Status'),
        content: const Text('Was this item delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NOT YET'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(deliveryProvider.notifier).markDelivered(deliveryId);
              Navigator.pop(context);
            },
            child: const Text('YES, DELIVERED'),
          ),
        ],
      ),
    );
  }
}
