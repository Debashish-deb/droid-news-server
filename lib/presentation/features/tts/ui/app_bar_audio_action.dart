import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import '../services/tts_providers.dart';
import '../../../providers/feature_providers.dart';
import '../../../providers/premium_providers.dart' show isPremiumProvider;
import 'package:go_router/go_router.dart';

// App Bar Action for TTS Control (Headset Icon)
class AppBarAudioAction extends ConsumerWidget {
  const AppBarAudioAction({
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
        ? 'Stop reading article: $title'
        : 'Listen to article with text-to-speech: $title',
      button: true,
      enabled: true,
      hint: effectivePlaying 
        ? 'Tap to stop playback'
        : 'Tap to start reading article aloud',
      child: IconButton(
        icon: Icon(
          effectivePlaying ? Icons.stop_circle_outlined : Icons.headset_mic_rounded,
          size: 28,
        ),
        tooltip: effectivePlaying ? 'Stop Reading' : 'Listen to Article',
        onPressed: () {
          debugPrint("TTS_DEBUG: Button Pressed. EffectivePlaying=$effectivePlaying");
          if (effectivePlaying) {
            ref.read(ttsManagerProvider).stop();
          } else {
            final bool isPremium = ref.read(isPremiumProvider);
            if (!isPremium) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✨ Audio Listen is a Premium feature.'),
                  action: SnackBarAction(
                    label: 'Upgrade',
                    onPressed: () => context.push('/subscription'),
                  ),
                ),
              );
              return;
            }

            debugPrint("TTS_DEBUG: Requesting speakArticle: $title");
            ref.read(ttsManagerProvider).speakArticle(
              articleId,
              title,
              content,
              language: language,
            );
          }
        },
      ),
    );
  }
}
