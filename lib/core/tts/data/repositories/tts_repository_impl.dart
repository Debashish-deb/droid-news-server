import 'dart:async';
import '../engines/tts_engine.dart';
import '../../domain/entities/tts_chunk.dart';
import '../../domain/entities/tts_config.dart';
import '../../domain/entities/voice_profile.dart';
import '../../domain/repositories/tts_repository.dart';

class TtsRepositoryImpl implements TtsRepository {
  TtsRepositoryImpl(this._engine);

  final TtsEngine _engine;

  // UI state streams
  final _chunkIndexController = StreamController<int>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  // Playback state
  List<TtsChunk> _currentChunks = [];
  int _currentChunkIndex = -1;
  bool _isInitialized = false;

  // Internal: maps flat [paragraphIndex, sentenceIndex] → TtsChunk flat index
  // so engine events can drive the UI without text comparison overhead.
  final Map<String, int> _sentenceKeyToChunkIndex = {};

  // ─── Init ─────────────────────────────────────────────────────────────────

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    await _engine.init();
    _engine.events.listen(_handleEngineEvent);
    _isInitialized = true;
  }

  // ─── Engine event handler ─────────────────────────────────────────────────

  void _handleEngineEvent(TtsEngineEvent event) {
    switch (event.type) {
      // ── Sentence-level tracking (engine → UI chunk index) ──────────────
      case TtsEngineEventType.sentenceStart:
        final pIdx = event.data['paragraphIndex'] as int?;
        final sIdx = event.data['sentenceIndex'] as int?;
        if (pIdx != null && sIdx != null) {
          final key = '${pIdx}_$sIdx';
          final chunkIndex = _sentenceKeyToChunkIndex[key];
          if (chunkIndex != null && chunkIndex != _currentChunkIndex) {
            _currentChunkIndex = chunkIndex;
            _chunkIndexController.add(_currentChunkIndex);
            _emitProgress();
          }
        }

      // ── Article fully spoken ───────────────────────────────────────────
      case TtsEngineEventType.completion:
        _onArticleEnd();

      // ── Cancel / stop ─────────────────────────────────────────────────
      case TtsEngineEventType.cancel:
        _reset();

      // ── Word-level progress (granular sub-chunk scrubbing) ────────────
      case TtsEngineEventType.progress:
        _emitProgress();

      case TtsEngineEventType.error:
        // Optionally: surface via a dedicated error stream
        break;

      default:
        break;
    }
  }

  void _onArticleEnd() {
    _reset();
    // Signal UI to close / reset highlight
    _chunkIndexController.add(-1);
    _progressController.add(1.0);
  }

  void _reset() {
    _currentChunkIndex = -1;
    _currentChunks = [];
    _sentenceKeyToChunkIndex.clear();
  }

  void _emitProgress() {
    if (_currentChunks.isEmpty) return;
    _progressController.add(
      _currentChunkIndex / (_currentChunks.length - 1).clamp(1, 999999),
    );
  }

  // ─── Core playback ────────────────────────────────────────────────────────

  @override
  Future<void> play(List<TtsChunk> chunks, int startIndex) async {
    _currentChunks = chunks;
    _currentChunkIndex = startIndex.clamp(0, chunks.length - 1);

    _buildSentenceIndex();

    _chunkIndexController.add(_currentChunkIndex);
    _emitProgress();

    // Reconstruct speakable text starting from [startIndex].
    // We rebuild from startIndex so seek()/resume() also use this path.
    final speakableText = _buildTextFromChunkIndex(_currentChunkIndex);
    if (speakableText.isEmpty) return;

    final lang = _inferLanguageFromChunks(chunks);
    await _engine.speakArticle(speakableText, language: lang);
  }

  /// Builds a sentence-key → chunk-index lookup table from [_currentChunks].
  /// Body chunks carry [paragraphIndex] and [sentenceIndexInParagraph];
  /// preamble chunks (title/author) use negative indices and are handled
  /// separately via a direct index update at play() start.
  void _buildSentenceIndex() {
    _sentenceKeyToChunkIndex.clear();
    for (final chunk in _currentChunks) {
      if (chunk.paragraphIndex >= 0) {
        final key = '${chunk.paragraphIndex}_${chunk.sentenceIndexInParagraph}';
        _sentenceKeyToChunkIndex[key] = chunk.index;
      }
    }
  }

  String _buildTextFromChunkIndex(int fromIndex) {
    return _currentChunks
        .where((c) => c.index >= fromIndex)
        .map((c) => c.text)
        .join(' ');
  }

  ArticleLanguage _inferLanguageFromChunks(List<TtsChunk> chunks) {
    final sample = chunks.take(5).map((c) => c.text).join(' ');
    final bengali = RegExp(r'[\u0980-\u09FF]').allMatches(sample).length;
    final total = sample
        .replaceAll(RegExp(r'[^\u0980-\u09FF\u0041-\u007A]'), '')
        .length;
    if (total == 0) return ArticleLanguage.english;
    return bengali / total > 0.25
        ? ArticleLanguage.bengali
        : ArticleLanguage.english;
  }

  // ─── Playback controls ────────────────────────────────────────────────────

  @override
  Future<void> pause() async {
    await _engine.pause();
  }

  @override
  Future<void> resume() async {
    await _engine.resume();
    // flutter_tts has no native resume; the engine's queue driver unblocks
    // automatically — no need to re-speak from here.
  }

  @override
  Future<void> stop() async {
    await _engine.stop();
    _reset();
    _chunkIndexController.add(-1);
    _progressController.add(0.0);
  }

  /// Seeks to [chunkIndex] by stopping current speech and re-speaking
  /// from that chunk onward so humanization is preserved across seeks.
  @override
  Future<void> seek(int chunkIndex) async {
    if (chunkIndex < 0 || chunkIndex >= _currentChunks.length) return;
    await _engine.stop();
    await play(_currentChunks, chunkIndex);
  }

  // ─── Configuration ────────────────────────────────────────────────────────

  @override
  Future<void> updateConfig(TtsConfig config) async {
    await Future.wait([
      _engine.setRate(config.rate),
      _engine.setPitch(config.pitch),
      _engine.setVolume(config.volume),
      _engine.setLanguage(config.languageCode),
      _engine.setHumanization(config.humanization),
    ]);

    if (config.voice != null) {
      final voice = (await _engine.getVoices()).firstWhere(
        (v) => v.name == config.voice,
        orElse: () => VoiceProfile(name: config.voice!, locale: config.languageCode),
      );
      await _engine.setVoice(voice);
    }
  }

  @override
  Future<List<VoiceProfile>> getAvailableVoices() => _engine.getVoices();

  Future<List<VoiceProfile>> getVoicesForLanguage(String languageCode) =>
      _engine.getVoicesForLanguage(languageCode);

  // ─── Streams ──────────────────────────────────────────────────────────────

  @override
  Stream<int> get currentChunkIndex => _chunkIndexController.stream;

  @override
  Stream<double> get progress => _progressController.stream;

  // ─── Disposal ─────────────────────────────────────────────────────────────

  void dispose() {
    _engine.dispose();
    _chunkIndexController.close();
    _progressController.close();
  }
}
