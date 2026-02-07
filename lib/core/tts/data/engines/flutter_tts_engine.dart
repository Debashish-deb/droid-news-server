import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'tts_engine.dart';
import '../../domain/entities/voice_profile.dart';

class FlutterTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  final _eventController = StreamController<TtsEngineEvent>.broadcast();

  @override
  Future<void> init() async {
    _tts.setStartHandler(() {
      _eventController.add(TtsEngineEvent(TtsEngineEventType.start));
    });

    _tts.setCompletionHandler(() {
      _eventController.add(TtsEngineEvent(TtsEngineEventType.completion));
    });

    _tts.setCancelHandler(() {
      _eventController.add(TtsEngineEvent(TtsEngineEventType.cancel));
    });

    _tts.setErrorHandler((msg) {
      _eventController.add(TtsEngineEvent(TtsEngineEventType.error, message: msg.toString()));
    });

    _tts.setProgressHandler((text, start, end, word) {
      _eventController.add(TtsEngineEvent(
        TtsEngineEventType.progress,
        data: {'text': text, 'start': start, 'end': end, 'word': word},
      ));
    });
    
    await _tts.setQueueMode(1); // queue mode 1 for immediate interrupt
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> pause() async {
    // flutter_tts doesn't have a true pause, it usually means stop but we handle resuming in repository
    await _tts.stop();
    _eventController.add(TtsEngineEvent(TtsEngineEventType.pause));
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  @override
  Future<void> setVoice(VoiceProfile voice) async {
    await _tts.setVoice({"name": voice.name, "locale": voice.locale});
  }

  @override
  Future<List<VoiceProfile>> getVoices() async {
    final voices = await _tts.getVoices;
    if (voices == null) return [];
    
    return (voices as List).map((dynamic v) {
      final map = v as Map;
      return VoiceProfile(
        name: map['name'] as String? ?? 'Unknown',
        locale: map['locale'] as String? ?? 'Unknown',
      );
    }).toList();
  }

  @override
  Stream<TtsEngineEvent> get events => _eventController.stream;
}
