import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/billing_history.dart';
import '../models/bill.dart';
import 'auth_service.dart';

class HistoryService {
  static const _historyKey = 'billing_history';

  /// Save a bill to local history and purge old entries.

  /// Save a bill to local history and purge old entries.
  static Future<void> saveBill(Bill bill, {required String adminEmail, String? replaceBillId, String? replaceFirestoreId}) async {
    final records = await _loadAndPurge();

    final targetDate = replaceBillId != null ? bill.date : todayKey();

    final newRecord = BillingHistoryRecord(
      billNumber: bill.billNumber,
      date: targetDate,
      time: bill.time,
      operatorName: bill.operatorName,
      customerType: bill.customerType,
      paymentMode: bill.paymentMode,
      grandTotal: bill.grandTotal,
      cashAmount: bill.cashAmount,
      upiAmount: bill.upiAmount,
      apartmentName: bill.apartmentName,
      blockAndDoor: bill.blockAndDoor,
      itemsJson: bill.cartItems.map((i) => i.toJson()).toList(),
      firestoreId: bill.firestoreId,
    );

    if (replaceBillId != null) {
      // Find and replace the existing record
      final index = records.indexWhere((r) => r.billNumber == replaceBillId);
      if (index >= 0) {
        records[index] = newRecord;
      } else {
        records.add(newRecord);
      }
    } else {
      records.add(newRecord);
    }
    
    await _saveAll(records);

    // Cloud Sync: Push to Firestore
    try {
      final safeName = bill.operatorName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      
      // If we have a specific firestoreId to replace, use it.
      // Otherwise, generate a new one.
      final uniqueDocId = replaceFirestoreId ?? 
          '${bill.billNumber}_${safeName}_${DateTime.now().millisecondsSinceEpoch}';
      
      await AuthService.saveBill(adminEmail, newRecord, docId: uniqueDocId);
      
      AuthService.purgeOldCloudBills(adminEmail, keepDays: 2);
    } catch (e) {
      debugPrint('Cloud sync error (will retry automatically): $e');
    }
  }

  /// Save a calculator entry to history.
  static Future<void> saveCalculatorEntry({
    required String expression,
    required double total,
    required String operatorName,
    required String adminEmail,
    required String paymentMode,
    String? replaceBillId,
    String? replaceFirestoreId,
  }) async {
    final records = await _loadAndPurge();

    // Format current time as HH:MM AM/PM
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final meridiem = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $meridiem';
    
    final targetDate = replaceBillId != null ? todayKey() : todayKey();

    String newBillNumber = replaceBillId ?? 'B-${await getDailyBillCount()}';

    final newRecord = BillingHistoryRecord(
      billNumber: newBillNumber,
      date: targetDate,
      time: timeStr,
      operatorName: operatorName,
      customerType: 'Calculator',
      paymentMode: paymentMode,
      grandTotal: total,
      cashAmount: 0,
      upiAmount: 0,
      firestoreId: replaceFirestoreId,
      itemsJson: [
        {'name': 'Expression', 'value': expression, 'price': total}
      ],
    );

    if (replaceBillId != null) {
      final index = records.indexWhere((r) => r.billNumber == replaceBillId);
      if (index >= 0) {
        // Keep original date when replacing
        final originalDate = records[index].date;
        final updatedRecord = newRecord.copyWith(date: originalDate);
        records[index] = updatedRecord;
      } else {
        records.add(newRecord);
      }
    } else {
      records.add(newRecord);
    }
    await _saveAll(records);

    // Cloud Sync
    try {
      final safeName = operatorName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final uniqueDocId = replaceFirestoreId ?? '${newRecord.billNumber}_${safeName}_${DateTime.now().millisecondsSinceEpoch}';
      
      await AuthService.saveBill(adminEmail, newRecord, docId: uniqueDocId);
      
      // Auto-purge old cloud bills
      AuthService.purgeOldCloudBills(adminEmail, keepDays: 2);
    } catch (e) {
      debugPrint('Cloud sync error for calculator entry: $e');
    }
  }

  /// Get all records (today + yesterday + day before yesterday), grouped by date string.
  static Future<Map<String, List<BillingHistoryRecord>>> getHistory() async {
    final records = await _loadAndPurge();
    final grouped = <String, List<BillingHistoryRecord>>{};
    for (final r in records) {
      grouped.putIfAbsent(r.date, () => []).add(r);
    }
    return grouped;
  }

  /// Get count and total sales for a specific date key (defaults to today).
  static Future<Map<String, dynamic>> getSummaryForDate(String dateKey) async {
    final records = await _loadAndPurge();
    final dayRecords = records.where((r) => r.date == dateKey).toList();
    final totalSales = dayRecords.fold<double>(
      0,
      (sum, r) => sum + r.grandTotal,
    );
    return {'count': dayRecords.length, 'totalSales': totalSales};
  }

  /// Full day-end report for a given date — bills, sales, cash, UPI breakdown.
  static Future<Map<String, dynamic>> getDayEndReport(String dateKey) async {
    final records = await _loadAndPurge();
    final dayRecords = records.where((r) => r.date == dateKey).toList();
    double totalSales = 0, totalCash = 0, totalUpi = 0;
    for (final r in dayRecords) {
      totalSales += r.grandTotal;
      totalCash += r.cashAmount;
      totalUpi += r.upiAmount;
    }
    return {
      'count': dayRecords.length,
      'totalSales': totalSales,
      'totalCash': totalCash,
      'totalUpi': totalUpi,
    };
  }

  /// Get count and total sales for today (convenience wrapper).
  static Future<Map<String, dynamic>> getTodaySummary() async {
    return getSummaryForDate(todayKey());
  }

  /// Returns the next bill number for today. Only counts regular bills (B-x).
  static Future<int> getDailyBillCount() async {
    final records = await _loadAndPurge();
    final today = todayKey();
    
    int maxNumber = 0;
    for (final r in records) {
      if (r.date == today && r.billNumber.startsWith('B-')) {
        final numberStr = r.billNumber.substring(2);
        final number = int.tryParse(numberStr);
        if (number != null && number > maxNumber) {
          maxNumber = number;
        }
      }
    }
    
    return maxNumber + 1;
  }

  // ===== Public helpers =====

  /// Returns today's date key in 'yyyy-MM-dd' format.
  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns the date key for a given number of days ago.
  static String dateKeyDaysAgo(int days) {
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Returns the three stored date keys: [today, yesterday, dayBeforeYesterday].
  static List<String> rollingWindowKeys() {
    return [
      dateKeyDaysAgo(0),
      dateKeyDaysAgo(1),
      dateKeyDaysAgo(2),
    ];
  }

  // ===== Private helpers =====

  /// Load all records, delete entries older than 3 days, and save back.
  static Future<List<BillingHistoryRecord>> _loadAndPurge() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];

    try {
      final all = BillingHistoryRecord.decodeList(raw);
      // Keep only today, yesterday, and day-before-yesterday
      final cutoff = DateTime.now().subtract(const Duration(days: 3));
      final cutoffKey =
          '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

      final filtered = all
          .where((r) => r.date.compareTo(cutoffKey) > 0)
          .toList();

      // Save back only if we purged anything
      if (filtered.length != all.length) {
        await _saveAll(filtered);
      }
      return filtered;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<BillingHistoryRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      BillingHistoryRecord.encodeList(records),
    );
  }
}
