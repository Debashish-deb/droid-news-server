import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/tts/domain/entities/tts_state.dart';
import '../../../../core/tts/presentation/providers/tts_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../domain/models/tts_runtime_diagnostics.dart';
import '../services/tts_providers.dart';
import '../../../providers/feature_providers.dart';
import 'tts_settings_sheet.dart';
import '../../../widgets/premium_screen_header.dart';

/// Full-screen TTS player.
///
/// Enhancements vs original:
/// - Interactive seekable progress slider (tap/drag to jump between chunks)
/// - Live position/duration bar within the current chunk (via positionStream)
/// - Skip ±15 s buttons alongside previous/next chunk
/// - Inline speed chips — no modal dialog per tap
/// - Animated waveform artwork that pulses while playing
/// - Sleep-timer badge in the app bar
/// - "Part X of Y" instead of engineering "Chunk X/Y" jargon
/// - Author/subtitle is the article's stored author, not the articleId
/// - Proper animated play/pause transition

class FullAudioPlayer extends ConsumerStatefulWidget {
  const FullAudioPlayer({super.key});

  @override
  ConsumerState<FullAudioPlayer> createState() => _FullAudioPlayerState();
}

class _FullAudioPlayerState extends ConsumerState<FullAudioPlayer>
    with SingleTickerProviderStateMixin {
  // Artwork pulse animation
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final manager = ref.watch(appTtsCoordinatorProvider);
    final ttsState = ref.watch(ttsControllerProvider);

    final playbackAsync = ref.watch(ttsPlaybackStateProvider);
    final playing = playbackAsync.value?.playing ?? false;
    final diagnosticsAsync = ref.watch(ttsDiagnosticsProvider);
    final diagnostics = diagnosticsAsync.value ?? manager.currentDiagnostics;

    // Start/stop pulse with playback state
    if (playing && !_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    if (!playing && _pulseCtrl.isAnimating) _pulseCtrl.stop();

    final title = manager.currentArticleTitle;
    final chunkNum = manager.currentChunkNumber;
    final totalChunks = manager.totalChunks;
    final timeRemain = manager.estimatedTimeRemaining;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PremiumScreenHeader(
        title: loc.nowReading,
        leading: PremiumHeaderLeading.close,
        actions: [
          _SleepTimerBadge(manager: manager),
          PremiumHeaderIconButton(
            icon: Icons.settings_rounded,
            onPressed: () => _openSettings(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface,
              cs.surfaceContainerLow,
              cs.surfaceContainerHighest.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight < 760 || constraints.maxWidth < 360;
              final artworkSize = compact ? 112.0 : 148.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 20,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: compact ? 4 : 12),
                      _AnimatedArtwork(
                        size: artworkSize,
                        pulseAnim: _pulseAnim,
                        isPlaying: playing,
                        color: cs.primaryContainer,
                        iconColor: cs.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title.isEmpty ? loc.articleLabel : title,
                        style:
                            (compact
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.titleLarge)
                                ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _SessionMetaWrap(
                        chunkNum: chunkNum,
                        totalChunks: totalChunks,
                        timeRemain: timeRemain,
                        diagnostics: diagnostics,
                      ),
                      if (ttsState.status == TtsStatus.error ||
                          diagnostics.hasError) ...[
                        const SizedBox(height: 10),
                        _DiagnosticsCard(
                          diagnostics: diagnostics,
                          errorMessage:
                              ttsState.error ??
                              diagnostics.lastError ??
                              'Playback needs attention.',
                          onRetry: ref
                              .read(ttsControllerProvider.notifier)
                              .retry,
                          onOpenStudio: () => _openSettings(context),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _PremiumCard(
                        child: Column(
                          children: [
                            _ChunkProgressBar(
                              manager: manager,
                              chunkNum: chunkNum,
                              totalChunks: totalChunks,
                              onSeek: (idx) {
                                HapticFeedback.selectionClick();
                                manager.seekToChunk(idx);
                              },
                            ),
                            const SizedBox(height: 8),
                            _PositionBar(manager: manager),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PremiumCard(
                        child: _PlaybackControls(
                          manager: manager,
                          playing: playing,
                          ttsState: ttsState,
                          chunkNum: chunkNum,
                          totalChunks: totalChunks,
                          onRetry: ref
                              .read(ttsControllerProvider.notifier)
                              .retry,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PremiumCard(child: _SpeedChips(manager: manager)),
                      SizedBox(height: compact ? 8 : 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    final manager = ref.read(appTtsCoordinatorProvider);
    final lang =
        manager.currentSession?.articleLanguage ?? manager.currentLanguage;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TtsSettingsSheet(articleLanguage: lang),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.42)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface.withValues(alpha: 0.7),
            cs.surfaceContainerHigh.withValues(alpha: 0.74),
          ],
        ),
        boxShadow: const <BoxShadow>[],
      ),
      child: child,
    );
  }
}

// ── _AnimatedArtwork ──────────────────────────────────────────────────────

class _AnimatedArtwork extends StatelessWidget {
  const _AnimatedArtwork({
    required this.size,
    required this.pulseAnim,
    required this.isPlaying,
    required this.color,
    required this.iconColor,
  });

  final double size;
  final Animation<double> pulseAnim;
  final bool isPlaying;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) {
        return Transform.scale(
          scale: isPlaying ? pulseAnim.value : 1.0,
          child: child,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.95),
              color.withValues(alpha: 0.65),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: iconColor.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: isPlaying ? 0.16 : 0.06),
              blurRadius: isPlaying ? 16 : 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _WaveformIcon(color: iconColor, isPlaying: isPlaying),
      ),
    );
  }
}

// ── _WaveformIcon — simple animated bars ─────────────────────────────────

class _WaveformIcon extends StatefulWidget {
  const _WaveformIcon({required this.color, required this.isPlaying});
  final Color color;
  final bool isPlaying;
  @override
  State<_WaveformIcon> createState() => _WaveformIconState();
}

class _WaveformIconState extends State<_WaveformIcon>
    with TickerProviderStateMixin {
  late final List<AnimationController> _bars;
  static const _heights = [0.4, 0.7, 1.0, 0.7, 0.4, 0.6, 0.9];

  @override
  void initState() {
    super.initState();
    _bars = List.generate(_heights.length, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 70),
      );
      if (widget.isPlaying) ctrl.repeat(reverse: true);
      return ctrl;
    });
  }

  @override
  void didUpdateWidget(_WaveformIcon old) {
    super.didUpdateWidget(old);
    for (final c in _bars) {
      if (widget.isPlaying && !c.isAnimating) c.repeat(reverse: true);
      if (!widget.isPlaying && c.isAnimating) c.stop();
    }
  }

  @override
  void dispose() {
    for (final c in _bars) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_bars.length, (i) {
          return AnimatedBuilder(
            animation: _bars[i],
            builder: (_, _) {
              final height = widget.isPlaying
                  ? 12 + _heights[i] * 34 * _bars[i].value
                  : 12.0;
              return Container(
                width: 5,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ── _ChunkProgressBar — tap/drag to seek to any chunk ────────────────────

class _ChunkProgressBar extends StatelessWidget {
  const _ChunkProgressBar({
    required this.manager,
    required this.chunkNum,
    required this.totalChunks,
    required this.onSeek,
  });

  final dynamic manager;
  final int chunkNum;
  final int totalChunks;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lastIndex = totalChunks - 1;
    final currentIndex = (chunkNum - 1).clamp(0, lastIndex < 0 ? 0 : lastIndex);
    final value = lastIndex > 0 ? currentIndex / lastIndex : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: totalChunks > 1
                ? (v) {
                    final idx = (v * lastIndex).round().clamp(0, lastIndex);
                    onSeek(idx);
                  }
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Part $chunkNum',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            Text(
              'of $totalChunks',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

// ── _PositionBar — within-chunk position from positionStream ─────────────

class _PositionBar extends StatelessWidget {
  const _PositionBar({required this.manager});
  final dynamic manager;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<Duration>(
      stream: manager.positionStream as Stream<Duration>,
      builder: (context, posSnap) {
        return StreamBuilder<Duration>(
          stream: manager.durationStream as Stream<Duration>,
          builder: (context, durSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? Duration.zero;
            final progress = dur.inMilliseconds > 0
                ? pos.inMilliseconds / dur.inMilliseconds
                : 0.0;

            return Column(
              children: [
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: cs.surfaceContainerHighest,
                  minHeight: 3,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(pos),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _fmt(dur),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── _PlaybackControls ─────────────────────────────────────────────────────

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.manager,
    required this.playing,
    required this.ttsState,
    required this.chunkNum,
    required this.totalChunks,
    required this.onRetry,
  });

  final dynamic manager;
  final bool playing;
  final TtsState ttsState;
  final int chunkNum;
  final int totalChunks;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPrev =
        (manager.canGoPreviousFeedArticle as bool?) == true || chunkNum > 1;
    final canNext =
        (manager.canGoNextFeedArticle as bool?) == true ||
        chunkNum < totalChunks;
    final previousButton = _RoundIconButton(
      icon: Icons.skip_previous_rounded,
      size: 44,
      onPressed: canPrev
          ? () {
              HapticFeedback.lightImpact();
              manager.previous();
            }
          : null,
    );
    final nextButton = _RoundIconButton(
      icon: Icons.skip_next_rounded,
      size: 44,
      onPressed: canNext
          ? () {
              HapticFeedback.lightImpact();
              manager.next();
            }
          : null,
    );
    final rewindButton = _RoundIconButton(
      icon: Icons.replay_10_rounded,
      onPressed: () {
        HapticFeedback.selectionClick();
        manager.seekRelative(const Duration(seconds: -15));
      },
      size: 44,
      iconSize: 22,
    );
    final forwardButton = _RoundIconButton(
      icon: Icons.forward_10_rounded,
      onPressed: () {
        HapticFeedback.selectionClick();
        manager.seekRelative(const Duration(seconds: 15));
      },
      size: 44,
      iconSize: 22,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final isLoading =
            ttsState.status == TtsStatus.loading ||
            ttsState.status == TtsStatus.buffering;
        final isError = ttsState.status == TtsStatus.error;
        final playButton = GestureDetector(
          onTap: isLoading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  if (isError) {
                    onRetry();
                  } else if (playing) {
                    manager.pause();
                  } else {
                    manager.resume();
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.primary.withValues(alpha: 0.82)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: cs.onPrimary,
                      ),
                    )
                  : Icon(
                      isError
                          ? Icons.refresh_rounded
                          : playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey('${ttsState.status}_$playing'),
                      color: cs.onPrimary,
                      size: 36,
                    ),
            ),
          ),
        );

        if (!compact) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              previousButton,
              rewindButton,
              playButton,
              forwardButton,
              nextButton,
            ],
          );
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                previousButton,
                const SizedBox(width: 14),
                playButton,
                const SizedBox(width: 14),
                nextButton,
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                rewindButton,
                const SizedBox(width: 16),
                forwardButton,
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: IconButton(
          icon: Icon(icon, size: iconSize ?? size * 0.58),
          onPressed: onPressed,
          color: onPressed != null
              ? cs.onSurface
              : cs.onSurface.withValues(alpha: 0.3),
          splashRadius: size * 0.58,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            minimumSize: Size.square(size),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

// ── _SpeedChips — inline speed selection with no dialog per tap ───────────

class _SpeedChips extends StatefulWidget {
  const _SpeedChips({required this.manager});
  final dynamic manager;
  @override
  State<_SpeedChips> createState() => _SpeedChipsState();
}

class _SessionMetaWrap extends StatelessWidget {
  const _SessionMetaWrap({
    required this.chunkNum,
    required this.totalChunks,
    required this.timeRemain,
    required this.diagnostics,
  });

  final int chunkNum;
  final int totalChunks;
  final Duration timeRemain;
  final TtsRuntimeDiagnostics diagnostics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <String>[
      if (totalChunks > 0) 'Part $chunkNum of $totalChunks',
      _fmtRemain(timeRemain),
      if ((diagnostics.synthesisStrategy ?? '').isNotEmpty)
        diagnostics.synthesisStrategy!.replaceAll('_', ' '),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  String _fmtRemain(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '$m min ${s}s left';
    return '${s}s left';
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({
    required this.diagnostics,
    required this.errorMessage,
    required this.onRetry,
    required this.onOpenStudio,
  });

  final TtsRuntimeDiagnostics diagnostics;
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onOpenStudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final detailChips = <String>[
      if (diagnostics.chunkLabel != null) diagnostics.chunkLabel!,
      if ((diagnostics.synthesisStrategy ?? '').isNotEmpty)
        diagnostics.synthesisStrategy!.replaceAll('_', ' '),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Playback needs attention',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onErrorContainer,
            ),
          ),
          if (detailChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detailChips
                  .map(
                    (label) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenStudio,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Voice Studio'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedChipsState extends State<_SpeedChips> {
  static const _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  double _selected = 1.0;

  @override
  void initState() {
    super.initState();
    _selected = (widget.manager.currentSpeed as double).clamp(0.75, 2.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Playback speed',
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurfaceVariant,
            letterSpacing: 0,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _speeds.map((s) {
            final isActive = (_selected - s).abs() < 0.01;
            return GestureDetector(
              onTap: () {
                setState(() => _selected = s);
                widget.manager.setSpeed(s);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? cs.primary
                      : cs.surfaceContainerHighest.withValues(alpha: 0.92),
                  border: Border.all(
                    color: isActive
                        ? cs.primary.withValues(alpha: 0.45)
                        : cs.outlineVariant.withValues(alpha: 0.55),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$s×',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── _SleepTimerBadge ──────────────────────────────────────────────────────

class _SleepTimerBadge extends StatelessWidget {
  const _SleepTimerBadge({required this.manager});
  final dynamic manager;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<Duration?>(
      stream: manager.sleepTimerRemaining as Stream<Duration?>,
      builder: (context, snap) {
        final rem = snap.data;
        if (rem == null || rem <= Duration.zero) {
          return const SizedBox.shrink();
        }
        final m = rem.inMinutes;
        final s = (rem.inSeconds % 60).toString().padLeft(2, '0');
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Chip(
            avatar: Icon(Icons.bedtime_rounded, size: 14, color: cs.primary),
            label: Text(
              m > 0 ? '$m:$s' : '${rem.inSeconds}s',
              style: TextStyle(fontSize: 12, color: cs.primary),
            ),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: cs.primaryContainer,
          ),
        );
      },
    );
  }
}
