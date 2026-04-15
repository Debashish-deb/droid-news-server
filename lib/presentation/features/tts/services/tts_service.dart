import 'dart:async' show Completer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../core/tts/shared/tts_voice_heuristics.dart';

@immutable
class TtsSynthesisDebugInfo {
  const TtsSynthesisDebugInfo({
    this.requestedPath,
    this.resolvedPath,
    this.strategy = 'idle',
    this.usedFullPath = false,
    this.resultCode,
    this.message,
  });

  static const Object _unset = Object();

  final String? requestedPath;
  final String? resolvedPath;
  final String strategy;
  final bool usedFullPath;
  final int? resultCode;
  final String? message;

  TtsSynthesisDebugInfo copyWith({
    Object? requestedPath = _unset,
    Object? resolvedPath = _unset,
    String? strategy,
    bool? usedFullPath,
    Object? resultCode = _unset,
    Object? message = _unset,
  }) {
    return TtsSynthesisDebugInfo(
      requestedPath: identical(requestedPath, _unset)
          ? this.requestedPath
          : requestedPath as String?,
      resolvedPath: identical(resolvedPath, _unset)
          ? this.resolvedPath
          : resolvedPath as String?,
      strategy: strategy ?? this.strategy,
      usedFullPath: usedFullPath ?? this.usedFullPath,
      resultCode: identical(resultCode, _unset)
          ? this.resultCode
          : resultCode as int?,
      message: identical(message, _unset) ? this.message : message as String?,
    );
  }
}

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

  TtsSynthesisDebugInfo get lastSynthesisDebugInfo;
}

class FlutterTtsAdapter implements TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  // ── Cached temp directory ─────────────────────────────────────────────────
  // Resolved once on first synthesis call; a platform-channel call costs ~5ms
  // so caching it prevents per-chunk overhead.
  String? _tempDirPath;

  double _currentRate = 0.45;
  TtsSynthesisDebugInfo _lastSynthesisDebugInfo = const TtsSynthesisDebugInfo();

  @override
  double get currentRate => _currentRate;

  @override
  TtsSynthesisDebugInfo get lastSynthesisDebugInfo => _lastSynthesisDebugInfo;

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
  @override
  Future<String?> synthesizeToFile(String text, String filePath) async {
    try {
      _tempDirPath ??= (await getTemporaryDirectory()).path;
      final targetPath = p.isAbsolute(filePath)
          ? filePath
          : p.join(_tempDirPath!, p.basename(filePath));
      final fileName = p.basename(targetPath);
      _lastSynthesisDebugInfo = TtsSynthesisDebugInfo(
        requestedPath: targetPath,
        strategy: Platform.isAndroid
            ? 'android_full_path'
            : Platform.isIOS
            ? 'ios_documents_lookup'
            : 'direct_path',
        usedFullPath: Platform.isAndroid,
      );

      if (Platform.isAndroid) {
        return await _synthesizeAndroid(text, fileName, targetPath);
      } else if (Platform.isIOS) {
        return await _synthesizeIos(text, fileName, targetPath);
      } else {
        await _flutterTts.synthesizeToFile(text, targetPath);
        _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
          resolvedPath: targetPath,
        );
        return targetPath;
      }
    } catch (e) {
      debugPrint('[TtsService] synthesizeToFile error: $e');
      _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
        message: e.toString(),
      );
      return null;
    }
  }

  Future<String?> _synthesizeAndroid(
    String text,
    String fileName,
    String targetPath,
  ) async {
    final targetFile = File(targetPath);
    await targetFile.parent.create(recursive: true);
    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    final completer = Completer<void>();
    Object? callbackError;
    bool completedNaturally = false;

    _flutterTts.setCompletionHandler(() {
      if (!completer.isCompleted) {
        completedNaturally = true;
        completer.complete();
      }
    });
    _flutterTts.setErrorHandler((message) {
      callbackError = StateError(message);
      if (!completer.isCompleted) {
        completer.completeError(callbackError!);
      }
    });

    final result = await _flutterTts.synthesizeToFile(text, targetPath, true);
    _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
      requestedPath: targetPath,
      strategy: 'android_full_path',
      usedFullPath: true,
      resultCode: result is int ? result : null,
    );
    if (result != 1) {
      debugPrint('[TtsService] Android synthesizeToFile returned $result');
      _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
        message: 'Android synthesizeToFile returned $result',
      );
      return null;
    }

    // Wait for the TTS engine to signal completion (or an error), with an
    // explicit 20 s ceiling.  We track whether the completer resolved
    // naturally so we can distinguish a real timeout from a slow synthesis.
    try {
      await Future.any([
        completer.future,
        Future<void>.delayed(const Duration(seconds: 20)),
      ]);
    } catch (error) {
      callbackError = error;
    }

    // Explicit timeout: synthesis never completed — return null immediately
    // instead of proceeding to file polling (which would always fail).
    if (!completedNaturally && callbackError == null) {
      const message =
          'Android synthesis timed out after 20 s — no completion callback received.';
      debugPrint('[TtsService] $message');
      _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
        message: message,
      );
      return null;
    }

    if (callbackError != null) {
      final message = 'Android synthesis callback error: $callbackError';
      debugPrint('[TtsService] $message');
      _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
        message: message,
      );
      return null;
    }

    final candidates = <String>[targetPath];
    final externalFilesPath = await _getExternalFilesPath(fileName);
    if (externalFilesPath != null) {
      candidates.add(externalFilesPath);
    }
    final publicMusicPath = await _getPublicMusicPath(fileName);
    if (publicMusicPath != null) {
      candidates.add(publicMusicPath);
    }

    final resolvedPath = await _resolveCandidateFile(candidates);
    if (resolvedPath == null) {
      final message =
          'Android synthesis completed but no readable file was found. '
          'Tried: ${candidates.join(', ')}';
      debugPrint('[TtsService] $message');
      _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
        message: message,
      );
      return null;
    }

    if (resolvedPath != targetPath) {
      final resolvedFile = File(resolvedPath);
      await resolvedFile.copy(targetPath);
      try {
        await resolvedFile.delete();
      } catch (_) {}
    }

    debugPrint('[TtsService] Android file ready: $targetPath');
    _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
      resolvedPath: targetPath,
      message: 'Android synthesis ready',
    );
    return targetPath;
  }

  Future<String?> _resolveCandidateFile(List<String> candidates) async {
    for (int attempt = 0; attempt < 20; attempt++) {
      for (final candidate in candidates) {
        final file = File(candidate);
        if (await file.exists() && await file.length() > 0) {
          return candidate;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
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
      _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
        strategy: 'ios_documents_lookup',
        resultCode: result is int ? result : null,
        message: 'iOS synthesizeToFile returned $result',
      );
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
        _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
          strategy: 'ios_documents_lookup',
          resolvedPath: file.path,
          resultCode: result is int ? result : null,
          message: 'iOS synthesis ready',
        );
        return file.path;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    debugPrint('[TtsService] iOS: file not found after synthesis');
    _lastSynthesisDebugInfo = _lastSynthesisDebugInfo.copyWith(
      strategy: 'ios_documents_lookup',
      resultCode: result is int ? result : null,
      message: 'iOS synthesis completed but file was not readable in time.',
    );
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

  Future<String?> _getPublicMusicPath(String fileName) async {
    try {
      final directory = Directory('/storage/emulated/0/Music');
      return p.join(directory.path, fileName);
    } catch (_) {}
    return null;
  }

  @override
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices == null) return [];
      final candidates = (voices as List)
          .whereType<Map>()
          .map(TtsVoiceCandidate.fromRawMap)
          .toList(growable: false);
      return TtsVoiceHeuristics.sanitizeCandidates(
        candidates,
      ).map((candidate) => candidate.toUiMap()).toList(growable: false);
    } catch (e) {
      debugPrint('[TtsService] getVoices error: $e');
      return [];
    }
  }

  @override
  Future<void> setVoice(String voiceName, String locale) async =>
      await _flutterTts.setVoice({'name': voiceName, 'locale': locale});
}
