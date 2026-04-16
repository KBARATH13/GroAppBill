import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/index.dart';
import '../services/auth_service.dart';
import 'auth_providers.dart';

// Bill History Stream Provider - fetches bills for the current shop (last 3 days)
final billHistoryStreamProvider = StreamProvider<Map<String, List<BillingHistoryRecord>>>((ref) {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  if (appUser == null) return Stream.value({});

  // Since we want to display bills from all devices, we stream from Firestore.
  return AuthService.billsStream(appUser.adminEmail).map((bills) {
    // 1. Get the rolling window keys (today, yesterday, day before)
    final now = DateTime.now();
    final window = List.generate(3, (i) {
      final d = now.subtract(Duration(days: i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }).toSet();

    // 2. Filter bills to only include those in our 3-day window
    final filtered = bills.where((b) => window.contains(b.date)).toList();

    // 3. Group by date and sort each group by time (descending)
    final grouped = <String, List<BillingHistoryRecord>>{};
    for (final bill in filtered) {
      grouped.putIfAbsent(bill.date, () => []).add(bill);
    }

    // Sort each group: latest first
    // We must parse the 12-hour time (e.g., "10:30 PM") to sort correctly.
    final timeFormat = DateFormat('hh:mm a');
    grouped.forEach((date, list) {
      list.sort((a, b) {
        try {
          final tA = timeFormat.parse(a.time);
          final tB = timeFormat.parse(b.time);
          return tB.compareTo(tA);
        } catch (_) {
          return b.time.compareTo(a.time); // Fallback
        }
      });
    });

    return grouped;
  });
});
