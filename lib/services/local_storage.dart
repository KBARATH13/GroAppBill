import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _keyPrefix = 'deliveries_';

  /// Saves a list of maps (JSON objects) to local storage.
  static Future<void> saveList(String uid, List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(list);
    await prefs.setString('$_keyPrefix$uid', json);
  }

  /// Reads a list of maps from local storage.
  static Future<List<Map<String, dynamic>>?> readList(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('$_keyPrefix$uid');
    if (json == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }

  // --- Legacy Compatibility (optional, can be removed if not used elsewhere) ---
  @Deprecated('Use saveList/readList for generic JSON')
  static Future<void> saveDeliveries(String uid, dynamic list) async {
    if (list is List<Map<String, dynamic>>) {
      await saveList(uid, list);
    }
  }
}
