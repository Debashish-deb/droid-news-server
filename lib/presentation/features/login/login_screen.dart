import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/feature_providers.dart';
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
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  void _login() async {
    final msg = await ref.read(authServiceProvider).login(
      _emailCtl.text.trim(),
      _passCtl.text.trim(),
    );

    if (msg != null) {
      setState(() => _error = msg);
    } else {
      if (!mounted) return;
      context.go('/home');
    }
  }

  void _loginWithGoogle() async {
    final result = await ref.read(authServiceProvider).signInWithGoogle();
    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    } else {
      context.go('/home');
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
              onPressed: () => context.go('/home'),
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
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(loc.login),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: Image.asset('assets/google_logo.png', height: 24),
                label: Text(AppLocalizations.of(context).continueWithGoogle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _loginWithGoogle,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/signup'),
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
