import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

// Firebase app user provider - tracks auth state and firestore role
final appUserProvider = StreamProvider<AppUser?>((ref) {
  return AuthService.appUserStream;
});

// User provider - manages operator login (legacy local strings)
final userProvider = StateNotifierProvider<UserNotifier, String?>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<String?> {
  UserNotifier() : super(null) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('grocery-user');
  }

  Future<void> login(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('grocery-user', name);
    state = name;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('grocery-user');
    state = null;
  }
}
