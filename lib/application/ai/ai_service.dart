import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SummaryType {
  tldr,       // Very short (1-2 sentences)
  keyPoints,  // Bullet points
  detailed,   // Full paragraph summary
}

/// Service responsible for AI operations (Summarization, Tagging, Explaining)
abstract class AIService {
  Future<String> summarize(String content, {SummaryType type = SummaryType.detailed});
  Future<String> explainComplexTerm(String term, String context);
  Future<List<String>> generateTags(String content);
  
  // Deprecated, mapped to summarize
  Future<String> summarizeArticle(String content); 
}

class AIServiceImpl implements AIService {
  @override
  Future<String> summarizeArticle(String content) async {
    return summarize(content);
  }

  @override
  Future<String> summarize(String content, {SummaryType type = SummaryType.detailed}) async {
    if (content.isEmpty) return '';
    
    // 1. Preprocessing: Clean and split
    final sentences = content
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.length > 20) // Filter junk
        .toList();

    if (sentences.isEmpty) return '';
    if (sentences.length <= 3) return content;

    switch (type) {
      case SummaryType.tldr:
        return _generateTLDR(sentences);
      case SummaryType.keyPoints:
        return _generateKeyPoints(sentences);
      case SummaryType.detailed:
        return _generateDetailedSummary(sentences);
    }
  }

  String _generateTLDR(List<String> sentences) {
    // Heuristic: First sentence + most significant sentence
    // Usually the lead contains the core info.
    return "TL;DR: ${sentences.first}";
  }

  String _generateKeyPoints(List<String> sentences) {
    // Heuristic: Pick sentences based on keywords, length, and position
    // We want 3-5 bullets.
    
    final scored = _scoreSentences(sentences);
    final topSentences = scored.take(4).map((e) => e.key).toList();
    
    // Sort back by original order to maintain flow
    topSentences.sort((a, b) => sentences.indexOf(a).compareTo(sentences.indexOf(b)));
    
    final buffer = StringBuffer();
    for (final s in topSentences) {
      buffer.writeln("• $s");
    }
    return buffer.toString().trim();
  }

  String _generateDetailedSummary(List<String> sentences) {
    // Extractive summary of ~20% of text
    final int targetCount = (sentences.length * 0.3).ceil().clamp(3, 8);
    
    final scored = _scoreSentences(sentences);
    final topSentences = scored.take(targetCount).map((e) => e.key).toList();
    
    topSentences.sort((a, b) => sentences.indexOf(a).compareTo(sentences.indexOf(b)));
    
    return topSentences.join(' ');
  }

  List<MapEntry<String, double>> _scoreSentences(List<String> sentences) {
     // Simple scoring:
     // - Position: Earlier is better (Lead bias)
     // - Length: Medium is better (avoid short fragments or massive run-ons)
     // - Keywords: (simplified here to just unique word count)
     
     final scores = <String, double>{};
     
     for (int i = 0; i < sentences.length; i++) {
        final s = sentences[i];
        double score = 0;
        
        // Position bias
        if (i == 0) {
          score += 2.0;
        } else if (i < 5) {
          score += 1.0;
        }
        
        // Length bias (sweet spot 50-150 chars)
        if (s.length > 50 && s.length < 150) score += 0.5;
        
        scores[s] = score;
     }
     
     final sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
        
     return sorted;
  }

  @override
  Future<String> explainComplexTerm(String term, String context) async {
    // Simulating explanation for Phase 1 (MiniAI)
    // Real implementation would query a dict or LLM.
    // Here we provide a specialized fallback or mock.
    
    return "Definition for '$term':\nA key concept found in the text. This term typically refers to specific entities, actions, or phenomena described in the surrounding context.";
  }

  @override
  Future<List<String>> generateTags(String content) async {
    if (content.isEmpty) return [];
    
    final stopWords = {'the', 'and', 'is', 'in', 'to', 'of', 'a', 'for', 'on', 'with', 'as', 'this', 'that', 'are', 'it', 'by', 'an', 'be', 'at', 'from', 'but', 'not', 'or'};
    
    final words = content.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4 && !stopWords.contains(w));
        
    final Map<String, int> frequency = {};
    for (final word in words) {
        frequency[word] = (frequency[word] ?? 0) + 1;
    }
    
    final sorted = frequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
        
    return sorted.take(5).map((e) => e.key).toList();
  }
}

final aiServiceProvider = Provider<AIService>((ref) => AIServiceImpl());
