import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import '../../infrastructure/services/auth/security_audit_service.dart';
import '../../infrastructure/persistence/auth/device_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/di/providers.dart';
import '../../core/theme/theme_skeleton.dart';
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
  static const Duration _initialValidationDelay = Duration(seconds: 12);
  static const Duration _validationCooldown = Duration(minutes: 10);
  static const Duration _activityUpdateCooldown = Duration(minutes: 2);

  bool _isValidating = false;
  ProviderSubscription? _startupSubscription;
  Timer? _initialValidationTimer;
  DateTime? _lastActivityUpdateAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _startupSubscription ??= ref.listenManual(startupControllerProvider, (
      prev,
      next,
    ) {
      if (next.isReady && next.firebaseReady) {
        _scheduleInitialValidation();
      }
    });

    // Safety delay to avoid premature access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final startup = ref.read(startupControllerProvider);
        if (startup.isReady && startup.firebaseReady) {
          _scheduleInitialValidation();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startupSubscription?.close();
    _initialValidationTimer?.cancel();
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

  void _scheduleInitialValidation() {
    if (_initialValidationTimer != null) {
      return;
    }

    _initialValidationTimer = Timer(_initialValidationDelay, () {
      _initialValidationTimer = null;
      if (!mounted) {
        return;
      }
      unawaited(_validateSession());
    });
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

    final securePrefs = ref.read(securePrefsProvider);
    final lastSuccessfulValidationAt = await securePrefs
        .getLastSuccessfulSessionValidationAt();
    if (DeviceSessionPolicy.canUseValidationGraceWindow(
      lastSuccessfulValidationAt,
      graceWindow: _validationCooldown,
    )) {
      return;
    }

    _isValidating = true;

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
      _isValidating = false;
    }
  }

  Future<void> _updateActivity() async {
    final lastUpdate = _lastActivityUpdateAt;
    if (lastUpdate != null &&
        DateTime.now().difference(lastUpdate) < _activityUpdateCooldown) {
      return;
    }

    try {
      _lastActivityUpdateAt = DateTime.now();
      await ref.read(deviceSessionServiceProvider).updateActivity();
    } catch (e) {
      _lastActivityUpdateAt = null;
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
            Icon(Icons.warning, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: ThemeSkeleton.size8),
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
