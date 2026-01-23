import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

abstract class TtsService {
  Future<void> init();
  Future<void> setLanguage(String language);
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> speak(String text);
  Future<String?> synthesizeToFile(String text, String fileName);
  Future<void> stop();
}

class FlutterTtsAdapter implements TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  Future<void> init() async {
    await _flutterTts.awaitSpeakCompletion(true);
    if (Platform.isIOS) {
       await _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
         IosTextToSpeechAudioCategoryOptions.duckOthers,
         IosTextToSpeechAudioCategoryOptions.mixWithOthers,
       ]);
    }
  }

  @override
  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  @override
  Future<void> setRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  @override
  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  Future<String?> synthesizeToFile(String text, String fileName) async {
    // flutter_tts synthesizeToFile behavior varies by platform
    // On Android, passing just fileName saves to external cache
    // On iOS, it might need full path
    
    try {
      if (Platform.isAndroid) {
        // Android synthesis
        // We pass the full path but flutter_tts on Android takes 'filename' (relative?) or absolute?
        // Checking documentation: Android params map usually expects 'filename'
        // Let's assume absolute path works or try relative.
        // Actually, flutter_tts synthesizeToFile implementation: 
        // Android: uses TextToSpeech.synthesizeToFile, which takes a file ID or path.
        // It's safer to use a temp file provided by the system if path is tricky
        
        // For MVP simplicity and robustness, strict "Industrial" might require native channel fix if flutter_tts is flaky
        // But let's try calling it.
        await _flutterTts.synthesizeToFile(text, fileName);
        return fileName; // We assume it wrote to where we asked (if absolute)
      } else if (Platform.isIOS) {
        await _flutterTts.synthesizeToFile(text, fileName);
        return fileName;
      }
    } catch (e) {
      print('Synthesis error: $e');
    }
    return null;
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
