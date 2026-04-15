import '../../domain/entities/voice_profile.dart';

// ─── Language / tone enums ────────────────────────────────────────────────────

/// Language hint for article processing.
enum ArticleLanguage { auto, bengali, english }

/// Sentence tone classification for prosody shaping.
enum SentenceTone { statement, question, exclamation, listing, parenthetical, quote, dialogue, exclamatoryQuestion }

// ─── Capabilities ─────────────────────────────────────────────────────────────

/// Declares which optional features a concrete [TtsEngine] supports.
///
/// Callers should check the relevant flag before invoking optional methods
/// such as [TtsEngine.seekTo] or [TtsEngine.getCurrentPosition].
class TtsEngineCapabilities {
  const TtsEngineCapabilities({
    this.canSeek = false,
    this.canGetPosition = false,
    this.supportsWordBoundary = false,
    this.supportsSsml = false,
    this.supportsProsodyVariance = true,
    this.supportsMultipleVoices = true,
    this.supportsNetworkVoices = false,
    this.supportsBackgroundPlayback = false,
  });

  /// Engine can seek to an arbitrary [Duration] mid-utterance.
  final bool canSeek;

  /// Engine can report [TtsEngine.getCurrentPosition].
  final bool canGetPosition;

  /// Engine fires [TtsEngineEventType.wordBoundary] events during synthesis.
  final bool supportsWordBoundary;

  /// Engine accepts SSML-tagged input in [TtsEngine.speak].
  final bool supportsSsml;

  /// Engine honours [HumanizationConfig] prosody variance parameters.
  final bool supportsProsodyVariance;

  /// Engine exposes more than one voice via [TtsEngine.getVoices].
  final bool supportsMultipleVoices;

  /// Engine includes network / cloud voices (WaveNet, Neural, etc.).
  final bool supportsNetworkVoices;

  /// Engine continues speaking when the app is in the background.
  final bool supportsBackgroundPlayback;

  /// A conservative baseline — safe to return from engines that have not yet
  /// declared their capabilities.
  static const TtsEngineCapabilities minimal = TtsEngineCapabilities();

  @override
  String toString() =>
      'TtsEngineCapabilities('
      'seek: $canSeek, '
      'position: $canGetPosition, '
      'wordBoundary: $supportsWordBoundary, '
      'ssml: $supportsSsml, '
      'prosody: $supportsProsodyVariance, '
      'voices: $supportsMultipleVoices, '
      'network: $supportsNetworkVoices, '
      'background: $supportsBackgroundPlayback)';
}

// ─── Typed exceptions ─────────────────────────────────────────────────────────

/// Error codes that [TtsEngineException] can carry.
enum TtsEngineErrorCode {
  /// [TtsEngine.init] has not been called yet.
  notInitialized,

  /// The requested voice name was not found on this device.
  voiceNotFound,

  /// The language code is not supported by the active engine.
  languageNotSupported,

  /// Synthesis failed during an active utterance.
  synthesisFailure,

  /// A network voice was requested but no network is available.
  networkRequired,

  /// The underlying platform TTS service reported a device-level error.
  deviceError,

  /// An operation was requested in an invalid state (e.g. resume when idle).
  invalidState,

  /// An unclassified / unknown error occurred.
  unknown,
}

/// Typed exception thrown by [TtsEngine] implementations.
class TtsEngineException implements Exception {
  const TtsEngineException(this.code, this.message, {this.cause});

  final TtsEngineErrorCode code;
  final String message;

  /// The underlying platform error, if any.
  final Object? cause;

  @override
  String toString() =>
      'TtsEngineException(${code.name}): $message'
      '${cause != null ? ' (caused by: $cause)' : ''}';
}

// ─── Events ───────────────────────────────────────────────────────────────────

enum TtsEngineEventType {
  // ── Lifecycle ──────────────────────────────────────────────────────────────
  initialized,
  start,
  completion,
  pause,
  resume,
  cancel,
  error,

  // ── Structural progress ────────────────────────────────────────────────────
  /// Fires at the start of a new sentence.
  sentenceStart,

  /// Fires at the end of a sentence.
  sentenceEnd,

  /// Fires when the engine enters a new paragraph.
  paragraphStart,

  /// Fires when the engine leaves a paragraph.
  paragraphEnd,

  // ── Word-level ─────────────────────────────────────────────────────────────
  /// Fires for each word boundary; carries [TtsEngineEvent.charIndex] and
  /// [TtsEngineEvent.charLength].
  wordBoundary,

  // ── Playback position ──────────────────────────────────────────────────────
  /// Coarse progress tick; carries [TtsEngineEvent.position].
  progress,

  /// Fires after a successful [TtsEngine.seekTo]; carries [TtsEngineEvent.position].
  seeked,

  // ── Configuration changes ──────────────────────────────────────────────────
  rateChanged,
  pitchChanged,
  volumeChanged,
  voiceChanged,
}

/// A single event emitted on [TtsEngine.events].
class TtsEngineEvent {
  const TtsEngineEvent(
    this.type, {
    this.message,
    this.data = const {},
    this.charIndex,
    this.charLength,
    this.position,
    this.sentenceIndex,
    this.paragraphIndex,
  });

  final TtsEngineEventType type;

  /// Human-readable description (primarily for error events).
  final String? message;

  /// Arbitrary extra payload for callers that need structured data beyond
  /// the typed fields.
  final Map<String, dynamic> data;

  // ── Typed payload fields ────────────────────────────────────────────────────

  /// Start character offset for [TtsEngineEventType.wordBoundary] events.
  final int? charIndex;

  /// Character length for [TtsEngineEventType.wordBoundary] events.
  final int? charLength;

  /// Current playback position for [TtsEngineEventType.progress] and
  /// [TtsEngineEventType.seeked] events.
  final Duration? position;

  /// Flat sentence index for [TtsEngineEventType.sentenceStart] /
  /// [TtsEngineEventType.sentenceEnd] events.
  final int? sentenceIndex;

  /// Paragraph index for [TtsEngineEventType.paragraphStart] /
  /// [TtsEngineEventType.paragraphEnd] events.
  final int? paragraphIndex;

  @override
  String toString() {
    final parts = <String>[type.name];
    if (message != null) parts.add(message!);
    if (charIndex != null) parts.add('char:$charIndex+$charLength');
    if (position != null) parts.add('pos:${position!.inMilliseconds}ms');
    if (sentenceIndex != null) parts.add('sentence:$sentenceIndex');
    if (paragraphIndex != null) parts.add('paragraph:$paragraphIndex');
    return 'TtsEngineEvent(${parts.join(', ')})';
  }
}

// ─── Humanization config ─────────────────────────────────────────────────────

/// Configures all humanization behaviour — pause timings, prosody variance, etc.
class HumanizationConfig {
  const HumanizationConfig({
    // --- Pause durations (ms) ---
    this.commaBreakMs = 280,
    this.semicolonBreakMs = 420,
    this.colonBreakMs = 360,
    this.periodBreakMs = 540,
    this.questionMarkBreakMs = 580,
    this.exclamationBreakMs = 480,
    this.dashBreakMs = 240,
    this.paragraphBreakMs = 880,
    this.ellipsisBreakMs = 640,

    // --- Prosody variance ---
    this.enableVariablePitch = true,
    this.enableVariableRate = true,
    this.pitchVarianceRange = 0.04,
    this.rateVarianceRange = 0.03,

    // --- Tone shaping ---
    this.questionPitchBoost = 1.03,
    this.questionRateFactor = 0.96,
    this.exclamationPitchBoost = 1.02,
    this.exclamationRateBoost = 1.03,
    this.listingRateFactor = 0.98,
    this.paragraphStartPitchBoost = 1.015,
    this.finalSentenceRateFactor = 0.96,

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

  // ─── Built-in presets ─────────────────────────────────────────────────────

  /// Balanced, natural-sounding preset — recommended default.
  static const HumanizationConfig natural = HumanizationConfig();

  /// Broadcast-style cadence for evening-news narration.
  static const HumanizationConfig anchorDesk = HumanizationConfig(
    commaBreakMs: 300,
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
    listingRateFactor: 0.96,
    paragraphStartPitchBoost: 1.02,
    finalSentenceRateFactor: 0.92,
  );

  /// Tighter pauses, less variance — useful for fast news-style reading.
  static const HumanizationConfig newsCast = HumanizationConfig(
    commaBreakMs: 180,
    periodBreakMs: 380,
    paragraphBreakMs: 600,
    exclamationRateBoost: 1.04,
  );

  /// Slower, wider variance — ideal for story / literary reading.
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

  /// Flat, predictable — for accessibility or testing.
  static const HumanizationConfig flat = HumanizationConfig(
    enableVariablePitch: false,
    enableVariableRate: false,
    commaBreakMs: 150,
    periodBreakMs: 300,
    paragraphBreakMs: 500,
    pitchVarianceRange: 0,
    rateVarianceRange: 0,
  );

  // ─── Lerp ────────────────────────────────────────────────────────────────

  /// Linearly interpolates between [a] and [b] by [t] ∈ [0, 1].
  ///
  /// Useful for smooth transitions between presets (e.g. speed ramping).
  static HumanizationConfig lerp(
    HumanizationConfig a,
    HumanizationConfig b,
    double t,
  ) {
    assert(t >= 0.0 && t <= 1.0, 't must be in [0, 1]');
    double lerpD(double av, double bv) => av + (bv - av) * t;
    int lerpI(int av, int bv) => (av + (bv - av) * t).round();
    bool lerpB(bool av, bool bv) => t < 0.5 ? av : bv;

    return HumanizationConfig(
      commaBreakMs: lerpI(a.commaBreakMs, b.commaBreakMs),
      semicolonBreakMs: lerpI(a.semicolonBreakMs, b.semicolonBreakMs),
      colonBreakMs: lerpI(a.colonBreakMs, b.colonBreakMs),
      periodBreakMs: lerpI(a.periodBreakMs, b.periodBreakMs),
      questionMarkBreakMs: lerpI(a.questionMarkBreakMs, b.questionMarkBreakMs),
      exclamationBreakMs: lerpI(a.exclamationBreakMs, b.exclamationBreakMs),
      dashBreakMs: lerpI(a.dashBreakMs, b.dashBreakMs),
      paragraphBreakMs: lerpI(a.paragraphBreakMs, b.paragraphBreakMs),
      ellipsisBreakMs: lerpI(a.ellipsisBreakMs, b.ellipsisBreakMs),
      enableVariablePitch: lerpB(a.enableVariablePitch, b.enableVariablePitch),
      enableVariableRate: lerpB(a.enableVariableRate, b.enableVariableRate),
      pitchVarianceRange: lerpD(a.pitchVarianceRange, b.pitchVarianceRange),
      rateVarianceRange: lerpD(a.rateVarianceRange, b.rateVarianceRange),
      questionPitchBoost: lerpD(a.questionPitchBoost, b.questionPitchBoost),
      questionRateFactor: lerpD(a.questionRateFactor, b.questionRateFactor),
      exclamationPitchBoost: lerpD(
        a.exclamationPitchBoost,
        b.exclamationPitchBoost,
      ),
      exclamationRateBoost: lerpD(
        a.exclamationRateBoost,
        b.exclamationRateBoost,
      ),
      listingRateFactor: lerpD(a.listingRateFactor, b.listingRateFactor),
      paragraphStartPitchBoost: lerpD(
        a.paragraphStartPitchBoost,
        b.paragraphStartPitchBoost,
      ),
      finalSentenceRateFactor: lerpD(
        a.finalSentenceRateFactor,
        b.finalSentenceRateFactor,
      ),
      enableParagraphPause: lerpB(
        a.enableParagraphPause,
        b.enableParagraphPause,
      ),
      enableClausePause: lerpB(a.enableClausePause, b.enableClausePause),
      expandAbbreviations: lerpB(a.expandAbbreviations, b.expandAbbreviations),
      normalizeNumbers: lerpB(a.normalizeNumbers, b.normalizeNumbers),
    );
  }

  // ─── copyWith ────────────────────────────────────────────────────────────

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

// ─── Abstract engine contract ─────────────────────────────────────────────────

abstract class TtsEngine {
  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// One-time initialisation — must be called before any other method.
  ///
  /// Throws [TtsEngineException] with code [TtsEngineErrorCode.deviceError]
  /// if the underlying TTS service cannot be started.
  Future<void> init();

  /// `true` after [init] completes successfully.
  bool get isInitialized;

  /// Declares the optional capabilities supported by this engine.
  TtsEngineCapabilities get capabilities;

  // ── Synthesis ───────────────────────────────────────────────────────────────

  /// Speaks [text] verbatim with no humanisation processing.
  Future<void> speak(String text);

  /// Speaks an article with full humanisation: pause shaping, prosody
  /// variance, abbreviation expansion, and paragraph / sentence segmentation.
  ///
  /// [language] defaults to [ArticleLanguage.auto] which detects Bengali vs
  /// English by Unicode character ratio.
  Future<void> speakArticle(
    String text, {
    ArticleLanguage language = ArticleLanguage.auto,
  });

  // ── Transport controls ──────────────────────────────────────────────────────

  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  // ── Seeking ─────────────────────────────────────────────────────────────────

  /// Seeks to [position] within the current utterance.
  ///
  /// Only valid when [capabilities.canSeek] is `true`. Fires a
  /// [TtsEngineEventType.seeked] event on success.
  ///
  /// Throws [TtsEngineException] with code [TtsEngineErrorCode.invalidState]
  /// when called on an engine that does not support seeking.
  Future<void> seekTo(Duration position);

  /// Returns the current playback position, or [Duration.zero] if unknown.
  ///
  /// Only valid when [capabilities.canGetPosition] is `true`.
  Future<Duration> getCurrentPosition();

  // ── Configuration ───────────────────────────────────────────────────────────

  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVolume(double volume);
  Future<void> setVoice(VoiceProfile voice);
  Future<void> setLanguage(String languageCode);
  Future<void> setHumanization(HumanizationConfig config);

  // ── Voice discovery ─────────────────────────────────────────────────────────

  Future<List<VoiceProfile>> getVoices();
  Future<List<VoiceProfile>> getVoicesForLanguage(String languageCode);

  // ── State inspection ────────────────────────────────────────────────────────

  bool get isSpeaking;
  bool get isPaused;

  // ── Event stream ────────────────────────────────────────────────────────────

  /// Broadcast stream of all engine lifecycle and progress events.
  Stream<TtsEngineEvent> get events;

  // ── Cleanup ─────────────────────────────────────────────────────────────────

  void dispose();
}
