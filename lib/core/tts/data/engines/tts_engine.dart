import '../../domain/entities/voice_profile.dart';

/// Language hint for article processing
enum ArticleLanguage { auto, bengali, english }

/// Sentence tone classification for prosody shaping
enum SentenceTone { statement, question, exclamation, listing, parenthetical }

/// Configures all humanization behavior — pause timings, prosody variance, etc.
class HumanizationConfig {
  const HumanizationConfig({
    // --- Pause durations (ms) ---
    this.commaBreakMs = 280,
    this.semicolonBreakMs = 420,
    this.colonBreakMs = 360,
    this.periodBreakMs = 580,
    this.questionMarkBreakMs = 620,
    this.exclamationBreakMs = 520,
    this.dashBreakMs = 240,
    this.paragraphBreakMs = 950,
    this.ellipsisBreakMs = 700,

    // --- Prosody variance ---
    this.enableVariablePitch = true,
    this.enableVariableRate = true,
    this.pitchVarianceRange = 0.09,
    this.rateVarianceRange = 0.07,

    // --- Tone shaping ---
    this.questionPitchBoost = 1.06,
    this.questionRateFactor = 0.93,
    this.exclamationPitchBoost = 1.04,
    this.exclamationRateBoost = 1.07,
    this.listingRateFactor = 0.97,
    this.paragraphStartPitchBoost = 1.03,
    this.finalSentenceRateFactor = 0.94,

    // --- Feature toggles ---
    this.enableParagraphPause = true,
    this.enableClausePause = true,
    this.expandAbbreviations = true,
    this.normalizeNumbers = true,
  });

  final int commaBreakMs;
  final int semicolonBreakMs;
  final int colonBreakMs;
  final int periodBreakMs;
  final int questionMarkBreakMs;
  final int exclamationBreakMs;
  final int dashBreakMs;
  final int paragraphBreakMs;
  final int ellipsisBreakMs;

  final bool enableVariablePitch;
  final bool enableVariableRate;
  final double pitchVarianceRange;
  final double rateVarianceRange;

  final double questionPitchBoost;
  final double questionRateFactor;
  final double exclamationPitchBoost;
  final double exclamationRateBoost;
  final double listingRateFactor;
  final double paragraphStartPitchBoost;
  final double finalSentenceRateFactor;

  final bool enableParagraphPause;
  final bool enableClausePause;
  final bool expandAbbreviations;
  final bool normalizeNumbers;

  /// Balanced, natural-sounding preset — recommended default
  static const HumanizationConfig natural = HumanizationConfig();

  /// Broadcast-style cadence for evening-news narration.
  static const HumanizationConfig anchorDesk = HumanizationConfig(
    commaBreakMs: 300,
    semicolonBreakMs: 420,
    colonBreakMs: 360,
    periodBreakMs: 800,
    questionMarkBreakMs: 760,
    exclamationBreakMs: 640,
    dashBreakMs: 280,
    paragraphBreakMs: 1200,
    ellipsisBreakMs: 900,
    pitchVarianceRange: 0.05,
    rateVarianceRange: 0.04,
    questionPitchBoost: 1.04,
    questionRateFactor: 0.95,
    exclamationPitchBoost: 1.03,
    exclamationRateBoost: 1.03,
    listingRateFactor: 0.96,
    paragraphStartPitchBoost: 1.02,
    finalSentenceRateFactor: 0.92,
  );

  /// Tighter pauses, less variance — useful for fast news-style reading
  static const HumanizationConfig newsCast = HumanizationConfig(
    commaBreakMs: 180,
    periodBreakMs: 380,
    paragraphBreakMs: 600,
    pitchVarianceRange: 0.04,
    rateVarianceRange: 0.03,
    questionPitchBoost: 1.03,
    exclamationRateBoost: 1.04,
  );

  /// Slower, wider variance — ideal for story/literary reading
  static const HumanizationConfig storyteller = HumanizationConfig(
    commaBreakMs: 380,
    periodBreakMs: 750,
    paragraphBreakMs: 1200,
    ellipsisBreakMs: 950,
    pitchVarianceRange: 0.13,
    rateVarianceRange: 0.11,
    questionPitchBoost: 1.09,
    finalSentenceRateFactor: 0.88,
  );

  /// Flat, predictable — for accessibility or testing
  static const HumanizationConfig flat = HumanizationConfig(
    enableVariablePitch: false,
    enableVariableRate: false,
    commaBreakMs: 150,
    periodBreakMs: 300,
    paragraphBreakMs: 500,
    pitchVarianceRange: 0,
    rateVarianceRange: 0,
  );

  HumanizationConfig copyWith({
    int? commaBreakMs,
    int? semicolonBreakMs,
    int? colonBreakMs,
    int? periodBreakMs,
    int? questionMarkBreakMs,
    int? exclamationBreakMs,
    int? dashBreakMs,
    int? paragraphBreakMs,
    int? ellipsisBreakMs,
    bool? enableVariablePitch,
    bool? enableVariableRate,
    double? pitchVarianceRange,
    double? rateVarianceRange,
    double? questionPitchBoost,
    double? questionRateFactor,
    double? exclamationPitchBoost,
    double? exclamationRateBoost,
    double? listingRateFactor,
    double? paragraphStartPitchBoost,
    double? finalSentenceRateFactor,
    bool? enableParagraphPause,
    bool? enableClausePause,
    bool? expandAbbreviations,
    bool? normalizeNumbers,
  }) => HumanizationConfig(
    commaBreakMs: commaBreakMs ?? this.commaBreakMs,
    semicolonBreakMs: semicolonBreakMs ?? this.semicolonBreakMs,
    colonBreakMs: colonBreakMs ?? this.colonBreakMs,
    periodBreakMs: periodBreakMs ?? this.periodBreakMs,
    questionMarkBreakMs: questionMarkBreakMs ?? this.questionMarkBreakMs,
    exclamationBreakMs: exclamationBreakMs ?? this.exclamationBreakMs,
    dashBreakMs: dashBreakMs ?? this.dashBreakMs,
    paragraphBreakMs: paragraphBreakMs ?? this.paragraphBreakMs,
    ellipsisBreakMs: ellipsisBreakMs ?? this.ellipsisBreakMs,
    enableVariablePitch: enableVariablePitch ?? this.enableVariablePitch,
    enableVariableRate: enableVariableRate ?? this.enableVariableRate,
    pitchVarianceRange: pitchVarianceRange ?? this.pitchVarianceRange,
    rateVarianceRange: rateVarianceRange ?? this.rateVarianceRange,
    questionPitchBoost: questionPitchBoost ?? this.questionPitchBoost,
    questionRateFactor: questionRateFactor ?? this.questionRateFactor,
    exclamationPitchBoost: exclamationPitchBoost ?? this.exclamationPitchBoost,
    exclamationRateBoost: exclamationRateBoost ?? this.exclamationRateBoost,
    listingRateFactor: listingRateFactor ?? this.listingRateFactor,
    paragraphStartPitchBoost:
        paragraphStartPitchBoost ?? this.paragraphStartPitchBoost,
    finalSentenceRateFactor:
        finalSentenceRateFactor ?? this.finalSentenceRateFactor,
    enableParagraphPause: enableParagraphPause ?? this.enableParagraphPause,
    enableClausePause: enableClausePause ?? this.enableClausePause,
    expandAbbreviations: expandAbbreviations ?? this.expandAbbreviations,
    normalizeNumbers: normalizeNumbers ?? this.normalizeNumbers,
  );
}

// ─── Events ───────────────────────────────────────────────────────────────────

enum TtsEngineEventType {
  start,
  completion,
  pause,
  resume,
  cancel,
  error,
  progress, // word-level progress from underlying engine
  sentenceStart,
  sentenceEnd,
  paragraphStart,
  paragraphEnd,
}

class TtsEngineEvent {
  const TtsEngineEvent(this.type, {this.message, this.data = const {}});

  final TtsEngineEventType type;
  final String? message;
  final Map<String, dynamic> data;

  @override
  String toString() =>
      'TtsEngineEvent($type${message != null ? ', $message' : ''})';
}

// ─── Abstract contract ────────────────────────────────────────────────────────

abstract class TtsEngine {
  /// One-time initialisation — call before any other method.
  Future<void> init();

  /// Speaks [text] verbatim with no humanisation processing.
  Future<void> speak(String text);

  /// Speaks an article with full humanisation: pause shaping, prosody
  /// variance, abbreviation expansion, and paragraph/sentence segmentation.
  ///
  /// [language] defaults to [ArticleLanguage.auto] which detects Bengali vs
  /// English by Unicode character ratio.
  Future<void> speakArticle(
    String text, {
    ArticleLanguage language = ArticleLanguage.auto,
  });

  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVolume(double volume);
  Future<void> setVoice(VoiceProfile voice);
  Future<void> setLanguage(String languageCode);
  Future<void> setHumanization(HumanizationConfig config);

  Future<List<VoiceProfile>> getVoices();
  Future<List<VoiceProfile>> getVoicesForLanguage(String languageCode);

  bool get isSpeaking;
  bool get isPaused;

  /// Broadcast stream of all engine lifecycle and progress events.
  Stream<TtsEngineEvent> get events;

  void dispose();
}
