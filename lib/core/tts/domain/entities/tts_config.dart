import 'package:flutter/foundation.dart';

import '../../data/engines/tts_engine.dart';

/// Immutable configuration snapshot for a TTS session.
///
/// All numeric parameters are validated and clamped on construction via
/// [copyWith].  Use the named factories for common presets.
@immutable
class TtsConfig {
  const TtsConfig({
    this.rate = 0.44,
    this.pitch = 0.98,
    this.volume = 1.0,
    this.voice,
    this.languageCode = 'en-US',
    this.humanization = HumanizationConfig.natural,
  }) : assert(rate >= 0.1 && rate <= 1.0, 'rate must be in [0.1, 1.0]'),
       assert(pitch >= 0.5 && pitch <= 2.0, 'pitch must be in [0.5, 2.0]'),
       assert(volume >= 0.0 && volume <= 1.0, 'volume must be in [0.0, 1.0]');

  // ─── Named constructors / presets ─────────────────────────────────────────

  /// Balanced defaults — suitable for most users and languages.
  factory TtsConfig.defaults() => const TtsConfig();

  /// Noticeably faster reading speed.
  factory TtsConfig.fast() =>
      const TtsConfig(rate: 0.65, humanization: HumanizationConfig.newsCast);

  /// Comfortable slower reading speed.
  factory TtsConfig.slow() => const TtsConfig(
    rate: 0.28,
    pitch: 0.96,
    humanization: HumanizationConfig.storyteller,
  );

  /// Broadcast-quality anchor cadence.
  factory TtsConfig.anchorDesk() => const TtsConfig(
    rate: 0.42,
    pitch: 0.95,
    humanization: HumanizationConfig.anchorDesk,
  );

  /// Defaults tuned for Bengali articles.
  factory TtsConfig.bengali() => const TtsConfig(
    languageCode: 'bn-BD',
    rate: 0.38,
  );

  /// Restores a [TtsConfig] serialised with [toJson].
  factory TtsConfig.fromJson(Map<String, dynamic> json) {
    return TtsConfig(
      rate: _clampRate(json['rate'] as double? ?? 0.44),
      pitch: _clampPitch(json['pitch'] as double? ?? 0.98),
      volume: _clampVolume(json['volume'] as double? ?? 1.0),
      voice: json['voice'] as String?,
      languageCode: json['languageCode'] as String? ?? 'en-US',
    );
  }

  // ─── Fields ────────────────────────────────────────────────────────────────

  /// Speaking rate in [0.1, 1.0]; 0.44 ≈ natural conversational pace.
  final double rate;

  /// Pitch multiplier in [0.5, 2.0]; 1.0 = no change.
  final double pitch;

  /// Volume in [0.0, 1.0].
  final double volume;

  /// Voice name; `null` means "use engine default".
  final String? voice;

  /// BCP-47 language code (e.g. `"en-US"`, `"bn-BD"`).
  final String languageCode;

  /// Humanisation / prosody parameters applied by the engine.
  final HumanizationConfig humanization;

  // ─── Computed helpers ──────────────────────────────────────────────────────

  /// BCP-47 language subtag without region (e.g. `"en"` from `"en-US"`).
  String get language =>
      languageCode.split(RegExp(r'[-_]')).first.toLowerCase();

  /// `true` when the config matches its own defaults.
  bool get isDefault =>
      (rate - 0.44).abs() < 0.005 &&
      (pitch - 0.98).abs() < 0.005 &&
      (volume - 1.0).abs() < 0.005 &&
      voice == null &&
      languageCode == 'en-US';

  /// Rate expressed as an integer percentage (e.g. 44 for 0.44).
  int get ratePercent => (rate * 100).round();

  /// Human-readable rate label, e.g. `"0.5×"`.
  String get displayRate {
    if (rate <= 0.28) return '0.5×';
    if (rate <= 0.36) return '0.75×';
    if (rate <= 0.52) return '1×';
    if (rate <= 0.65) return '1.25×';
    if (rate <= 0.78) return '1.5×';
    return '2×';
  }

  /// `true` when the engine should use Bengali voices/rules.
  bool get isBengali => languageCode.toLowerCase().startsWith('bn');

  // ─── copyWith (with clamping) ──────────────────────────────────────────────

  TtsConfig copyWith({
    double? rate,
    double? pitch,
    double? volume,
    String? voice,
    String? languageCode,
    HumanizationConfig? humanization,
  }) {
    return TtsConfig(
      rate: _clampRate(rate ?? this.rate),
      pitch: _clampPitch(pitch ?? this.pitch),
      volume: _clampVolume(volume ?? this.volume),
      voice: voice ?? this.voice,
      languageCode: languageCode ?? this.languageCode,
      humanization: humanization ?? this.humanization,
    );
  }

  // ─── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rate': rate,
    'pitch': pitch,
    'volume': volume,
    if (voice != null) 'voice': voice,
    'languageCode': languageCode,
  };

  // ─── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsConfig &&
          runtimeType == other.runtimeType &&
          rate == other.rate &&
          pitch == other.pitch &&
          volume == other.volume &&
          voice == other.voice &&
          languageCode == other.languageCode;

  @override
  int get hashCode => Object.hash(rate, pitch, volume, voice, languageCode);

  @override
  String toString() =>
      'TtsConfig(rate: $rate, pitch: $pitch, vol: $volume, '
      'voice: ${voice ?? "default"}, lang: $languageCode)';

  // ─── Private helpers ──────────────────────────────────────────────────────

  static double _clampRate(double v) => v.clamp(0.1, 1.0);
  static double _clampPitch(double v) => v.clamp(0.5, 2.0);
  static double _clampVolume(double v) => v.clamp(0.0, 1.0);
}
