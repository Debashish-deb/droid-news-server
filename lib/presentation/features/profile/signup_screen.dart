// File: lib/features/auth/signup_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../l10n/generated/app_localizations.dart';

import '../../providers/theme_providers.dart' show currentThemeModeProvider;
import '../../providers/feature_providers.dart';
import '../../../core/theme.dart';
import '../../widgets/glass_icon_button.dart';
import '../common/app_bar.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _passCtl = TextEditingController();
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
    final String? msg = await ref.read(authServiceProvider).signUp(
      _nameCtl.text.trim(),
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

  Future<void> _signupWithGoogle() async {
    setState(() => _loading = true);
    final String? result = await ref.read(authServiceProvider).signInWithGoogle();
    setState(() => _loading = false);
    if (result != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    } else {
      if (!mounted) return;
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);

    final AppThemeMode mode = ref.watch(currentThemeModeProvider);
    final Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 64,
        title: AppBarTitle(loc.signup),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Center(
            child: GlassIconButton(
              icon: Icons.arrow_back,
              onPressed: () => context.go('/login'),
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildBackground(mode),
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
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
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

                        if (_error != null) ...<Widget>[
                          Text(
                            _mapError(loc, _error!),
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _glassField(
                          loc.fullName,
                          controller: _nameCtl,
                          textColor: textColor,
                        ),
                        const SizedBox(height: 12),
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
                          onPressed: _loading ? null : _signup,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _loading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    loc.signup,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 12),

                        ElevatedButton(
                          onPressed: _loading ? null : _signupWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/google_logo.png',
                                height: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.login,
                                    size: 24,
                                    color: Colors.white,
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  loc.continueWithGoogle,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
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
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withOpacity(0.85),
            colors[1].withOpacity(0.85),
          ],
        ),
      ),
    );
  }

  Widget _glassField(
    String label, {
    required TextEditingController controller,
    required Color textColor,
    bool obscure = false,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
