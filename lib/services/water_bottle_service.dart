import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/water_bottle_record.dart';

class WaterBottleService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _recordsCollection(String adminEmail) {
    return _db.collection('shops').doc(adminEmail).collection('waterBottleRecords');
  }

  static Future<void> saveRecord(String adminEmail, WaterBottleRecord record) async {
    await _recordsCollection(adminEmail).doc(record.id).set(record.toJson());
  }

  static Future<void> deleteRecord(String adminEmail, String recordId) async {
    await _recordsCollection(adminEmail).doc(recordId).delete();
  }

  static Stream<List<WaterBottleRecord>> recordsStream(String adminEmail) {
    return _recordsCollection(adminEmail).snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        return WaterBottleRecord.fromJson({
          ...data,
          'id': doc.id,
        });
      }).toList();
    });
  }
}
