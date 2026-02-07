import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../infrastructure/services/device_session_service.dart';
import '../../infrastructure/services/security_audit_service.dart';

/// Widget that validates device sessions on app lifecycle changes
class SessionValidator extends StatefulWidget {

  const SessionValidator({required this.child, super.key});
  final Widget child;

  @override
  State<SessionValidator> createState() => _SessionValidatorState();
}

class _SessionValidatorState extends State<SessionValidator>
    with WidgetsBindingObserver {
  final DeviceSessionService _deviceSession = DeviceSessionService();
  final SecurityAuditService _auditService = SecurityAuditService();
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _validateSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);


    if (state == AppLifecycleState.resumed) {
      _validateSession();
      _updateActivity();
    }
  }

  Future<void> _validateSession() async {
    if (_isValidating) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isValidating = true);

    try {
      final isValid = await _deviceSession.validateSession();

      if (!isValid && mounted) {
        await _auditService.logEvent(
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
      await _deviceSession.updateActivity();
    } catch (e) {
      debugPrint('[SessionValidator] Activity update failed: $e');
    }
  }

  void _showSessionRevokedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Session Ended'),
              ],
            ),
            content: const Text(
              'Your session on this device has been ended.\n\n'
              'This may have happened because:\n'
              '• You logged out from another device\n'
              '• Your account exceeded device limits\n'
              '• Security precaution\n\n'
              'Please login again to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
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
