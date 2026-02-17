import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tts_chunk.dart';
import '../../domain/entities/tts_state.dart';
import '../../domain/repositories/tts_repository.dart';
import '../../data/chunking/chunk_scheduler.dart';
import '../../data/repositories/tts_repository_impl.dart';
import '../../data/engines/flutter_tts_engine.dart';

final ttsEngineProvider = Provider((ref) => FlutterTtsEngine());

final ttsRepositoryProvider = Provider<TtsRepository>((ref) {
  final engine = ref.watch(ttsEngineProvider);
  return TtsRepositoryImpl(engine)..init();
});

final ttsControllerProvider = StateNotifierProvider<TtsController, TtsState>((ref) {
  final repository = ref.watch(ttsRepositoryProvider);
  return TtsController(repository);
});

class TtsController extends StateNotifier<TtsState> {

  TtsController(this._repo) : super(TtsState.idle()) {
    _listenToRepo();
  }
  final TtsRepository _repo;

  void _listenToRepo() {
    _repo.currentChunkIndex.listen((index) {
      if (index == -1) {
        state = state.copyWith(status: TtsStatus.stopped, currentChunk: 0);
      } else {
        state = state.copyWith(status: TtsStatus.playing, currentChunk: index);
      }
    });
  }

  Future<void> playFromText(
    String text, {
    String? title,
    String? author,
    String? imageSource,
    String language = 'en',
  }) async {
    if (text.isEmpty) return;
    
    state = state.copyWith(status: TtsStatus.loading);
    
    try {
      final chunks = ChunkScheduler.buildChunks(
        text,
        title: title,
        author: author,
        imageSource: imageSource,
        language: language,
      );
      await playChunks(chunks);
    } catch (e) {
      state = state.copyWith(status: TtsStatus.error, error: e.toString());
    }
  }

  Future<void> playChunks(List<TtsChunk> chunks, {int startIndex = 0}) async {
    if (chunks.isEmpty) return;
    
    state = state.copyWith(status: TtsStatus.playing, currentChunk: startIndex);
    await _repo.play(chunks, startIndex);
  }

  Future<void> pause() async {
    await _repo.pause();
    state = state.copyWith(status: TtsStatus.paused);
  }

  Future<void> resume() async {
    await _repo.resume();
    state = state.copyWith(status: TtsStatus.playing);
  }

  Future<void> stop() async {
    await _repo.stop();
    state = TtsState.idle();
  }

  Future<void> next() async {
    await _repo.seek(state.currentChunk + 1);
  }

  Future<void> previous() async {
    if (state.currentChunk > 0) {
      await _repo.seek(state.currentChunk - 1);
    }
  }
}
