import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/index.dart';
import '../services/auth_service.dart';
import '../services/printer_service.dart';
import '../models/app_user.dart';
import '../widgets/glass_container.dart';
import '../widgets/vibrant_background.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _printerController;
  late TextEditingController _portController;
  late TextEditingController _shopNameController;
  List<TextEditingController> _addressControllers = [];
  late TextEditingController _shopPhoneController;
  late TextEditingController _billGreetingController;
  late TextEditingController _billExtraInfoController;
  bool _isLoading = true;
  final Map<String, bool> _pendingInventoryClearance = {};

  @override
  void initState() {
    super.initState();
    _printerController = TextEditingController();
    _portController = TextEditingController();
    _shopNameController = TextEditingController();
    _addressControllers = [TextEditingController()];
    _shopPhoneController = TextEditingController();
    _billGreetingController = TextEditingController();
    _billExtraInfoController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _printerController.dispose();
    _portController.dispose();
    _shopNameController.dispose();
    for (var controller in _addressControllers) {
      controller.dispose();
    }
    _shopPhoneController.dispose();
    _billGreetingController.dispose();
    _billExtraInfoController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final config = await PrinterService.getConfig();
      if (mounted) {
        setState(() {
          _printerController.text = config['printerHost'] ?? '';
          _portController.text = config['printerPort']?.toString() ?? '9100';
          // Note: shop metadata is now handled by shopInfoProvider, not local config
        });
        
        // Background cleanup for removed users (Admin only)
        final appUser = ref.read(appUserProvider).valueOrNull;
        if (appUser != null && appUser.isAdmin) {
          AuthService.cleanUpRemovedUsers(appUser.adminEmail);
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    final port = int.tryParse(_portController.text);
    if (port == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid port number')));
      return;
    }
    await PrinterService.saveConfig(
      printerHost: _printerController.text,
      printerPort: port,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully')));
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);
    final result = await PrinterService.testPrinterConnection();
    setState(() => _isLoading = false);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result['success'] ? 'Success' : 'Failed'),
          content: Text(result['message']),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _discoverPrinters() async {
    int scanned = 0;
    int total = 254;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future.microtask(() async {
            if (scanned == 0 && total == 254) {
              final found = await PrinterService.discoverPrinters(
                onProgress: (s, t) => setDialogState(() { scanned = s; total = t; }),
              );
              if (mounted && Navigator.canPop(ctx)) Navigator.pop(ctx, found);
            }
          });
          return AlertDialog(
            title: const Text('🔍 Discovering Printers...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: scanned / total),
                const SizedBox(height: 12),
                Text('Scanning network: $scanned / $total', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Looking for devices with port 9100 open...', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          );
        },
      ),
    ).then((found) {
      if (found != null && found is List<String>) _handleDiscoveryResults(found);
    });
  }

  void _handleDiscoveryResults(List<String> found) {
    if (!mounted) return;
    if (found.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Printers Found'),
          content: const Text('No devices with port 9100 were found on your network.\n\nMake sure:\n• Printer is turned ON\n• Printer is connected to the same WiFi/Ethernet\n• Router AP Isolation is disabled'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return AlertDialog(
              title: Text('Found ${found.length} Printer(s)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tap an IP to set it as your printer:'),
                  const SizedBox(height: 12),
                  ...found.map((ip) => ListTile(
                    leading: Icon(Icons.print, color: scheme.secondary),
                    title: Text(ip),
                    subtitle: const Text('Port 9100 — Thermal Printer'),
                    onTap: () {
                      setState(() => _printerController.text = ip);
                      Navigator.pop(context);
                      PrinterService.saveConfig(printerHost: ip);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✓ Printer set to $ip'), backgroundColor: scheme.secondary));
                    },
                  )),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
            );
          },
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _approveUser(AppUser user, bool canAddInventory) async {
    await AuthService.approveUser(user.uid, canAddInventory: canAddInventory);
    if (mounted) {
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✓ ${user.email} approved'), backgroundColor: scheme.secondary));
    }
  }

  Future<void> _rejectUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: const Text('Reject User?'),
            content: Text('This will delete the account for ${user.email}. They will not be able to access the app.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Reject', style: TextStyle(color: scheme.error))),
            ],
          );
        },
      ),
    );
    if (confirmed == true) {
      await AuthService.rejectUser(user.uid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.email} rejected')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(appUserProvider);
    final appUser = appUserAsync.valueOrNull;
    final isAdmin = appUser?.isAdmin ?? false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: VibrantBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Account Info ---
                    if (appUser != null) ...[
                      const Text('Account', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(appUser.email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(isAdmin ? '👑 Administrator' : 'Operator', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
                              label: const Text('Sign Out', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                backgroundColor: Colors.white.withOpacity(0.05),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // --- User Approvals (Admin only) ---
                    if (isAdmin) ...[
                      const Text('Approvals', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      StreamBuilder<List<AppUser>>(
                        stream: AuthService.pendingUsersStream(appUser?.adminEmail ?? ''),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
                          }
                          final pending = snapshot.data ?? [];
                          if (pending.isEmpty) {
                            return Builder(
                              builder: (context) {
                                final scheme = Theme.of(context).colorScheme;
                                return GlassContainer(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: scheme.secondary.withOpacity(0.7)),
                                      const SizedBox(width: 12),
                                      const Text('No pending approvals', style: TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                          return Builder(
                            builder: (context) {
                              final scheme = Theme.of(context).colorScheme;
                              return Column(
                                children: pending.map((user) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: scheme.tertiary.withOpacity(0.2),
                                          child: Icon(Icons.person_outline, color: scheme.tertiary),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(user.email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              Row(
                                                children: [
                                                  const Text('Inventory Access: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                                  SizedBox(
                                                    height: 30,
                                                    child: Switch(
                                                      value: _pendingInventoryClearance[user.uid] ?? false,
                                                      onChanged: (val) => setState(() => _pendingInventoryClearance[user.uid] = val),
                                                      activeColor: scheme.secondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.check_circle, color: scheme.secondary),
                                          onPressed: () => _approveUser(user, _pendingInventoryClearance[user.uid] ?? false),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.cancel, color: scheme.error),
                                          onPressed: () => _rejectUser(user),
                                        ),
                                      ],
                                    ),
                                  ),
                                )).toList(),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text('Managed Operators', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      StreamBuilder<List<AppUser>>(
                        stream: AuthService.approvedUsersStream(appUser?.adminEmail ?? ''),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
                          }
                          final approved = snapshot.data ?? [];
                          if (approved.isEmpty) {
                            return GlassContainer(
                              padding: const EdgeInsets.all(16),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white70),
                                  SizedBox(width: 12),
                                  Text('No managed operators yet', style: TextStyle(color: Colors.white70)),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: approved.map((user) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue.withOpacity(0.2),
                                      child: const Icon(Icons.person, color: Colors.blueAccent),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(user.email.isNotEmpty ? user.email : 'Unknown Email', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Row(
                                            children: [
                                              const Text('Approved Worker', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                              if (user.canAddInventory)
                                                const Tooltip(
                                                  message: 'Can add products using scanner/+',
                                                  child: Padding(
                                                    padding: EdgeInsets.only(left: 6.0),
                                                    child: Icon(Icons.qr_code_scanner, size: 14, color: Colors.greenAccent),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Text('Inv. Access: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                        SizedBox(
                                          height: 30,
                                          child: Switch(
                                            value: user.canAddInventory,
                                            onChanged: (val) async {
                                              await AuthService.updateUserPermission(user.uid, val);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Permission ${val ? "granted" : "revoked"} for ${user.email}'),
                                                    duration: const Duration(seconds: 1),
                                                  ),
                                                );
                                              }
                                            },
                                            activeColor: const Color(0xFF2ECC71),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.person_remove, color: Colors.redAccent, size: 20),
                                          tooltip: 'Remove Operator',
                                          onPressed: () async {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Remove Operator?'),
                                                content: Text(
                                                  'Are you sure you want to remove ${user.email}?\n\n'
                                                  '• They will be logged out immediately.\n'
                                                  '• They cannot login again.\n'
                                                  '• Their account will be permanently deleted after 3 days.'
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, true), 
                                                    child: const Text('Remove & Block', style: TextStyle(color: Colors.red))
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed == true) {
                                              await AuthService.blockAndRemoveOperator(user.uid);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Operator removed and blocked')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // --- Shop/Bill Configuration (Admin only) ---
                    if (isAdmin) ...[
                      const Text('Shop & Bill Info', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, child) {
                          final info = ref.watch(shopInfoProvider);
                          
                          // Initial population if controllers are empty and info has data
                          if (_shopNameController.text.isEmpty && info.shopName.isNotEmpty) {
                            _shopNameController.text = info.shopName;
                          }
                          if (_shopPhoneController.text.isEmpty && info.phone.isNotEmpty) {
                            _shopPhoneController.text = info.phone;
                          }
                          if (_billGreetingController.text.isEmpty && info.greeting.isNotEmpty) {
                            _billGreetingController.text = info.greeting;
                          }
                          if (_billExtraInfoController.text.isEmpty && info.extraInfo.isNotEmpty) {
                            _billExtraInfoController.text = info.extraInfo;
                          }
                          if (_addressControllers.length == 1 && _addressControllers[0].text.isEmpty && info.address.isNotEmpty) {
                             final lines = info.address.split('\n');
                             _addressControllers = lines.map((l) => TextEditingController(text: l)).toList();
                          }

                          // Update controllers only if Firestore forced an update (diff detected)
                          ref.listen(shopInfoProvider, (prev, next) {
                            if (!mounted) return;
                            if (_shopNameController.text != next.shopName) {
                              _shopNameController.text = next.shopName;
                            }
                            if (_shopPhoneController.text != next.phone) {
                              _shopPhoneController.text = next.phone;
                            }
                            if (_billGreetingController.text != next.greeting) {
                              _billGreetingController.text = next.greeting;
                            }
                            if (_billExtraInfoController.text != next.extraInfo) {
                              _billExtraInfoController.text = next.extraInfo;
                            }
                            
                            // Handling multi-line address sync
                            final currentJoined = _addressControllers.map((c) => c.text).join('\n');
                            if (currentJoined != next.address) {
                              setState(() {
                                for(var c in _addressControllers) { c.dispose(); }
                                _addressControllers = next.address.split('\n').map((l) => TextEditingController(text: l)).toList();
                                if (_addressControllers.isEmpty) _addressControllers.add(TextEditingController());
                               });
                            }
                          });
                              
                          return GlassContainer(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildTextField(_shopNameController, 'Shop Name', Icons.store),
                                    const SizedBox(height: 12),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Address Lines (for proper spacing)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._addressControllers.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final controller = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _buildTextField(controller, 'Address Line ${idx + 1}', Icons.location_on),
                                            ),
                                            if (_addressControllers.length > 1)
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                onPressed: () {
                                                  setState(() => _addressControllers.removeAt(idx));
                                                },
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() => _addressControllers.add(TextEditingController()));
                                      },
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Address Line'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTextField(_shopPhoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
                                    const SizedBox(height: 12),
                                    _buildTextField(_billGreetingController, 'Bill Greeting', Icons.message),
                                    const SizedBox(height: 12),
                                    _buildTextField(_billExtraInfoController, 'Extra Info (Footer)', Icons.info),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final newInfo = ShopInfo(
                                          shopName: _shopNameController.text.trim(),
                                          address: _addressControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join('\n'),
                                          phone: _shopPhoneController.text.trim(),
                                          greeting: _billGreetingController.text.trim(),
                                          extraInfo: _billExtraInfoController.text.trim(),
                                        );
                                        await ref.read(shopInfoProvider.notifier).updateShopInfo(appUser!.adminEmail, newInfo);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('✓ Shop details updated'), backgroundColor: Colors.green),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.save),
                                      label: const Text('Save Shop & Bill Info'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2ECC71).withOpacity(0.4),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(double.infinity, 45),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    const Text('Printer', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _printerController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'IP Address',
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.print, color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () async {
                              await PrinterService.saveConfig(
                                printerHost: _printerController.text.trim(),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✓ Printer IP updated'), backgroundColor: Colors.green),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Save IP Address'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Port',
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.settings_ethernet, color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: _discoverPrinters,
                            child: GlassContainer(
                              color: Colors.purple,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              borderRadius: 12,
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.radar, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Auto-Discover', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _testConnection,
                                  child: GlassContainer(
                                    color: Colors.orange,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    borderRadius: 12,
                                    child: const Center(
                                      child: Text('Test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _saveSettings,
                                  child: GlassContainer(
                                    color: Colors.blue,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    borderRadius: 12,
                                    child: const Center(
                                      child: Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text('Tips', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• Use a static IP for your printer in router settings.\n'
                            '• Standard port is usually 9100.\n'
                            '• Devices must be on the same WiFi network.',
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6), height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}
