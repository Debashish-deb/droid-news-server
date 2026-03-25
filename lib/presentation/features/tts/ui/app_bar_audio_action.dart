import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../../l10n/generated/app_localizations.dart';

import '../services/tts_providers.dart';
import '../../../providers/feature_providers.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/navigation/app_paths.dart';

// App Bar Action for TTS Control (Headset Icon)
class AppBarAudioAction extends ConsumerWidget {
  const AppBarAudioAction({
    required this.articleId,
    required this.title,
    required this.content,
    this.language = 'en',
    this.author,
    this.imageSource,
    super.key,
  });

  final String articleId;
  final String title;
  final String content;
  final String language;
  final String? author;
  final String? imageSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final playbackStateAsync = ref.watch(ttsPlaybackStateProvider);
    final mediaItemAsync = ref.watch(ttsMediaItemProvider);

    final playbackState = playbackStateAsync.value;
    final mediaItem = mediaItemAsync.value;

    final bool isPlaying = playbackState?.playing ?? false;
    final bool isBuffering =
        playbackState?.processingState == AudioProcessingState.buffering ||
        playbackState?.processingState == AudioProcessingState.loading;

    final bool isCurrentItem = mediaItem?.id == articleId;

    final bool effectivePlaying = isCurrentItem && isPlaying;
    final bool effectiveBuffering = isCurrentItem && isBuffering;

    if (effectiveBuffering) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    }

    return Semantics(
      label: effectivePlaying
          ? loc.stopReadingArticle(title)
          : loc.listenToArticle(title),
      button: true,
      enabled: true,
      hint: effectivePlaying ? loc.tapToStop : loc.tapToStart,
      child: IconButton(
        icon: Icon(
          effectivePlaying
              ? Icons.stop_circle_outlined
              : Icons.headset_mic_rounded,
          size: 28,
        ),
        tooltip: effectivePlaying ? loc.readerStop : loc.readerListen,
        onPressed: () async {
          debugPrint(
            "TTS_DEBUG: Button Pressed. EffectivePlaying=$effectivePlaying",
          );
          if (effectivePlaying) {
            ref.read(ttsManagerProvider).stop();
          } else {
            final subRepo = ref.read(subscriptionRepoProvider);
            final canUseResult = await subRepo.canUseTts();

            if (!context.mounted) return;

            final canUse = canUseResult.fold((l) => false, (r) => r);

            if (!canUse) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Daily limit reached. Upgrade for unlimited.',
                  ),
                  action: SnackBarAction(
                    label: loc.upgrade,
                    onPressed: () =>
                        context.push(AppPaths.subscriptionManagement),
                  ),
                ),
              );
              return;
            }

            // Increment usage and play
            await subRepo.incrementTtsUsage();

            debugPrint("TTS_DEBUG: Requesting speakArticle: $title");
            ref
                .read(ttsManagerProvider)
                .speakArticle(
                  articleId,
                  title,
                  content,
                  language: language,
                  author: author,
                  imageSource: imageSource,
                );
          }
        },
      ),
    );
  }
}
