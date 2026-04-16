import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../services/history_service.dart';
import '../services/printer_service.dart';
import 'app_providers.dart';

final billingControllerProvider = Provider((ref) => BillingController(ref));

class BillingController {
  final Ref ref;
  BillingController(this.ref);

  Future<Map<String, dynamic>> checkout({
    required Map<String, dynamic> paymentDetails,
    required bool isPrint,
  }) async {
    final cartState = ref.read(cartProvider);
    final cart = cartState.activeCart;
    if (cart.isEmpty) return {'success': false, 'message': 'Cart is empty'};

    try {
      final now = DateTime.now();
      final dateStr = cartState.editingBillDate ?? DateFormat('dd/MM/yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);
      
      String bNumber;
      if (cartState.editingBillId != null) {
        bNumber = cartState.editingBillId!;
      } else {
        final billCount = await HistoryService.getDailyBillCount();
        bNumber = 'B-$billCount';
      }

      final operatorName = ref.read(userProvider) ?? 'NA';
      final shopInfo = ref.read(shopInfoProvider);
      final delivery = ref.read(deliveryInfoProvider);

      final bill = Bill(
        billNumber: bNumber,
        date: dateStr,
        time: timeStr,
        operatorName: operatorName,
        customerType: delivery.customerType,
        apartmentName: delivery.customerType == 'Home Delivery' ? delivery.apartmentName : null,
        blockAndDoor: delivery.customerType == 'Home Delivery' ? delivery.blockAndDoor : null,
        cartItems: cart,
        paymentMode: paymentDetails['paymentMode'] as String,
        cashAmount: paymentDetails['cashAmount'] as double,
        upiAmount: paymentDetails['upiAmount'] as double,
        shopName: shopInfo.shopName,
        shopAddress: shopInfo.address,
        shopPhone: shopInfo.phone,
        billGreeting: shopInfo.greeting,
        billExtraInfo: shopInfo.extraInfo,
        firestoreId: cartState.editingFirestoreId,
      );

      final adminEmail = ref.read(appUserProvider).valueOrNull?.adminEmail;
      
      if (isPrint) {
        final result = await PrinterService.sendBillToPrinter(bill);
        if (result['success'] != true) {
          return {'success': false, 'message': result['message'] ?? 'Print failed'};
        }
      }

      await HistoryService.saveBill(
        bill,
        adminEmail: adminEmail ?? 'local-only',
        replaceBillId: cartState.editingBillId,
        replaceFirestoreId: cartState.editingFirestoreId,
      );

      ref.read(cartProvider.notifier).clearCart();
      ref.read(cartProvider.notifier).clearEditingState();
      ref.read(deliveryInfoProvider.notifier).reset();

      return {'success': true, 'bill': bill};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
