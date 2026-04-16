import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_container.dart';
import 'cart_screen.dart';
import '../widgets/vibrant_background.dart';
import 'billing_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'calculator_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasPendingSync = false;
  bool _adminHasLocalChanges = false;

  Future<bool> _promptPublishBeforeSwitch() async {
    if (!_adminHasLocalChanges) return true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: Colors.orange),
            SizedBox(width: 8),
            Text('Unpublished Changes'),
          ],
        ),
        content: const Text(
          'You have inventory changes that have not been published to Firebase yet.\n\n'
          'What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: const Text('Stay'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'publish'),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Publish Now'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );

    if (result == 'publish') {
      final products = ref.read(productsProvider);
      final user = ref.read(appUserProvider).valueOrNull;
      if (user != null) {
        await SyncService.pushToFirestore(user.adminEmail, products);
      }
      setState(() => _adminHasLocalChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Inventory published to Firebase successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return true;
    } else if (result == 'discard') {
      setState(() => _adminHasLocalChanges = false);
      return true;
    }
    return false;
  }

  Future<void> _onTabSelected(int index) async {
    final selectedIndex = ref.read(navigationProvider);
    if (selectedIndex == index) return;

    if (selectedIndex == 1 && index == 0) {
      final canLeave = await _promptPublishBeforeSwitch();
      if (!canLeave) return;
    }
    HapticFeedback.lightImpact();
    ref.read(navigationProvider.notifier).setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationProvider);
    
    return VibrantBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.05),
          elevation: 0,
          title: Consumer(
            builder: (context, ref, child) {
              final shopInfo = ref.watch(shopInfoProvider);
              return Text(
                shopInfo.shopName.isEmpty ? 'GroAppBill' : shopInfo.shopName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: 0.5),
              );
            },
          ),
          actions: [
            // Cart Button (Only on Billing Tab)
            if (selectedIndex == 0)
              Consumer(
                builder: (context, ref, child) {
                  final cart = ref.watch(cartProvider).carts[
                      ref.watch(cartProvider).activeIndex];
                  return IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.shopping_cart),
                        if (cart.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${cart.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () => _showCartBottomSheet(context, ref),
                    tooltip: 'View Cart',
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
              tooltip: 'Bill History',
            ),
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalculatorScreen()),
              ),
              tooltip: 'Calculator',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: IndexedStack(
          index: selectedIndex,
          children: [
            const BillingScreen(),
            if (ref.watch(appUserProvider).valueOrNull?.isAdmin == true)
              AdminScreen(
                hasPendingSync: false,
                onSync: () async {},
                onChangeMade: () => setState(() => _adminHasLocalChanges = true),
                onPublishComplete: () =>
                    setState(() => _adminHasLocalChanges = false),
              )
            else
              const Center(child: Text('Admin Access Required')),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: GlassContainer(
              height: 64,
              borderRadius: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavBarItem(
                    icon: Icons.shopping_cart,
                    label: 'Billing',
                    isSelected: selectedIndex == 0,
                    onTap: () => _onTabSelected(0),
                  ),
                  if (ref.watch(appUserProvider).valueOrNull?.isAdmin == true)
                    Builder(
                      builder: (context) {
                        final scheme = Theme.of(context).colorScheme;
                        return _NavBarItem(
                          icon: Icons.inventory_2,
                          label: 'Inventory',
                          isSelected: selectedIndex == 1,
                          hasBadge: _hasPendingSync || _adminHasLocalChanges,
                          badgeColor: _adminHasLocalChanges
                              ? scheme.error
                              : scheme.tertiary,
                          onTap: () => _onTabSelected(1),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCartBottomSheet(BuildContext context, WidgetRef ref) {
    final cartState = ref.read(cartProvider);
    final cart = cartState.carts[cartState.activeIndex];

    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty! Add products first.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => const CartScreen(),
    );
  }
}

// ─── Nav Bar Item ─────────────────────────────────────────────────────────────

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasBadge;
  final Color? badgeColor;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.hasBadge = false,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          highlightColor: Colors.white10,
          splashColor: Colors.white24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white54,
                    size: 26,
                  ),
                  if (hasBadge)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: badgeColor ?? Colors.orange,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white24, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
