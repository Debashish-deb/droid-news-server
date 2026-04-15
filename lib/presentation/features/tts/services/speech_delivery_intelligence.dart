import 'dart:convert';

import '../domain/models/speech_chunk.dart';

enum SpeechPauseBoundary {
  none,
  clauseMinor,
  clauseMajor,
  sentenceEnd,
  paragraphEnd,
}

class SpeechPauseAnalysis {
  const SpeechPauseAnalysis({
    required this.isArticleLead,
    required this.isParagraphStart,
    required this.isParagraphEnd,
    required this.minorPauseCount,
    required this.majorPauseCount,
    required this.boundary,
  });

  final bool isArticleLead;
  final bool isParagraphStart;
  final bool isParagraphEnd;
  final int minorPauseCount;
  final int majorPauseCount;
  final SpeechPauseBoundary boundary;
}

class SpeechDeliveryProfile {
  const SpeechDeliveryProfile({
    required this.normalizedCategory,
    required this.rateBias,
    required this.pitchBias,
    required this.leadRateBias,
    required this.leadPitchBias,
    required this.paragraphStartRateBias,
    required this.paragraphEndRateBias,
    required this.pauseDensityRateBias,
  });

  final String normalizedCategory;
  final double rateBias;
  final double pitchBias;
  final double leadRateBias;
  final double leadPitchBias;
  final double paragraphStartRateBias;
  final double paragraphEndRateBias;
  final double pauseDensityRateBias;
}

// ignore: avoid_classes_with_only_static_members
class SpeechDeliveryIntelligence {
  static const String articleStartMarker = '[ARTICLE_START]';
  static const String paragraphStartMarker = '[PARAGRAPH_START]';
  static const String paragraphEndMarker = '[PARAGRAPH_END]';

  static final RegExp _minorPausePattern = RegExp(r',');
  static final RegExp _majorPausePattern = RegExp(r'[;:]|(?:\s[-–—]\s)');
  static final RegExp _markerPattern = RegExp(
    r'\[(?:ARTICLE_START|PARAGRAPH_START|PARAGRAPH_END)\]',
    caseSensitive: false,
  );

  static SpeechPauseAnalysis analyzeRawChunkText(String rawText) {
    final trimmed = rawText.trim();
    final isArticleLead = trimmed.contains(articleStartMarker);
    final isParagraphStart = trimmed.contains(paragraphStartMarker);
    final isParagraphEnd = trimmed.contains(paragraphEndMarker);
    final withoutMarkers = stripMarkers(trimmed);

    final minorPauseCount = _minorPausePattern
        .allMatches(withoutMarkers)
        .length;
    final majorPauseCount = _majorPausePattern
        .allMatches(withoutMarkers)
        .length;

    final boundary = switch (true) {
      _ when isParagraphEnd => SpeechPauseBoundary.paragraphEnd,
      _ when RegExp(r'[.!?।]["”’)\]]?$').hasMatch(withoutMarkers) =>
        SpeechPauseBoundary.sentenceEnd,
      _ when majorPauseCount > 0 => SpeechPauseBoundary.clauseMajor,
      _ when minorPauseCount > 0 => SpeechPauseBoundary.clauseMinor,
      _ => SpeechPauseBoundary.none,
    };

    return SpeechPauseAnalysis(
      isArticleLead: isArticleLead,
      isParagraphStart: isParagraphStart,
      isParagraphEnd: isParagraphEnd,
      minorPauseCount: minorPauseCount,
      majorPauseCount: majorPauseCount,
      boundary: boundary,
    );
  }

  static SpeechPauseAnalysis analyzeChunk(SpeechChunk chunk) {
    if (chunk.isArticleLead ||
        chunk.isParagraphStart ||
        chunk.isParagraphEnd ||
        chunk.minorPauseCount > 0 ||
        chunk.majorPauseCount > 0 ||
        chunk.pauseBoundary != SpeechPauseBoundary.none.name) {
      return SpeechPauseAnalysis(
        isArticleLead: chunk.isArticleLead,
        isParagraphStart: chunk.isParagraphStart,
        isParagraphEnd: chunk.isParagraphEnd,
        minorPauseCount: chunk.minorPauseCount,
        majorPauseCount: chunk.majorPauseCount,
        boundary: SpeechPauseBoundary.values.firstWhere(
          (value) => value.name == chunk.pauseBoundary,
          orElse: () => SpeechPauseBoundary.none,
        ),
      );
    }
    return analyzeRawChunkText(chunk.text);
  }

  static SpeechDeliveryProfile profileForCategory(String category) {
    final normalized = normalizeCategory(category);

    return switch (normalized) {
      'breaking' => const SpeechDeliveryProfile(
        normalizedCategory: 'breaking',
        rateBias: 0.010,
        pitchBias: 0.012,
        leadRateBias: 0.008,
        leadPitchBias: 0.010,
        paragraphStartRateBias: -0.004,
        paragraphEndRateBias: -0.006,
        pauseDensityRateBias: -0.0015,
      ),
      'sports' => const SpeechDeliveryProfile(
        normalizedCategory: 'sports',
        rateBias: 0.008,
        pitchBias: 0.010,
        leadRateBias: 0.006,
        leadPitchBias: 0.008,
        paragraphStartRateBias: -0.003,
        paragraphEndRateBias: -0.004,
        pauseDensityRateBias: -0.0013,
      ),
      'business' || 'politics' || 'technology' => const SpeechDeliveryProfile(
        normalizedCategory: 'analysis',
        rateBias: 0.000,
        pitchBias: 0.000,
        leadRateBias: -0.004,
        leadPitchBias: -0.002,
        paragraphStartRateBias: -0.005,
        paragraphEndRateBias: -0.006,
        pauseDensityRateBias: -0.0018,
      ),
      'culture' ||
      'lifestyle' ||
      'entertainment' => const SpeechDeliveryProfile(
        normalizedCategory: 'warm',
        rateBias: -0.006,
        pitchBias: 0.006,
        leadRateBias: -0.008,
        leadPitchBias: 0.006,
        paragraphStartRateBias: -0.006,
        paragraphEndRateBias: -0.007,
        pauseDensityRateBias: -0.0016,
      ),
      'solemn' => const SpeechDeliveryProfile(
        normalizedCategory: 'solemn',
        rateBias: -0.012,
        pitchBias: -0.010,
        leadRateBias: -0.010,
        leadPitchBias: -0.008,
        paragraphStartRateBias: -0.008,
        paragraphEndRateBias: -0.010,
        pauseDensityRateBias: -0.0022,
      ),
      _ => const SpeechDeliveryProfile(
        normalizedCategory: 'general',
        rateBias: 0.000,
        pitchBias: 0.000,
        leadRateBias: -0.004,
        leadPitchBias: 0.000,
        paragraphStartRateBias: -0.004,
        paragraphEndRateBias: -0.005,
        pauseDensityRateBias: -0.0015,
      ),
    };
  }

  static String normalizeCategory(String rawCategory) {
    final normalized = rawCategory.trim().toLowerCase();
    if (normalized.isEmpty) return 'general';

    if (_matchesAny(normalized, const <String>[
      'breaking',
      'live',
      'urgent',
      'latest',
    ])) {
      return 'breaking';
    }
    if (_matchesAny(normalized, const <String>[
      'sports',
      'football',
      'cricket',
    ])) {
      return 'sports';
    }
    if (_matchesAny(normalized, const <String>[
      'business',
      'finance',
      'economy',
      'economics',
    ])) {
      return 'business';
    }
    if (_matchesAny(normalized, const <String>[
      'politics',
      'policy',
      'government',
      'election',
    ])) {
      return 'politics';
    }
    if (_matchesAny(normalized, const <String>[
      'technology',
      'tech',
      'science',
    ])) {
      return 'technology';
    }
    if (_matchesAny(normalized, const <String>[
      'culture',
      'arts',
      'lifestyle',
      'travel',
      'fashion',
      'entertainment',
    ])) {
      return normalized.contains('entertainment') ? 'entertainment' : 'culture';
    }
    if (_matchesAny(normalized, const <String>[
      'obituary',
      'death',
      'accident',
      'disaster',
      'mourning',
      'tragedy',
    ])) {
      return 'solemn';
    }

    return normalized;
  }

  static String stripMarkers(String text) {
    return text
        .replaceAll(_markerPattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String buildSynthesisProfileKey({
    required String language,
    required String category,
    required String presetName,
    required double baseRate,
    required double basePitch,
    double adaptiveRateBias = 0,
    double adaptivePitchBias = 0,
  }) {
    final normalizedLanguage = language.trim().toLowerCase();
    final normalizedCategory = normalizeCategory(category);
    final payload = jsonEncode(<String, Object>{
      'language': normalizedLanguage,
      'category': normalizedCategory,
      'preset': presetName,
      'textNormalizer': 'bn_pronunciation_punctuation_v2',
      'prosodyModel': 'session_stable_v1',
      'rate': baseRate.toStringAsFixed(3),
      'pitch': basePitch.toStringAsFixed(3),
      'adaptiveRate': adaptiveRateBias.toStringAsFixed(3),
      'adaptivePitch': adaptivePitchBias.toStringAsFixed(3),
    });
    return base64Url.encode(utf8.encode(payload));
  }

  static bool _matchesAny(String value, Iterable<String> needles) {
    return needles.any(value.contains);
  }
}
