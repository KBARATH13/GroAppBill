import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/salesman_payment.dart';
import '../services/salesman_service.dart';
import 'auth_providers.dart';

final salesmanPaymentsProvider = StateNotifierProvider<SalesmanPaymentsNotifier, List<SalesmanPayment>>((ref) {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  final adminEmail = appUser?.adminEmail ?? '';
  final notifier = SalesmanPaymentsNotifier(adminEmail: adminEmail);
  return notifier;
});

class SalesmanPaymentsNotifier extends StateNotifier<List<SalesmanPayment>> {
  final String adminEmail;

  SalesmanPaymentsNotifier({required this.adminEmail}) : super([]) {
    _init();
  }

  Future<void> _init() async {
    // 1. Load local cache
    final local = await SalesmanService.loadLocalPayments();
    state = local;

    // 2. Perform purge of expired items (31-day creation & 7-day soft-delete limits)
    if (adminEmail.isNotEmpty) {
      await SalesmanService.purgeOldPayments(adminEmail);
      // Reload after purging
      state = await SalesmanService.loadLocalPayments();
      
      // 3. Listen to Firestore stream to keep updated
      SalesmanService.salesmanPaymentsStream(adminEmail).listen((firestorePayments) async {
        // Find if we have any updates to merge or replace
        state = firestorePayments;
        // Keep SharedPreferences updated with remote state
        final prefsPayments = await SalesmanService.loadLocalPayments();
        
        // Merge logic or simple override (Firestore is source of truth for synced accounts)
        // Check if there are local-only payments to keep (like offline adds)
        final Map<String, SalesmanPayment> merged = {
          for (var p in prefsPayments) p.id: p,
          for (var p in firestorePayments) p.id: p,
        };
        state = merged.values.toList();
      });
    }
  }

  /// Add or update a payment
  Future<void> addOrUpdatePayment(SalesmanPayment payment) async {
    await SalesmanService.savePayment(payment, adminEmail: adminEmail);
    // Refresh state from local db to ensure responsiveness
    state = await SalesmanService.loadLocalPayments();
  }

  /// Soft delete a payment. It is flagged as deleted and will be hidden from main UI.
  Future<void> softDelete(SalesmanPayment payment) async {
    final updated = payment.copyWith(
      isDeleted: true,
      deletedAt: DateTime.now().toIso8601String(),
    );
    await addOrUpdatePayment(updated);
  }
}

