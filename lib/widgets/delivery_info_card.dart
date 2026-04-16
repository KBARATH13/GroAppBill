import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'glass_container.dart';

class DeliveryInfoCard extends ConsumerWidget {
  final TextEditingController operatorController;
  final TextEditingController apartmentController;
  final TextEditingController blockDoorController;

  const DeliveryInfoCard({
    super.key,
    required this.operatorController,
    required this.apartmentController,
    required this.blockDoorController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final delivery = ref.watch(deliveryInfoProvider);
    final deliveryNotifier = ref.read(deliveryInfoProvider.notifier);

    return GlassContainer(
      color: Colors.white.withOpacity(0.12),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: operatorController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Operator Name',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
            onChanged: (value) {
              ref.read(userProvider.notifier).login(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            dropdownColor: scheme.surfaceContainer,
            style: const TextStyle(color: Colors.white),
            value: delivery.customerType,
            onChanged: (value) {
              if (value != null) {
                deliveryNotifier.setCustomerType(value);
              }
            },
            items: ['Walk-in', 'Home Delivery']
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            decoration: InputDecoration(
              labelText: 'Customer Type',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
            ),
          ),
          if (delivery.customerType == 'Home Delivery') ...[
            const SizedBox(height: 12),
            TextField(
              controller: apartmentController,
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => deliveryNotifier.setApartment(value),
              decoration: InputDecoration(
                labelText: 'Apartment Name',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Enter apartment/area name',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.apartment, color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: blockDoorController,
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => deliveryNotifier.setBlockAndDoor(value),
              decoration: InputDecoration(
                labelText: 'Block & Door Number',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'e.g., Block A, Door 302',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.door_front_door_outlined, color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
