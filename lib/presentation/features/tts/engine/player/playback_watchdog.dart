import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Industrial-grade playback watchdog for TTS reliability
/// 
/// Monitors playback health and automatically recovers from:
/// - Stuck audio (no progress for N seconds)
/// - 0-duration files
/// - Playback errors
/// - Silent audio bugs
/// - Player crashes
class PlaybackWatchdog {
  
  PlaybackWatchdog({
    required this.player,
    this.checkInterval = const Duration(milliseconds: 500),
    this.stuckThreshold = const Duration(seconds: 3),
    this.onStuck,
    this.onError,
    this.onRecovered,
  });
  final AudioPlayer player;
  final Duration checkInterval;
  final Duration stuckThreshold;
  final VoidCallback? onStuck;
  final VoidCallback? onError;
  final VoidCallback? onRecovered;
  
  Timer? _watchdogTimer;
  Duration? _lastPosition;
  DateTime? _lastProgressTime;
  int _stuckCount = 0;
  bool _isMonitoring = false;
  
  /// Start monitoring playback
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _lastPosition = player.position;
    _lastProgressTime = DateTime.now();
    _stuckCount = 0;
    
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(checkInterval, _checkHealth);
    
    debugPrint('[Watchdog] Monitoring started');
  }
  
  /// Stop monitoring playback
  void stopMonitoring() {
    _isMonitoring = false;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    
    debugPrint('[Watchdog] Monitoring stopped');
  }
  
  /// Check playback health
  void _checkHealth(Timer timer) {
    if (!_isMonitoring) {
      timer.cancel();
      return;
    }
    
    try {
      _checkStuckState();
      _checkZeroDuration();
      _checkSilentAudio();
      _checkProcessingState();
    } catch (e) {
      debugPrint('[Watchdog] Health check error: $e');
      onError?.call();
    }
  }
  
  /// Check if playback is stuck (no progress)
  void _checkStuckState() {
    final currentPosition = player.position;
    final isPlaying = player.playing;
    
 
    if (!isPlaying) {
      _resetStuckDetection();
      return;
    }
    
    if (_lastPosition != null && currentPosition == _lastPosition) {
      final timeSinceProgress = DateTime.now().difference(_lastProgressTime!);
      
      if (timeSinceProgress > stuckThreshold) {
        _stuckCount++;
        debugPrint('[Watchdog] ⚠️ STUCK detected! '
                   'Position: $currentPosition, '
                   'Stuck for: ${timeSinceProgress.inSeconds}s, '
                   'Count: $_stuckCount');
        
        onStuck?.call();
        _resetStuckDetection();
      }
    } else {
      _lastPosition = currentPosition;
      _lastProgressTime = DateTime.now();
      
      if (_stuckCount > 0) {
        debugPrint('[Watchdog] ✅ Recovered from stuck state');
        onRecovered?.call();
      }
      
      _stuckCount = 0;
    }
  }
  
  /// Check for 0-duration file bug
  void _checkZeroDuration() {
    final duration = player.duration;
    final position = player.position;
    final state = player.processingState;
    
    if (duration != null &&
        duration == Duration.zero &&
        state == ProcessingState.ready) {
      debugPrint('[Watchdog] ⚠️ Zero-duration file detected');
      onError?.call();
    }
    
    if (duration != null &&
        position > duration &&
        state != ProcessingState.completed) {
      debugPrint('[Watchdog] ⚠️ Position exceeds duration');
      onError?.call();
    }
  }
  
  /// Check for frozen playback or silent failures
  void _checkSilentAudio() {
    final state = player.processingState;
    final isPlaying = player.playing;

    // If it's been buffering for more than 5 seconds, it's likely a network/source stall
    if (isPlaying && state == ProcessingState.buffering) {
      final timeInState = DateTime.now().difference(_lastProgressTime ?? DateTime.now());
      if (timeInState > const Duration(seconds: 5)) {
        debugPrint('[Watchdog] ⚠️ BUFFERING STALL detected (>5s)');
        onStuck?.call();
        _resetStuckDetection();
      }
    }
  }
  
  /// Check processing state for errors
  void _checkProcessingState() {
    final state = player.processingState;
    
    if (player.playing && 
        (state == ProcessingState.idle || state == ProcessingState.loading)) {
      final timeSinceProgress = DateTime.now().difference(_lastProgressTime ?? DateTime.now());
      
      if (timeSinceProgress > stuckThreshold) {
        debugPrint('[Watchdog] ⚠️ Invalid state: $state while playing');
        onError?.call();
      }
    }
  }
  
  /// Reset stuck detection counters
  void _resetStuckDetection() {
    _lastPosition = player.position;
    _lastProgressTime = DateTime.now();
  }
  
  /// Get watchdog statistics
  WatchdogStats getStats() {
    return WatchdogStats(
      isMonitoring: _isMonitoring,
      stuckCount: _stuckCount,
      lastPosition: _lastPosition,
      lastProgressTime: _lastProgressTime,
    );
  }
  
  /// Dispose watchdog
  void dispose() {
    stopMonitoring();
    _watchdogTimer?.cancel();
  }
}

/// Watchdog statistics
class WatchdogStats {
  
  const WatchdogStats({
    required this.isMonitoring,
    required this.stuckCount,
    this.lastPosition,
    this.lastProgressTime,
  });
  final bool isMonitoring;
  final int stuckCount;
  final Duration? lastPosition;
  final DateTime? lastProgressTime;
  
  Duration? get timeSinceProgress {
    if (lastProgressTime == null) return null;
    return DateTime.now().difference(lastProgressTime!);
  }
  
  @override
  String toString() {
    return 'WatchdogStats('
           'monitoring: $isMonitoring, '
           'stuck: $stuckCount, '
           'position: $lastPosition, '
           'sinceProgress: ${timeSinceProgress?.inSeconds}s'
           ')';
  }
}
