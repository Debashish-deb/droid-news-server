import 'package:flutter/material.dart';
import '../../../../../core/theme/theme_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/generated/app_localizations.dart';

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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: ThemeSkeleton.shared.insetsOnly(bottom: 24),
      child: Center(
        child: Material(
          color: cs.surfaceContainerHigh,
          shape: StadiumBorder(
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: ThemeSkeleton.shared.insetsSymmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hideTtsButton) ...[
                    _ReaderBarButton(
                      icon: isTtsPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      onPressed: onTtsPressed,
                      color: cs.primary,
                      label: isTtsPlaying
                          ? AppLocalizations.of(context).readerStop
                          : AppLocalizations.of(context).readerListen,
                    ),
                    const SizedBox(width: ThemeSkeleton.size8),
                  ],
                  _ReaderBarButton(
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

class _ReaderBarButton extends StatelessWidget {
  const _ReaderBarButton({
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
    final cs = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: cs.onSurface,
        backgroundColor: color?.withValues(alpha: 0.10),
        padding: ThemeSkeleton.shared.insetsSymmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
      icon: Icon(icon, size: 20, color: color ?? cs.onSurface),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
