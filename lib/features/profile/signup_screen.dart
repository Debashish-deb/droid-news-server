// File: lib/features/auth/signup_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import '../../../features/profile/auth_service.dart';
import '/l10n/app_localizations.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    setState(() => _loading = true);
    final msg = await AuthService().signUp(
      _nameCtl.text.trim(),
      _emailCtl.text.trim(),
      _passCtl.text.trim(),
    );
    setState(() => _loading = false);
    if (msg != null) {
      setState(() => _error = msg);
    } else {
      context.go('/home');
    }
  }

  Future<void> _signupWithGoogle() async {
    setState(() => _loading = true);
    final result = await AuthService().signInWithGoogle();
    setState(() => _loading = false);
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final mode = context.watch<ThemeProvider>().appThemeMode;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(mode),
          Container(color: _glassTint(mode)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          loc.signup,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_error != null) ...[
                          Text(
                            _mapError(loc, _error!),
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _glassField(loc.fullName, controller: _nameCtl, textColor: textColor),
                        const SizedBox(height: 12),
                        _glassField(loc.email, controller: _emailCtl, textColor: textColor),
                        const SizedBox(height: 12),
                        _glassField(
                          loc.password,
                          controller: _passCtl,
                          obscure: true,
                          textColor: textColor,
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _loading ? null : _signup,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  loc.signup,
                                  style: TextStyle(
                                      color: textColor, fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(height: 12),

                        ElevatedButton.icon(
                          icon: Image.asset('assets/google_logo.png', height: 24),
                          label: Text(
                            loc.continueWithGoogle,
                            style: TextStyle(color: textColor),
                          ),
                          onPressed: _loading ? null : _signupWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(
                            loc.alreadyHaveAccount,
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mapError(AppLocalizations loc, String msg) {
    switch (msg) {
      case 'Invalid email or password.':
        return loc.invalidCredentials;
      case 'No account found. Please sign up first.':
        return loc.noAccountFound;
      case 'Account already exists. Please log in.':
        return loc.accountExists;
      default:
        return msg;
    }
  }

  Widget _buildBackground(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D0F13), Color(0xFF1A1C20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      case AppThemeMode.light:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE0E0E0), Color(0xFFF5F5F5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        );
      case AppThemeMode.bangladesh:
      default:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF006B3C), Color(0xFFBD1F2D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
    }
  }

  Color _glassTint(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return const Color(0xFF121417).withOpacity(0.1);
      case AppThemeMode.light:
        return Colors.white.withOpacity(0.05);
      case AppThemeMode.bangladesh:
      default:
        return const Color(0xFF2F4238).withOpacity(0.12);
    }
  }

  Widget _glassField(
    String label, {
    required TextEditingController controller,
    bool obscure = false,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}