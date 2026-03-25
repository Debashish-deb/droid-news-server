import 'dart:async' show FutureOr, unawaited;

import 'package:flutter/material.dart';
import '../../../../domain/entities/news_article.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'webview_tokens.dart';

// ─────────────────────────────────────────────
// PREMIUM HEADER
// Accepts a ValueNotifier<double> for progress so only
// the progress bar repaints on load changes, not the entire header.
// ─────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    final base = cs.onSurface;
    final surfaceTone = cs.surface;
    final content = Container(
      decoration: BoxDecoration(
        color: surfaceTone,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.55),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: WT.headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  HeaderIconBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (article.source.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                article.source.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary.withValues(alpha: 0.95),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          Text(
                            article.title,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: base.withValues(alpha: 0.95),
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  HeaderIconBtn(
                    icon: isReader ? Icons.web_rounded : Icons.article_rounded,
                    onTap: onReaderToggle,
                  ),
                  HeaderIconBtn(icon: ttsIcon, onTap: onTtsToggle),
                  if (onTtsSettings != null)
                    HeaderIconBtn(
                      icon: Icons.tune_rounded,
                      onTap: onTtsSettings!,
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: base.withValues(alpha: 0.65),
                    ),
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    onSelected: (value) {
                      if (value == 'translate' && onTranslate != null) {
                        onTranslate?.call();
                      }
                      if (value == 'tts_settings' && onTtsSettings != null) {
                        onTtsSettings?.call();
                      }
                      if (value == 'share') onShare();
                    },
                    itemBuilder: (context) {
                      final loc = AppLocalizations.of(context);
                      return [
                        if (onTranslate != null)
                          PopupMenuItem(
                            value: 'translate',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.translate_rounded,
                                  color: base.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  loc.translate,
                                  style: TextStyle(
                                    color: base.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (onTtsSettings != null)
                          PopupMenuItem(
                            value: 'tts_settings',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  color: base.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'TTS Mode',
                                  style: TextStyle(
                                    color: base.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(
                                Icons.share_rounded,
                                color: base.withValues(alpha: 0.7),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                loc.share,
                                style: TextStyle(
                                  color: base.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            // ValueListenableBuilder → only the progress bar repaints.
            RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, progress, childWidget) =>
                    ReadingProgressBar(progress: progress),
              ),
            ),
          ],
        ),
      ),
    );
    return content;
  }
}

class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({required this.progress, super.key});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: WT.progressHeight,
      child: Stack(
        children: [
          const ColoredBox(color: WT.progressGoldBg, child: SizedBox.expand()),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 150),
            widthFactor: progress.clamp(0.0, 1.0),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB8892B), Color(0xFFD4A853)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x55D4A853),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderIconBtn extends StatefulWidget {
  const HeaderIconBtn({required this.icon, required this.onTap, super.key});
  final IconData icon;
  final FutureOr<void> Function() onTap;

  @override
  State<HeaderIconBtn> createState() => _HeaderIconBtnState();
}

class _HeaderIconBtnState extends State<HeaderIconBtn> {
  bool _pressed = false;

  void _triggerTap() {
    final result = widget.onTap();
    if (result is Future<void>) {
      unawaited(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    final color = base.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: _triggerTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: _pressed ? WT.toolPress : WT.toolRelease,
        curve: _pressed ? Curves.easeIn : Curves.elasticOut,
        child: AnimatedContainer(
          duration: WT.toolPress,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
          ),
          child: Icon(widget.icon, size: 19, color: color),
        ),
      ),
    );
  }
}
