// VaxTrace AI — Login Screen
// JWT Email/Password Auth (zero-cost, no Firebase needed)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final authService = ref.read(jwtAuthServiceProvider);
      if (_isLogin) {
        await authService.signInWithEmail(
            _emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await authService.signUpWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          displayName: _nameCtrl.text.trim().isEmpty
              ? null
              : _nameCtrl.text.trim(),
        );
      }
      // Auth state stream will update and AuthGate routes to HomeScreen
    } catch (e) {
      setState(() => _errorMessage = _parseError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String error) {
    if (error.contains('Incorrect')) return 'Incorrect email or password.';
    if (error.contains('already registered')) return 'Email already registered.';
    if (error.contains('SocketException') || error.contains('Connection refused')) {
      return 'Cannot reach server. Check your connection.';
    }
    return error.length > 80 ? 'Authentication failed. Try again.' : error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [VaxColors.navyDark, VaxColors.deepNavy, VaxColors.navyLight],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: VaxColors.electricCyan, width: 2),
                          color: VaxColors.surface,
                        ),
                        child: const Icon(Icons.vaccines,
                            size: 52, color: VaxColors.electricCyan),
                      ),
                      const SizedBox(height: 20),

                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [VaxColors.electricCyan, VaxColors.cyanLight],
                        ).createShader(bounds),
                        child: const Text('VaxTrace AI',
                            style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 1.2)),
                      ),
                      const Text('Vaccine Equity System',
                          style: TextStyle(
                              color: VaxColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 8),

                      // Auth mode badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: VaxColors.riskLow.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: VaxColors.riskLow.withOpacity(0.3)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.lock_open, color: VaxColors.riskLow, size: 12),
                          SizedBox(width: 4),
                          Text('Secure JWT Auth',
                              style: TextStyle(
                                  color: VaxColors.riskLow, fontSize: 11)),
                        ]),
                      ),
                      const SizedBox(height: 32),

                      // Error banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: VaxColors.riskCritical.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: VaxColors.riskCritical.withOpacity(0.5)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                color: VaxColors.riskCritical, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: VaxColors.riskCritical,
                                      fontSize: 13)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Display name (sign-up only)
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: VaxColors.white),
                          decoration: const InputDecoration(
                            labelText: 'Your Name (optional)',
                            prefixIcon: Icon(Icons.badge_outlined,
                                color: VaxColors.electricCyan),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: VaxColors.white),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined,
                              color: VaxColors.electricCyan),
                        ),
                        validator: (v) =>
                            v == null || !v.contains('@') ? 'Enter valid email' : null,
                      ),
                      const SizedBox(height: 12),

                      // Password
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: VaxColors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: VaxColors.electricCyan),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: VaxColors.textSecondary,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? 'Min 6 characters' : null,
                      ),
                      const SizedBox(height: 24),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: VaxColors.deepNavy))
                              : Text(
                                  _isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Toggle
                      TextButton(
                        onPressed: () => setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        }),
                        child: Text(
                          _isLogin
                              ? "Don't have an account? Sign Up"
                              : 'Already have an account? Sign In',
                          style: const TextStyle(color: VaxColors.electricCyan),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
