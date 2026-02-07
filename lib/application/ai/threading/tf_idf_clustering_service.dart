import 'dart:math';
import '../../../domain/entities/news_article.dart';
import '../../../domain/entities/news_thread.dart';
import 'package:flutter/foundation.dart';

// Service that groups articles into threads using TF-IDF and Cosine Similarity.
// 
// This runs entirely client-side to provide "Smart Threading" without
// needing a backend Vector DB immediately.
class TfIdfClusteringService {
  static const double _similarityThreshold = 0.6;
  
  static final Set<String> _stopWords = {
    'the', 'is', 'at', 'of', 'on', 'and', 'a', 'an', 'in', 'to', 'for', 'with', 'by',
    'ও', 'এবং', 'থেকে', 'করে', 'করা', 'এর', 'এ', 'কি'
  };

  Future<List<NewsThread>> clusterArticles(List<NewsArticle> articles) async {
    if (articles.isEmpty) return [];

    return await compute(_clusterLogic, articles);
  }

  static List<NewsThread> _clusterLogic(List<NewsArticle> articles) {
    final List<NewsThread> threads = [];
    final List<NewsArticle> unprocessed = List.from(articles);

    final Map<NewsArticle, Map<String, double>> tfVectors = {};
    for (var article in articles) {
      tfVectors[article] = _computeTfVector(article);
    }

    while (unprocessed.isNotEmpty) {
      final mainArticle = unprocessed.removeAt(0);
      final List<NewsArticle> related = [];
      final mainVector = tfVectors[mainArticle]!;

      unprocessed.removeWhere((candidate) {
        final candidateVector = tfVectors[candidate]!;
        final similarity = _cosineSimilarity(mainVector, candidateVector);
        if (similarity >= _similarityThreshold) {
          related.add(candidate);
          return true; 
        }
        return false;
      });

      threads.add(NewsThread(
        id: 'thread_${mainArticle.url.hashCode}',
        mainArticle: mainArticle,
        relatedArticles: related,
      ));
    }

    return threads;
  }

  static Map<String, double> _computeTfVector(NewsArticle article) {
    final text = '${article.title} ${article.description}'.toLowerCase();
    
    final tokens = text
        .replaceAll(RegExp(r'[^\w\s\u0980-\u09FF]'), '')
        .split(RegExp(r'\s+'));

    final Map<String, double> tf = {};
    int totalTerms = 0;

    for (var token in tokens) {
      if (_stopWords.contains(token) || token.length < 3) continue;
      
      tf[token] = (tf[token] ?? 0) + 1;
      totalTerms++;
    }

    if (totalTerms > 0) {
      tf.updateAll((key, val) => val / totalTerms);
    }

    return tf;
  }

  static double _cosineSimilarity(
      Map<String, double> vecA, Map<String, double> vecB) {
    final Set<String> unionKeys = {...vecA.keys, ...vecB.keys};
    
    double dotProduct = 0.0;
    double magA = 0.0;
    double magB = 0.0;

    for (var key in unionKeys) {
      final valA = vecA[key] ?? 0.0;
      final valB = vecB[key] ?? 0.0;
      
      dotProduct += valA * valB;
      magA += valA * valA;
      magB += valB * valB;
    }

    if (magA == 0 || magB == 0) return 0.0;

    return dotProduct / (sqrt(magA) * sqrt(magB));
  }
}
