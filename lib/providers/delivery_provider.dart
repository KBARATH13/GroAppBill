import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery.dart';
import '../services/local_storage.dart';
import '../services/delivery_service.dart';
import '../providers/app_providers.dart';

/// Public provider you will use from the UI.
final deliveryProvider = StateNotifierProvider<
    DeliveryNotifier,
    AsyncValue<List<Delivery>>>(
  (ref) => DeliveryNotifier(ref),
);

class DeliveryNotifier
    extends StateNotifier<AsyncValue<List<Delivery>>> {
  final Ref _ref;
  Timer? _cleanupTimer;

  DeliveryNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadInitialData();
    // Periodic purge check
    _cleanupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _purgeOldDelivered(),
    );
  }

  Future<void> _loadInitialData() async {
    final uid = _ref.read(appUserProvider).valueOrNull?.uid;
    if (uid == null) {
      state = const AsyncValue.data([]);
      return;
    }

    // 1️⃣ Load from local cache first (fast start‑up)
    final cached = await LocalStorage.readList('alarm_$uid');
    if (cached != null) {
      state = AsyncValue.data(cached.map((d) => Delivery.fromJson(d)).toList());
    }

    // 2️⃣ Sync with Firestore via Service
    try {
      final deliveries = await DeliveryService.fetchDeliveries(uid);
      state = AsyncValue.data(deliveries);
    } catch (e) {
      debugPrint('Error loading initial alarm data: $e');
    }
  }

  Future<void> addDelivery(Delivery delivery) async {
    final uid = _ref.read(appUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    // Service call
    await DeliveryService.addDelivery(delivery);

    // Update state & local cache
    state = state.whenData((list) => [...list, delivery]);
    
    final currentList = state.valueOrNull;
    if (currentList != null) {
      await LocalStorage.saveList('alarm_$uid', currentList.map((d) => d.toJson()).toList());
    }
  }

  Future<void> markDelivered(String id) async {
    final uid = _ref.read(appUserProvider).valueOrNull?.uid;
    final list = state.valueOrNull;
    
    if (uid == null || list == null) return;
    
    final idx = list.indexWhere((d) => d.id == id);
    if (idx == -1) return;

    final updated = list[idx].copyWith(
      isDelivered: true,
      deliveredAt: DateTime.now(),
    );

    // Service call
    await DeliveryService.markDelivered(id);

    final newList = [...list];
    newList[idx] = updated;
    state = AsyncValue.data(newList);
    await LocalStorage.saveList('alarm_$uid', newList.map((d) => d.toJson()).toList());
  }

  Future<void> updatePayment(String id, double paidAmount) async {
    final uid = _ref.read(appUserProvider).valueOrNull?.uid;
    final list = state.valueOrNull;
    
    if (uid == null || list == null) return;
    
    final idx = list.indexWhere((d) => d.id == id);
    if (idx == -1) return;

    final delivery = list[idx];
    final updated = delivery.copyWith(
      paidAmount: paidAmount,
      isPaid: paidAmount >= delivery.totalAmount,
    );

    // Service call
    await DeliveryService.updatePayment(id, updated.paidAmount, updated.isPaid);

    final newList = [...list];
    newList[idx] = updated;
    state = AsyncValue.data(newList);
    await LocalStorage.saveList('alarm_$uid', newList.map((d) => d.toJson()).toList());
  }

  Future<void> rescheduleDelivery(String id, DateTime newTime) async {
    final uid = _ref.read(appUserProvider).valueOrNull?.uid;
    final list = state.valueOrNull;
    
    if (uid == null || list == null) return;
    
    final idx = list.indexWhere((d) => d.id == id);
    if (idx == -1) return;

    final updated = list[idx].copyWith(
      alarmAt: newTime,
      isDelivered: false,
    );

    // Service call
    await DeliveryService.rescheduleDelivery(id, newTime);

    final newList = [...list];
    newList[idx] = updated;
    state = AsyncValue.data(newList);
    await LocalStorage.saveList('alarm_$uid', newList.map((d) => d.toJson()).toList());
  }

  Future<void> _purgeOldDelivered() async {
    final uid = _ref.read(appUserProvider).valueOrNull?.uid;
    final list = state.valueOrNull;
    
    if (uid == null || list == null) return;

    final now = DateTime.now();
    final toRemove = list.where((d) {
      if (!d.isDelivered || d.deliveredAt == null) return false;
      
      final daysOld = now.difference(d.deliveredAt!).inDays;
      
      if (d.isPaid) {
        return daysOld >= 2; // Paid items: 2 days retention
      } else {
        return daysOld >= 31; // Unpaid items: 31 days retention
      }
    }).toList();
    
    if (toRemove.isEmpty) return;

    // Service call
    await DeliveryService.purgeOldDelivered(toRemove);

    final remaining = list.where((d) => !toRemove.contains(d)).toList();
    state = AsyncValue.data(remaining);
    await LocalStorage.saveList('alarm_$uid', remaining.map((d) => d.toJson()).toList());
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
