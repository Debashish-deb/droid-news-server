// lib/features/auth/login_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme_provider.dart';
import '../../../features/profile/auth_service.dart';
import '/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _passCtl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final msg = await AuthService().login(
      _emailCtl.text.trim(),
      _passCtl.text.trim(),
    );
    setState(() => _loading = false);
    if (msg != null) {
      setState(() => _error = msg);
    } else {
      if (!mounted) return;
      context.go('/home');
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    final result = await AuthService().signInWithGoogle();
    setState(() => _loading = false);
    if (!mounted) return;
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
                          loc.login,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textColor),
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

                        _glassField(
                          loc.email,
                          controller: _emailCtl,
                          textColor: textColor,
                        ),
                        const SizedBox(height: 12),
                        _glassField(
                          loc.password,
                          controller: _passCtl,
                          obscure: true,
                          textColor: textColor,
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _loading ? null : _login,
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
                                  loc.login,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),

                        ElevatedButton.icon(
                          icon: Image.asset('assets/google_logo.png', height: 24),
                          label: Text(
                            loc.continueWithGoogle,
                            style: TextStyle(color: textColor),
                          ),
                          onPressed: _loading ? null : _loginWithGoogle,
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
                          onPressed: () => context.go('/signup'),
                          child: Text(
                            loc.createAccount,
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
              colors: [Color(0xFF1C1F22), Color(0xFF121417)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      case AppThemeMode.light:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFB0B0B0), Color(0xFFD0D0D0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(color: Colors.white70, offset: Offset(-4, -4), blurRadius: 6),
              BoxShadow(color: Colors.black26, offset: Offset(4, 4), blurRadius: 6),
            ],
          ),
        );
      case AppThemeMode.bangladesh:
      default:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8FA49D), Color(0xFF6E7B75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black38, offset: Offset(2, 2), blurRadius: 8),
            ],
          ),
        );
    }
  }

  Color _glassTint(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return const Color(0xFF1C1F26).withOpacity(0.1);
      case AppThemeMode.light:
        return Colors.white.withOpacity(0.1);
      case AppThemeMode.bangladesh:
      default:
        return const Color(0xFF6E7B75).withOpacity(0.15);
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
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
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
