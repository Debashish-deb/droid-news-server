class TtsConfig {

  static const int maxCacheSizeMB = 500;
  static const int preloadBufferSize = 3;
  static const Duration synthesisTimeout = Duration(seconds: 30);
  static const Set<String> supportedLanguages = {'en', 'bn', 'hi'};
  

  static const double defaultSpeechRate = 1.0;
  static const double defaultPitch = 1.0;
  static const double defaultVolume = 1.0;


  static const String databaseName = 'tts_cache.db';
  static const int databaseVersion = 2; 
}
