import 'package:flutter_riverpod/flutter_riverpod.dart';

// Delivery Info Provider - manages customer & delivery data for billing
class DeliveryInfo {
  final String customerType;
  final String apartmentName;
  final String blockAndDoor;

  const DeliveryInfo({
    this.customerType = 'Walk-in',
    this.apartmentName = '',
    this.blockAndDoor = '',
  });

  DeliveryInfo copyWith({
    String? customerType,
    String? apartmentName,
    String? blockAndDoor,
  }) {
    return DeliveryInfo(
      customerType: customerType ?? this.customerType,
      apartmentName: apartmentName ?? this.apartmentName,
      blockAndDoor: blockAndDoor ?? this.blockAndDoor,
    );
  }
}

class DeliveryInfoNotifier extends StateNotifier<DeliveryInfo> {
  DeliveryInfoNotifier() : super(const DeliveryInfo());

  void setCustomerType(String type) => state = state.copyWith(customerType: type);
  void setApartment(String apartment) => state = state.copyWith(apartmentName: apartment);
  void setBlockAndDoor(String info) => state = state.copyWith(blockAndDoor: info);
  
  void reset() => state = const DeliveryInfo();
}

final deliveryInfoProvider = StateNotifierProvider<DeliveryInfoNotifier, DeliveryInfo>((ref) {
  return DeliveryInfoNotifier();
});
