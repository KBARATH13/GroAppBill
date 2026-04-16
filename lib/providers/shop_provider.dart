import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/index.dart';
import '../services/auth_service.dart';
import 'auth_providers.dart';

// Shop info provider - manages shop metadata with local caching and firestore sync
final shopInfoProvider = StateNotifierProvider<ShopNotifier, ShopInfo>((ref) {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  final notifier = ShopNotifier();
  if (appUser != null) {
    notifier.syncWithFirestore(appUser.adminEmail);
  }
  return notifier;
});

class ShopNotifier extends StateNotifier<ShopInfo> {
  ShopNotifier() : super(const ShopInfo()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('grocery-shop-info');
    if (data != null) {
      try {
        state = ShopInfo.fromMap(jsonDecode(data));
      } catch (_) {}
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('grocery-shop-info', jsonEncode(state.toMap()));
  }

  void syncWithFirestore(String adminEmail) {
    AuthService.shopInfoStream(adminEmail).listen((info) {
      if (info != null) {
        state = info;
        _saveToPrefs();
      }
    });
  }

  Future<void> updateShopInfo(String adminEmail, ShopInfo newInfo) async {
    state = newInfo;
    await _saveToPrefs();
    await AuthService.updateShopInfo(adminEmail, newInfo);
  }
}
