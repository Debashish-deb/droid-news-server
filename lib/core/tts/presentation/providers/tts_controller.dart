import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/tts_repository_impl.dart' show TtsRepositoryImpl;
import '../../domain/entities/tts_chunk.dart';
import '../../domain/entities/tts_config.dart';
import '../../domain/entities/tts_state.dart';
import '../../domain/entities/voice_profile.dart';
import '../../domain/repositories/tts_repository.dart';
import '../../data/chunking/chunk_scheduler.dart';
import '../../data/engines/flutter_tts_engine.dart';
import '../../data/engines/tts_engine.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final ttsEngineProvider = Provider<TtsEngine>((ref) {
  final engine = FlutterTtsEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final ttsRepositoryProvider = Provider<TtsRepositoryImpl>((ref) {
  final engine = ref.watch(ttsEngineProvider);
  final repo = TtsRepositoryImpl(engine)..init();
  ref.onDispose(repo.dispose);
  return repo;
});

final ttsControllerProvider =
    StateNotifierProvider<TtsController, TtsState>((ref) {
  final repo = ref.watch(ttsRepositoryProvider);
  return TtsController(repo);
});

// ─── Controller ───────────────────────────────────────────────────────────────

class TtsController extends StateNotifier<TtsState> {
  TtsController(this._repo) : super(TtsState.idle()) {
    _listenToRepo();
  }

  final TtsRepository _repo;
  final List<StreamSubscription> _subscriptions = [];

  // Keep a reference to the current chunk list so next()/previous() work
  // without going back through the repository.
  List<TtsChunk> _chunks = [];

  // ─── Repo listeners ────────────────────────────────────────────────────

  void _listenToRepo() {
    _subscriptions.add(
      _repo.currentChunkIndex.listen((index) {
        if (!mounted) return;
        if (index == -1) {
          // Article finished or stopped
          state = TtsState.idle();
          _chunks = [];
        } else {
          state = state.copyWith(
            status: TtsStatus.playing,
            currentChunk: index,
            totalChunks: _chunks.length,
          );
        }
      }),
    );

    _subscriptions.add(
      _repo.progress.listen((p) {
        if (!mounted) return;
        state = state.copyWith(progressFraction: p);
      }),
    );
  }

  // ─── Main entry points ─────────────────────────────────────────────────

  /// Full article play — builds chunks then starts humanized engine.
  Future<void> playFromText(
    String text, {
    String? title,
    String? author,
    String? imageSource,
    String language = 'en',
    HumanizationConfig? humanization,
    int startChunkIndex = 0,
  }) async {
    if (text.trim().isEmpty) return;

    state = state.copyWith(status: TtsStatus.loading);

    try {
      // Apply custom humanization preset before speaking
      if (humanization != null) {
        await _repo.updateConfig(
          TtsConfig.defaults().copyWith(humanization: humanization),
        );
      }

      // Build display-layer chunks (for UI highlighting)
      _chunks = ChunkScheduler.buildChunks(
        text,
        title: title,
        author: author,
        imageSource: imageSource,
        language: language,
      );

      state = state.copyWith(
        status: TtsStatus.playing,
        currentChunk: startChunkIndex,
        totalChunks: _chunks.length,
        language: language,
      );

      await _repo.play(_chunks, startChunkIndex);
    } catch (e) {
      state = state.copyWith(
        status: TtsStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Plays a pre-built chunk list (e.g. from cache or unit tests).
  Future<void> playChunks(List<TtsChunk> chunks, {int startIndex = 0}) async {
    if (chunks.isEmpty) return;

    _chunks = chunks;
    state = state.copyWith(
      status: TtsStatus.playing,
      currentChunk: startIndex,
      totalChunks: chunks.length,
    );

    await _repo.play(chunks, startIndex);
  }

  // ─── Playback controls ─────────────────────────────────────────────────

  Future<void> pause() async {
    if (state.status != TtsStatus.playing) return;
    await _repo.pause();
    state = state.copyWith(status: TtsStatus.paused);
  }

  Future<void> resume() async {
    if (state.status != TtsStatus.paused) return;
    await _repo.resume();
    state = state.copyWith(status: TtsStatus.playing);
  }

  Future<void> stop() async {
    await _repo.stop();
    state = TtsState.idle();
    _chunks = [];
  }

  Future<void> togglePlayPause() async {
    switch (state.status) {
      case TtsStatus.playing:
        await pause();
      case TtsStatus.paused:
        await resume();
      default:
        break;
    }
  }

  // ─── Seeking / navigation ──────────────────────────────────────────────

  Future<void> seekToChunk(int chunkIndex) async {
    if (chunkIndex < 0 || chunkIndex >= _chunks.length) return;
    state = state.copyWith(status: TtsStatus.playing, currentChunk: chunkIndex);
    await _repo.seek(chunkIndex);
  }

  Future<void> next() async {
    final next = state.currentChunk + 1;
    if (next < _chunks.length) await seekToChunk(next);
  }

  Future<void> previous() async {
    final prev = state.currentChunk - 1;
    if (prev >= 0) await seekToChunk(prev);
  }

  // ─── Configuration ─────────────────────────────────────────────────────

  Future<void> updateConfig(TtsConfig config) async {
    await _repo.updateConfig(config);
    state = state.copyWith(config: config);
  }

  Future<void> setHumanization(HumanizationConfig config) async {
    await _repo.updateConfig(state.config.copyWith(humanization: config));
    state = state.copyWith(config: state.config.copyWith(humanization: config));
  }

  Future<void> setRate(double rate) async {
    await _repo.updateConfig(state.config.copyWith(rate: rate));
    state = state.copyWith(config: state.config.copyWith(rate: rate));
  }

  Future<void> setPitch(double pitch) async {
    await _repo.updateConfig(state.config.copyWith(pitch: pitch));
    state = state.copyWith(config: state.config.copyWith(pitch: pitch));
  }

  Future<void> setVoice(VoiceProfile voice) async {
    await _repo.updateConfig(state.config.copyWith(voice: voice.name));
    state = state.copyWith(config: state.config.copyWith(voice: voice.name));
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _repo.stop();
    super.dispose();
  }

  // ─── Queries ───────────────────────────────────────────────────────────

  TtsChunk? get currentChunk {
    final idx = state.currentChunk;
    if (idx < 0 || idx >= _chunks.length) return null;
    return _chunks[idx];
  }

  List<TtsChunk> get chunks => List.unmodifiable(_chunks);
}