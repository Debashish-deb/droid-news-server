// signup_screen.dart with Google Sign-In button
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';
import '../../../../localization/l10n/app_localizations.dart';

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

  void _signup() async {
    final msg = await AuthService().signUp(
      _nameCtl.text.trim(),
      _emailCtl.text.trim(),
      _passCtl.text.trim(),
    );

    if (msg != null) {
      setState(() => _error = msg);
    } else {
      context.go('/home');
    }
  }

  void _signupWithGoogle() async {
    final result = await AuthService().signInWithGoogle();
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.signup)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_error != null) ...[
              Text(
                _localizedError(loc, _error!),
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _nameCtl,
              decoration: InputDecoration(labelText: loc.fullName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtl,
              decoration: InputDecoration(labelText: loc.email),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtl,
              decoration: InputDecoration(labelText: loc.password),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _signup, child: Text(loc.signup)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Image.asset('assets/google_logo.png', height: 24),
              label: const Text('Continue with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _signupWithGoogle,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(loc.alreadyHaveAccount),
            ),
          ],
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