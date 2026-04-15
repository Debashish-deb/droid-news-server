// lib/widgets/error_screen.dart

import 'package:flutter/foundation.dart';
import '../../core/theme/theme_skeleton.dart';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

/// A user-friendly error screen displayed when uncaught errors occur
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    required this.error,
    super.key,
    this.stackTrace,
    this.onRetry,
  });

  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: ThemeSkeleton.shared.insetsAll(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: ThemeSkeleton.shared.insetsAll(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: ThemeSkeleton.size32),

                  Text(
                    AppLocalizations.of(context).errorOops,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: ThemeSkeleton.size16),

                  Text(
                    AppLocalizations.of(context).errorUnexpected,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (kDebugMode) ...<Widget>[
                    const SizedBox(height: ThemeSkeleton.size24),
                    Container(
                      padding: ThemeSkeleton.shared.insetsAll(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade200,
                        borderRadius: ThemeSkeleton.shared.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppLocalizations.of(context).debugInfo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: ThemeSkeleton.size8),
                          Text(
                            error.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: ThemeSkeleton.size32),

                  if (onRetry != null)
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context).restartApp),
                      style: ElevatedButton.styleFrom(
                        padding: ThemeSkeleton.shared.insetsSymmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: ThemeSkeleton.shared.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
