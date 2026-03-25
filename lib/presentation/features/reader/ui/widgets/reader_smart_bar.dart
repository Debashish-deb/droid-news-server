import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderSmartBar extends ConsumerWidget {
  const ReaderSmartBar({
    required this.onTtsPressed,
    required this.onAppearancePressed,
    super.key,
    this.isTtsPlaying = false,
    this.hideTtsButton = false,
  });
  final VoidCallback onTtsPressed;
  final VoidCallback onAppearancePressed;
  final bool isTtsPlaying;
  final bool hideTtsButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                color: cs.surfaceContainerHigh.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.65),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Only show the TTS button when TtsPlayerBar
                    // is NOT already visible (avoids duplicate controls).
                    if (!hideTtsButton) ...[
                      _IconButton(
                        icon: isTtsPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        onPressed: onTtsPressed,
                        color: theme.colorScheme.primary,
                        label: isTtsPlaying
                            ? AppLocalizations.of(context).readerStop
                            : AppLocalizations.of(context).readerListen,
                      ),
                      const SizedBox(width: 8),
                    ],
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
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.label,
    this.color,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Subtle highlight if colored
          color: color?.withValues(alpha: 0.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color ?? cs.onSurface),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}
