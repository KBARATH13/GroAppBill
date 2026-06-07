import 'package:flutter/material.dart';

@immutable
class Delivery {
  final String? apartmentName;
  final String? blockAndDoor;

  const Delivery({
    this.apartmentName,
    this.blockAndDoor,
  });

  Delivery copyWith({
    String? apartmentName,
    String? blockAndDoor,
  }) {
    return Delivery(
      apartmentName: apartmentName ?? this.apartmentName,
      blockAndDoor: blockAndDoor ?? this.blockAndDoor,
    );
  }

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
        apartmentName: json['apartmentName'] as String?,
        blockAndDoor: json['blockAndDoor'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'apartmentName': apartmentName,
        'blockAndDoor': blockAndDoor,
      };
}
