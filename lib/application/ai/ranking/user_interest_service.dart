import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/news_article.dart' show NewsArticle;
import '../../../infrastructure/ai/engine/quantized_tfidf_engine.dart' show QuantizedTfIdfEngine;
import '../../../core/telemetry/app_logger.dart';

import 'package:injectable/injectable.dart';

/// Tracks user behavior at a granular term-level to build a Quantized "User Interest Vector".
@lazySingleton
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

  void _loadState() {
    final vocabJson = _prefs.getString(_kVocabularyKey);
    if (vocabJson != null) {
      _vocabulary = List<String>.from(json.decode(vocabJson));
    }

    final vectorBase64 = _prefs.getString(_kInterestVectorKey);
    if (vectorBase64 != null) {
      _currentInterestVector = Uint16List.fromList(base64.decode(vectorBase64).buffer.asUint16List());
    }
  }

  Future<void> _saveState() async {
    await _prefs.setString(_kVocabularyKey, json.encode(_vocabulary));
    if (_currentInterestVector != null) {
      final bytes = Uint8List.view(_currentInterestVector!.buffer);
      await _prefs.setString(_kInterestVectorKey, base64.encode(bytes));
    }
  }

  /// Updates the interest vector based on interactions.
  Future<void> recordInteraction({
    required NewsArticle article,
    required InteractionType type,
  }) async {
    // 1. Ensure vocabulary is initialized/updated if needed
    if (_vocabulary.isEmpty) {
      _vocabulary = _engine.extractVocabulary([article]);
    }

    // 2. Generate vector for the current article
    final articleVector = _engine.generateVector(article, _vocabulary);

    // 3. Update interest vector (moving average / weight update)
    if (_currentInterestVector == null) {
      _currentInterestVector = articleVector;
    } else {
      final double weight = _getWeightForType(type);
      for (int i = 0; i < _vocabulary.length; i++) {
        // Simple smoothing update: V_new = V_old * (1-w) + V_art * w
        final oldVal = _currentInterestVector![i];
        final newVal = articleVector[i];
        _currentInterestVector![i] = (oldVal * (1 - weight) + newVal * weight).toInt();
      }
    }

    await _saveState();
    AppLogger.debug('UserInterest: Updated interest vector for ${article.title}');
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

  /// Returns the similarity of an article to the user's current interest vector.
  double getPersonalizationScore(NewsArticle article) {
    if (_currentInterestVector == null || _vocabulary.isEmpty) return 0.5;

    final articleVector = _engine.generateVector(article, _vocabulary);
    return _engine.calculateSimilarity(_currentInterestVector!, articleVector);
  }

  /// Returns a weighted score for a category based on user history.
  double getInterestScore(String category) {
    if (_currentInterestVector == null || _vocabulary.isEmpty) return 1.0;
    
    // Look for the category keyword in the vocabulary
    final index = _vocabulary.indexOf(category.toLowerCase());
    if (index != -1) {
      // Normalize the quantized weight (0-65535) to a 0.5 - 2.0 range boost
      final weight = _currentInterestVector![index];
      return 1.0 + (weight / 65535.0);
    }
    
    return 1.0;
  }
}

enum InteractionType {
  view, click, share, bookmark, dismiss
}
