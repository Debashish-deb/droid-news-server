// lib/application/ai/ranking/user_interest_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/news_article.dart' show NewsArticle;
import '../../../infrastructure/ai/engine/quantized_tfidf_engine.dart' show QuantizedTfIdfEngine;
import '../../../core/telemetry/app_logger.dart';

/// Data class to pass interest state across Isolate boundaries
class UserInterestSnapshot {
  final Uint16List? interestVector;
  final List<String> vocabulary;

  UserInterestSnapshot({this.interestVector, required this.vocabulary});
}


class UserInterestService {
  UserInterestService(this._engine, this._prefs) {
    _loadState();
  }

  final QuantizedTfIdfEngine _engine;
  final SharedPreferences _prefs;
  
  static const String _kInterestVectorKey = 'ai_user_interest_vector';
  static const String _kVocabularyKey = 'ai_system_vocabulary';
  
  Uint16List? _currentInterestVector;
  List<String> _vocabulary = [];

  /// NEW: Provides a thread-safe snapshot for the Ranking Isolate
  UserInterestSnapshot getSnapshot() {
    return UserInterestSnapshot(
      interestVector: _currentInterestVector != null 
          ? Uint16List.fromList(_currentInterestVector!) 
          : null,
      vocabulary: List<String>.from(_vocabulary),
    );
  }

  void _loadState() {
    final vocabJson = _prefs.getString(_kVocabularyKey);
    if (vocabJson != null) {
      _vocabulary = List<String>.from(json.decode(vocabJson));
    }

    final vectorBase64 = _prefs.getString(_kInterestVectorKey);
    if (vectorBase64 != null) {
      try {
        _currentInterestVector = Uint16List.fromList(
          base64.decode(vectorBase64).buffer.asUint16List()
        );
      } catch (e) {
        AppLogger.error('Failed to decode interest vector', e);
      }
    }
  }

  Future<void> _saveState() async {
    await _prefs.setString(_kVocabularyKey, json.encode(_vocabulary));
    if (_currentInterestVector != null) {
      final bytes = Uint8List.view(_currentInterestVector!.buffer);
      await _prefs.setString(_kInterestVectorKey, base64.encode(bytes));
    }
  }

  Future<void> recordInteraction({
    required NewsArticle article,
    required InteractionType type,
  }) async {
    if (_vocabulary.isEmpty) {
      _vocabulary = _engine.extractVocabulary([article]);
    }

    final articleVector = _engine.generateVector(article, _vocabulary);

    if (_currentInterestVector == null) {
      _currentInterestVector = articleVector;
    } else {
      final double weight = _getWeightForType(type);
      for (int i = 0; i < _vocabulary.length; i++) {
        final oldVal = _currentInterestVector![i];
        final newVal = articleVector[i];
        _currentInterestVector![i] = (oldVal * (1 - weight) + newVal * weight).toInt();
      }
    }

    await _saveState();
  }

  double _getWeightForType(InteractionType type) {
    switch (type) {
      case InteractionType.view: return 0.05;
      case InteractionType.click: return 0.2;
      case InteractionType.share: return 0.4;
      case InteractionType.bookmark: return 0.35;
      case InteractionType.dismiss: return -0.3;
    }
  }

  double getPersonalizationScore(NewsArticle article) {
    if (_currentInterestVector == null || _vocabulary.isEmpty) return 0.5;
    final articleVector = _engine.generateVector(article, _vocabulary);
    return _engine.calculateSimilarity(_currentInterestVector!, articleVector);
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