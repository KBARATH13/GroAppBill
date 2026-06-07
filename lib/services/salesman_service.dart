import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/salesman_payment.dart';

class SalesmanService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _salesmanKey = 'grocery-salesman-payments';

  /// Save or update a salesman payment locally and in Firestore.
  static Future<void> savePayment(SalesmanPayment payment, {required String adminEmail}) async {
    // 1. Save locally
    final localPayments = await loadLocalPayments();
    final index = localPayments.indexWhere((p) => p.id == payment.id);
    if (index >= 0) {
      localPayments[index] = payment;
    } else {
      localPayments.add(payment);
    }
    await _saveLocalPayments(localPayments);

    // 2. Sync to Firestore if network is available (offline persistence handles queueing)
    if (adminEmail.isNotEmpty) {
      await _db
          .collection('shops')
          .doc(adminEmail)
          .collection('salesman_payments')
          .doc(payment.id)
          .set(payment.toJson());
    }
  }

  /// Delete a payment permanently (from Firestore).
  static Future<void> deletePaymentPermanently(String id, {required String adminEmail}) async {
    // Remove locally
    final localPayments = await loadLocalPayments();
    localPayments.removeWhere((p) => p.id == id);
    await _saveLocalPayments(localPayments);

    // Remove from Firestore
    if (adminEmail.isNotEmpty) {
      await _db
          .collection('shops')
          .doc(adminEmail)
          .collection('salesman_payments')
          .doc(id)
          .delete();
    }
  }

  /// Load payments from SharedPreferences.
  static Future<List<SalesmanPayment>> loadLocalPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_salesmanKey);
    if (raw == null) return [];
    try {
      return SalesmanPayment.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  /// Stream salesman payments from Firestore.
  static Stream<List<SalesmanPayment>> salesmanPaymentsStream(String adminEmail) {
    if (adminEmail.isEmpty) {
      return Stream.value([]);
    }
    return _db
        .collection('shops')
        .doc(adminEmail)
        .collection('salesman_payments')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SalesmanPayment.fromJson(d.data()))
            .toList());
  }

  /// Run retention and soft-delete purging rules:
  /// 1. Delete items soft-deleted (isDeleted == true) more than 7 days ago.
  /// 2. Delete items created (createdAt) more than 31 days ago.
  static Future<void> purgeOldPayments(String adminEmail) async {
    final now = DateTime.now();
    final localPayments = await loadLocalPayments();
    
    final List<SalesmanPayment> remaining = [];
    final List<String> toDeleteIds = [];

    for (final p in localPayments) {
      bool shouldDelete = false;

      // Rule 1: Soft-deleted more than 7 days ago
      if (p.isDeleted && p.deletedAt != null) {
        final delDate = DateTime.tryParse(p.deletedAt!);
        if (delDate != null && now.difference(delDate).inDays >= 7) {
          shouldDelete = true;
        }
      }

      // Rule 2: Created more than 31 days ago
      final creDate = DateTime.tryParse(p.createdAt);
      if (creDate != null && now.difference(creDate).inDays >= 31) {
        shouldDelete = true;
      }

      if (shouldDelete) {
        toDeleteIds.add(p.id);
      } else {
        remaining.add(p);
      }
    }

    if (toDeleteIds.isNotEmpty) {
      await _saveLocalPayments(remaining);
      if (adminEmail.isNotEmpty) {
        final batch = _db.batch();
        final collection = _db.collection('shops').doc(adminEmail).collection('salesman_payments');
        for (final id in toDeleteIds) {
          batch.delete(collection.doc(id));
        }
        await batch.commit();
      }
    }
  }

  /// Helper to save the list to SharedPreferences.
  static Future<void> _saveLocalPayments(List<SalesmanPayment> payments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_salesmanKey, SalesmanPayment.encodeList(payments));
  }
}
