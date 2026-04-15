import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'speech_delivery_intelligence.dart';

class AdaptiveSpeechProfile {
  const AdaptiveSpeechProfile({
    this.rateBias = 0,
    this.pitchBias = 0,
    this.preferredPresetName,
    this.correctionCount = 0,
  });

  factory AdaptiveSpeechProfile.fromJson(Map<String, dynamic> json) {
    return AdaptiveSpeechProfile(
      rateBias: (json['rateBias'] as num?)?.toDouble() ?? 0,
      pitchBias: (json['pitchBias'] as num?)?.toDouble() ?? 0,
      preferredPresetName: json['preferredPresetName'] as String?,
      correctionCount: json['correctionCount'] as int? ?? 0,
    );
  }

  final double rateBias;
  final double pitchBias;
  final String? preferredPresetName;
  final int correctionCount;

  AdaptiveSpeechProfile copyWith({
    double? rateBias,
    double? pitchBias,
    String? preferredPresetName,
    int? correctionCount,
  }) {
    return AdaptiveSpeechProfile(
      rateBias: rateBias ?? this.rateBias,
      pitchBias: pitchBias ?? this.pitchBias,
      preferredPresetName: preferredPresetName ?? this.preferredPresetName,
      correctionCount: correctionCount ?? this.correctionCount,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rateBias': rateBias,
    'pitchBias': pitchBias,
    'preferredPresetName': preferredPresetName,
    'correctionCount': correctionCount,
  };
}

class AdaptiveSpeechProfileStore {
  static const String _prefsKey = 'tts_adaptive_speech_profiles_v1';

  Future<AdaptiveSpeechProfile> resolve({
    required String language,
    required String category,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _readMap(prefs);
      final data = map[_key(language, category)];
      if (data is Map<String, dynamic>) {
        return AdaptiveSpeechProfile.fromJson(data);
      }
      if (data is Map) {
        return AdaptiveSpeechProfile.fromJson(data.cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('[AdaptiveSpeechProfileStore] resolve failed: $e');
    }
    return const AdaptiveSpeechProfile();
  }

  Future<void> recordPresetCorrection({
    required String language,
    required String category,
    required String presetName,
  }) async {
    await _saveUpdatedProfile(
      language: language,
      category: category,
      transform: (current) => current.copyWith(
        preferredPresetName: presetName,
        correctionCount: current.correctionCount + 1,
      ),
    );
  }

  Future<void> recordPitchCorrection({
    required String language,
    required String category,
    required double pitch,
  }) async {
    final nextBias = (pitch - 0.98).clamp(-0.04, 0.04).toDouble();
    await _saveUpdatedProfile(
      language: language,
      category: category,
      transform: (current) => current.copyWith(
        pitchBias: _blend(current.pitchBias, nextBias, current.correctionCount),
        correctionCount: current.correctionCount + 1,
      ),
    );
  }

  Future<void> recordPlaybackPaceCorrection({
    required String language,
    required String category,
    required double playbackSpeed,
  }) async {
    final nextBias = ((playbackSpeed - 1.0) * 0.06).clamp(-0.035, 0.035).toDouble();
    await _saveUpdatedProfile(
      language: language,
      category: category,
      transform: (current) => current.copyWith(
        rateBias: _blend(current.rateBias, nextBias, current.correctionCount),
        correctionCount: current.correctionCount + 1,
      ),
    );
  }

  Future<void> _saveUpdatedProfile({
    required String language,
    required String category,
    required AdaptiveSpeechProfile Function(AdaptiveSpeechProfile current)
    transform,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _readMap(prefs);
      final key = _key(language, category);
      final currentRaw = map[key];
      final current = currentRaw is Map<String, dynamic>
          ? AdaptiveSpeechProfile.fromJson(currentRaw)
          : currentRaw is Map
          ? AdaptiveSpeechProfile.fromJson(currentRaw.cast<String, dynamic>())
          : const AdaptiveSpeechProfile();

      map[key] = transform(current).toJson();
      await prefs.setString(_prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[AdaptiveSpeechProfileStore] save failed: $e');
    }
  }

  Map<String, dynamic> _readMap(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  String _key(String language, String category) {
    final normalizedLanguage = language.trim().toLowerCase();
    final normalizedCategory = SpeechDeliveryIntelligence.normalizeCategory(
      category,
    );
    return '$normalizedLanguage::$normalizedCategory';
  }

  double _blend(double current, double next, int correctionCount) {
    final weight = correctionCount <= 0 ? 0.0 : correctionCount.toDouble();
    return ((current * weight) + next) / (weight + 1.0);
  }
}
