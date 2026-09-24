import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/billing_history.dart';
import '../models/bill.dart';
import 'auth_service.dart';

class HistoryService {
  static const _historyKey = 'billing_history';
  static const _pendingUploadKey = 'billing_pending_upload';
  static const storedBillsKey = '__stored_bills__';

  static Future<bool> _isConnected() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }

  static Future<void> saveBill(
    Bill bill, {
    required String adminEmail,
    String? replaceBillId,
    String? replaceFirestoreId,
  }) async {
    final records = await _loadAndPurge();
    final createdAtMs = DateTime.now().millisecondsSinceEpoch;
    final targetDate = replaceBillId != null ? bill.date : todayKey();
    final existingRecord = replaceBillId == null
        ? null
        : records.cast<BillingHistoryRecord?>().firstWhere(
            (record) => record?.billNumber == replaceBillId,
            orElse: () => null,
          );

    final docId =
        replaceFirestoreId ??
        '${bill.billNumber}_${bill.operatorName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${createdAtMs}';

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
      firestoreId: docId,
      originalOperator: bill.originalOperator ?? bill.operatorName,
      isEdited: replaceBillId != null,
      createdAtMs: createdAtMs,
      uploadedToCloud: false,
      isStored: existingRecord?.isStored ?? false,
    );

    if (replaceBillId != null) {
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
    await _savePendingUploadQueue();

    try {
      await syncPendingBills(adminEmail);
      AuthService.purgeOldCloudBills(adminEmail, keepDays: 2);
    } catch (e) {
      debugPrint('Cloud sync error (will retry automatically): $e');
    }
  }

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
    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final meridiem = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $meridiem';
    final createdAtMs = now.millisecondsSinceEpoch;
    final targetDate = todayKey();

    String newBillNumber =
        replaceBillId ?? 'B-${await getDailyBillCount(operatorName)}';
    final docId =
        replaceFirestoreId ??
        '${newBillNumber}_${operatorName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${createdAtMs}';

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
      firestoreId: docId,
      itemsJson: [
        {'name': 'Expression', 'value': expression, 'price': total},
      ],
      createdAtMs: createdAtMs,
      uploadedToCloud: false,
    );

    if (replaceBillId != null) {
      final index = records.indexWhere((r) => r.billNumber == replaceBillId);
      if (index >= 0) {
        final originalDate = records[index].date;
        final updatedRecord = newRecord.copyWith(
          date: originalDate,
          firestoreId: docId,
        );
        records[index] = updatedRecord;
      } else {
        records.add(newRecord);
      }
    } else {
      records.add(newRecord);
    }
    await _saveAll(records);
    await _savePendingUploadQueue();

    try {
      await syncPendingBills(adminEmail);
      AuthService.purgeOldCloudBills(adminEmail, keepDays: 2);
    } catch (e) {
      debugPrint('Cloud sync error for calculator entry: $e');
    }
  }

  static Future<List<BillingHistoryRecord>> getPendingUploadRecords() async {
    final records = await _loadAndPurge();
    final pending = records.where((r) => !r.uploadedToCloud).toList()
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return pending;
  }

  static Future<int> getPendingUploadCount() async {
    return (await getPendingUploadRecords()).length;
  }

  static Future<void> syncPendingBills(String adminEmail) async {
    if (adminEmail.trim().isEmpty || adminEmail == 'local-only') return;
    if (!await _isConnected()) return;

    final records = await _loadAndPurge();
    final pending = records
        .where(
          (r) =>
              !(r.uploadedToCloud ||
                  (r.firestoreId != null &&
                      r.firestoreId!.isNotEmpty &&
                      r.firestoreId!.startsWith('uploaded_'))),
        )
        .toList();

    if (pending.isEmpty) return;

    pending.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));

    for (final record in pending) {
      final docId = (record.firestoreId ?? '').trim().isNotEmpty
          ? record.firestoreId!
          : '${record.billNumber}_${record.operatorName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${record.createdAtMs}';

      try {
        await AuthService.saveBill(
          adminEmail,
          record.copyWith(firestoreId: docId),
          docId: docId,
        );
        final index = records.indexWhere(
          (r) =>
              r.createdAtMs == record.createdAtMs &&
              r.billNumber == record.billNumber &&
              r.time == record.time,
        );
        if (index >= 0) {
          records[index] = records[index].copyWith(
            firestoreId: docId,
            uploadedToCloud: true,
          );
        }
      } catch (e) {
        debugPrint('Upload failed for queued bill ${record.billNumber}: $e');
        break;
      }
    }

    await _saveAll(records);
    await _savePendingUploadQueue();
  }

  static Future<void> markLocalBillStored(
    BillingHistoryRecord bill,
    bool isStored,
  ) async {
    final records = await _loadAndPurge();
    final index = records.indexWhere(
      (record) =>
          record.billNumber == bill.billNumber &&
          record.createdAtMs == bill.createdAtMs,
    );
    if (index < 0) return;
    records[index] = records[index].copyWith(isStored: isStored);
    await _saveAll(records);
    await _savePendingUploadQueue();
  }

  static Future<void> deleteLocalBill(BillingHistoryRecord bill) async {
    final records = await _loadAndPurge();
    records.removeWhere(
      (record) =>
          record.billNumber == bill.billNumber &&
          record.createdAtMs == bill.createdAtMs,
    );
    await _saveAll(records);
    await _savePendingUploadQueue();
  }

  static Future<void> _savePendingUploadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final records = await _loadAndPurge();
    final queue = records
        .where((r) => !r.uploadedToCloud)
        .map(
          (r) => {
            'billNumber': r.billNumber,
            'createdAtMs': r.createdAtMs,
            'firestoreId': r.firestoreId ?? '',
          },
        )
        .toList();
    await prefs.setString(
      _pendingUploadKey,
      BillingHistoryRecord.encodeList(
        records.where((r) => !r.uploadedToCloud).toList(),
      ),
    );
    debugPrint('Queued bills pending upload: ${queue.length}');
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
  static Future<int> getDailyBillCount(String currentOperator) async {
    final records = await _loadAndPurge();
    final today = todayKey();

    int maxNumber = 0;
    for (final r in records) {
      if (r.date == today && r.billNumber.startsWith('B-')) {
        final String origOp = r.originalOperator ?? r.operatorName;
        if (origOp == currentOperator) {
          final numberStr = r.billNumber.substring(2);
          final number = int.tryParse(numberStr);
          if (number != null && number > maxNumber) {
            maxNumber = number;
          }
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
    return [dateKeyDaysAgo(0), dateKeyDaysAgo(1), dateKeyDaysAgo(2)];
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
          .where((r) => r.isStored || r.date.compareTo(cutoffKey) > 0)
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
