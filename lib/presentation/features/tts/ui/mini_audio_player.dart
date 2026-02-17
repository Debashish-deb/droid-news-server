import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../services/tts_providers.dart';
import '../../../providers/feature_providers.dart';

import '../services/tts_manager.dart' show TtsManager;

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
    final playbackStateAsync = ref.watch(ttsPlaybackStateProvider);
    final mediaItemAsync = ref.watch(ttsMediaItemProvider);

    return playbackStateAsync.when(
      data: (state) {
        final isPlaying = state.playing;
        final processingState = state.processingState;
        
        return mediaItemAsync.when(
          data: (mediaItem) {
            final currentId = mediaItem?.id;
            
            
            
            final bool isThisArticle = mediaItem?.title == title; 
            
            if (isThisArticle && (processingState != AudioProcessingState.idle)) {
              return _buildPlayerControl(context, ref, isPlaying, processingState);
            } else {
              return _buildListenButton(context, ref, processingState == AudioProcessingState.loading);
            }
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => _buildListenButton(context, ref, false),
      error: (_, __) {
         return _buildListenButton(context, ref, false);
      },
    );
  }

  Widget _buildListenButton(BuildContext context, WidgetRef ref, bool isLoading) {
    final scheme = Theme.of(context).colorScheme;
    
    return FloatingActionButton.extended(
      heroTag: 'tts_listen_btn',
      onPressed: isLoading ? null : () {
        ref.read(ttsManagerProvider).speakArticle(articleId, title, content, language: language);
      },
      icon: isLoading 
          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: scheme.onPrimaryContainer, strokeWidth: 2))
          : const Icon(Icons.headset_rounded),
      label: Text(isLoading ? 'Loading...' : 'Listen'),
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    );
  }

  Widget _buildPlayerControl(BuildContext context, WidgetRef ref, bool isPlaying, AudioProcessingState state) {
    final scheme = Theme.of(context).colorScheme;
    final manager = ref.read(ttsManagerProvider);

    return Container(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
         
          IconButton(
            onPressed: () {
              final ttsManager = ref.read(ttsManagerProvider);
              if (isPlaying) {
                ttsManager.pause();
              } else {
                ttsManager.resume();
              }
            },
            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            color: scheme.onPrimaryContainer,
            tooltip: isPlaying ? 'Pause' : 'Resume',
          ),
          
          if (state == AudioProcessingState.buffering)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 8.0),
               child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimaryContainer)),
             )
          else 
             const SizedBox(width: 8),


          Flexible(
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
          
          const SizedBox(width: 8),

        
          IconButton(
            onPressed: () {
              ref.read(ttsManagerProvider).stop();
            },
            icon: const Icon(Icons.stop_rounded),
            color: scheme.onPrimaryContainer.withOpacity(0.8),
            tooltip: 'Stop',
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
