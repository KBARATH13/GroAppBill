import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class SyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _syncTimestampKey = 'grocery-sync-timestamp';

  /// Push all products to Firestore as individual documents (admin only).
  /// This ensures that edits to different products don't overwrite each other.
  static Future<void> pushToFirestore(String adminEmail, List<Product> products) async {
    final batch = _db.batch();
    final collection = _db.collection('shops').doc(adminEmail).collection('products');

    // 1. Delete all existing products in Firestore for this shop (optional, or just update)
    // To be safe and clean, we'll overwrite/create.
    for (final p in products) {
      final docId = p.id.isEmpty ? _db.collection('products').doc().id : p.id;
      batch.set(collection.doc(docId), p.toJson()..['id'] = docId);
    }

    await batch.commit();

    // Mark local as in-sync
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get real-time products stream for a shop.
  static Stream<List<Product>> productsStream(String adminEmail) {
    return _db
        .collection('shops')
        .doc(adminEmail)
        .collection('products')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Product.fromJson(d.data()))
            .toList());
  }

  /// Granular update for a single product.
  static Future<void> updateProduct(String adminEmail, Product product) async {
    final docId = product.id.isEmpty ? _db.collection('dummy').doc().id : product.id;
    await _db
        .collection('shops')
        .doc(adminEmail)
        .collection('products')
        .doc(docId)
        .set(product.toJson()..['id'] = docId);
  }

  /// Granular delete for a single product.
  static Future<void> deleteProduct(String adminEmail, String productId) async {
    await _db
        .collection('shops')
        .doc(adminEmail)
        .collection('products')
        .doc(productId)
        .delete();
  }

  /// ONE-TIME MIGRATION: Fetch all items from the legacy global 'inventory' collection 
  /// and save them to the new shop-specific path.
  static Future<int> migrateGlobalToShop(String adminEmail) async {
    final globalSnap = await _db.collection('inventory').get();
    if (globalSnap.docs.isEmpty) return 0;

    final batch = _db.batch();
    final shopCollection = _db.collection('shops').doc(adminEmail).collection('products');

    int count = 0;
    for (final doc in globalSnap.docs) {
      final data = doc.data();
      final p = Product.fromJson(data);
      // Ensure the ID is preserved or generated
      final docId = p.id.isEmpty ? doc.id : p.id;
      batch.set(shopCollection.doc(docId), p.toJson()..['id'] = docId);
      count++;
    }

    await batch.commit();
    return count;
  }
}
