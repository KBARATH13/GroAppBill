import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/water_bottle_record.dart';
import '../providers/water_bottle_provider.dart';
import '../widgets/glass_container.dart';

class WaterBottleScreen extends ConsumerStatefulWidget {
  const WaterBottleScreen({super.key});

  @override
  ConsumerState<WaterBottleScreen> createState() => _WaterBottleScreenState();
}

class _WaterBottleScreenState extends ConsumerState<WaterBottleScreen> {
  late final TextEditingController _searchController;

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

  Future<void> _showRecordDialog({WaterBottleRecord? record}) async {
    final isEditing = record != null;
    final customerController = TextEditingController(text: record?.customerName ?? '');
    final addressController = TextEditingController(text: record?.address ?? '');
    final purchaseItems = record?.items.map((item) => item.copyWith()).toList() ?? [
      WaterBottlePurchaseItem(
        bottleType: BottleType.normal,
        paymentMethod: PaymentMethod.advancePaid,
        quantity: 1,
        depositAmount: BottleType.normal.defaultDeposit,
      ),
    ];
    final quantityControllers = purchaseItems
        .map((item) => TextEditingController(text: item.quantity.toString()))
        .toList();
    final depositControllers = purchaseItems
        .map((item) => TextEditingController(text: item.depositAmount.toStringAsFixed(0)))
        .toList();

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            void updateDeposit(int index) {
              final quantity = int.tryParse(quantityControllers[index].text) ?? 1;
              final item = purchaseItems[index];
              final deposit = item.paymentMethod == PaymentMethod.advancePaid
                  ? item.bottleType.defaultDeposit * quantity
                  : 0.0;
              purchaseItems[index] = item.copyWith(quantity: quantity, depositAmount: deposit);
              depositControllers[index].text = deposit.toStringAsFixed(0);
            }

            void addItemRow() {
              purchaseItems.add(
                WaterBottlePurchaseItem(
                  bottleType: BottleType.normal,
                  paymentMethod: PaymentMethod.advancePaid,
                  quantity: 1,
                  depositAmount: BottleType.normal.defaultDeposit,
                ),
              );
              quantityControllers.add(TextEditingController(text: '1'));
              depositControllers.add(TextEditingController(text: BottleType.normal.defaultDeposit.toStringAsFixed(0)));
              setStateDialog(() {});
            }

            void removeItemRow(int index) {
              if (purchaseItems.length <= 1) return;
              purchaseItems.removeAt(index);
              quantityControllers.removeAt(index);
              depositControllers.removeAt(index);
              setStateDialog(() {});
            }

            final totalDeposit = purchaseItems.fold<double>(0, (sum, item) => sum + item.depositAmount);

            return AlertDialog(
              title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: customerController,
                        decoration: const InputDecoration(labelText: 'Customer Name'),
                        validator: (value) => (value?.trim().isEmpty ?? true) ? 'Name required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        validator: (value) => (value?.trim().isEmpty ?? true) ? 'Address required' : null,
                      ),
                      const SizedBox(height: 16),
                      ...purchaseItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Column(
                          key: ValueKey('purchase-row-$index'),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<BottleType>(
                                    value: item.bottleType,
                                    decoration: const InputDecoration(labelText: 'Bottle Type'),
                                    items: BottleType.values
                                        .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      purchaseItems[index] = item.copyWith(bottleType: value);
                                      updateDeposit(index);
                                      setStateDialog(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: quantityControllers[index],
                                    decoration: const InputDecoration(labelText: 'Qty'),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) {
                                      updateDeposit(index);
                                    },
                                    validator: (value) {
                                      final qty = int.tryParse(value ?? '');
                                      if (qty == null || qty <= 0) return 'Invalid qty';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: purchaseItems.length > 1 ? () => removeItemRow(index) : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<PaymentMethod>(
                                    value: item.paymentMethod,
                                    decoration: const InputDecoration(labelText: 'Payment'),
                                    items: PaymentMethod.values
                                        .map((method) => DropdownMenuItem(value: method, child: Text(method.label)))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      purchaseItems[index] = item.copyWith(paymentMethod: value);
                                      updateDeposit(index);
                                      setStateDialog(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: depositControllers[index],
                                    decoration: const InputDecoration(labelText: 'Deposit Amount'),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      purchaseItems[index] = item.copyWith(
                                        depositAmount: double.tryParse(value) ?? item.depositAmount,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: addItemRow,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add another bottle entry'),
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Deposit', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('₹${totalDeposit.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final updatedItems = List<WaterBottlePurchaseItem>.generate(
                        purchaseItems.length,
                        (index) {
                          final item = purchaseItems[index];
                          final qty = int.tryParse(quantityControllers[index].text) ?? item.quantity;
                          final deposit = double.tryParse(depositControllers[index].text) ?? item.depositAmount;
                          return item.copyWith(quantity: qty, depositAmount: deposit);
                        },
                      );
                      final newRecord = WaterBottleRecord(
                        id: record?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        customerName: customerController.text.trim(),
                        address: addressController.text.trim(),
                        items: updatedItems,
                      );
                      if (isEditing) {
                        ref.read(waterBottleProvider.notifier).updateRecord(newRecord);
                      } else {
                        ref.read(waterBottleProvider.notifier).addRecord(newRecord);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRecordDetails(WaterBottleRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(record.customerName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Address: ${record.address}'),
              const SizedBox(height: 8),
                Text('Total Bottles: ${record.totalBottles} x 20L'),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: record.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      '${item.quantity} x ${item.bottleType.label} | ${item.paymentMethod.label} | ₹${item.depositAmount.toStringAsFixed(0)}',
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text('Total Deposit: ₹${record.totalDeposit.toStringAsFixed(0)}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showRecordDialog(record: record);
              },
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final waterState = ref.watch(waterBottleProvider);
    final filteredRecords = waterState.filteredRecords;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search by customer or address',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: ref.read(waterBottleProvider.notifier).setSearchTerm,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showRecordDialog(),
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    color: Colors.green,
                    borderRadius: 16,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredRecords.isEmpty
                  ? Center(
                      child: Text(
                        waterState.searchTerm.isNotEmpty
                            ? 'No customers found'
                            : 'No water bottle customers yet',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _showRecordDetails(record),
                            child: GlassContainer(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.customerName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    record.address,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${record.totalBottles} x 20L',
                                          style: const TextStyle(color: Colors.white70),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '₹${record.totalDeposit.toStringAsFixed(0)}',
                                        style: const TextStyle(color: Colors.greenAccent),
                                      ),
                                    ],
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
      ),
    );
  }
}
