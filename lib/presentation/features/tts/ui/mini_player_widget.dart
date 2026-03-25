import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import '../domain/models/tts_session.dart';
import 'full_audio_player.dart';
import 'tts_settings_sheet.dart';
import '../../../providers/feature_providers.dart';

class MiniPlayerWidget extends ConsumerStatefulWidget {
  const MiniPlayerWidget({super.key});

  @override
  ConsumerState<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends ConsumerState<MiniPlayerWidget>
    with SingleTickerProviderStateMixin {
  static const double _swipeThreshold = 90.0;
  static const double _maxDrag = 180.0;

  // ── Drag state via ValueNotifier — no setState on every pixel ────────────
  final _dragOffset = ValueNotifier<double>(0.0);

  // ── Slide-back animation ──────────────────────────────────────────────────
  late final AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = _zeroSlide();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  Animation<Offset> _zeroSlide() => Tween<Offset>(
    begin: Offset.zero,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

  // ── Gesture handlers ──────────────────────────────────────────────────────

  void _onDragUpdate(DragUpdateDetails d) {
    final next = (_dragOffset.value + d.delta.dx).clamp(-_maxDrag, _maxDrag);
    _dragOffset.value = next;
  }

  void _onDragEnd(DragEndDetails _) {
    final offset = _dragOffset.value;
    final manager = ref.read(ttsManagerProvider);

    if (offset.abs() >= _swipeThreshold) {
      HapticFeedback.lightImpact();

      if (offset > 0) {
        manager.previous();
      } else {
        manager.next();
      }

      // Fly the widget in from the opposite direction
      _slideAnim = Tween<Offset>(
        begin: Offset(offset > 0 ? 0.6 : -0.6, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

      _slideCtrl.forward(from: 0.0);
    }

    // Reset drag offset — only ONE setState equivalent
    _dragOffset.value = 0.0;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manager = ref.watch(ttsManagerProvider);

    return StreamBuilder<int>(
      stream: manager.currentChunkIndex,
      builder: (context, snap) {
        final currentIndex = snap.data ?? -1;

        if (currentIndex < 0 ||
            manager.totalChunks == 0 ||
            manager.currentSession?.state == TtsSessionState.stopped) {
          return const SizedBox.shrink();
        }

        final chunkNum = manager.currentChunkNumber;
        final totalChunks = manager.totalChunks;
        final title = manager.currentArticleTitle;
        final timeRemain = manager.estimatedTimeRemaining;
        final timeText = _fmtTime(timeRemain);

        return Semantics(
          label:
              'Now playing part $chunkNum of $totalChunks from $title. $timeText remaining.',
          button: true,
          onIncrease: manager.next,
          onDecrease: manager.previous,
          child: GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FullAudioPlayer(),
                fullscreenDialog: true,
              ),
            ),
            // ── Transform reads ValueNotifier directly — zero rebuilds ────
            child: ValueListenableBuilder<double>(
              valueListenable: _dragOffset,
              builder: (_, offset, child) =>
                  Transform.translate(offset: Offset(offset, 0), child: child),
              child: SlideTransition(
                position: _slideAnim,
                child: _MiniPlayerCard(
                  scheme: scheme,
                  theme: theme,
                  title: title,
                  chunkNum: chunkNum,
                  totalChunks: totalChunks,
                  timeText: timeText,
                  manager: manager,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmtTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')} left' : '${s}s left';
  }
}

// ── _MiniPlayerCard — extracted so SlideTransition child is stable ────────

class _MiniPlayerCard extends StatelessWidget {
  const _MiniPlayerCard({
    required this.scheme,
    required this.theme,
    required this.title,
    required this.chunkNum,
    required this.totalChunks,
    required this.timeText,
    required this.manager,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final String title;
  final int chunkNum;
  final int totalChunks;
  final String timeText;
  final dynamic manager;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000), // Colors.black @ 15%
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Playback buttons ─────────────────────────────────────────────
          _PlaybackButtons(scheme: scheme, manager: manager),

          const SizedBox(width: 10),

          // ── Title + progress info ────────────────────────────────────────
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Part $chunkNum/$totalChunks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: const Color(0xB3000000),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '·',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: const Color(0xB3000000),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Settings ─────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 18),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const TtsSettingsSheet(),
            ),
            color: const Color(0x99000000),
            tooltip: 'Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),

          // ── Stop ─────────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              HapticFeedback.selectionClick();
              manager.stop();
            },
            color: const Color(0x99000000),
            tooltip: 'Stop',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── _PlaybackButtons — extracted to avoid full card rebuild ──────────────

class _PlaybackButtons extends StatelessWidget {
  const _PlaybackButtons({required this.scheme, required this.manager});
  final ColorScheme scheme;
  final dynamic manager;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: manager.playbackState as Stream<PlaybackState>,
      builder: (context, snap) {
        final ps = snap.data?.processingState ?? AudioProcessingState.idle;
        final playing = snap.data?.playing ?? false;
        final buffering =
            ps == AudioProcessingState.buffering ||
            ps == AudioProcessingState.loading;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 20),
              onPressed: () {
                HapticFeedback.selectionClick();
                manager.previous();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Previous',
            ),
            const SizedBox(width: 6),
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    color: scheme.primary.withValues(alpha: buffering ? 0.4 : 1.0),
                    size: 40,
                  ),
                  onPressed: buffering
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          if (playing) {
                            manager.pause();
                          } else {
                            manager.resume();
                          }
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (buffering)
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 20),
              onPressed: () {
                HapticFeedback.selectionClick();
                manager.next();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Next',
            ),
          ],
        );
      },
    );
  }
}
