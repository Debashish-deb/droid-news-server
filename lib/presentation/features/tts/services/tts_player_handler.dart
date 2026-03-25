import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../engine/player/playback_watchdog.dart';

/// Audio handler that bridges just_audio with audio_service.
///
/// Key design decisions vs original:
/// - [onChunkCompleted] is a REQUIRED constructor parameter so there is never
///   a window where ProcessingState.completed fires before the callback is
///   wired — the original nullable post-construction assignment caused chunks
///   to silently fail to advance.
/// - [_isStopping] flag prevents the completion callback from firing during a
///   manual stop(), closing the race condition that could restart playback on
///   a cleared session.
/// - Word-boundary progress is forwarded on [wordProgress] for UI highlighting.
class TtsPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  TtsPlayerHandler({required this.onChunkCompleted}) {
    _watchdog = PlaybackWatchdog(
      player: _player,
      onStuck: () {
        debugPrint('[TtsPlayerHandler] Watchdog: stuck, skipping chunk.');
        _maybeCompleteChunk();
      },
      onError: () {
        debugPrint('[TtsPlayerHandler] Watchdog: error, skipping chunk.');
        _maybeCompleteChunk();
      },
    );

    _player.playbackEventStream.listen(_broadcastState);

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        debugPrint('[TtsPlayerHandler] Chunk completed naturally.');
        _watchdog.stopMonitoring();
        _maybeCompleteChunk();
      }
    });

    // Forward position to enable seek-within-chunk in the UI
    _player.positionStream.listen((pos) {
      _positionController.add(pos);
    });

    _player.durationStream.listen((dur) {
      if (dur != null) _durationController.add(dur);
    });
  }

  // ── Required callback (no nullable window) ─────────────────────────────────
  final void Function() onChunkCompleted;

  // ── Internal state ─────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();
  late final PlaybackWatchdog _watchdog;

  /// Set to true during stop() to block the completion callback from
  /// triggering nextChunk() while the session is being torn down.
  bool _isStopping = false;

  // ── Streams ────────────────────────────────────────────────────────────────
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  Duration get currentPosition => _player.position;
  Duration? get currentDuration => _player.duration;

  // ── Safe completion ────────────────────────────────────────────────────────

  void _maybeCompleteChunk() {
    if (_isStopping) {
      debugPrint('[TtsPlayerHandler] Completion ignored (stop in progress).');
      return;
    }
    onChunkCompleted();
  }

  // ── State broadcast ────────────────────────────────────────────────────────

  void _broadcastState(PlaybackEvent event) {
    final processingStateMap = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    };

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState:
            processingStateMap[_player.processingState] ??
            AudioProcessingState.idle,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  // ── BaseAudioHandler overrides ─────────────────────────────────────────────

  @override
  Future<void> play() async {
    _isStopping = false;
    _watchdog.startMonitoring();
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _watchdog.stopMonitoring();
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    // Raise the flag BEFORE stopping the player so any in-flight completion
    // event is suppressed before it can call onChunkCompleted.
    _isStopping = true;
    _watchdog.stopMonitoring();
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  // ── Custom actions ─────────────────────────────────────────────────────────

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    debugPrint('[TtsPlayerHandler] playFromUri: ${uri.path}');
    try {
      _isStopping = false;

      final item = MediaItem(
        id: uri.path,
        album: extras?['album'] as String? ?? 'Reading',
        title: extras?['title'] as String? ?? 'Article',
        artist: extras?['artist'] as String? ?? 'News Reader',
        extras: extras,
      );

      mediaItem.add(item);
      await _player.setFilePath(uri.path);
      _watchdog.startMonitoring();
      await _player.play();

      debugPrint('[TtsPlayerHandler] Playback started: ${uri.path}');
    } catch (e, st) {
      debugPrint('[TtsPlayerHandler] playFromUri error: $e\n$st');
      _watchdog.stopMonitoring();
      rethrow;
    }
  }

  /// Seek forward/backward within the current chunk for "skip 10s" controls.
  Future<void> seekRelative(Duration offset) async {
    final pos = _player.position;
    final dur = _player.duration ?? Duration.zero;
    final candidate = pos + offset;
    final clampedMicros = candidate.inMicroseconds.clamp(
      0,
      dur.inMicroseconds,
    );
    final next = Duration(microseconds: clampedMicros);
    await _player.seek(next);
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  void dispose() {
    _watchdog.dispose();
    _player.dispose();
    _positionController.close();
    _durationController.close();
  }
}
