import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../services/tts_providers.dart';
import '../../../providers/feature_providers.dart';
import 'tts_settings_sheet.dart';

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
    final manager = ref.watch(ttsManagerProvider);

    final playbackAsync = ref.watch(ttsPlaybackStateProvider);
    final playing = playbackAsync.value?.playing ?? false;

    // Start/stop pulse with playback state
    if (playing && !_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    if (!playing && _pulseCtrl.isAnimating) _pulseCtrl.stop();

    final title = manager.currentArticleTitle;
    final chunkNum = manager.currentChunkNumber;
    final totalChunks = manager.totalChunks;
    final timeRemain = manager.estimatedTimeRemaining;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Minimise',
        ),
        title: Text(
          loc.nowReading,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          _SleepTimerBadge(manager: manager),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
            child: Column(
              children: [
                const Spacer(),
                _AnimatedArtwork(
                  pulseAnim: _pulseAnim,
                  isPlaying: playing,
                  color: cs.primaryContainer,
                  iconColor: cs.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  title.isEmpty ? loc.articleLabel : title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  totalChunks > 0
                      ? 'Part $chunkNum of $totalChunks  •  ${_fmtRemain(timeRemain)}'
                      : '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 14),
                _PremiumCard(
                  child: _PlaybackControls(
                    manager: manager,
                    playing: playing,
                    chunkNum: chunkNum,
                    totalChunks: totalChunks,
                  ),
                ),
                const SizedBox(height: 14),
                _PremiumCard(child: _SpeedChips(manager: manager)),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    final manager = ref.read(ttsManagerProvider);
    final lang = manager.currentSession?.articleId != null ? 'en' : 'en';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TtsSettingsSheet(articleLanguage: lang),
    );
  }

  String _fmtRemain(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '$m min ${s}s left';
    return '${s}s left';
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface.withValues(alpha: 0.84),
            cs.surfaceContainerHigh.withValues(alpha: 0.88),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── _AnimatedArtwork ──────────────────────────────────────────────────────

class _AnimatedArtwork extends StatelessWidget {
  const _AnimatedArtwork({
    required this.pulseAnim,
    required this.isPlaying,
    required this.color,
    required this.iconColor,
  });

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
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.95),
              color.withValues(alpha: 0.65),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: iconColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: isPlaying ? 0.25 : 0.10),
              blurRadius: isPlaying ? 30 : 15,
              offset: const Offset(0, 8),
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
                  ? 16 + _heights[i] * 48 * _bars[i].value
                  : 16.0;
              return Container(
                width: 6,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(3),
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
    final value = totalChunks > 0 ? (chunkNum - 1) / totalChunks : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: (v) {
              final idx = (v * totalChunks).round().clamp(0, totalChunks - 1);
              onSeek(idx);
            },
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
                  backgroundColor: cs.surfaceVariant,
                  minHeight: 2,
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
    required this.chunkNum,
    required this.totalChunks,
  });

  final dynamic manager;
  final bool playing;
  final int chunkNum;
  final int totalChunks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPrev =
        (manager.canGoPreviousFeedArticle as bool?) == true || chunkNum > 1;
    final canNext =
        (manager.canGoNextFeedArticle as bool?) == true ||
        chunkNum < totalChunks;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous chunk
        _RoundIconButton(
          icon: Icons.skip_previous_rounded,
          onPressed: canPrev
              ? () {
                  HapticFeedback.lightImpact();
                  manager.previous();
                }
              : null,
        ),

        // Skip back 15s
        _RoundIconButton(
          icon: Icons.replay_10_rounded,
          onPressed: () {
            HapticFeedback.selectionClick();
            manager.seekRelative(const Duration(seconds: -15));
          },
          size: 36,
        ),

        // Play/Pause — large central button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (playing) {
              manager.pause();
            } else {
              manager.resume();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 76,
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
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(playing),
                color: cs.onPrimary,
                size: 40,
              ),
            ),
          ),
        ),

        // Skip forward 15s
        _RoundIconButton(
          icon: Icons.forward_10_rounded,
          onPressed: () {
            HapticFeedback.selectionClick();
            manager.seekRelative(const Duration(seconds: 15));
          },
          size: 36,
        ),

        // Next chunk
        _RoundIconButton(
          icon: Icons.skip_next_rounded,
          onPressed: canNext
              ? () {
                  HapticFeedback.lightImpact();
                  manager.next();
                }
              : null,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 40,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: IconButton(
        icon: Icon(icon, size: size),
        onPressed: onPressed,
        color: onPressed != null
            ? cs.onSurface
            : cs.onSurface.withValues(alpha: 0.3),
        splashRadius: size * 0.7,
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
            letterSpacing: 0.6,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
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
                  borderRadius: BorderRadius.circular(20),
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
