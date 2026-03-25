import '../../domain/entities/news_article.dart';

class ArticleLanguageGateResult {
  const ArticleLanguageGateResult({
    required this.accepted,
    required this.detectedLanguage,
    required this.reasonCode,
  });

  final bool accepted;
  final String detectedLanguage;
  final String reasonCode;
}

class ArticleLanguageGate {
  ArticleLanguageGate._();

  static const String reasonAccepted = 'accepted';
  static const String reasonNonBanglaContent = 'non_bangla_content';

  static final RegExp _banglaScriptRegExp = RegExp(r'[\u0980-\u09FF]');
  static final RegExp _latinScriptRegExp = RegExp(r'[A-Za-z]');

  static ArticleLanguageGateResult evaluate({
    required NewsArticle article,
    required String requestedLanguage,
  }) {
    final normalizedRequested = _normalizeLanguage(requestedLanguage);
    final normalizedMetadata = _normalizeLanguage(article.language);
    final text = _combinedText(article);
    final banglaCharCount = _banglaScriptRegExp.allMatches(text).length;
    final latinCharCount = _latinScriptRegExp.allMatches(text).length;
    final totalLetters = banglaCharCount + latinCharCount;
    final banglaRatio = totalLetters == 0
        ? 0.0
        : banglaCharCount / totalLetters;

    final detectedLanguage = _detectLanguage(
      banglaCharCount: banglaCharCount,
      latinCharCount: latinCharCount,
      banglaRatio: banglaRatio,
      metadataLanguage: normalizedMetadata,
    );

    if (normalizedRequested != 'bn') {
      return ArticleLanguageGateResult(
        accepted: true,
        detectedLanguage: detectedLanguage,
        reasonCode: reasonAccepted,
      );
    }

    final metadataBangla = normalizedMetadata == 'bn';
    final hasBanglaScript = banglaCharCount >= 6;
    final strongBanglaScript =
        banglaCharCount >= 20 || (banglaCharCount >= 10 && banglaRatio >= 0.25);
    final accepted = strongBanglaScript || (metadataBangla && hasBanglaScript);

    return ArticleLanguageGateResult(
      accepted: accepted,
      detectedLanguage: accepted ? 'bn' : detectedLanguage,
      reasonCode: accepted ? reasonAccepted : reasonNonBanglaContent,
    );
  }

  static String _combinedText(NewsArticle article) {
    return '${article.title} ${article.description} ${article.snippet} ${article.fullContent}'
        .trim();
  }

  static String _detectLanguage({
    required int banglaCharCount,
    required int latinCharCount,
    required double banglaRatio,
    required String metadataLanguage,
  }) {
    if (banglaCharCount >= 6 && (banglaRatio >= 0.18 || latinCharCount <= 8)) {
      return 'bn';
    }
    if (latinCharCount >= 6 && banglaRatio <= 0.06) {
      return 'en';
    }
    if (metadataLanguage == 'bn' || metadataLanguage == 'en') {
      return metadataLanguage;
    }
    return 'unknown';
  }

  static String _normalizeLanguage(String language) {
    final normalized = language.trim().toLowerCase();
    if (normalized.startsWith('bn')) return 'bn';
    if (normalized.startsWith('en')) return 'en';
    return normalized;
  }
}
