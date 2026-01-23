import 'package:flutter/material.dart';

/// Reusable error widget for displaying failures with retry option
class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final Color? iconColor;
  
  const ErrorDisplay({
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.iconColor,
    super.key,
  });
  
  /// Factory for network errors
  factory ErrorDisplay.network({VoidCallback? onRetry}) {
    return ErrorDisplay(
      message: 'No internet connection.\nPlease check your network.',
      icon: Icons.wifi_off,
      onRetry: onRetry,
    );
  }
  
  /// Factory for loading errors
  factory ErrorDisplay.loadFailed({String? what, VoidCallback? onRetry}) {
    return ErrorDisplay(
      message: 'Failed to load ${what ?? 'content'}.\nTap to retry.',
      icon: Icons.cloud_off,
      onRetry: onRetry,
    );
  }
  
  /// Factory for empty state
  factory ErrorDisplay.empty({String? what}) {
    return ErrorDisplay(
      message: 'No ${what ?? 'items'} found.',
      icon: Icons.inbox_outlined,
      iconColor: Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor ?? (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading indicator with optional message
class LoadingDisplay extends StatelessWidget {
  final String? message;
  
  const LoadingDisplay({this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white60 
                    : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
