import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/salesman_payment.dart';
import '../providers/salesman_provider.dart';
import '../providers/auth_providers.dart';
import '../widgets/glass_container.dart';
import '../widgets/vibrant_background.dart';

class SalesmanPaymentScreen extends ConsumerStatefulWidget {
  const SalesmanPaymentScreen({super.key});

  @override
  ConsumerState<SalesmanPaymentScreen> createState() => _SalesmanPaymentScreenState();
}

class _SalesmanPaymentScreenState extends ConsumerState<SalesmanPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _moneyGivenController = TextEditingController();
  final _balanceOwedController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _companyController.dispose();
    _moneyGivenController.dispose();
    _balanceOwedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showAddPaymentDialog() {
    _companyController.clear();
    _moneyGivenController.clear();
    _balanceOwedController.clear();
    _notesController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Salesman Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _companyController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration('Company/Salesman Name', Icons.business),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter company name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _moneyGivenController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration('Money Given (Rs)', Icons.monetization_on),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter money given';
                      if (double.tryParse(val) == null) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _balanceOwedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration('Money Needed to be Given (Rs)', Icons.account_balance_wallet),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter balance owed';
                      if (double.tryParse(val) == null) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration('Notes (Optional)', Icons.notes),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => _submitForm(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add Entry'),
            ),
          ],
        );
      },
    );
  }

  void _submitForm(BuildContext dialogCtx) async {
    if (!_formKey.currentState!.validate()) return;

    final operatorName = ref.read(userProvider) ?? 'NA';
    final now = DateTime.now();

    final payment = SalesmanPayment(
      id: '${now.millisecondsSinceEpoch}-${Random().nextInt(10000)}',
      company: _companyController.text.trim(),
      amountGiven: double.parse(_moneyGivenController.text.trim()),
      balanceOwed: double.parse(_balanceOwedController.text.trim()),
      createdAt: now.toIso8601String(),
      addedBy: operatorName,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      isDeleted: false,
    );

    await ref.read(salesmanPaymentsProvider.notifier).addOrUpdatePayment(payment);
    if (mounted) {
      Navigator.pop(dialogCtx);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Salesman entry added successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  InputDecoration _dialogInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(salesmanPaymentsProvider)
        .where((p) => !p.isDeleted)
        .toList();

    // Sort by creation date descending
    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalDues = payments.fold<double>(0, (sum, item) => sum + item.balanceOwed);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Salesman Ledger', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: VibrantBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                
                // Total Dues Summary Header
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Balance Owed',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Active salesman dues',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      Text(
                        'Rs.${totalDues.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                const Text(
                  'Active Ledger Entries',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
                const SizedBox(height: 12),

                // Table / List
                Expanded(
                  child: payments.isEmpty
                      ? const Center(
                          child: Text(
                            'No salesman entries found.\nClick + to add a record.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: payments.length,
                          itemBuilder: (context, index) {
                            final item = payments[index];
                            final createdDate = DateTime.tryParse(item.createdAt) ?? DateTime.now();
                            final formattedDate = DateFormat('dd-MM-yyyy HH:mm').format(createdDate.toLocal());
                            final ageInDays = DateTime.now().difference(createdDate).inDays;
                            final isOverdueWarning = ageInDays >= 30;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Dismissible(
                                key: Key(item.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20.0),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (direction) async {
                                  await ref.read(salesmanPaymentsProvider.notifier).softDelete(item);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Entry for ${item.company} moved to Trash (retained for 7 days)'),
                                        duration: const Duration(seconds: 3),
                                        action: SnackBarAction(
                                          label: 'Undo',
                                          textColor: Colors.yellow,
                                          onPressed: () async {
                                            final restored = item.copyWith(isDeleted: false, deletedAt: null);
                                            await ref.read(salesmanPaymentsProvider.notifier).addOrUpdatePayment(restored);
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(14),
                                  border: isOverdueWarning ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1) : null,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.company,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isOverdueWarning)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.redAccent, width: 1),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 12),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '30+ Days Due',
                                                    style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Date/Time', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text(formattedDate, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Money Given', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text('Rs.${item.amountGiven.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Balance Owed', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Rs.${item.balanceOwed.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: item.balanceOwed > 0 ? Colors.orangeAccent : Colors.greenAccent,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (item.notes != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Notes: ${item.notes}',
                                          style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                                        ),
                                      ],
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
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPaymentDialog,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
