import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_chunk.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_config.dart';
import 'package:bdnewsreader/core/tts/domain/entities/voice_profile.dart';
import 'package:bdnewsreader/core/tts/domain/repositories/tts_repository.dart';
import 'package:bdnewsreader/core/tts/presentation/providers/tts_controller.dart';

class _FakeTtsRepository implements TtsRepository {
  final _chunkIndexController = StreamController<int>.broadcast();
  int? lastSeekIndex;

  @override
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;

  @override
  Stream<double> get progress => const Stream<double>.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(List<TtsChunk> chunks, int startIndex) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(int chunkIndex) async {
    lastSeekIndex = chunkIndex;
    _chunkIndexController.add(chunkIndex);
  }

  @override
  Future<void> stop() async {
    _chunkIndexController.add(-1);
  }

  @override
  Future<void> updateConfig(TtsConfig config) async {}

  @override
  Future<List<VoiceProfile>> getAvailableVoices() async =>
      const <VoiceProfile>[];
}

void main() {
  test(
    'seekToChunk delegates to repository and updates current chunk state',
    () async {
      final repo = _FakeTtsRepository();
      final controller = TtsController(repo);

      // We need to provide chunks to the controller so seekToChunk doesn't return early
      final List<TtsChunk> chunks = [
        TtsChunk(
          text: 'Chunk 0',
          index: 0,
          estimatedDuration: const Duration(seconds: 1),
        ),
        TtsChunk(
          text: 'Chunk 1',
          index: 1,
          estimatedDuration: const Duration(seconds: 1),
        ),
        TtsChunk(
          text: 'Chunk 2',
          index: 2,
          estimatedDuration: const Duration(seconds: 1),
        ),
        TtsChunk(
          text: 'Chunk 3',
          index: 3,
          estimatedDuration: const Duration(seconds: 1),
        ),
      ];
      await controller.playChunks(chunks);

      await controller.seekToChunk(3);

      expect(repo.lastSeekIndex, 3);
      expect(controller.state.currentChunk, 3);
    },
  );
}
