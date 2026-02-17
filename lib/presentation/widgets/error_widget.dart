import '../../core/architecture/failure.dart';
import 'package:flutter/material.dart' show Colors, ElevatedButton, Icons, ScaffoldMessenger, SizedBox, SnackBar, SnackBarAction, SnackBarBehavior, TextAlign, TextButton, Theme;
import 'package:flutter/rendering.dart' show EdgeInsets, MainAxisAlignment, TextStyle;
import 'package:flutter/widgets.dart' show Border, BorderRadius, BoxDecoration, BuildContext, Center, Column, Container, Expanded, FontWeight, Icon, Padding, RoundedRectangleBorder, Row, StatelessWidget, Text, VoidCallback, Widget;
import '../../l10n/generated/app_localizations.dart';

/// Widget to display errors with retry actions
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({required this.error, this.onRetry, super.key});

  final AppFailure error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
           
            Text(error.icon, style: const TextStyle(fontSize: 64)),

            const SizedBox(height: 24),

     
            Text(
              error.userMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 32),

       
            if (error.actionLabel != null || onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(error.actionLabel ?? AppLocalizations.of(context).retry),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact error banner for smaller spaces
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.error, this.onRetry, super.key});

  final AppFailure error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(error.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.userMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (error.actionLabel != null || onRetry != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(error.actionLabel ?? AppLocalizations.of(context).retry),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error snackbar helper
class ErrorSnackBar {
  static void show(
    BuildContext context,
    AppFailure error, {
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(error.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(error.userMessage)),
          ],
        ),
        action:
            (error.actionLabel != null || onRetry != null)
                ? SnackBarAction(
                  label: error.actionLabel ?? AppLocalizations.of(context).retry,
                  onPressed: onRetry ?? () {},
                )
                : null,
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
