import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/news_article.dart' show NewsArticle;
import '../../../infrastructure/ai/engine/quantized_tfidf_engine.dart'
    show QuantizedTfIdfEngine;
import '../../../core/telemetry/app_logger.dart';
import 'learning_event.dart';

/// Data class to pass interest state across Isolate boundaries
class UserInterestSnapshot {
  UserInterestSnapshot({required this.vocabulary, this.interestVector});
  final Uint16List? interestVector;
  final List<String> vocabulary;
}

class UserInterestService {
  UserInterestService(this._engine, this._prefs) {
    if (_prefs != null) {
      _loadState();
    }
  }

  factory UserInterestService.disabled(QuantizedTfIdfEngine engine) =>
      UserInterestService(engine, null);

  final QuantizedTfIdfEngine _engine;
  final SharedPreferences? _prefs;

  static const String _kInterestVectorKey = 'ai_user_interest_vector';
  static const String _kVocabularyKey = 'ai_system_vocabulary';
  static const String _kLastUpdatedAtKey = 'ai_interest_last_updated_at';
  static const String _kSourcePenaltyKey = 'ai_interest_source_penalty_v1';
  static const String _kCategoryPenaltyKey = 'ai_interest_category_penalty_v1';

  Uint16List? _currentInterestVector;
  List<String> _vocabulary = [];
  DateTime? _lastUpdatedAt;
  final Map<String, double> _sourcePenalty = <String, double>{};
  final Map<String, double> _categoryPenalty = <String, double>{};

  /// thread-safe snapshot for the Ranking Isolate
  UserInterestSnapshot getSnapshot() {
    return UserInterestSnapshot(
      interestVector: _currentInterestVector != null
          ? Uint16List.fromList(_currentInterestVector!)
          : null,
      vocabulary: List<String>.from(_vocabulary),
    );
  }

  static const int _kStateVersion = 3;
  static const String _kVersionKey = 'ai_state_version';

  void _loadState() {
    try {
      final savedVersion = _prefs?.getInt(_kVersionKey) ?? 0;
      if (savedVersion < _kStateVersion) {
        AppLogger.info(
          'Invalidating old interest state (v$savedVersion -> v$_kStateVersion)',
        );
        _vocabulary = [];
        _currentInterestVector = null;
        return;
      }

      final vocabJson = _prefs?.getString(_kVocabularyKey);
      if (vocabJson != null) {
        _vocabulary = List<String>.from(json.decode(vocabJson));
      }

      final vectorBase64 = _prefs?.getString(_kInterestVectorKey);
      if (vectorBase64 != null) {
        final bytes = base64.decode(vectorBase64);
        if (bytes.length % 2 == 0) {
          _currentInterestVector = Uint16List.fromList(
            bytes.buffer.asUint16List(),
          );
        } else {
          AppLogger.error(
            'Interest vector corrupted: odd byte length (${bytes.length})',
          );
          _currentInterestVector = null;
        }
      }

      final rawLastUpdated = _prefs?.getString(_kLastUpdatedAtKey);
      if (rawLastUpdated != null && rawLastUpdated.isNotEmpty) {
        _lastUpdatedAt = DateTime.tryParse(rawLastUpdated);
      }

      _loadPenaltyMap(
        raw: _prefs?.getString(_kSourcePenaltyKey),
        output: _sourcePenalty,
      );
      _loadPenaltyMap(
        raw: _prefs?.getString(_kCategoryPenaltyKey),
        output: _categoryPenalty,
      );
    } catch (e) {
      AppLogger.error('Failed to load interest state', e);
      _currentInterestVector = null;
      _vocabulary = [];
      _sourcePenalty.clear();
      _categoryPenalty.clear();
      _lastUpdatedAt = null;
    }
  }

  void _loadPenaltyMap({
    required String? raw,
    required Map<String, double> output,
  }) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        if (key.isEmpty) continue;
        final value = (entry.value as num?)?.toDouble() ?? 0.0;
        if (value <= 0.0) continue;
        output[key] = value.clamp(0.0, 0.9).toDouble();
      }
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _saveState() async {
    if (_prefs == null) return;
    await _prefs.setInt(_kVersionKey, _kStateVersion);
    await _prefs.setString(_kVocabularyKey, json.encode(_vocabulary));
    if (_currentInterestVector != null) {
      final bytes = Uint8List.view(_currentInterestVector!.buffer);
      await _prefs.setString(_kInterestVectorKey, base64.encode(bytes));
    }
    if (_lastUpdatedAt != null) {
      await _prefs.setString(
        _kLastUpdatedAtKey,
        _lastUpdatedAt!.toIso8601String(),
      );
    }
    await _prefs.setString(_kSourcePenaltyKey, jsonEncode(_sourcePenalty));
    await _prefs.setString(_kCategoryPenaltyKey, jsonEncode(_categoryPenalty));
  }

  Future<void> recordInteraction({
    required NewsArticle article,
    required InteractionType type,
  }) async {
    await recordInteractionV2(
      article: article,
      type: switch (type) {
        InteractionType.view => InteractionTypeV2.open,
        InteractionType.click => InteractionTypeV2.open,
        InteractionType.share => InteractionTypeV2.share,
        InteractionType.bookmark => InteractionTypeV2.bookmark,
        InteractionType.dismiss => InteractionTypeV2.dismiss,
      },
    );
  }

  Future<void> recordInteractionV2({
    required NewsArticle article,
    required InteractionTypeV2 type,
  }) async {
    final now = DateTime.now();
    _applyTimeDecay(now);

    if (_vocabulary.isEmpty) {
      _vocabulary = _engine.extractVocabulary([article]);
    }

    final articleVector = _engine.generateVector(article, _vocabulary);

    if (_currentInterestVector == null) {
      _currentInterestVector = articleVector;
    } else {
      final double weight = _getWeightForType(type);
      for (int i = 0; i < _vocabulary.length; i++) {
        final oldVal = _currentInterestVector![i].toDouble();
        final newVal = articleVector[i].toDouble();
        final nextVal = (oldVal + ((newVal - oldVal) * weight))
            .clamp(0.0, 65535.0)
            .toDouble();
        _currentInterestVector![i] = nextVal.round();
      }
    }

    _lastUpdatedAt = now;
    await _saveState();
  }

  Future<void> recordFeedback({
    required NewsArticle article,
    required FeedbackReason reason,
  }) async {
    final source = article.source.trim().toLowerCase();
    final category = article.category.trim().toLowerCase();

    final sourcePenaltyDelta = reason == FeedbackReason.wrongLabel
        ? 0.20
        : 0.12;
    final categoryPenaltyDelta = reason == FeedbackReason.wrongLabel
        ? 0.16
        : 0.1;

    if (source.isNotEmpty) {
      _sourcePenalty[source] =
          ((_sourcePenalty[source] ?? 0.0) + sourcePenaltyDelta)
              .clamp(0.0, 0.8)
              .toDouble();
    }
    if (category.isNotEmpty) {
      _categoryPenalty[category] =
          ((_categoryPenalty[category] ?? 0.0) + categoryPenaltyDelta)
              .clamp(0.0, 0.7)
              .toDouble();
    }
    _lastUpdatedAt = DateTime.now();
    await _saveState();
  }

  double _getWeightForType(InteractionTypeV2 type) {
    switch (type) {
      case InteractionTypeV2.open:
        return 0.08;
      case InteractionTypeV2.readDuration:
        return 0.12;
      case InteractionTypeV2.bookmark:
        return 0.35;
      case InteractionTypeV2.share:
        return 0.4;
      case InteractionTypeV2.dismiss:
      case InteractionTypeV2.wrongLabel:
        return -0.22;
      case InteractionTypeV2.searchSubmit:
      case InteractionTypeV2.suggestionClick:
        return 0.0;
    }
  }

  void _applyTimeDecay(DateTime now) {
    if (_lastUpdatedAt == null) return;
    final hours = now.difference(_lastUpdatedAt!).inMinutes / 60.0;
    if (hours <= 1.0) return;
    final decay = math.pow(0.997, hours).toDouble().clamp(0.80, 0.9995);
    if (_currentInterestVector != null) {
      for (var i = 0; i < _currentInterestVector!.length; i++) {
        _currentInterestVector![i] = (_currentInterestVector![i] * decay)
            .round()
            .clamp(0, 65535)
            .toInt();
      }
    }
    _decayPenaltyMap(_sourcePenalty, decay);
    _decayPenaltyMap(_categoryPenalty, decay);
  }

  void _decayPenaltyMap(Map<String, double> map, double decay) {
    final keys = map.keys.toList(growable: false);
    for (final key in keys) {
      final next = ((map[key] ?? 0.0) * decay).clamp(0.0, 0.9).toDouble();
      if (next < 0.01) {
        map.remove(key);
      } else {
        map[key] = next;
      }
    }
  }

  double getPersonalizationScore(NewsArticle article) {
    if (_currentInterestVector == null || _vocabulary.isEmpty) return 0.5;
    final articleVector = _engine.generateVector(article, _vocabulary);
    final base = _engine.calculateSimilarity(
      _currentInterestVector!,
      articleVector,
    );
    final source = article.source.trim().toLowerCase();
    final category = article.category.trim().toLowerCase();
    final sourcePenalty = _sourcePenalty[source] ?? 0.0;
    final categoryPenalty = _categoryPenalty[category] ?? 0.0;
    final multiplier =
        (1.0 - sourcePenalty).clamp(0.35, 1.0).toDouble() *
        (1.0 - categoryPenalty).clamp(0.45, 1.0).toDouble();
    return (base * multiplier).clamp(0.0, 1.0).toDouble();
  }

  double getInterestScore(String category) {
    if (_currentInterestVector == null || _vocabulary.isEmpty) return 1.0;
    final index = _vocabulary.indexOf(category.toLowerCase());
    if (index != -1) {
      return 1.0 + (_currentInterestVector![index] / 65535.0);
    }
    return 1.0;
  }
}

enum InteractionType { view, click, share, bookmark, dismiss }
