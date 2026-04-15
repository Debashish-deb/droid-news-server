import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/news_article.dart';
import '../../../infrastructure/ai/collection/ai_event_collector.dart';
import 'learning_event.dart';
import 'user_interest_service.dart';

class LocalLearningEngine {
  LocalLearningEngine(
    this._interestService, {
    required SharedPreferences? prefs,
    AIEventCollector? eventCollector,
  }) : _prefs = prefs,
       _eventCollector = eventCollector {
    _loadState();
  }

  final UserInterestService _interestService;
  final SharedPreferences? _prefs;
  final AIEventCollector? _eventCollector;

  static const String _kQueryScoresKey = 'ai_query_scores_v1';
  static const Duration _flushDebounce = Duration(milliseconds: 900);
  static const int _maxPendingEvents = 120;
  static const int _maxQueryTerms = 120;

  final List<LearningEvent> _pending = <LearningEvent>[];
  Timer? _flushTimer;
  bool _flushInFlight = false;
  final Map<String, double> _queryScores = <String, double>{};

  void trackEvent(LearningEvent event) {
    _pending.add(event);
    if (_pending.length > _maxPendingEvents) {
      _pending.removeRange(0, _pending.length - _maxPendingEvents);
    }
    _scheduleFlush();
  }

  void trackOpen(NewsArticle article) {
    trackEvent(
      LearningEvent(
        type: InteractionTypeV2.open,
        timestamp: DateTime.now(),
        article: article,
      ),
    );
  }

  void trackReadDuration(NewsArticle article, int durationSeconds) {
    trackEvent(
      LearningEvent(
        type: InteractionTypeV2.readDuration,
        timestamp: DateTime.now(),
        article: article,
        durationSeconds: durationSeconds,
      ),
    );
  }

  void trackSearchSubmit(String query) {
    trackEvent(
      LearningEvent(
        type: InteractionTypeV2.searchSubmit,
        timestamp: DateTime.now(),
        query: query,
      ),
    );
  }

  void trackSuggestionClick(String topic) {
    trackEvent(
      LearningEvent(
        type: InteractionTypeV2.suggestionClick,
        timestamp: DateTime.now(),
        topic: topic,
      ),
    );
  }

  void trackBookmark(NewsArticle article) {
    trackEvent(
      LearningEvent(
        type: InteractionTypeV2.bookmark,
        timestamp: DateTime.now(),
        article: article,
      ),
    );
  }

  void trackShare(NewsArticle article) {
    trackEvent(
      LearningEvent(
        type: InteractionTypeV2.share,
        timestamp: DateTime.now(),
        article: article,
      ),
    );
  }

  void trackDismiss(
    NewsArticle article, {
    FeedbackReason reason = FeedbackReason.dismiss,
  }) {
    trackEvent(
      LearningEvent(
        type: reason == FeedbackReason.wrongLabel
            ? InteractionTypeV2.wrongLabel
            : InteractionTypeV2.dismiss,
        timestamp: DateTime.now(),
        article: article,
        reason: reason,
      ),
    );
  }

  List<String> topQueries({int limit = 8}) {
    final entries = _queryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList(growable: false);
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDebounce, () => unawaited(_flush()));
  }

  Future<void> _flush() async {
    if (_flushInFlight || _pending.isEmpty) return;
    _flushInFlight = true;
    final batch = List<LearningEvent>.from(_pending);
    _pending.clear();
    try {
      for (final event in batch) {
        await _applyEvent(event);
      }
      await _persistState();
    } finally {
      _flushInFlight = false;
    }
  }

  Future<void> _applyEvent(LearningEvent event) async {
    final article = event.article;

    switch (event.type) {
      case InteractionTypeV2.open:
        if (article != null) {
          await _interestService.recordInteractionV2(
            article: article,
            type: InteractionTypeV2.open,
          );
          _eventCollector?.logArticleOpen(article.url, topic: article.category);
        }
        return;
      case InteractionTypeV2.readDuration:
        if (article != null) {
          await _interestService.recordInteractionV2(
            article: article,
            type: InteractionTypeV2.readDuration,
          );
          final duration = event.durationSeconds ?? 0;
          _eventCollector?.logReadDuration(
            article.url,
            duration,
            topic: article.category,
          );
        }
        return;
      case InteractionTypeV2.bookmark:
        if (article != null) {
          await _interestService.recordInteractionV2(
            article: article,
            type: InteractionTypeV2.bookmark,
          );
          _eventCollector?.logInteraction(
            article.url,
            'bookmark',
            topic: article.category,
          );
        }
        return;
      case InteractionTypeV2.share:
        if (article != null) {
          await _interestService.recordInteractionV2(
            article: article,
            type: InteractionTypeV2.share,
          );
          _eventCollector?.logInteraction(
            article.url,
            'share',
            topic: article.category,
          );
        }
        return;
      case InteractionTypeV2.dismiss:
      case InteractionTypeV2.wrongLabel:
        if (article != null) {
          await _interestService.recordInteractionV2(
            article: article,
            type: InteractionTypeV2.dismiss,
          );
          final reason = event.reason ??
              (event.type == InteractionTypeV2.wrongLabel
                  ? FeedbackReason.wrongLabel
                  : FeedbackReason.dismiss);
          await _interestService.recordFeedback(article: article, reason: reason);
          _eventCollector?.logSkip(article.url, topic: article.category);
        }
        return;
      case InteractionTypeV2.searchSubmit:
        _bumpQuery(event.query, weight: 1.0);
        return;
      case InteractionTypeV2.suggestionClick:
        _bumpQuery(event.topic, weight: 0.8);
        return;
    }
  }

  void _bumpQuery(String? raw, {required double weight}) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.length < 2) return;
    _queryScores[normalized] = (_queryScores[normalized] ?? 0.0) + weight;
    if (_queryScores.length > _maxQueryTerms) {
      final entries = _queryScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final keep = entries.take(_maxQueryTerms).map((e) => e.key).toSet();
      _queryScores.removeWhere((k, _) => !keep.contains(k));
    }
  }

  void _loadState() {
    try {
      final raw = _prefs?.getString(_kQueryScoresKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim().toLowerCase();
        if (key.isEmpty) continue;
        final value = (entry.value as num?)?.toDouble() ?? 0.0;
        if (value <= 0) continue;
        _queryScores[key] = value;
      }
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _persistState() async {
    if (_prefs == null) return;
    try {
      await _prefs.setString(_kQueryScoresKey, jsonEncode(_queryScores));
    } catch (_) {
      // Best effort only.
    }
  }

  void dispose() {
    _flushTimer?.cancel();
  }
}
