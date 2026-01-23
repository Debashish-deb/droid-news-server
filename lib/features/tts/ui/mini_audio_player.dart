import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../services/tts_providers.dart';
import '../services/tts_manager.dart';

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
            // Check if playing *this* article (or a chunk of it)
            // Our ID strategy for mediaItem was file path, which isn't articleId.
            // But we put articleTitle in title.
            // A better strategy is to store articleId in extras.
            // TtsManager put 'chunkIndex' in extras.
            // We should ask TtsManager for current article ID?
            // Or TtsManager could expose `currentArticleId`.
            
            // For now, let's rely on TtsManager state or assume single article context if playing.
            // If playing and title matches? Risk of duplicate titles.
            // Let's assume if it's playing, it's the active one.
            
            // Actually, TtsManager: `final mediaItem = MediaItem(..., id: audioPath, ...)`
            // We can't match ID.
            // But MiniPlayer is inside the screen.
            
            final bool isThisArticle = mediaItem?.title == title; 
            // Better: If isThisArticle, show controls. Else show Listen.
            
            if (isThisArticle && (processingState != AudioProcessingState.idle)) {
              return _buildPlayerControl(context, isPlaying, processingState);
            } else {
              // Idle or playing something else -> Show "Listen" button
              return _buildListenButton(context, processingState == AudioProcessingState.loading);
            }
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => _buildListenButton(context, false),
      error: (_, __) {
         // Show listen button on error (likely uninitialized state), but it will init on press
         return _buildListenButton(context, false);
      },
    );
  }

  Widget _buildListenButton(BuildContext context, bool isLoading) {
    final scheme = Theme.of(context).colorScheme;
    
    return FloatingActionButton.extended(
      heroTag: 'tts_listen_btn',
      onPressed: isLoading ? null : () {
        TtsManager.instance.speakArticle(articleId, title, content, language: language);
      },
      icon: isLoading 
          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: scheme.onPrimaryContainer, strokeWidth: 2))
          : const Icon(Icons.headset_rounded),
      label: Text(isLoading ? 'Loading...' : 'Listen'),
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    );
  }

  Widget _buildPlayerControl(BuildContext context, bool isPlaying, AudioProcessingState state) {
    final scheme = Theme.of(context).colorScheme;

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
          // Play/Pause
          IconButton(
            onPressed: () {
              if (isPlaying) {
                TtsManager.instance.pause();
              } else {
                TtsManager.instance.resume();
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

          // Status Text
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

          // Stop / Close
          IconButton(
            onPressed: () {
              TtsManager.instance.stop();
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
