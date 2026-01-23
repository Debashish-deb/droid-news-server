// lib/features/security/security_lockout_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/l10n/app_localizations.dart';

class SecurityLockoutScreen extends StatelessWidget {
  const SecurityLockoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.security_rounded,
                size: 80,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Security Alert',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your device does not meet the security requirements to run this application. \n\n'
                'This may be due to:\n'
                '• Rooted/Jailbroken device\n'
                '• Debugger attached\n'
                '• Hooking framework detected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Text(AppLocalizations.of(context)!.exit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
