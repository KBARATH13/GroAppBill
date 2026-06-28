import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/water_bottle_record.dart';
import '../providers/auth_providers.dart';
import '../services/water_bottle_service.dart';

class WaterBottleState {
  final List<WaterBottleRecord> records;
  final String searchTerm;

  const WaterBottleState({
    this.records = const [],
    this.searchTerm = '',
  });

  List<WaterBottleRecord> get filteredRecords {
    if (searchTerm.trim().isEmpty) return records;
    final query = searchTerm.toLowerCase();
    return records.where((record) {
      return record.customerName.toLowerCase().contains(query) ||
          record.address.toLowerCase().contains(query);
    }).toList();
  }

  WaterBottleState copyWith({
    List<WaterBottleRecord>? records,
    String? searchTerm,
  }) {
    return WaterBottleState(
      records: records ?? this.records,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }
}

class WaterBottleNotifier extends StateNotifier<WaterBottleState> {
  final Ref ref;
  StreamSubscription<List<WaterBottleRecord>>? _cloudSubscription;

  static const _prefsKey = 'water-bottle-records';

  WaterBottleNotifier(this.ref) : super(const WaterBottleState()) {
    _init();
  }

  void _init() {
    ref.listen<AsyncValue<AppUser?>>(appUserProvider, (previous, next) {
      final appUser = next.valueOrNull;
      if (appUser == null) {
        _cloudSubscription?.cancel();
        state = const WaterBottleState();
        return;
      }
      _subscribeToCloud(appUser.adminEmail);
    });

    _loadLocalCache();
  }

  void _subscribeToCloud(String adminEmail) {
    _cloudSubscription?.cancel();
    _cloudSubscription = WaterBottleService.recordsStream(adminEmail).listen((records) {
      state = state.copyWith(records: records);
      _saveLocalCache();
    });
  }

  Future<void> _loadLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString == null || jsonString.isEmpty) return;

    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      final records = decoded
          .map((item) => WaterBottleRecord.fromJson(item as Map<String, dynamic>))
          .toList();
      if (records.isNotEmpty && state.records.isEmpty) {
        state = state.copyWith(records: records);
      }
    } catch (_) {
      state = const WaterBottleState();
    }
  }

  Future<void> _saveLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(state.records.map((r) => r.toJson()).toList());
    await prefs.setString(_prefsKey, jsonString);
  }

  Future<void> addRecord(WaterBottleRecord record) async {
    state = state.copyWith(records: [...state.records, record]);
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser != null) {
      await WaterBottleService.saveRecord(appUser.adminEmail, record);
    }
    await _saveLocalCache();
  }

  Future<void> updateRecord(WaterBottleRecord record) async {
    state = state.copyWith(
      records: state.records.map((item) => item.id == record.id ? record : item).toList(),
    );
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser != null) {
      await WaterBottleService.saveRecord(appUser.adminEmail, record);
    }
    await _saveLocalCache();
  }

  Future<void> deleteRecord(String id) async {
    state = state.copyWith(records: state.records.where((item) => item.id != id).toList());
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser != null) {
      await WaterBottleService.deleteRecord(appUser.adminEmail, id);
    }
    await _saveLocalCache();
  }

  void setSearchTerm(String term) {
    state = state.copyWith(searchTerm: term);
  }

  @override
  void dispose() {
    _cloudSubscription?.cancel();
    super.dispose();
  }
}

final waterBottleProvider = StateNotifierProvider<WaterBottleNotifier, WaterBottleState>((ref) {
  return WaterBottleNotifier(ref);
});
