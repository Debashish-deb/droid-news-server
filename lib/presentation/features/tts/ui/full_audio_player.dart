import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tts_providers.dart';
import '../../../providers/feature_providers.dart';

/// Full screen audio player for TTS
/// 
/// Shows:
/// - Article Title/Author
/// - Large playback controls (Play/Pause, Skip)
/// - Progress (Chunk info)
/// - Speed control (Future enhancement)
class FullAudioPlayer extends ConsumerWidget {
  const FullAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final manager = ref.watch(ttsManagerProvider);
    
   
    final playbackStateAsync = ref.watch(ttsPlaybackStateProvider);
    final mediaItemAsync = ref.watch(ttsMediaItemProvider);
    
    final playing = playbackStateAsync.value?.playing ?? false;
    final mediaItem = mediaItemAsync.value;
    final title = mediaItem?.title ?? manager.currentArticleTitle;
    
    return StreamBuilder<int>(
      stream: manager.currentChunkIndex,
      builder: (context, snapshot) {
        final chunkIndex = (snapshot.data ?? (manager.currentChunkNumber - 1));
        final chunkNumber = chunkIndex + 1;
        final totalChunks = manager.totalChunks;
        
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Now Reading'),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.audiotrack_rounded,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                ),
                
                const SizedBox(height: 32),
                
              
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  manager.currentSession?.articleId ?? 'Article', 
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                
                const SizedBox(height: 32),
                
            
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: totalChunks > 0 ? chunkNumber / totalChunks : 0,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$chunkNumber / $totalChunks chunks'),
                        Text(
                          _formatDuration(manager.estimatedTimeRemaining),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
               
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                 
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded),
                      iconSize: 48,
                      onPressed: chunkNumber > 1 ? manager.previousChunk : null,
                    ),
                    
           
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: theme.colorScheme.onPrimary,
                        ),
                        iconSize: 48,
                        onPressed: playing ? manager.pause : manager.resume,
                      ),
                    ),
                    
                 
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded),
                      iconSize: 48,
                      onPressed: chunkNumber < totalChunks ? manager.nextChunk : null,
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                   
                    IconButton(
                      icon: const Icon(Icons.speed),
                      onPressed: () {
                         showDialog(
                           context: context,
                           builder: (context) => SimpleDialog(
                             title: const Text('Playback Speed'),
                             children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => 
                               SimpleDialogOption(
                                 child: Text('${s}x'),
                                 onPressed: () {
                                   manager.setSpeed(s);
                                   Navigator.pop(context);
                                 },
                               )
                             ).toList(),
                           ),
                         );
                      },
                      tooltip: 'Playback Speed',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }
  
  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

