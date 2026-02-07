import '../../domain/entities/voice_profile.dart';

abstract class TtsEngine {
  Future<void> init();
  Future<void> speak(String text);
  Future<void> pause();
  Future<void> stop();
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVoice(VoiceProfile voice);
  Future<List<VoiceProfile>> getVoices();
  
  Stream<TtsEngineEvent> get events;
}

enum TtsEngineEventType {
  start,
  completion,
  pause,
  cancel,
  error,
  progress,
}

class TtsEngineEvent {

  TtsEngineEvent(this.type, {this.message, this.data = const {}});
  final TtsEngineEventType type;
  final String? message;
  final Map<String, dynamic> data;
}
