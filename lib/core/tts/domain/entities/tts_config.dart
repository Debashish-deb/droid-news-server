import '../../data/engines/tts_engine.dart';

class TtsConfig {
  const TtsConfig({
    this.rate = 0.44,
    this.pitch = 0.94,
    this.volume = 1.0,
    this.voice,
    this.languageCode = 'en-US',
    this.humanization = HumanizationConfig.anchorDesk,
  });

  factory TtsConfig.defaults() => const TtsConfig();

  final double rate;
  final double pitch;
  final double volume;
  final String? voice;
  final String languageCode;
  final HumanizationConfig humanization;

  TtsConfig copyWith({
    double? rate,
    double? pitch,
    double? volume,
    String? voice,
    String? languageCode,
    HumanizationConfig? humanization,
  }) {
    return TtsConfig(
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      voice: voice ?? this.voice,
      languageCode: languageCode ?? this.languageCode,
      humanization: humanization ?? this.humanization,
    );
  }
}
