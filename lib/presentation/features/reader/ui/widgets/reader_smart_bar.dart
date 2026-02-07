import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderSmartBar extends ConsumerWidget {

  const ReaderSmartBar({
    required this.onSummaryPressed, required this.onTtsPressed, required this.onAppearancePressed, super.key,
    this.isTtsPlaying = false,
  });
  final VoidCallback onSummaryPressed;
  final VoidCallback onTtsPressed;
  final VoidCallback onAppearancePressed;
  final bool isTtsPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconButton(
                    icon: Icons.auto_awesome, // Sparkles for AI
                    onPressed: onSummaryPressed,
                    color: Colors.amber,
                    label: AppLocalizations.of(context).readerSummary,
                  ),
                  const SizedBox(width: 8),
                  _IconButton(
                    icon: isTtsPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    onPressed: onTtsPressed,
                    color: theme.colorScheme.primary,
                    label: isTtsPlaying ? AppLocalizations.of(context).readerStop : AppLocalizations.of(context).readerListen,
                  ),
                  const SizedBox(width: 8),
                  _IconButton(
                    icon: Icons.text_fields,
                    onPressed: onAppearancePressed,
                    label: AppLocalizations.of(context).readerFont,
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

class _IconButton extends StatelessWidget {

  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.label, this.color,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Subtle highlight if colored
          color: color?.withOpacity(0.1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? (isDark ? Colors.white : Colors.black87)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
