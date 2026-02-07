import 'dart:async';
import '../engines/tts_engine.dart';
import '../../domain/entities/tts_chunk.dart';
import '../../domain/entities/tts_config.dart';
import '../../domain/entities/voice_profile.dart';
import '../../domain/repositories/tts_repository.dart';

class TtsRepositoryImpl implements TtsRepository {

  TtsRepositoryImpl(this._engine);
  final TtsEngine _engine;
  final _chunkIndexController = StreamController<int>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  
  List<TtsChunk> _currentChunks = [];
  int _currentIndex = -1;
  TtsConfig _config = const TtsConfig();

  @override
  Future<void> init() async {
    await _engine.init();
    _engine.events.listen(_handleEngineEvent);
  }

  void _handleEngineEvent(TtsEngineEvent event) {
    switch (event.type) {
      case TtsEngineEventType.completion:
        _playNext();
        break;
      case TtsEngineEventType.error:
        // Handle error, maybe retry or notify
        break;
      case TtsEngineEventType.progress:
        // Update word-level progress if needed
        break;
      default:
        break;
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex < _currentChunks.length - 1) {
      _currentIndex++;
      _chunkIndexController.add(_currentIndex);
      await _engine.speak(_currentChunks[_currentIndex].text);
    }
  }

  @override
  Future<void> play(List<TtsChunk> chunks, int startIndex) async {
    _currentChunks = chunks;
    _currentIndex = startIndex;
    _chunkIndexController.add(_currentIndex);
    await _engine.speak(_currentChunks[_currentIndex].text);
  }

  @override
  Future<void> pause() async {
    await _engine.pause();
  }

  @override
  Future<void> resume() async {
    if (_currentIndex >= 0 && _currentIndex < _currentChunks.length) {
      await _engine.speak(_currentChunks[_currentIndex].text);
    }
  }

  @override
  Future<void> stop() async {
    _currentIndex = -1;
    _currentChunks = [];
    _chunkIndexController.add(-1);
    await _engine.stop();
  }

  @override
  Future<void> seek(int chunkIndex) async {
    if (chunkIndex >= 0 && chunkIndex < _currentChunks.length) {
      _currentIndex = chunkIndex;
      _chunkIndexController.add(_currentIndex);
      await _engine.speak(_currentChunks[_currentIndex].text);
    }
  }

  @override
  Future<void> updateConfig(TtsConfig config) async {
    _config = config;
    await _engine.setRate(config.rate);
    await _engine.setPitch(config.pitch);
    if (config.voice != null) {
      // Logic to find voice profile by name and set it
    }
  }

  @override
  Future<List<VoiceProfile>> getAvailableVoices() {
    return _engine.getVoices();
  }

  @override
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;

  @override
  Stream<double> get progress => _progressController.stream;

  void dispose() {
    _chunkIndexController.close();
    _progressController.close();
  }
}
