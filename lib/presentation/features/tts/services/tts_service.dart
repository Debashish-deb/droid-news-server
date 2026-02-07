import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';


abstract class TtsService {
  Future<void> init();
  Future<void> setLanguage(String language);
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> speak(String text);
  Future<String?> synthesizeToFile(String text, String fileName);
  Future<List<Map<String, String>>> getVoices();
  Future<void> setVoice(String voiceName, String locale);
  Future<void> stop();
  Future<void> setSpeed(double speed);
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
  Future<String?> synthesizeToFile(String text, String absolutePath) async {
    try {
      final String fileName = absolutePath.split('/').last;
      
      if (Platform.isAndroid) {
       debugPrint("TTS_DEBUG: Android synthesis to name: $fileName");
        final int result = await _flutterTts.synthesizeToFile(text, fileName);
        
        if (result == 1) {
          final Directory? externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final File file = File('${externalDir.path}/$fileName');
            
            int attempts = 0;
            while (attempts < 10) {
              if (await file.exists() && await file.length() > 0) {
                debugPrint("TTS_DEBUG: Android file verified at: ${file.path}");
                return file.path;
              }
              await Future.delayed(const Duration(milliseconds: 300));
              attempts++;
            }
          }
        }
        debugPrint("TTS_DEBUG: Android synthesis failed or file not found.");
        return null;
      } else if (Platform.isIOS) {
        debugPrint("TTS_DEBUG: iOS synthesis to name: $fileName");
        final int result = await _flutterTts.synthesizeToFile(text, fileName);
        
        if (result == 1) {
          final Directory docsDir = await getApplicationDocumentsDirectory();
          final File file = File('${docsDir.path}/$fileName');
          
          int attempts = 0;
          while (attempts < 10) {
            if (await file.exists() && await file.length() > 0) {
              debugPrint("TTS_DEBUG: iOS file verified at: ${file.path}");
              return file.path;
            }
            await Future.delayed(const Duration(milliseconds: 300));
            attempts++;
          }
        }
        debugPrint("TTS_DEBUG: iOS synthesis failed or file not found.");
        return null;
      } else {
        await _flutterTts.synthesizeToFile(text, absolutePath);
        return absolutePath;
      }
    } catch (e) {
      debugPrint('Synthesis error: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final List<dynamic>? voices = await _flutterTts.getVoices;
      if (voices == null) return [];
      
      return voices.map((v) => {
        'name': (v['name'] ?? '').toString(),
        'locale': (v['locale'] ?? '').toString(),
      }).toList();
    } catch (e) {
      debugPrint("Error getting voices: $e");
      return [];
    }
  }

  @override
  Future<void> setVoice(String voiceName, String locale) async {
    await _flutterTts.setVoice({"name": voiceName, "locale": locale});
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await setRate(speed);
  }
}
