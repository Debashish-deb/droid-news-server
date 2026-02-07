import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../domain/models/tts_session.dart';
import 'full_audio_player.dart';
import 'tts_settings_sheet.dart';
import '../../../providers/feature_providers.dart';

// Mini player widget that appears at the bottom of the screen during TTS playback
// Supports swipe gestures to navigate between chunks
class MiniPlayerWidget extends ConsumerStatefulWidget {
  const MiniPlayerWidget({super.key});

  @override
  ConsumerState<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends ConsumerState<MiniPlayerWidget> 
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  static const double _swipeThreshold = 100.0;
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-200.0, 200.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() >= _swipeThreshold) {
      if (_dragOffset > 0) {
        ref.read(ttsManagerProvider).previousChunk();
      } else {
        ref.read(ttsManagerProvider).nextChunk();
      }
      
    
      _slideAnimation = Tween<Offset>(
        begin: Offset(_dragOffset > 0 ? 1.0 : -1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ));
      
      _slideController.forward(from: 0.0);
    }
    
    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final manager = ref.watch(ttsManagerProvider);
    
    return StreamBuilder<int>(
      stream: manager.currentChunkIndex,
      builder: (context, chunkSnapshot) {
        final currentIndex = chunkSnapshot.data ?? -1;
        
        if (currentIndex < 0 || manager.totalChunks == 0 || manager.currentSession?.state == TtsSessionState.stopped) {
          return const SizedBox.shrink();
        }

        final chunkNumber = manager.currentChunkNumber;
        final totalChunks = manager.totalChunks;
        final title = manager.currentArticleTitle;
        final timeRemaining = manager.estimatedTimeRemaining;
    
        final minutes = timeRemaining.inMinutes;
        final seconds = timeRemaining.inSeconds % 60;
        final timeText = minutes > 0 
            ? '$minutes:${seconds.toString().padLeft(2, '0')} left'
            : '$seconds sec left';
            
        return Semantics(
          label: 'Now playing chunk $chunkNumber of $totalChunks from $title. $timeText remaining.',
          button: true,
          onIncrease: () => manager.nextChunk(),
          onDecrease: () => manager.previousChunk(),
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FullAudioPlayer(),
                  fullscreenDialog: true,
                ),
              );
            },
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                    
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, size: 22),
                            onPressed: () => manager.previousChunk(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Previous',
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder<PlaybackState>(
                            stream: manager.playbackState,
                            builder: (context, stateSnapshot) {
                              final playing = stateSnapshot.data?.playing ?? false;
                              final processingState = stateSnapshot.data?.processingState ?? AudioProcessingState.idle;
                              final isBuffering = processingState == AudioProcessingState.buffering || 
                                                processingState == AudioProcessingState.loading;
                              
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                      color: scheme.primary.withOpacity(isBuffering ? 0.5 : 1.0),
                                      size: 42,
                                    ),
                                    onPressed: isBuffering ? null : (playing ? manager.pause : manager.resume),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: playing ? 'Pause' : 'Play',
                                  ),
                                  if (isBuffering)
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.primary,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, size: 22),
                            onPressed: () => manager.nextChunk(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Next',
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 16),
                      
                   
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
                                  'Chunk $chunkNumber/$totalChunks',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: scheme.onPrimaryContainer.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: TextStyle(color: scheme.onPrimaryContainer.withOpacity(0.5)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: scheme.onPrimaryContainer.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
              
                      IconButton(
                        icon: const Icon(Icons.settings_rounded, size: 20),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const TtsSettingsSheet(),
                          );
                        },
                        color: scheme.onPrimaryContainer.withOpacity(0.6),
                        tooltip: 'Settings',
                      ),
                      
                  
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => manager.stop(),
                        color: scheme.onPrimaryContainer.withOpacity(0.6),
                        tooltip: 'Stop',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}
