import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/navigation_helper.dart';
import '../../domain/entities/tts_state.dart';
import '../providers/tts_controller.dart';
import 'reader_tts_settings_sheet.dart';
import '../../../../l10n/generated/app_localizations.dart';

class TtsPlayerBar extends ConsumerWidget {
  const TtsPlayerBar({
    this.onPreviousArticle,
    this.onNextArticle,
    this.canGoPreviousArticle = false,
    this.canGoNextArticle = false,
    this.showAutoPlayControls = true,
    super.key,
  });

  final VoidCallback? onPreviousArticle;
  final VoidCallback? onNextArticle;
  final bool canGoPreviousArticle;
  final bool canGoNextArticle;
  final bool showAutoPlayControls;

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

    final prevAction = onPreviousArticle ?? ttsNotifier.previous;
    final nextAction = onNextArticle ?? ttsNotifier.next;

    final gradientColors = <Color>[
      cs.primaryContainer.withValues(alpha: 0.95),
      cs.secondaryContainer.withValues(alpha: 0.95),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: const <BoxShadow>[],
      ),
      child: Stack(
        children: [
          // Soft highlight layer keeps the bar "fuzzy" while preserving contrast.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          _buildFullPlayerButton(context, cs),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusSection(context, ttsState, cs),
                          ),
                          const SizedBox(width: 4),
                          _buildCloseButton(ttsNotifier, cs),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(child: controlsRow),
                    ],
                  );
                }

                return Row(
                  children: [
                    _buildSettingsButton(context, cs),
                    _buildFullPlayerButton(context, cs),
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
      style: IconButton.styleFrom(minimumSize: const Size.square(44)),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ReaderTtsSettingsSheet(
            showAutoPlayControls: showAutoPlayControls,
          ),
        );
      },
    );
  }

  Widget _buildFullPlayerButton(BuildContext context, ColorScheme cs) {
    return IconButton(
      icon: Icon(
        Icons.open_in_full_rounded,
        color: cs.onPrimaryContainer.withValues(alpha: 0.85),
        size: 20,
      ),
      style: IconButton.styleFrom(minimumSize: const Size.square(44)),
      onPressed: () => NavigationHelper.openFullAudioPlayer<void>(context),
    );
  }

  Widget _buildCloseButton(TtsController ttsNotifier, ColorScheme cs) {
    return IconButton(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        padding: EdgeInsets.zero,
      ),
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
          style: TextStyle(
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
        _buildTransportButton(
          icon: Icons.skip_previous_rounded,
          onPressed: prevAction,
          cs: cs,
          iconSize: 26,
        ),
        const SizedBox(width: 6),
        _buildTransportButton(
          icon: Icons.replay_10_rounded,
          onPressed: () =>
              ttsNotifier.seekRelative(const Duration(seconds: -10)),
          cs: cs,
          size: 42,
        ),
        const SizedBox(width: 8),
        _buildPlayPauseButton(ttsState, ttsNotifier, cs: cs),
        const SizedBox(width: 8),
        _buildTransportButton(
          icon: Icons.forward_10_rounded,
          onPressed: () =>
              ttsNotifier.seekRelative(const Duration(seconds: 10)),
          cs: cs,
          size: 42,
        ),
        const SizedBox(width: 6),
        _buildTransportButton(
          icon: Icons.skip_next_rounded,
          onPressed: nextAction,
          cs: cs,
          iconSize: 26,
        ),
      ],
    );
  }

  Widget _buildTransportButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ColorScheme cs,
    double size = 44,
    double iconSize = 24,
    bool primary = false,
  }) {
    final backgroundColor = primary
        ? cs.primary
        : cs.surface.withValues(alpha: 0.28);
    final foregroundColor = primary ? cs.onPrimary : cs.onPrimaryContainer;
    final borderColor = primary
        ? cs.primary.withValues(alpha: 0.9)
        : cs.outlineVariant.withValues(alpha: 0.75);

    return Material(
      color: backgroundColor,
      shape: CircleBorder(
        side: BorderSide(color: borderColor, width: primary ? 1.8 : 1.4),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: iconSize, color: foregroundColor),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(
    TtsState state,
    TtsController notifier, {
    required ColorScheme cs,
  }) {
    final isPlaying = state.status == TtsStatus.playing;
    final isLoading =
        state.status == TtsStatus.loading ||
        state.status == TtsStatus.buffering;
    final isError = state.status == TtsStatus.error;

    if (isLoading) {
      return Material(
        color: cs.primary,
        shape: CircleBorder(
          side: BorderSide(
            color: cs.primary.withValues(alpha: 0.95),
            width: 1.8,
          ),
        ),
        child: SizedBox.square(
          dimension: 52,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: cs.onPrimary,
              ),
            ),
          ),
        ),
      );
    }

    if (isError) {
      return _buildTransportButton(
        icon: Icons.refresh_rounded,
        onPressed: notifier.retry,
        cs: cs,
        size: 52,
        iconSize: 28,
        primary: true,
      );
    }

    return _buildTransportButton(
      icon: isPlaying
          ? Icons.pause_circle_filled_rounded
          : Icons.play_circle_filled_rounded,
      onPressed: isPlaying ? notifier.pause : notifier.resume,
      cs: cs,
      size: 52,
      iconSize: 32,
      primary: true,
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
