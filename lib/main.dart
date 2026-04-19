import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/index.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'providers/app_providers.dart';
import 'widgets/glass_container.dart';
import 'widgets/vibrant_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Enable Firestore offline persistence so Firestore reads are served from
  // the local device cache on repeat launches — eliminating the network
  // round-trip that causes slow startup.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);

    return appUserAsync.when(
      data: (appUser) {
        Widget home;
        if (appUser == null) {
          home = const LoginScreen();
        } else if (!appUser.isApproved) {
          home = const _PendingApprovalScreen();
        } else {
          home = const HomeScreen();
        }

        return MaterialApp(
          title: 'GroAppBill',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2C5364),
              brightness: Brightness.dark,
              surface: const Color(0xFF1A1A2E),
              onSurface: Colors.white,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F1419),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF16213E),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00A86B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2ECC71),
                side: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          home: home,
        );
      },
      loading: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: VibrantBackground(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      ),
      error: (err, stack) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: VibrantBackground(
            child: Center(
              child: Text('Error: $err', style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingApprovalScreen extends ConsumerWidget {
  const _PendingApprovalScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: VibrantBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: GlassContainer(
              padding: const EdgeInsets.all(32),
              borderRadius: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_filled, size: 80, color: Colors.white70),
                  const SizedBox(height: 24),
                  const Text(
                    'Pending Approval',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your account is waiting for admin approval.\nPlease contact your manager to get access.',
                    style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: () {
                      AuthService.signOut();
                    },
                    child: GlassContainer(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      borderRadius: 12,
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

