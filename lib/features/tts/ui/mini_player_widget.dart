import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tts_manager.dart';

/// Mini player widget that appears at the bottom of the screen during TTS playback
/// Supports swipe gestures to navigate between chunks
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
      // Clamp drag to prevent excessive dragging
      _dragOffset = _dragOffset.clamp(-200.0, 200.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() >= _swipeThreshold) {
      if (_dragOffset > 0) {
        // Swipe right - Previous chunk
        TtsManager.instance.previousChunk();
      } else {
        // Swipe left - Next chunk
        TtsManager.instance.nextChunk();
      }
      
      // Animate slide
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
    final manager = TtsManager.instance;
    
    // Only show if chunks exist
    if (manager.totalChunks == 0) {
      return const SizedBox.shrink();
    }

    final chunkNumber = manager.currentChunkNumber;
    final totalChunks = manager.totalChunks;
    final title = manager.currentArticleTitle;
    final timeRemaining = manager.estimatedTimeRemaining;
    
    // Format time remaining
    final minutes = timeRemaining.inMinutes;
    final seconds = timeRemaining.inSeconds % 60;
    final timeText = minutes > 0 
        ? '$minutes:${seconds.toString().padLeft(2, '0')} left'
        : '$seconds sec left';

    return Semantics(
      label: 'Now playing chunk $chunkNumber of $totalChunks from $title. $timeText remaining.',
      button: true,
      onIncrease: () => TtsManager.instance.nextChunk(),
      onDecrease: () => TtsManager.instance.previousChunk(),
      child: GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Play/Pause button
                  IconButton(
                    icon: Icon(
                      Icons.pause_circle_filled,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    onPressed: () => TtsManager.instance.pause(),
                    tooltip: 'Pause',
                  ),
                  const SizedBox(width: 12),
                  
                  // Content column
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        
                        // Progress info
                        Row(
                          children: [
                            Text(
                              'Chunk $chunkNumber/$totalChunks',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Stop button
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () => TtsManager.instance.stop(),
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
}
