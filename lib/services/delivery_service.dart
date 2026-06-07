import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/delivery.dart';
import 'local_storage.dart';

class DeliveryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'delivery_alarms';

  /// Fetch deliveries from Firestore and sync with local storage.
  static Future<List<Delivery>> fetchDeliveries(String uid) async {
    final snap = await _db
        .collection(_collection)
        .where('userId', isEqualTo: uid)
        .get();

    final deliveries = snap.docs
        .map((doc) => Delivery.fromJson(doc.data()))
        .toList();

    // Cache to local storage
    await LocalStorage.saveList(uid, deliveries.map((d) => d.toJson()).toList());
    
    return deliveries;
  }

  /// Add a new delivery to Firestore and local cache.
  static Future<void> addDelivery(Delivery delivery) async {
    await _db
        .collection(_collection)
        .doc(delivery.id)
        .set(delivery.toFirestore());
  }

  /// Mark a delivery as delivered in Firestore.
  static Future<void> markDelivered(String id) async {
    await _db
        .collection(_collection)
        .doc(id)
        .update({
          'isDelivered': true,
          'deliveredAt': Timestamp.now(),
        });
  }

  /// Update payment details for a delivery.
  static Future<void> updatePayment(String id, double paidAmount, bool isPaid) async {
    await _db
        .collection(_collection)
        .doc(id)
        .update({
          'paidAmount': paidAmount,
          'isPaid': isPaid,
        });
  }

  /// Reschedule a delivery.
  static Future<void> rescheduleDelivery(String id, DateTime newTime) async {
    await _db
        .collection(_collection)
        .doc(id)
        .update({
          'alarmAt': Timestamp.fromDate(newTime),
          'isDelivered': false,
        });
  }

  /// Delete old delivered items based on payment status:
  /// - Fully paid: Purge after 2 days.
  /// - Unpaid/Partial: Purge after 31 days.
  static Future<void> purgeOldDelivered(List<Delivery> toRemove) async {
    if (toRemove.isEmpty) return;
    
    final batch = _db.batch();
    for (final d in toRemove) {
      batch.delete(_db.collection(_collection).doc(d.id));
    }
    await batch.commit();
  }
}
