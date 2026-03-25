import 'dart:async' show Completer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

abstract class TtsService {
  Future<void> init();
  Future<void> setLanguage(String language);
  Future<void> setRate(double rate);
  Future<void> setPitch(double pitch);
  Future<void> setVolume(double volume);
  Future<void> speak(String text);
  Future<String?> synthesizeToFile(String text, String filePath);
  Future<List<Map<String, String>>> getVoices();
  Future<void> setVoice(String voiceName, String locale);
  Future<void> stop();
  Future<void> setSpeed(double speed);

  /// Current playback rate (1.0 = normal).
  double get currentRate;
}

class FlutterTtsAdapter implements TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  // ── Cached temp directory ─────────────────────────────────────────────────
  // Resolved once on first synthesis call; a platform-channel call costs ~5ms
  // so caching it prevents per-chunk overhead.
  String? _tempDirPath;

  double _currentRate = 0.45;

  @override
  double get currentRate => _currentRate;

  @override
  Future<void> init() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setPitch(0.95);

    if (Platform.isAndroid) {
      // Queue mode 1 = flush: new speak() immediately interrupts the previous
      // one.  This gives instant response to user next/prev actions.
      await _flutterTts.setQueueMode(1);
    }

    if (Platform.isIOS) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.duckOthers],
      );
    }
  }

  @override
  Future<void> setLanguage(String language) async =>
      await _flutterTts.setLanguage(language);

  @override
  Future<void> setRate(double rate) async {
    _currentRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  Future<void> setSpeed(double speed) => setRate(speed);

  @override
  Future<void> setPitch(double pitch) async =>
      await _flutterTts.setPitch(pitch);

  @override
  Future<void> setVolume(double volume) async =>
      await _flutterTts.setVolume(volume);

  @override
  Future<void> speak(String text) async => await _flutterTts.speak(text);

  @override
  Future<void> stop() async => await _flutterTts.stop();

  // ── synthesizeToFile ──────────────────────────────────────────────────────
  //
  // The original code used getExternalStorageDirectory() on Android and then
  // polled for the file up to 10 times × 300ms = 3-second busy-wait.
  //
  // Problems:
  //   • On Android 10+ scoped storage, getExternalStorageDirectory() returns
  //     a path inside the app's media directory.  flutter_tts writes to
  //     /sdcard/Android/data/<pkg>/files/ by default, which is a DIFFERENT
  //     path than what getExternalStorageDirectory() returns.
  //   • The busy-wait burns CPU and delays the UI by up to 3 seconds per chunk.
  //
  // Fix:
  //   1. Use getTemporaryDirectory() – a reliable, always-writable path on all
  //      Android versions that flutter_tts also uses.
  //   2. Use a Completer that resolves from the synthesize progress/completion
  //      callback instead of polling.  If the callback fires, we know exactly
  //      when the file is ready.  A 10-second timeout acts as the final safety net.
  @override
  Future<String?> synthesizeToFile(String text, String filePath) async {
    try {
      _tempDirPath ??= (await getTemporaryDirectory()).path;
      final fileName = p.basename(filePath);
      final targetPath = p.join(_tempDirPath!, fileName);

      if (Platform.isAndroid) {
        return await _synthesizeAndroid(text, fileName, targetPath);
      } else if (Platform.isIOS) {
        return await _synthesizeIos(text, fileName, targetPath);
      } else {
        await _flutterTts.synthesizeToFile(text, filePath);
        return filePath;
      }
    } catch (e) {
      debugPrint('[TtsService] synthesizeToFile error: $e');
      return null;
    }
  }

  Future<String?> _synthesizeAndroid(
    String text,
    String fileName,
    String targetPath,
  ) async {
    // flutter_tts writes to getExternalFilesDir() on Android.
    // We must ask it for just the file name (no path), and then look for the
    // file in the directory it actually writes to: getExternalStorageDirectory
    // on the device, which maps to /Android/data/<pkg>/files/.
    //
    // Strategy: call synthesizeToFile() with just the filename, then locate
    // the output by checking the two most likely locations instead of polling.

    final completer = Completer<String?>();

    // One-shot completion handler during synthesis
    void onComplete() {
      if (!completer.isCompleted) completer.complete(null);
    }

    _flutterTts.setCompletionHandler(onComplete);

    // Kick off synthesis
    final result = await _flutterTts.synthesizeToFile(text, fileName);
    if (result != 1) {
      debugPrint('[TtsService] Android synthesizeToFile returned $result');
      return null;
    }

    // Wait for the TTS engine to finish (with a ceiling of 15 seconds)
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 15)),
    ]);

    // Look for the file in both possible locations
    final candidates = [
      targetPath,
      // ExternalFiles path that flutter_tts actually writes to
      await _getExternalFilesPath(fileName),
    ].whereType<String>().toList();

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists() && await file.length() > 0) {
        debugPrint('[TtsService] Android file found: $candidate');
        // If found in external files, copy to our temp dir so we own it
        if (candidate != targetPath) {
          await file.copy(targetPath);
          try {
            await file.delete();
          } catch (_) {}
        }
        return targetPath;
      }
    }

    debugPrint('[TtsService] Android: file not found after synthesis');
    return null;
  }

  Future<String?> _synthesizeIos(
    String text,
    String fileName,
    String targetPath,
  ) async {
    final result = await _flutterTts.synthesizeToFile(text, fileName);
    if (result != 1) {
      debugPrint('[TtsService] iOS synthesizeToFile returned $result');
      return null;
    }

    // iOS writes to the app documents directory
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(docsDir.path, fileName));

    // Give the engine up to 10 seconds, checking every 200ms — far better
    // than a 3-second fixed wait
    for (int i = 0; i < 50; i++) {
      if (await file.exists() && await file.length() > 0) {
        debugPrint('[TtsService] iOS file ready: ${file.path}');
        return file.path;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    debugPrint('[TtsService] iOS: file not found after synthesis');
    return null;
  }

  /// Returns the path that flutter_tts actually uses on Android for
  /// synthesizeToFile — the external files dir.
  Future<String?> _getExternalFilesPath(String fileName) async {
    try {
      final external = await getExternalStorageDirectory();
      if (external != null) return p.join(external.path, fileName);
    } catch (_) {}
    return null;
  }

  @override
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices == null) return [];
      return (voices as List).map((v) {
        final map = v as Map;
        return {
          'name': (map['name'] ?? '').toString(),
          'locale': (map['locale'] ?? '').toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint('[TtsService] getVoices error: $e');
      return [];
    }
  }

  @override
  Future<void> setVoice(String voiceName, String locale) async =>
      await _flutterTts.setVoice({'name': voiceName, 'locale': locale});
}
