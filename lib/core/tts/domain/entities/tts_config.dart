class TtsConfig {

  const TtsConfig({
    this.rate = 1.0,
    this.pitch = 1.0,
    this.voice,
    this.language = 'en-US',
  });
  final double rate;
  final double pitch;
  final String? voice;
  final String language;

  TtsConfig copyWith({
    double? rate,
    double? pitch,
    String? voice,
    String? language,
  }) {
    return TtsConfig(
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      voice: voice ?? this.voice,
      language: language ?? this.language,
    );
  }
}
