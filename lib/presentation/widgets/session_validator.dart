import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../infrastructure/services/auth/security_audit_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/di/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget that validates device sessions on app lifecycle changes
class SessionValidator extends ConsumerStatefulWidget {
  const SessionValidator({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<SessionValidator> createState() => _SessionValidatorState();
}

class _SessionValidatorState extends ConsumerState<SessionValidator>
    with WidgetsBindingObserver {
  bool _isValidating = false;
  ProviderSubscription? _startupSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _startupSubscription ??= ref.listenManual(startupControllerProvider, (
      prev,
      next,
    ) {
      if (next.isReady && next.firebaseReady) {
        _validateSession();
      }
    });

    // Safety delay to avoid premature access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final startup = ref.read(startupControllerProvider);
        if (startup.isReady && startup.firebaseReady) {
          _validateSession();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startupSubscription?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      final startup = ref.read(startupControllerProvider);
      if (startup.isReady && startup.firebaseReady) {
        _validateSession();
        _updateActivity();
      }
    }
  }

  Future<void> _validateSession() async {
    if (_isValidating) return;

    final startup = ref.read(startupControllerProvider);
    if (!startup.firebaseReady || Firebase.apps.isEmpty) {
      return;
    }

    // Double check current user via FirebaseAuth safely
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isValidating = true);

    try {
      final isValid = await ref
          .read(deviceSessionServiceProvider)
          .validateSession();

      if (!isValid && mounted) {
        await ref.read(securityAuditServiceProvider).logEvent(
          SecurityEventType.sessionValidationFailed,
          {'reason': 'session_revoked_or_expired'},
        );

        await FirebaseAuth.instance.signOut();

        if (mounted) {
          _showSessionRevokedDialog();
        }
      }
    } catch (e) {
      debugPrint('[SessionValidator] Validation failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  Future<void> _updateActivity() async {
    try {
      await ref.read(deviceSessionServiceProvider).updateActivity();
    } catch (e) {
      debugPrint('[SessionValidator] Activity update failed: $e');
    }
  }

  void _showSessionRevokedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).sessionEnded),
          ],
        ),
        content: Text(AppLocalizations.of(context).sessionEndedDesc),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
