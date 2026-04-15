import 'package:flutter/material.dart';
import '../../../../core/theme/theme_skeleton.dart';

import '../../../../domain/entities/news_article.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'webview_tokens.dart';

class WebHeader extends StatelessWidget {
  const WebHeader({
    required this.article,
    required this.progressNotifier,
    required this.reduceEffects,
    required this.cs,
    required this.isReader,
    required this.onBack,
    required this.onReaderToggle,
    required this.onTtsToggle,
    required this.ttsIcon,
    required this.onShare,
    this.onTtsSettings,
    this.onTranslate,
    this.showTtsButton = true,
    super.key,
  });

  final NewsArticle article;
  final ValueNotifier<double> progressNotifier;
  final bool reduceEffects;
  final ColorScheme cs;
  final bool isReader;
  final VoidCallback onBack;
  final VoidCallback onReaderToggle;
  final VoidCallback onTtsToggle;
  final IconData ttsIcon;
  final VoidCallback onShare;
  final VoidCallback? onTtsSettings;
  final VoidCallback? onTranslate;
  final bool showTtsButton;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).width < 390;
    final showDirectTtsSettings =
        showTtsButton && onTtsSettings != null && !compact;

    return Material(
      color: cs.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    _HeaderActionButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                      cs: cs,
                    ),
                    const SizedBox(width: ThemeSkeleton.size8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (article.source.isNotEmpty)
                            Text(
                              article.source.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          Text(
                            article.title,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ThemeSkeleton.size4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeaderActionButton(
                          icon: isReader
                              ? Icons.web_rounded
                              : Icons.article_rounded,
                          onTap: onReaderToggle,
                          cs: cs,
                        ),
                        if (showTtsButton)
                          _HeaderActionButton(
                            icon: ttsIcon,
                            onTap: onTtsToggle,
                            cs: cs,
                          ),
                        if (showDirectTtsSettings)
                          _HeaderActionButton(
                            icon: Icons.tune_rounded,
                            onTap: onTtsSettings!,
                            cs: cs,
                          ),
                        PopupMenuButton<String>(
                          tooltip: '',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          color: cs.surfaceContainerHighest,
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: ThemeSkeleton.shared.circular(12),
                          ),
                          onSelected: (value) {
                            if (value == 'translate' && onTranslate != null) {
                              onTranslate?.call();
                            }
                            if (value == 'tts_settings' &&
                                onTtsSettings != null) {
                              onTtsSettings?.call();
                            }
                            if (value == 'share') {
                              onShare();
                            }
                          },
                          itemBuilder: (context) => _buildMenuItems(context),
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, progress, _) =>
                    ReadingProgressBar(progress: progress),
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return <PopupMenuEntry<String>>[
      if (onTranslate != null)
        PopupMenuItem<String>(
          value: 'translate',
          child: Row(
            children: [
              Icon(
                Icons.translate_rounded,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: ThemeSkeleton.size12),
              Text(loc.translate),
            ],
          ),
        ),
      if (showTtsButton && onTtsSettings != null)
        PopupMenuItem<String>(
          value: 'tts_settings',
          child: Row(
            children: [
              Icon(Icons.tune_rounded, color: cs.onSurfaceVariant, size: 20),
              const SizedBox(width: ThemeSkeleton.size12),
              const Text('TTS Mode'),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'share',
        child: Row(
          children: [
            Icon(Icons.share_rounded, color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: ThemeSkeleton.size12),
            Text(loc.share),
          ],
        ),
      ),
    ];
  }
}

class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: ThemeSkeleton.shared.circular(999),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: WT.progressHeight,
          backgroundColor: cs.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: cs.onSurfaceVariant,
      style: IconButton.styleFrom(
        backgroundColor: cs.surfaceContainerHigh,
        foregroundColor: cs.onSurfaceVariant,
        minimumSize: const Size.square(48),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
