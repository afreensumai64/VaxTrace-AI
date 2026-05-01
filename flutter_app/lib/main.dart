// VaxTrace AI — App Entry Point
// Auth: JWT (zero-cost). No Firebase.initializeApp() needed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/providers.dart';
import 'services/jwt_auth_service.dart';
import 'views/login_screen.dart';
import 'views/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No Firebase.initializeApp() — JWT auth is fully local + server-side.
  runApp(const ProviderScope(child: VaxTraceApp()));
}

class VaxTraceApp extends StatelessWidget {
  const VaxTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaxTrace AI',
      debugShowCheckedModeBanner: false,
      theme: VaxTheme.dark,
      home: const _AuthGate(),
    );
  }
}

/// Routes to LoginScreen or HomeScreen based on JWT session state.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        backgroundColor: VaxColors.deepNavy,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vaccines, color: VaxColors.electricCyan, size: 60),
              SizedBox(height: 20),
              CircularProgressIndicator(color: VaxColors.electricCyan),
              SizedBox(height: 16),
              Text('Starting VaxTrace AI...',
                  style: TextStyle(color: VaxColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
      error: (_, __) => const LoginScreen(),
      data: (JwtUser? user) =>
          user != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}
