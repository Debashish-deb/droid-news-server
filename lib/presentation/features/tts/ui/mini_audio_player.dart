// mini_audio_player.dart
// mini_audio_player.dart
// ═══════════════════════════════════════════════════════════════════════════
//
// The FAB-style "Listen" button / compact player shown on the article detail
// page (above the bottom nav bar).
//
// Key fixes vs original:
// - heroTag: 'tts_listen_${articleId}' — unique per article so two articles
//   visible simultaneously (e.g. in a split-screen or master-detail layout)
//   don't throw a Hero conflict crash.
// - Uses ref.read (not ref.read inside a callback) for the manager to avoid
//   double-read on re-render.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:go_router/go_router.dart';

import '../services/tts_providers.dart';
import '../../../providers/feature_providers.dart';
import '../../../../core/navigation/app_paths.dart';

class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({
    required this.articleId,
    required this.title,
    required this.content,
    this.language = 'en',
    super.key,
  });

  final String articleId;
  final String title;
  final String content;
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackAsync = ref.watch(ttsPlaybackStateProvider);
    final mediaAsync = ref.watch(ttsMediaItemProvider);

    return playbackAsync.when(
      data: (state) {
        final playing = state.playing;
        final ps = state.processingState;
        final mediaItem = mediaAsync.value;
        final isThis = mediaItem?.extras?['articleId'] == articleId;

        if (isThis && ps != AudioProcessingState.idle) {
          return _PlayerControl(
            articleId: articleId,
            isPlaying: playing,
            state: ps,
          );
        }
        return _ListenButton(
          articleId: articleId,
          title: title,
          content: content,
          language: language,
          isLoading: ps == AudioProcessingState.loading && isThis,
        );
      },
      loading: () => _ListenButton(
        articleId: articleId,
        title: title,
        content: content,
        language: language,
        isLoading: false,
      ),
      error: (_, _) => _ListenButton(
        articleId: articleId,
        title: title,
        content: content,
        language: language,
        isLoading: false,
      ),
    );
  }
}

// ── _ListenButton ─────────────────────────────────────────────────────────

class _ListenButton extends ConsumerWidget {
  const _ListenButton({
    required this.articleId,
    required this.title,
    required this.content,
    required this.language,
    required this.isLoading,
  });

  final String articleId;
  final String title;
  final String content;
  final String language;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Hero(
      tag: 'tts_btn_$articleId',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () => _onTap(context, ref),
          borderRadius: BorderRadius.circular(30),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer,
                  scheme.primaryContainer.withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: scheme.onPrimaryContainer,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    Icons.headset_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  isLoading ? 'Loading...' : 'Listen',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();

    final subRepo = ref.read(subscriptionRepoProvider);
    final canUseResult = await subRepo.canUseTts();

    if (!context.mounted) return;

    final canUse = canUseResult.fold((_) => false, (r) => r);
    if (!canUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Daily limit reached. Upgrade for unlimited TTS.',
          ),
          action: SnackBarAction(
            label: 'Upgrade',
            onPressed: () => context.push(AppPaths.subscriptionManagement),
          ),
        ),
      );
      return;
    }

    await subRepo.incrementTtsUsage();
    ref
        .read(ttsManagerProvider)
        .speakArticle(articleId, title, content, language: language);
  }
}

// ── _PlayerControl ────────────────────────────────────────────────────────

class _PlayerControl extends ConsumerWidget {
  const _PlayerControl({
    required this.articleId,
    required this.isPlaying,
    required this.state,
  });

  final String articleId;
  final bool isPlaying;
  final AudioProcessingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final manager = ref.read(ttsManagerProvider);
    final buffering = state == AudioProcessingState.buffering;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (isPlaying) {
                manager.pause();
              } else {
                manager.resume();
              }
            },
            color: scheme.onPrimaryContainer,
            tooltip: isPlaying ? 'Pause' : 'Resume',
          ),

          if (buffering)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            )
          else
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  isPlaying ? 'Listening...' : 'Paused',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // Stop
          IconButton(
            icon: const Icon(Icons.stop_rounded, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              manager.stop();
            },
            color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
            tooltip: 'Stop',
          ),
        ],
      ),
    );
  }
}
