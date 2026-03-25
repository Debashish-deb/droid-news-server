import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart' show AppLocalizations;
import '../../providers/feature_providers.dart' show authServiceProvider;
import '../../../core/navigation/app_paths.dart';
import '../common/app_bar.dart';
import '../../widgets/glass_icon_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _passCtl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  void _login() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final msg = await ref
          .read(authServiceProvider)
          .login(
            _emailCtl.text.trim(),
            _passCtl.text, // ✅ FIXED: Don't trim password
          )
          .timeout(const Duration(seconds: 15));

      if (msg != null) {
        setState(() => _error = msg);
      } else {
        if (!mounted) return;
        context.go(AppPaths.home);
      }
    } catch (e) {
      setState(() => _error = 'Login timed out. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(authServiceProvider)
          .signInWithGoogle()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (result != null) {
        setState(() => _error = result);
      } else {
        context.go(AppPaths.home);
      }
    } catch (e) {
      setState(() => _error = 'Google sign-in timed out.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: AppBarTitle(loc.login),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Center(
            child: GlassIconButton(
              icon: Icons.arrow_back,
              onPressed: () => context.go(AppPaths.home),
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/play_store_512-app.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.article_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(
                  _localizedError(loc, _error!),
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailCtl,
                decoration: InputDecoration(labelText: loc.email),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtl,
                decoration: InputDecoration(labelText: loc.password),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(loc.login),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Image.asset('assets/google_logo.png', height: 24),
                label: Text(AppLocalizations.of(context).continueWithGoogle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _isLoading ? null : _loginWithGoogle,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go(AppPaths.signup),
                  child: Text(loc.createAccount),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localizedError(AppLocalizations loc, String msg) {
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
}
