import 'dart:async';
import 'dart:math';

import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/entities/voice_profile.dart';
import 'tts_engine.dart';

// ─── Internal chunk model ─────────────────────────────────────────────────────

enum _ChunkType { speech, silentPause }

class _SpeechChunk {
  const _SpeechChunk({
    required this.type,
    required this.text,
    required this.tone,
    required this.paragraphIndex,
    required this.sentenceIndex,
    required this.isFirstInParagraph,
    required this.isLastInParagraph,
    required this.isLastSentenceInArticle,
    required this.pauseAfterMs,
  });

  const _SpeechChunk.pause(int ms)
    : type = _ChunkType.silentPause,
      text = '',
      tone = SentenceTone.statement,
      paragraphIndex = 0,
      sentenceIndex = 0,
      isFirstInParagraph = false,
      isLastInParagraph = false,
      isLastSentenceInArticle = false,
      pauseAfterMs = ms;

  final _ChunkType type;
  final String text;
  final SentenceTone tone;
  final int paragraphIndex;
  final int sentenceIndex;
  final bool isFirstInParagraph;
  final bool isLastInParagraph;
  final bool isLastSentenceInArticle;
  final int pauseAfterMs;
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine({
    double defaultRate = 0.44,
    double defaultPitch = 0.94,
    double defaultVolume = 1.0,
    HumanizationConfig humanization = HumanizationConfig.anchorDesk,
  }) : _baseRate = defaultRate,
       _basePitch = defaultPitch,
       _baseVolume = defaultVolume,
       _humanization = humanization;

  final FlutterTts _tts = FlutterTts();
  final StreamController<TtsEngineEvent> _events = StreamController.broadcast();
  final Random _rng = Random();

  double _baseRate;
  double _basePitch;
  double _baseVolume;
  HumanizationConfig _humanization;

  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _stopRequested = false;

  List<_SpeechChunk> _queue = [];
  int _currentChunkIndex = 0;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  bool get isPaused => _isPaused;

  @override
  Stream<TtsEngineEvent> get events => _events.stream;

  // ─── Init ────────────────────────────────────────────────────────────────

  @override
  Future<void> init() async {
    // awaitSpeakCompletion lets us drive the queue with simple awaits
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      _isPaused = false;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _isPaused = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _emit(TtsEngineEventType.error, message: msg.toString());
    });

    _tts.setProgressHandler((text, start, end, word) {
      _emit(
        TtsEngineEventType.progress,
        data: {
          'text': text,
          'start': start,
          'end': end,
          'word': word,
          'chunkIndex': _currentChunkIndex,
        },
      );
    });
  }

  // ─── Public speak API ────────────────────────────────────────────────────

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> speakArticle(
    String text, {
    ArticleLanguage language = ArticleLanguage.auto,
  }) async {
    _stopRequested = false;
    _queue = [];
    _currentChunkIndex = 0;

    final lang = language == ArticleLanguage.auto
        ? _detectLanguage(text)
        : language;

    _queue = _buildQueue(text, lang);

    _emit(TtsEngineEventType.start);
    await _driveQueue(lang);

    if (!_stopRequested) {
      _emit(TtsEngineEventType.completion);
    }
  }

  // ─── Queue driver ────────────────────────────────────────────────────────

  Future<void> _driveQueue(ArticleLanguage lang) async {
    for (var i = 0; i < _queue.length; i++) {
      if (_stopRequested) break;

      // Honour pause — busy-wait in tight loop
      while (_isPaused && !_stopRequested) {
        await Future.delayed(const Duration(milliseconds: 80));
      }
      if (_stopRequested) break;

      final chunk = _queue[i];
      _currentChunkIndex = i;

      if (chunk.type == _ChunkType.silentPause) {
        await Future.delayed(Duration(milliseconds: chunk.pauseAfterMs));
        continue;
      }

      // Paragraph / sentence boundary events
      if (chunk.isFirstInParagraph) {
        _emit(
          TtsEngineEventType.paragraphStart,
          data: {'paragraphIndex': chunk.paragraphIndex},
        );
      }
      _emit(
        TtsEngineEventType.sentenceStart,
        data: {
          'text': chunk.text,
          'sentenceIndex': chunk.sentenceIndex,
          'paragraphIndex': chunk.paragraphIndex,
        },
      );

      // Shape prosody for this chunk
      await _applyProsody(chunk);

      // Speak
      _isSpeaking = true;
      await _tts.speak(chunk.text);
      _isSpeaking = false;

      _emit(
        TtsEngineEventType.sentenceEnd,
        data: {
          'sentenceIndex': chunk.sentenceIndex,
          'paragraphIndex': chunk.paragraphIndex,
        },
      );
      if (chunk.isLastInParagraph) {
        _emit(
          TtsEngineEventType.paragraphEnd,
          data: {'paragraphIndex': chunk.paragraphIndex},
        );
      }
    }
  }

  // ─── Prosody shaping ─────────────────────────────────────────────────────

  Future<void> _applyProsody(_SpeechChunk chunk) async {
    double rate = _baseRate;
    double pitch = _basePitch;

    if (_humanization.enableVariableRate) {
      rate = switch (chunk.tone) {
        SentenceTone.question =>
          _baseRate * _humanization.questionRateFactor + _jitter(0.03),
        SentenceTone.exclamation =>
          _baseRate * _humanization.exclamationRateBoost + _jitter(0.03),
        SentenceTone.listing =>
          _baseRate * _humanization.listingRateFactor + _jitter(0.02),
        _ => _baseRate * (1.0 + _jitter(_humanization.rateVarianceRange)),
      };

      // Naturally decelerate at the very last sentence
      if (chunk.isLastSentenceInArticle) {
        rate *= _humanization.finalSentenceRateFactor;
      }

      rate = rate.clamp(0.25, 1.0);
    }

    if (_humanization.enableVariablePitch) {
      pitch = switch (chunk.tone) {
        SentenceTone.question =>
          _basePitch * _humanization.questionPitchBoost + _jitter(0.03),
        SentenceTone.exclamation =>
          _basePitch * _humanization.exclamationPitchBoost + _jitter(0.02),
        _ => _basePitch * (1.0 + _jitter(_humanization.pitchVarianceRange)),
      };

      // Paragraph-opening sentences sound slightly more alert/fresh
      if (chunk.isFirstInParagraph) {
        pitch *= _humanization.paragraphStartPitchBoost;
      }

      pitch = pitch.clamp(0.5, 2.0);
    }

    await Future.wait([
      _tts.setSpeechRate(rate),
      _tts.setPitch(pitch),
      _tts.setVolume(_baseVolume),
    ]);
  }

  double _jitter(double range) => (_rng.nextDouble() * 2.0 - 1.0) * range;

  // ─── Text preprocessing ──────────────────────────────────────────────────

  List<_SpeechChunk> _buildQueue(String rawText, ArticleLanguage lang) {
    final chunks = <_SpeechChunk>[];

    final paragraphs = rawText
        .split(RegExp(r'\n{2,}|\r\n\r\n'))
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final totalParagraphs = paragraphs.length;

    for (var pIdx = 0; pIdx < totalParagraphs; pIdx++) {
      if (pIdx > 0 && _humanization.enableParagraphPause) {
        chunks.add(_SpeechChunk.pause(_humanization.paragraphBreakMs));
      }

      final sentences = _splitSentences(paragraphs[pIdx], lang);
      final totalSentences = sentences.length;

      for (var sIdx = 0; sIdx < totalSentences; sIdx++) {
        final raw = sentences[sIdx];
        final isLastSentence =
            pIdx == totalParagraphs - 1 && sIdx == totalSentences - 1;

        // Each sentence may itself be broken into clauses separated by
        // commas / semicolons / colons / dashes, each as its own chunk
        // with a shorter inter-clause pause injected between them.
        final clauses = _humanization.enableClausePause
            ? _splitClauses(raw, lang)
            : [raw];

        for (var cIdx = 0; cIdx < clauses.length; cIdx++) {
          final clauseText = _normalise(clauses[cIdx], lang);
          if (clauseText.isEmpty) continue;

          final isLastClause = cIdx == clauses.length - 1;
          final tone = isLastClause
              ? _detectTone(raw, lang) // tone determined by full sentence
              : SentenceTone.statement;

          chunks.add(
            _SpeechChunk(
              type: _ChunkType.speech,
              text: clauseText,
              tone: tone,
              paragraphIndex: pIdx,
              sentenceIndex: sIdx,
              isFirstInParagraph: sIdx == 0 && cIdx == 0,
              isLastInParagraph: sIdx == totalSentences - 1 && isLastClause,
              isLastSentenceInArticle: isLastSentence && isLastClause,
              pauseAfterMs: 0,
            ),
          );

          if (!isLastClause) {
            // Inter-clause pause (comma / dash)
            final clausePause = _inferClausePauseMs(clauses[cIdx]);
            if (clausePause > 0) {
              chunks.add(_SpeechChunk.pause(clausePause));
            }
          }
        }

        // Inter-sentence pause (after the full sentence, not the last clause)
        if (!isLastSentence) {
          chunks.add(
            _SpeechChunk.pause(_sentencePauseMs(_detectTone(raw, lang))),
          );
        }
      }
    }

    return chunks;
  }

  // ─── Sentence splitting ──────────────────────────────────────────────────

  List<String> _splitSentences(String text, ArticleLanguage lang) {
    // Bengali terminators: ।  ? !
    // English: . ? ! — with naïve abbreviation guard (single uppercase letter)
    final pattern = lang == ArticleLanguage.bengali
        ? RegExp(r'[^।?!]+[।?!]+', dotAll: true)
        : RegExp(
            r'(?<!\b[A-Z])(?<!\b(?:Mr|Dr|Mrs|Ms|Prof|St|vs|etc|e\.g|i\.e))[^.?!]+[.?!]+',
            dotAll: true,
          );

    final results = pattern
        .allMatches(text)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Capture any trailing text not ending in punctuation
    final lastEnd = pattern.allMatches(text).fold(0, (p, m) => m.end);
    final tail = text.substring(lastEnd).trim();
    if (tail.isNotEmpty) results.add(tail);

    return results.isEmpty ? [text.trim()] : results;
  }

  // ─── Clause splitting ────────────────────────────────────────────────────

  /// Splits a sentence on clause-level delimiters: , ; : — –
  /// Returns the parts *with* their trailing delimiter attached so we can
  /// infer the appropriate pause length later.
  List<String> _splitClauses(String sentence, ArticleLanguage lang) {
    // Only split when the clause is long enough to warrant a breath pause.
    // Short sentences (< 6 words) are left intact to avoid choppy delivery.
    final wordCount = sentence.split(RegExp(r'\s+')).length;
    if (wordCount < 7) return [sentence];

    final pattern = RegExp(r'([^,;:\u2014\u2013]+[,;:\u2014\u2013]?)');
    final parts = pattern
        .allMatches(sentence)
        .map((m) => m.group(0)!.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return parts.length > 1 ? parts : [sentence];
  }

  int _inferClausePauseMs(String clauseWithDelimiter) {
    if (clauseWithDelimiter.isEmpty) return 0;
    final last = clauseWithDelimiter[clauseWithDelimiter.length - 1];
    return switch (last) {
      ',' => _humanization.commaBreakMs,
      ';' => _humanization.semicolonBreakMs,
      ':' => _humanization.colonBreakMs,
      '\u2014' || '\u2013' || '-' => _humanization.dashBreakMs,
      _ => 0,
    };
  }

  int _sentencePauseMs(SentenceTone tone) => switch (tone) {
    SentenceTone.question => _humanization.questionMarkBreakMs,
    SentenceTone.exclamation => _humanization.exclamationBreakMs,
    _ => _humanization.periodBreakMs,
  };

  // ─── Tone detection ──────────────────────────────────────────────────────

  SentenceTone _detectTone(String sentence, ArticleLanguage lang) {
    final s = sentence.trim();
    if (s.isEmpty) return SentenceTone.statement;
    final last = s[s.length - 1];
    if (last == '?') return SentenceTone.question;
    if (last == '!') return SentenceTone.exclamation;
    // Heuristic: sentences with serial commas are likely lists
    if (RegExp(r'(,\s*\w+){2,}').hasMatch(s)) return SentenceTone.listing;
    // Parenthetical — text in brackets reads at a slightly faster, lower tone
    if (s.startsWith('(') || s.startsWith('–') || s.startsWith('\u2014')) {
      return SentenceTone.parenthetical;
    }
    return SentenceTone.statement;
  }

  // ─── Language detection ──────────────────────────────────────────────────

  ArticleLanguage _detectLanguage(String text) {
    final bengaliCount = RegExp(r'[\u0980-\u09FF]').allMatches(text).length;
    final totalAlpha = text
        .replaceAll(RegExp(r'[^\u0980-\u09FF\u0041-\u007A\u0041-\u005A]'), '')
        .length;
    if (totalAlpha == 0) return ArticleLanguage.english;
    return bengaliCount / totalAlpha > 0.25
        ? ArticleLanguage.bengali
        : ArticleLanguage.english;
  }

  // ─── Text normalisation ──────────────────────────────────────────────────

  String _normalise(String text, ArticleLanguage lang) {
    var t = text.trim();
    if (t.isEmpty) return t;

    if (_humanization.expandAbbreviations) {
      t = lang == ArticleLanguage.bengali
          ? _expandBengali(t)
          : _expandEnglish(t);
    }

    if (_humanization.normalizeNumbers) {
      t = lang == ArticleLanguage.bengali
          ? _normaliseBengaliNumbers(t)
          : t; // English TTS handles numerals well natively
    }

    // Collapse multiple spaces
    return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  String _expandBengali(String text) {
    const map = {
      'ড.': 'ডক্টর',
      'ডা.': 'ডাক্তার',
      'মি.': 'মিস্টার',
      'মিস.': 'মিসেস',
      'প্রফ.': 'প্রফেসর',
      'অধ্যা.': 'অধ্যাপক',
      'নং': 'নম্বর',
      'বিঃদ্রঃ': 'বিশেষ দ্রষ্টব্য',
      'বিঃ দ্রঃ': 'বিশেষ দ্রষ্টব্য',
      'পৃঃ': 'পৃষ্ঠা',
      'সঃ': 'সাহেব',
      'জনাব': 'জনাব',
      'ইত্যাদি': 'ইত্যাদি',
    };
    var result = text;
    map.forEach((abbr, full) => result = result.replaceAll(abbr, full));
    return result;
  }

  String _expandEnglish(String text) {
    final map = <Pattern, String>{
      RegExp(r'\bDr\.', caseSensitive: false): 'Doctor',
      RegExp(r'\bMr\.', caseSensitive: false): 'Mister',
      RegExp(r'\bMrs\.', caseSensitive: false): 'Missus',
      RegExp(r'\bMs\.', caseSensitive: false): 'Miss',
      RegExp(r'\bProf\.', caseSensitive: false): 'Professor',
      RegExp(r'\bSt\.', caseSensitive: false): 'Saint',
      RegExp(r'\betc\.', caseSensitive: false): 'etcetera',
      RegExp(r'\bvs\.', caseSensitive: false): 'versus',
      RegExp(r'\be\.g\.', caseSensitive: false): 'for example',
      RegExp(r'\bi\.e\.', caseSensitive: false): 'that is',
      RegExp(r'\bno\.', caseSensitive: false): 'number',
      RegExp(r'\bft\.', caseSensitive: false): 'feet',
      RegExp(r'\bkm\.', caseSensitive: false): 'kilometers',
      RegExp(r'\bkg\.', caseSensitive: false): 'kilograms',
    };
    var result = text;
    map.forEach(
      (pattern, replacement) =>
          result = result.replaceAll(pattern, replacement),
    );
    return result;
  }

  /// Converts Bengali digit strings (০–৯) to ASCII digits so the TTS
  /// number-reading engine can handle them consistently.
  String _normaliseBengaliNumbers(String text) {
    const bengaliDigits = '০১২৩৪৫৬৭৮৯';
    var result = text;
    for (var i = 0; i < bengaliDigits.length; i++) {
      result = result.replaceAll(bengaliDigits[i], '$i');
    }
    return result;
  }

  // ─── Playback controls ───────────────────────────────────────────────────

  @override
  Future<void> pause() async {
    _isPaused = true;
    await _tts.pause();
    _emit(TtsEngineEventType.pause);
  }

  @override
  Future<void> resume() async {
    _isPaused = false;
    _emit(TtsEngineEventType.resume);
    // flutter_tts has no native resume; the queue driver re-speaks automatically
    // because _isPaused becomes false and the busy-wait loop unblocks.
  }

  @override
  Future<void> stop() async {
    _stopRequested = true;
    _isPaused = false;
    _isSpeaking = false;
    _queue = [];
    await _tts.stop();
    _emit(TtsEngineEventType.cancel);
  }

  // ─── Configuration setters ───────────────────────────────────────────────

  @override
  Future<void> setRate(double rate) async {
    _baseRate = rate;
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    _basePitch = pitch;
    await _tts.setPitch(pitch);
  }

  @override
  Future<void> setVolume(double volume) async {
    _baseVolume = volume;
    await _tts.setVolume(volume);
  }

  @override
  Future<void> setVoice(VoiceProfile voice) async {
    await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
  }

  @override
  Future<void> setLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }

  @override
  Future<void> setHumanization(HumanizationConfig config) async {
    _humanization = config;
  }

  // ─── Voice discovery ─────────────────────────────────────────────────────

  @override
  Future<List<VoiceProfile>> getVoices() async {
    final raw = await _tts.getVoices;
    if (raw == null) return [];
    return (raw as List).map((dynamic v) {
      final m = v as Map;
      return VoiceProfile(
        name: m['name'] as String? ?? 'Unknown',
        locale: m['locale'] as String? ?? 'Unknown',
      );
    }).toList();
  }

  @override
  Future<List<VoiceProfile>> getVoicesForLanguage(String languageCode) async {
    final all = await getVoices();
    return all
        .where(
          (v) => v.locale.toLowerCase().startsWith(languageCode.toLowerCase()),
        )
        .toList();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _emit(
    TtsEngineEventType type, {
    String? message,
    Map<String, dynamic> data = const {},
  }) {
    if (!_events.isClosed) {
      _events.add(TtsEngineEvent(type, message: message, data: data));
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _events.close();
  }
}
