import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum DeliveryItemType { bisleriWater, normalWater, groceries }

@immutable
class Delivery {
  final String id;
  final String userId;
  final String? apartmentName;
  final String? blockAndDoor;
  final Map<DeliveryItemType, int> items;
  final String? notes;
  final DateTime alarmAt;
  final bool isDelivered;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  
  // New fields for Delivery Manager
  final double groceryAmount;
  final double totalAmount;
  final double paidAmount;
  final bool isPaid;

  Delivery({
    required this.id,
    required this.userId,
    this.apartmentName,
    this.blockAndDoor,
    required this.items,
    this.notes,
    required this.alarmAt,
    this.isDelivered = false,
    DateTime? createdAt,
    this.deliveredAt,
    this.groceryAmount = 0.0,
    this.totalAmount = 0.0,
    this.paidAmount = 0.0,
    this.isPaid = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Delivery copyWith({
    String? id,
    String? userId,
    String? apartmentName,
    String? blockAndDoor,
    Map<DeliveryItemType, int>? items,
    String? notes,
    DateTime? alarmAt,
    bool? isDelivered,
    DateTime? createdAt,
    DateTime? deliveredAt,
    double? groceryAmount,
    double? totalAmount,
    double? paidAmount,
    bool? isPaid,
  }) {
    return Delivery(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      apartmentName: apartmentName ?? this.apartmentName,
      blockAndDoor: blockAndDoor ?? this.blockAndDoor,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      alarmAt: alarmAt ?? this.alarmAt,
      isDelivered: isDelivered ?? this.isDelivered,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      groceryAmount: groceryAmount ?? this.groceryAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  factory Delivery.fromJson(Map<String, dynamic> json) {
    Map<DeliveryItemType, int> itemsMap = {};
    final rawItems = json['items'] as Map<String, dynamic>?;
    if (rawItems != null) {
      rawItems.forEach((k, v) {
        try {
          final type = DeliveryItemType.values.firstWhere((e) => e.name == k);
          itemsMap[type] = v as int;
        } catch (_) {}
      });
    }

    return Delivery(
      id: json['id'] as String,
      userId: json['userId'] as String,
      apartmentName: json['apartmentName'] as String?,
      blockAndDoor: json['blockAndDoor'] as String?,
      items: itemsMap,
      notes: json['notes'] as String?,
      alarmAt: _parseDate(json['alarmAt']),
      isDelivered: json['isDelivered'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
      deliveredAt: json['deliveredAt'] != null ? _parseDate(json['deliveredAt']) : null,
      groceryAmount: (json['groceryAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      isPaid: json['isPaid'] as bool? ?? false,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'apartmentName': apartmentName,
    'blockAndDoor': blockAndDoor,
    'items': items.map((k, v) => MapEntry(k.name, v)),
    'notes': notes,
    'alarmAt': alarmAt.toIso8601String(),
    'isDelivered': isDelivered,
    'createdAt': createdAt.toIso8601String(),
    if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
    'groceryAmount': groceryAmount,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'isPaid': isPaid,
  };

  // Helper for Firestore updates which REQUIRES Timestamps
  Map<String, dynamic> toFirestore() {
    final map = toJson();
    map['alarmAt'] = Timestamp.fromDate(alarmAt);
    map['createdAt'] = Timestamp.fromDate(createdAt);
    if (deliveredAt != null) map['deliveredAt'] = Timestamp.fromDate(deliveredAt!);
    return map;
  }
}
