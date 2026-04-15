import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart' show AppLocalizations;
import '../../providers/feature_providers.dart' show authServiceProvider;
import '../../../core/navigation/app_paths.dart';
import '../../widgets/premium_screen_header.dart';

const String _emailVerificationRequiredPrefix =
    'Please verify your email address before logging in.';
const String _verificationEmailCooldownMessage =
    'Verification email was sent recently. Please wait before requesting another one.';

bool _isEmailVerificationMessage(String msg) {
  return msg.startsWith(_emailVerificationRequiredPrefix) ||
      msg == _verificationEmailCooldownMessage;
}

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
      final auth = ref.read(authServiceProvider);
      final msg = await auth.login(
        _emailCtl.text.trim(),
        _passCtl.text, // ✅ FIXED: Don't trim password
      );

      if (!mounted) return;
      if (msg == null || auth.currentUser != null) {
        context.go(AppPaths.home);
      } else {
        setState(() => _error = msg);
      }
    } on TimeoutException {
      if (!mounted) return;
      final auth = ref.read(authServiceProvider);
      if (auth.currentUser != null) {
        context.go(AppPaths.home);
      } else {
        setState(() => _error = 'Connection timed out. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Unable to sign in right now. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendEmailVerification() async {
    if (_isLoading) return;
    if (_emailCtl.text.trim().isEmpty || _passCtl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final msg = await auth.resendEmailVerification(
        _emailCtl.text.trim(),
        _passCtl.text,
      );
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      final snackMessage = msg == null
          ? loc.verificationEmailResent
          : _localizedError(loc, msg);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(snackMessage)));
      setState(() {
        if (msg == null || _isEmailVerificationMessage(msg)) {
          _error = _emailVerificationRequiredPrefix;
        } else {
          _error = msg;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Unable to resend verification email right now.',
        );
      }
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
      final auth = ref.read(authServiceProvider);
      final result = await auth.signInWithGoogle();
      if (!mounted) return;
      if (result == null || auth.currentUser != null) {
        context.go(AppPaths.home);
      } else {
        setState(() => _error = result);
      }
    } on TimeoutException {
      if (!mounted) return;
      final auth = ref.read(authServiceProvider);
      if (auth.currentUser != null) {
        context.go(AppPaths.home);
      } else {
        setState(
          () => _error = 'Google sign-in is taking longer than expected.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: PremiumScreenHeader(
        title: loc.login,
        onLeadingTap: () => context.go(AppPaths.home),
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isEmailVerificationMessage(_error!)) ...[
                  const SizedBox(height: 12),
                  _VerificationRecoveryPanel(
                    isLoading: _isLoading,
                    onResend: _resendEmailVerification,
                    onRetry: _login,
                    loc: loc,
                  ),
                ],
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
    if (msg.startsWith(_emailVerificationRequiredPrefix)) {
      return loc.emailNotVerified;
    }
    if (msg == _verificationEmailCooldownMessage) {
      return loc.verificationEmailCooldown;
    }
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

class _VerificationRecoveryPanel extends StatelessWidget {
  const _VerificationRecoveryPanel({
    required this.isLoading,
    required this.onResend,
    required this.onRetry,
    required this.loc,
  });

  final bool isLoading;
  final VoidCallback onResend;
  final VoidCallback onRetry;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.primaryContainer.withValues(alpha: 0.22),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.verifyEmailTitle,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.checkInboxPrompt,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: isLoading ? null : onResend,
                child: Text(loc.resendVerificationEmail),
              ),
              TextButton(
                onPressed: isLoading ? null : onRetry,
                child: Text(loc.iVerifiedTryAgain),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
