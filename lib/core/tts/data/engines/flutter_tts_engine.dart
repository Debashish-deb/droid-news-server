import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/entities/voice_profile.dart';
import '../../shared/tts_voice_heuristics.dart';
import 'tts_engine.dart';

// ─── Internal chunk model ─────────────────────────────────────────────────────

const double _referenceSpeechRate = 0.44;
const double _periodToCommaRatio = 1.9;
const double _paragraphToSentenceRatio = 1.9;

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
    double defaultPitch = 0.98,
    double defaultVolume = 1.0,
    HumanizationConfig humanization = HumanizationConfig.natural,
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

  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _stopRequested = false;
  Duration _lastKnownPosition = Duration.zero;

  List<_SpeechChunk> _queue = [];
  int _currentChunkIndex = 0;

  @override
  bool get isInitialized => _isInitialized;

  @override
  TtsEngineCapabilities get capabilities =>
      const TtsEngineCapabilities(supportsWordBoundary: true);

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  bool get isPaused => _isPaused;

  @override
  Stream<TtsEngineEvent> get events => _events.stream;

  // ─── Init ────────────────────────────────────────────────────────────────

  @override
  Future<void> init() async {
    if (_isInitialized) return;

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
      _emit(
        TtsEngineEventType.wordBoundary,
        charIndex: start,
        charLength: end - start,
        data: {'text': text, 'word': word, 'chunkIndex': _currentChunkIndex},
      );
    });

    _isInitialized = true;
    _emit(TtsEngineEventType.initialized);
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
      await _applyProsody(chunk, lang);

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

  Future<void> _applyProsody(_SpeechChunk chunk, ArticleLanguage lang) async {
    double rate = _baseRate;
    double pitch = _basePitch;

    if (_humanization.enableVariableRate) {
      rate = switch (chunk.tone) {
        SentenceTone.question => _baseRate * _humanization.questionRateFactor,
        SentenceTone.exclamation =>
          _baseRate * _humanization.exclamationRateBoost,
        SentenceTone.exclamatoryQuestion =>
          _baseRate * _humanization.exclamationRateBoost,
        SentenceTone.listing => _baseRate * _humanization.listingRateFactor,
        SentenceTone.quote => _baseRate * 0.95,
        SentenceTone.dialogue => _baseRate * 1.02,
        _ => _baseRate,
      };

      // Naturally decelerate at the very last sentence
      if (chunk.isLastSentenceInArticle) {
        rate *= _humanization.finalSentenceRateFactor;
      }

      rate = rate.clamp(0.25, 1.0);
    }

    if (_humanization.enableVariablePitch) {
      pitch = switch (chunk.tone) {
        SentenceTone.question => _basePitch * _humanization.questionPitchBoost,
        SentenceTone.exclamation =>
          _basePitch * _humanization.exclamationPitchBoost,
        SentenceTone.exclamatoryQuestion =>
          _basePitch * (_humanization.questionPitchBoost + 0.02),
        SentenceTone.quote => _basePitch * 1.03, // Slight pitch up for quotes
        SentenceTone.dialogue => _basePitch * 1.01,
        _ => _basePitch,
      };

      // Paragraph-opening sentences sound slightly more alert/fresh
      if (chunk.isFirstInParagraph) {
        pitch *= _humanization.paragraphStartPitchBoost;
      }

      // Bengali Formal/Informal pitch adjustments (heuristic)
      if (lang == ArticleLanguage.bengali) {
        if (_isFormalBengali(chunk.text)) {
          pitch *=
              0.985; 
        }
      }

      pitch = pitch.clamp(0.5, 2.0);
    }

    if (lang == ArticleLanguage.bengali) {
      final complexity = _calculateBengaliComplexity(chunk.text);
      if (complexity > 0.15) {
        rate *= (1.0 - (complexity * 0.12)).clamp(0.92, 0.98);
      }
    }

    await Future.wait([
      _tts.setSpeechRate(rate),
      _tts.setPitch(pitch),
      _tts.setVolume(_baseVolume),
    ]);
  }

  //  Text preprocessing 

  List<_SpeechChunk> _buildQueue(String rawText, ArticleLanguage lang) {
    final chunks = <_SpeechChunk>[];

    final paragraphs = rawText
        .split(RegExp(r'\n{2,}|\r\n\r\n'))
        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final totalParagraphs = paragraphs.length;

    for (var pIdx = 0; pIdx < totalParagraphs; pIdx++) {
      final paragraphText = paragraphs[pIdx];
      final sentences = _splitSentences(paragraphText, lang);
      final totalSentences = sentences.length;

      for (var sIdx = 0; sIdx < totalSentences; sIdx++) {
        final raw = sentences[sIdx];
        final sentenceTone = _detectTone(raw, lang);
        final isLastSentenceInParagraph = sIdx == totalSentences - 1;
        final isLastSentenceInArticle =
            pIdx == totalParagraphs - 1 && sIdx == totalSentences - 1;

        
        final clauses = _humanization.enableClausePause
            ? _splitClauses(raw, lang)
            : [raw];

        for (var cIdx = 0; cIdx < clauses.length; cIdx++) {
          final clauseText = _normalise(clauses[cIdx], lang);
          if (clauseText.isEmpty) continue;

          final isLastClause = cIdx == clauses.length - 1;
          final tone = isLastClause
              ? sentenceTone 
              : SentenceTone.statement;

          chunks.add(
            _SpeechChunk(
              type: _ChunkType.speech,
              text: clauseText,
              tone: tone,
              paragraphIndex: pIdx,
              sentenceIndex: sIdx,
              isFirstInParagraph: sIdx == 0 && cIdx == 0,
              isLastInParagraph: isLastSentenceInParagraph && isLastClause,
              isLastSentenceInArticle: isLastSentenceInArticle && isLastClause,
              pauseAfterMs: 0,
            ),
          );

          if (!isLastClause) {
            // Inter-clause pause (comma / dash)
            final clausePause = _inferClausePauseMs(
              clauses[cIdx],
              sentenceTone: sentenceTone,
            );
            if (clausePause > 0) {
              chunks.add(_SpeechChunk.pause(clausePause));
            }
          }
        }

        if (!isLastSentenceInArticle) {
          if (isLastSentenceInParagraph && _humanization.enableParagraphPause) {
            final paragraphPause = _paragraphPauseMs(
              paragraphText: paragraphText,
              sentenceCount: totalSentences,
            );
            if (paragraphPause > 0) {
              chunks.add(_SpeechChunk.pause(paragraphPause));
            }
          } else {
            chunks.add(
              _SpeechChunk.pause(
                _sentencePauseMs(tone: sentenceTone, sentence: raw),
              ),
            );
          }
        }
      }
    }

    return chunks;
  }

  // ─── Sentence splitting 

  List<String> _splitSentences(String text, ArticleLanguage lang) {

    final pattern = lang == ArticleLanguage.bengali
        ? RegExp(r'[^।?!]+[।?!]+(?:["”\u0027\u2019\u201D]{1,2})?', dotAll: true)
        : RegExp(
            r'(?<!\b[A-Z])(?<!\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|St|vs|etc|e\.g|i\.e|approx|dept|est|no|vol|fig|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec|Inc|Ltd|Gov|Rep|Sen|Gen|Capt|Col|U\.S|U\.K|U\.N))[^.?!]+[.?!]+(?:["”\u0027\u2019\u201D]{1,2})?',
            dotAll: true,
          );

    final results = pattern
        .allMatches(text)
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final lastEnd = pattern.allMatches(text).fold(0, (p, m) => m.end);
    final tail = text.substring(lastEnd).trim();
    if (tail.isNotEmpty) results.add(tail);

    return results.isEmpty ? [text.trim()] : results;
  }

  // ─── Clause splitting ────────────────────────────────────────────────────

 
  List<String> _splitClauses(String sentence, ArticleLanguage lang) {

    final wordCount = sentence.split(RegExp(r'\s+')).length;
    if (wordCount < 7) return [sentence];

    final pattern = RegExp(
      r'(.+?(?:[,;:](?=\s+)|\u2014|\u2013|\u2026|\.\.\.|$))',
    );
    final parts = pattern
        .allMatches(sentence)
        .map((m) => m.group(0)!.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return parts.length > 1 ? parts : [sentence];
  }

  int _inferClausePauseMs(
    String clauseWithDelimiter, {
    required SentenceTone sentenceTone,
  }) {
    if (clauseWithDelimiter.isEmpty) return 0;
    final last = clauseWithDelimiter[clauseWithDelimiter.length - 1];
    final base = switch (last) {
      ',' => _humanization.commaBreakMs,
      ';' => _humanization.semicolonBreakMs,
      ':' => _humanization.colonBreakMs,
      '\u2014' || '\u2013' || '-' => _humanization.dashBreakMs,
      '.' || '\u2026' => _humanization.ellipsisBreakMs,
      _ => 0,
    };
    if (base == 0) return 0;

    var contextFactor = 1.0;
    final words = _wordCount(clauseWithDelimiter);
    if (words >= 16) {
      contextFactor += 0.16;
    } else if (words <= 5) {
      contextFactor -= 0.12;
    }
    if (_containsBreathCue(clauseWithDelimiter)) {
      contextFactor += 0.08;
    }
    if (sentenceTone == SentenceTone.listing && last == ',') {
      contextFactor -= 0.06;
    }

    final shaped = _scaledPause(
      base,
      minMs: 150,
      maxMs: 980,
      contextFactor: contextFactor,
    );
    final commaRef = _scaledPause(_humanization.commaBreakMs, minMs: 160);
    final floor = last == ',' ? (commaRef * 0.85).round() : commaRef;
    return shaped < floor ? floor : shaped;
  }

  int _sentencePauseMs({required SentenceTone tone, required String sentence}) {
    final base = switch (tone) {
      SentenceTone.question => _humanization.questionMarkBreakMs,
      SentenceTone.exclamation => _humanization.exclamationBreakMs,
      _ => _humanization.periodBreakMs,
    };

    var contextFactor = switch (tone) {
      SentenceTone.question => 1.06,
      SentenceTone.exclamation => 0.92,
      SentenceTone.listing => 0.90,
      SentenceTone.parenthetical => 0.88,
      _ => 1.0,
    };

    final words = _wordCount(sentence);
    if (words >= 24) {
      contextFactor += 0.16;
    } else if (words <= 7) {
      contextFactor -= 0.10;
    }

    if (sentence.contains('...') || sentence.contains('…')) {
      contextFactor += 0.18;
    }
    if (RegExp(r"""["”']\s*[.?!।]$""").hasMatch(sentence.trim())) {
      contextFactor += 0.06;
    }

    final shaped = _scaledPause(
      base,
      minMs: 380,
      maxMs: 1700,
      contextFactor: contextFactor,
    );
    final commaReference = _scaledPause(_humanization.commaBreakMs, minMs: 170);
    final floor = (commaReference * _periodToCommaRatio).round();
    return shaped < floor ? floor : shaped;
  }

  int _paragraphPauseMs({
    required String paragraphText,
    required int sentenceCount,
  }) {
    var contextFactor = 1.0;
    final words = _wordCount(paragraphText);

    if (words >= 120) {
      contextFactor += 0.22;
    } else if (words <= 22) {
      contextFactor -= 0.08;
    }

    if (sentenceCount >= 5) {
      contextFactor += 0.10;
    } else if (sentenceCount == 1) {
      contextFactor += 0.06;
    }

    if (paragraphText.contains('...') || paragraphText.contains('…')) {
      contextFactor += 0.10;
    }

    final shaped = _scaledPause(
      _humanization.paragraphBreakMs,
      minMs: 900,
      contextFactor: contextFactor,
    );
    final sentenceReference = _sentencePauseMs(
      tone: SentenceTone.statement,
      sentence: paragraphText,
    );
    final floor = (sentenceReference * _paragraphToSentenceRatio).round();
    final clampedFloor = floor.clamp(900, 2600);
    return shaped < clampedFloor ? clampedFloor : shaped;
  }

  int _scaledPause(
    int baseMs, {
    int minMs = 120,
    int maxMs = 2600,
    double contextFactor = 1.0,
  }) {
    final raw = (baseMs * _pauseRateFactor * contextFactor).round();
    return raw.clamp(minMs, maxMs);
  }

  double get _pauseRateFactor {
    final safeRate = _baseRate <= 0 ? _referenceSpeechRate : _baseRate;
    return (_referenceSpeechRate / safeRate).clamp(0.82, 1.24);
  }

  int _wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  bool _containsBreathCue(String text) {
    return RegExp(
          r'\b(and|but|because|however|therefore|meanwhile|while|although|then)\b',
          caseSensitive: false,
        ).hasMatch(text) ||
        RegExp(
          r'(এবং|কিন্তু|তবে|যদিও|কারণ|এদিকে|অন্যদিকে|তাই|এরপর|তারপর|ফলে|এছাড়াও|তাছাড়া|সুতরাং|বরং|অথবা|নতুবা)',
        ).hasMatch(text);
  }

  /// Calculates "Jukta Barna density" by identifying the frequency of
  /// the Unicode Hasant (U+09CD) relative to printable characters.
  double _calculateBengaliComplexity(String text) {
    if (text.isEmpty) return 0.0;
    const hasant = '\u09CD';
    final totalChars = text.trim().length;
    if (totalChars == 0) return 0.0;

    final count = hasant.allMatches(text).length;
    return count / totalChars;
  }

  /// Returns true if the passage uses formal Bengali constructs (Apni-style).
  bool _isFormalBengali(String text) {
    return text.contains('আপনি') ||
        text.contains('আপনার') ||
        text.contains('আপনাদের') ||
        text.contains('হলেন') ||
        text.contains('বললেন') ||
        text.contains('করলেন');
  }

  @visibleForTesting
  int debugClausePauseMs(
    String clauseWithDelimiter, {
    SentenceTone sentenceTone = SentenceTone.statement,
  }) => _inferClausePauseMs(clauseWithDelimiter, sentenceTone: sentenceTone);

  @visibleForTesting
  int debugSentencePauseMs(
    String sentence, {
    ArticleLanguage language = ArticleLanguage.auto,
  }) {
    final lang = language == ArticleLanguage.auto
        ? _detectLanguage(sentence)
        : language;
    final tone = _detectTone(sentence, lang);
    return _sentencePauseMs(tone: tone, sentence: sentence);
  }

  @visibleForTesting
  int debugParagraphPauseMs(String paragraphText, {int sentenceCount = 1}) =>
      _paragraphPauseMs(
        paragraphText: paragraphText,
        sentenceCount: sentenceCount,
      );

  @visibleForTesting
  List<int> debugPausePlan(
    String text, {
    ArticleLanguage language = ArticleLanguage.auto,
  }) {
    final lang = language == ArticleLanguage.auto
        ? _detectLanguage(text)
        : language;
    return _buildQueue(text, lang)
        .where((chunk) => chunk.type == _ChunkType.silentPause)
        .map((chunk) => chunk.pauseAfterMs)
        .toList(growable: false);
  }

  // ─── Tone detection 

  SentenceTone _detectTone(String sentence, ArticleLanguage lang) {
    final s = sentence.trim();
    if (s.isEmpty) return SentenceTone.statement;

    final isQuote =
        s.startsWith('"') || s.startsWith('“') || s.startsWith('\u0027');
    final coreStr = isQuote
        ? s.replaceAll(RegExp(r'["”\u0027\u2019\u201D]'), '').trim()
        : s;
    final lastChar = coreStr.isNotEmpty
        ? coreStr[coreStr.length - 1]
        : s[s.length - 1];

    if (lastChar == '?') {
      return isQuote ? SentenceTone.exclamatoryQuestion : SentenceTone.question;
    }
    if (lastChar == '!') return SentenceTone.exclamation;

    if (isQuote) {
      return SentenceTone.quote;
    }

    if (RegExp(r'(,\s*\S+){2,}').hasMatch(s)) return SentenceTone.listing;

    // Parenthetical / aside
    if (s.startsWith('(') ||
        s.startsWith('\u2014') ||
        s.startsWith('\u2013') ||
        s.startsWith('–')) {
      return SentenceTone.parenthetical;
    }

    if (s.contains('"') || s.contains('“')) {
      return SentenceTone.dialogue;
    }

    return SentenceTone.statement;
  }

  // ─── Language detection

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

  // ─── Text normalisation

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
      'মো.': 'মোহাম্মদ',
      'মোঃ': 'মোহাম্মদ',
      'মু.': 'মুহাম্মদ',
      'সা.': 'সাল্লাল্লাহু আলাইহি ওয়া সাল্লাম',
      'রা.': 'রাদিয়াল্লাহু আনহু',
      'রহ.': 'রহমাতুল্লাহি আলাইহি',
      'আ.': 'আব্দুল',
      'লি.': 'লিমিটেড',
      'প্রা.': 'প্রাইভেট',
      'ইন্জি.': 'ইঞ্জিনিয়ার',
      'খ্রি.': 'খ্রিস্টাব্দ',
      'খ্রি.পূ.': 'খ্রিস্টপূর্ব',
      'এড.': 'অ্যাডভোকেট',
      'অ্যাড.': 'অ্যাডভোকেট',
      'ব্রি.': 'ব্রিগেডিয়ার',
      'জেনা.': 'জেনারেল',
      'ক্যা.': 'ক্যাপ্টেন',
      'অব.': 'অবসরপ্রাপ্ত',
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
    _lastKnownPosition = Duration.zero;
    _queue = [];
    await _tts.stop();
    _emit(TtsEngineEventType.cancel);
  }

  @override
  Future<void> seekTo(Duration position) async {
    throw const TtsEngineException(
      TtsEngineErrorCode.invalidState,
      'FlutterTtsEngine does not support arbitrary seek.',
    );
  }

  @override
  Future<Duration> getCurrentPosition() async => _lastKnownPosition;

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
    final candidates = (raw as List)
        .whereType<Map>()
        .map(TtsVoiceCandidate.fromRawMap)
        .toList(growable: false);
    return TtsVoiceHeuristics.sortCandidates(
      candidates,
    ).map((candidate) => candidate.toVoiceProfile()).toList(growable: false);
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
    int? charIndex,
    int? charLength,
    Duration? position,
  }) {
    if (!_events.isClosed) {
      _events.add(
        TtsEngineEvent(
          type,
          message: message,
          data: data,
          charIndex: charIndex,
          charLength: charLength,
          position: position,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _events.close();
    _isInitialized = false;
  }
}
