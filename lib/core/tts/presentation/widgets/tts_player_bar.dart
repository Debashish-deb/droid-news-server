import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/tts_state.dart';
import '../providers/tts_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../presentation/features/tts/ui/tts_settings_sheet.dart';

class TtsPlayerBar extends ConsumerWidget {
  const TtsPlayerBar({
    this.onPreviousArticle,
    this.onNextArticle,
    this.canGoPreviousArticle = false,
    this.canGoNextArticle = false,
    super.key,
  });

  final VoidCallback? onPreviousArticle;
  final VoidCallback? onNextArticle;
  final bool canGoPreviousArticle;
  final bool canGoNextArticle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsControllerProvider);
    final ttsNotifier = ref.read(ttsControllerProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (ttsState.status == TtsStatus.idle ||
        ttsState.status == TtsStatus.stopped) {
      return const SizedBox.shrink();
    }

    final prevAction = (canGoPreviousArticle && onPreviousArticle != null)
        ? onPreviousArticle
        : ttsNotifier.previous;
    final nextAction = (canGoNextArticle && onNextArticle != null)
        ? onNextArticle
        : ttsNotifier.next;

    final gradientColors = <Color>[
      cs.primaryContainer.withValues(alpha: 0.95),
      cs.secondaryContainer.withValues(alpha: 0.95),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft highlight layer keeps the bar "fuzzy" while preserving contrast.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -1.0),
                  radius: 1.1,
                  colors: [
                    cs.onPrimaryContainer.withValues(alpha: 0.18),
                    cs.onPrimaryContainer.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 520;

                final controlsRow = _buildControlsRow(
                  ttsState,
                  ttsNotifier,
                  prevAction,
                  nextAction,
                  cs,
                );

                if (isCompact) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          _buildSettingsButton(context, cs),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusSection(context, ttsState, cs),
                          ),
                          const SizedBox(width: 4),
                          _buildCloseButton(ttsNotifier, cs),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: controlsRow,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    _buildSettingsButton(context, cs),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 6,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: controlsRow,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: _buildStatusSection(context, ttsState, cs),
                    ),
                    const SizedBox(width: 4),
                    _buildCloseButton(ttsNotifier, cs),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context, ColorScheme cs) {
    return IconButton(
      icon: Icon(
        Icons.settings_rounded,
        color: cs.onPrimaryContainer.withValues(alpha: 0.85),
        size: 20,
      ),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const TtsSettingsSheet(),
        );
      },
    );
  }

  Widget _buildCloseButton(TtsController ttsNotifier, ColorScheme cs) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        Icons.close_rounded,
        color: cs.onPrimaryContainer.withValues(alpha: 0.72),
        size: 20,
      ),
      onPressed: ttsNotifier.stop,
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    TtsState ttsState,
    ColorScheme cs,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getStatusText(context, ttsState.status),
          style: GoogleFonts.inter(
            color: cs.onPrimaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: ttsState.progressFraction > 0
              ? ttsState.progressFraction
              : null,
          backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation(cs.primary),
          minHeight: 2,
        ),
      ],
    );
  }

  Widget _buildControlsRow(
    TtsState ttsState,
    TtsController ttsNotifier,
    VoidCallback? prevAction,
    VoidCallback? nextAction,
    ColorScheme cs,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          icon: Icon(Icons.skip_previous_rounded, color: cs.onPrimaryContainer),
          onPressed: prevAction,
        ),
        IconButton(
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          icon: Icon(
            Icons.replay_10_rounded,
            color: cs.onPrimaryContainer.withValues(alpha: 0.9),
          ),
          onPressed: ttsNotifier.previous,
        ),
        _buildPlayPauseButton(
          ttsState,
          ttsNotifier,
          iconColor: cs.onPrimaryContainer,
        ),
        IconButton(
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          icon: Icon(
            Icons.forward_10_rounded,
            color: cs.onPrimaryContainer.withValues(alpha: 0.9),
          ),
          onPressed: ttsNotifier.next,
        ),
        IconButton(
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          icon: Icon(Icons.skip_next_rounded, color: cs.onPrimaryContainer),
          onPressed: nextAction,
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton(
    TtsState state,
    TtsController notifier, {
    required Color iconColor,
  }) {
    final isPlaying = state.status == TtsStatus.playing;
    final isLoading =
        state.status == TtsStatus.loading ||
        state.status == TtsStatus.buffering;

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
        ),
      );
    }

    return IconButton(
      iconSize: 36,
      icon: Icon(
        isPlaying
            ? Icons.pause_circle_filled_rounded
            : Icons.play_circle_filled_rounded,
        color: iconColor,
      ),
      onPressed: isPlaying ? notifier.pause : notifier.resume,
    );
  }

  String _getStatusText(BuildContext context, TtsStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case TtsStatus.loading:
        return l10n.ttsLoading;
      case TtsStatus.playing:
        return l10n.ttsReadingArticle;
      case TtsStatus.paused:
        return l10n.ttsPaused;
      case TtsStatus.buffering:
        return l10n.ttsBuffering;
      case TtsStatus.error:
        return l10n.ttsError;
      default:
        return "";
    }
  }
}
