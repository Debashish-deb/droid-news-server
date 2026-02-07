import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/tts_state.dart';
import '../providers/tts_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'dart:ui';

class TtsPlayerBar extends ConsumerWidget {
  const TtsPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsControllerProvider);
    final ttsNotifier = ref.read(ttsControllerProvider.notifier);
    final theme = Theme.of(context);

    if (ttsState.status == TtsStatus.idle || ttsState.status == TtsStatus.stopped) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      height: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                // Previous
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                  onPressed: ttsNotifier.previous,
                ),
                
                // Play/Pause
                _buildPlayPauseButton(ttsState, ttsNotifier),
                
                // Next
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                  onPressed: ttsNotifier.next,
                ),
                
                const SizedBox(width: 10),
                
                // Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusText(context, ttsState.status),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: ttsState.progress > 0 ? ttsState.progress : null,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                        minHeight: 2,
                      ),
                    ],
                  ),
                ),
                
                // Close
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: ttsNotifier.stop,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(TtsState state, TtsController notifier) {
    final isPlaying = state.status == TtsStatus.playing;
    final isLoading = state.status == TtsStatus.loading || state.status == TtsStatus.buffering;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    return IconButton(
      iconSize: 36,
      icon: Icon(
        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
        color: Colors.white,
      ),
      onPressed: isPlaying ? notifier.pause : notifier.resume,
    );
  }

  String _getStatusText(BuildContext context, TtsStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case TtsStatus.loading: return l10n.ttsLoading;
      case TtsStatus.playing: return l10n.ttsReadingArticle;
      case TtsStatus.paused: return l10n.ttsPaused;
      case TtsStatus.buffering: return l10n.ttsBuffering;
      case TtsStatus.error: return l10n.ttsError;
      default: return "";
    }
  }
}
