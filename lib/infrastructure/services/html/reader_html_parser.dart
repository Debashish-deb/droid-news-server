import 'dart:async';
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter/foundation.dart';
import '../../../core/telemetry/app_logger.dart';
import '../../../core/config/performance_config.dart';
import '../../../presentation/features/reader/models/reader_article.dart';
import '../../../presentation/features/reader/models/reader_settings.dart';
import '../../../core/tts/domain/entities/tts_chunk.dart';

// lib/features/reader/controllers/reader_controller.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  READER CONTROLLER – ANDROID-OPTIMISED v2                ║
// ║                                                          ║
// ║  Optimisation layers applied                             ║
// ║  • compute() isolate for _processHtmlForTts              ║
// ║    (heavy HTML parse → never blocks UI thread)           ║
// ║  • In-flight cancellation via Completer flag             ║
// ║    (rapid reader toggles won't pile up)                  ║
// ║  • LRU article cache (capacity=5) – re-opening same      ║
// ║    URL skips re-parse entirely                           ║
// ║  • Debounced settings persistence (300 ms) –             ║
// ║    slider drags don't hammer disk I/O                    ║
// ║  • Granular state model + copyWith guards –              ║
// ║    unchanged fields don't trigger listener notify        ║
// ║  • Settings load: parallel Future.wait instead of        ║
// ║    sequential awaits                                     ║
// ║  • _ttsSubscription correctly closed on dispose          ║
// ║  • Readability JS cached on first load (singleton)       ║
// ║  • Error states carry actionable codes, not raw strings  ║
// ╚══════════════════════════════════════════════════════════╝


// ─────────────────────────────────────────────
// ISOLATE PAYLOAD TYPES
// All fields must be primitive / JSON-serialisable to cross
// Isolate boundaries without copies via TransferableTypedData.
// ─────────────────────────────────────────────
class ReaderHtmlProcessInput {
  const ReaderHtmlProcessInput({
    required this.content,
    required this.articleTitle,
    required this.noiseTokens,
    required this.noisyPrefixes,
    this.strictMode = true,
  });

  final String content;
  final String articleTitle;
  final List<String> noiseTokens;
  final List<String> noisyPrefixes;
  final bool strictMode;
}

@visibleForTesting
class ReaderHtmlProcessOutput {
  const ReaderHtmlProcessOutput({
    required this.html,
    required this.chunks,
    required this.removedElements,
    required this.linkHeavyRemoved,
    required this.headlineListRemoved,
    required this.contaminationScore,
    required this.contentLength,
  });

  final String html;
  final List<TtsChunk> chunks;
  final int removedElements;
  final int linkHeavyRemoved;
  final int headlineListRemoved;
  final double contaminationScore;
  final int contentLength;
}

class _ReaderRemovalStats {
  const _ReaderRemovalStats({
    required this.removedElements,
    required this.linkHeavyRemoved,
    required this.headlineListRemoved,
  });

  final int removedElements;
  final int linkHeavyRemoved;
  final int headlineListRemoved;
}

const int _kStrictMinContentLength = 420;
const int _kSoftMinContentLength = 220;
const double _kStrictMaxContamination = 0.34;
const double _kSoftMaxContamination = 0.55;

enum ReaderPageType { article, liveFeed, listing, unknown }

enum ReaderTitleSource {
  hint,
  metaOg,
  metaTwitter,
  jsonld,
  h1,
  documentTitle,
  fallback,
}

extension ReaderPageTypeWire on ReaderPageType {
  String get wireValue {
    switch (this) {
      case ReaderPageType.article:
        return 'article';
      case ReaderPageType.liveFeed:
        return 'live_feed';
      case ReaderPageType.listing:
        return 'listing';
      case ReaderPageType.unknown:
        return 'unknown';
    }
  }

  static ReaderPageType fromWire(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'article':
        return ReaderPageType.article;
      case 'live_feed':
      case 'live':
        return ReaderPageType.liveFeed;
      case 'listing':
      case 'collection':
        return ReaderPageType.listing;
      default:
        return ReaderPageType.unknown;
    }
  }
}

extension ReaderTitleSourceWire on ReaderTitleSource {
  String get wireValue {
    switch (this) {
      case ReaderTitleSource.hint:
        return 'hint';
      case ReaderTitleSource.metaOg:
        return 'meta_og';
      case ReaderTitleSource.metaTwitter:
        return 'meta_twitter';
      case ReaderTitleSource.jsonld:
        return 'jsonld';
      case ReaderTitleSource.h1:
        return 'h1';
      case ReaderTitleSource.documentTitle:
        return 'document_title';
      case ReaderTitleSource.fallback:
        return 'fallback';
    }
  }

  static ReaderTitleSource fromWire(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'hint':
        return ReaderTitleSource.hint;
      case 'meta_og':
      case 'og':
        return ReaderTitleSource.metaOg;
      case 'meta_twitter':
      case 'twitter':
        return ReaderTitleSource.metaTwitter;
      case 'jsonld':
      case 'json-ld':
        return ReaderTitleSource.jsonld;
      case 'h1':
        return ReaderTitleSource.h1;
      case 'document_title':
      case 'doc_title':
        return ReaderTitleSource.documentTitle;
      default:
        return ReaderTitleSource.fallback;
    }
  }
}

@immutable
class ReaderExtractionMeta {
  const ReaderExtractionMeta({
    required this.pageType,
    required this.titleSource,
    required this.qualityScore,
    this.failureCode,
  });

  final ReaderPageType pageType;
  final ReaderTitleSource titleSource;
  final double qualityScore;
  final String? failureCode;

  bool get isSupportedArticle => pageType == ReaderPageType.article;

  static ReaderExtractionMeta fromPayload(Map<String, dynamic>? payload) {
    if (payload == null) {
      return const ReaderExtractionMeta(
        pageType: ReaderPageType.unknown,
        titleSource: ReaderTitleSource.fallback,
        qualityScore: 0,
      );
    }
    final qualityRaw = payload['qualityScore'];
    final qualityScore = switch (qualityRaw) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0.0,
      _ => 0.0,
    };
    final failureCodeRaw = payload['failureCode']?.toString().trim();
    return ReaderExtractionMeta(
      pageType: ReaderPageTypeWire.fromWire(payload['pageType']),
      titleSource: ReaderTitleSourceWire.fromWire(payload['titleSource']),
      qualityScore: qualityScore,
      failureCode: (failureCodeRaw == null || failureCodeRaw.isEmpty)
          ? null
          : failureCodeRaw,
    );
  }
}

@visibleForTesting
bool passesReaderQualityGate({
  required int contentLength,
  required double contaminationScore,
  required bool strict,
}) {
  final minLength = strict ? _kStrictMinContentLength : _kSoftMinContentLength;
  final maxContamination = strict
      ? _kStrictMaxContamination
      : _kSoftMaxContamination;
  return contentLength >= minLength && contaminationScore <= maxContamination;
}

@visibleForTesting
String chooseReaderExtractionPass({
  required ReaderHtmlProcessOutput strictOutput,
  required ReaderHtmlProcessOutput softOutput,
}) {
  if (passesReaderQualityGate(
    contentLength: strictOutput.contentLength,
    contaminationScore: strictOutput.contaminationScore,
    strict: true,
  )) {
    return 'strict';
  }
  if (passesReaderQualityGate(
    contentLength: softOutput.contentLength,
    contaminationScore: softOutput.contaminationScore,
    strict: false,
  )) {
    return 'soft';
  }
  return 'fallback';
}

@visibleForTesting
bool passesReaderFallbackQualityGate({
  required int contentLength,
  required int chunkCount,
  required double qualityScore,
  bool likelyReadableBody = false,
  ReaderPageType? classifiedPageType,
  bool allowFeedLikeRecovery = false,
}) {
  final normalizedScore = qualityScore.clamp(0.0, 1.0);
  final strongLongBody =
      contentLength >= _kSoftMinContentLength && normalizedScore >= 0.48;
  final mediumBody =
      contentLength >= 140 && chunkCount >= 3 && normalizedScore >= 0.46;
  final shortCoherentBody =
      contentLength >= 95 && chunkCount >= 2 && normalizedScore >= 0.58;
  final ultraShortBullet =
      contentLength >= 70 && chunkCount >= 1 && normalizedScore >= 0.74;
  final readableBodyRecovery =
      likelyReadableBody &&
      contentLength >= 100 &&
      chunkCount >= 1 &&
      normalizedScore >= 0.30;

  final classifiedAsFeedLike =
      classifiedPageType == ReaderPageType.listing ||
      classifiedPageType == ReaderPageType.liveFeed;
  if (classifiedAsFeedLike) {
    if (allowFeedLikeRecovery) {
      return strongLongBody ||
          mediumBody ||
          shortCoherentBody ||
          (contentLength >= 120 &&
              chunkCount >= 2 &&
              normalizedScore >= 0.42) ||
          (likelyReadableBody &&
              contentLength >= 110 &&
              chunkCount >= 1 &&
              normalizedScore >= 0.28);
    }
    return strongLongBody ||
        (contentLength >= 140 && chunkCount >= 3 && normalizedScore >= 0.64) ||
        (likelyReadableBody &&
            contentLength >= 150 &&
            chunkCount >= 2 &&
            normalizedScore >= 0.52);
  }
  return strongLongBody ||
      mediumBody ||
      shortCoherentBody ||
      ultraShortBullet ||
      readableBodyRecovery;
}

@visibleForTesting
bool looksLikeReaderBodyText(String text) {
  final normalized = _compactWhitespace(text);
  if (normalized.length < 70) {
    return false;
  }

  final lines = text
      .split(RegExp(r'\n+'))
      .map(_compactWhitespace)
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return false;
  }

  final words = normalized
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
  final longLines = lines.where((line) => line.length >= 32).length;
  final metadataLines = lines.where((line) {
    final lower = line.toLowerCase();
    return kNoisyPrefixes.any(lower.startsWith) ||
        kNoiseTokens.any(lower.contains) ||
        kMetadataLinePattern.hasMatch(lower);
  }).length;
  final metadataRatio = metadataLines / lines.length;
  final alphaNumericCount = RegExp(
    r'[A-Za-z0-9\u0980-\u09ff]',
  ).allMatches(normalized).length;
  final alphaNumericRatio = alphaNumericCount / normalized.length;
  final punctuationCount = RegExp(r'[.!?।]').allMatches(normalized).length;
  final structuredBody =
      longLines >= 2 || (lines.length <= 2 && normalized.length >= 110);

  return words >= 18 &&
      structuredBody &&
      metadataRatio <= 0.45 &&
      alphaNumericRatio >= 0.55 &&
      (punctuationCount >= 1 || normalized.length >= 120);
}

@visibleForTesting
bool looksLikeReaderArticleUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  final normalized = (uri?.toString() ?? url).trim().toLowerCase();
  if (normalized.isEmpty) return false;

  final path = (uri?.path ?? '').toLowerCase();
  if (path.isEmpty || path == '/') return false;

  if (RegExp(r'/\d{4}/\d{2}/\d{2}(?:/|$)').hasMatch(path)) {
    return true;
  }
  if (RegExp(r'/\d{5,}(?:[-/]|$)').hasMatch(path)) {
    return true;
  }
  if (RegExp(
    r'/(news|article|story|stories|opinion|features?)/',
  ).hasMatch(path)) {
    return true;
  }

  final segments = path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.length < 2) return false;

  const sectionNames = <String>{
    'news',
    'latest',
    'world',
    'national',
    'international',
    'politics',
    'business',
    'sports',
    'entertainment',
    'lifestyle',
    'opinion',
    'editorial',
    'technology',
    'tech',
    'science',
    'health',
    'economy',
    'bangladesh',
    'live',
    'video',
    'videos',
    'photo',
    'photos',
    'gallery',
    'topic',
    'topics',
    'category',
    'categories',
    'section',
    'sections',
  };

  final lastSegment = segments.last;
  if (sectionNames.contains(lastSegment)) return false;

  final slugLike =
      lastSegment.length >= 12 &&
      (lastSegment.contains('-') ||
          RegExp(r'[a-z0-9]{10,}').hasMatch(lastSegment));
  if (slugLike) return true;

  return false;
}

@visibleForTesting
bool shouldAttemptUnsupportedReaderExtraction({
  required bool allowPublisherFallback,
  required bool likelyArticleUrl,
  ReaderPageType? classifiedPageType,
}) {
  if (!allowPublisherFallback || !likelyArticleUrl) return false;
  return classifiedPageType != ReaderPageType.liveFeed;
}

@visibleForTesting
bool shouldAllowUnsupportedReaderRecovery({
  required bool allowPublisherFallback,
  required bool likelyArticleUrl,
  required bool trustedArticleHost,
  ReaderPageType? classifiedPageType,
}) {
  if (classifiedPageType == ReaderPageType.liveFeed) {
    return !allowPublisherFallback && (likelyArticleUrl || trustedArticleHost);
  }
  return likelyArticleUrl || (!allowPublisherFallback && trustedArticleHost);
}

/// Top-level function required by `compute()` — must not be a closure
/// or instance method so Dart can spawn it in a separate Isolate.
final RegExp _readerWordTokenPattern = RegExp(r'\s+|\S+');
final RegExp _readerReadableWordPattern = RegExp(r'[A-Za-z0-9\u0980-\u09FF]');

void _appendReaderWordSpans(
  dom.Element parent,
  String text, {
  required int sentenceIndex,
}) {
  var wordIndex = 0;
  for (final match in _readerWordTokenPattern.allMatches(text)) {
    final token = match.group(0) ?? '';
    if (token.trim().isEmpty || !_readerReadableWordPattern.hasMatch(token)) {
      parent.nodes.add(dom.Text(token));
      continue;
    }

    final wordNode = dom.Element.tag('span')
      ..classes.add('reader-word')
      ..attributes['data-sentence-index'] = sentenceIndex.toString()
      ..attributes['data-word-index'] = wordIndex.toString()
      ..text = token;
    parent.nodes.add(wordNode);
    wordIndex++;
  }
}

ReaderHtmlProcessOutput processReaderHtmlForTtsIsolate(
  ReaderHtmlProcessInput input,
) {
  final document = html_parser.parseFragment(input.content);
  final List<TtsChunk> chunks = [];
  final seenSentenceFingerprints = <String, int>{};
  int chunkCount = 0;

  final removalStats = removeNoiseAndMetadata(document, input);
  normalizeForMobileReadability(document);

  // ── Walk & annotate text nodes ──────────────────────
  final sentenceRegExp = RegExp(r'(?<=[.!?।])\s+');

  void walk(dom.Node node) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      final text = _compactWhitespace(node.text ?? '');
      if (text.length > 5) {
        final parent = node.parentNode;
        if (parent == null) return;
        final index = parent.nodes.indexOf(node);
        if (index < 0) return;
        parent.nodes.removeAt(index);
        final parentTag = parent is dom.Element
            ? parent.localName?.toLowerCase()
            : null;

        final parts = text.split(sentenceRegExp);
        final nodesToInsert = <dom.Node>[];

        for (var i = 0; i < parts.length; i++) {
          final part = _compactWhitespace(parts[i]);
          final isHeadingParent =
              parentTag == 'h1' ||
              parentTag == 'h2' ||
              parentTag == 'h3' ||
              parentTag == 'h4' ||
              parentTag == 'h5' ||
              parentTag == 'h6';
          if (_looksLikeNoisySentence(
            part,
            input,
            isHeading: isHeadingParent,
          )) {
            continue;
          }

          final fingerprint = _normalizedComparable(part);
          if (fingerprint.length < 8) {
            continue;
          }
          final seenCount = (seenSentenceFingerprints[fingerprint] ?? 0) + 1;
          seenSentenceFingerprints[fingerprint] = seenCount;
          if (seenCount > 1 && part.length < 180) continue;

          final finalPart = i < parts.length - 1 ? '$part ' : part;

          chunks.add(
            TtsChunk(
              index: chunkCount,
              text: finalPart.trim(),
              estimatedDuration: Duration(milliseconds: finalPart.length * 40),
            ),
          );

          final sentenceNode = parentTag == 'a'
              ? dom.Element.tag('span')
              : dom.Element.tag('a');
          if (parentTag != 'a') {
            sentenceNode
              ..attributes['href'] = 'reader://chunk/$chunkCount'
              ..attributes['style'] = 'color:inherit;text-decoration:none;';
          }

          sentenceNode
            ..classes.add('reader-sentence')
            ..classes.add('reader-sentence-anchor')
            ..attributes['data-index'] = chunkCount.toString();
          _appendReaderWordSpans(
            sentenceNode,
            finalPart,
            sentenceIndex: chunkCount,
          );

          nodesToInsert.add(sentenceNode);
          nodesToInsert.add(dom.Text(' '));
          chunkCount++;
        }

        parent.nodes.insertAll(index, nodesToInsert);
      }
    } else if (node.hasChildNodes()) {
      for (final child in List<dom.Node>.from(node.nodes)) {
        walk(child);
      }
    }
  }

  walk(document);

  final contentLength = chunks.fold<int>(
    0,
    (sum, chunk) => sum + chunk.text.length,
  );
  final contaminationScore = _estimateChunkContaminationScore(chunks, input);

  return ReaderHtmlProcessOutput(
    html: document.outerHtml,
    chunks: chunks,
    removedElements: removalStats.removedElements,
    linkHeavyRemoved: removalStats.linkHeavyRemoved,
    headlineListRemoved: removalStats.headlineListRemoved,
    contaminationScore: contaminationScore,
    contentLength: contentLength,
  );
}

const List<String> _kMetadataMarkers = <String>[
  'breadcrumb',
  'breadcrumbs',
  'byline',
  'author',
  'published',
  'publish',
  'updated',
  'timestamp',
  'date',
  'category',
  'tag',
  'share',
  'social',
  'related',
  'recommended',
  'trending',
  'comment',
  'newsletter',
  'subscribe',
  'read-more',
  'also-read',
  'প্রকাশ',
  'সংশ্লিষ্ট',
  'সম্পর্কিত',
  'জনপ্রিয়',
];

final RegExp kMetadataLinePattern = RegExp(
  r'^\s*(published|posted|updated|last updated|source|by|read more|also read|advertisement|sponsored|'
  r'প্রকাশ(?:িত)?|আপডেট|হালনাগাদ|সূত্র|আরও পড়ুন|সংশ্লিষ্ট)\b[\s:–-]*',
  caseSensitive: false,
);

final RegExp _kBreadcrumbPattern = RegExp(r'(\s[>›|/]\s)|(^[>›|/])');
final RegExp kUrlPattern = RegExp(
  r'https?://\S+|www\.\S+',
  caseSensitive: false,
);

String _compactWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

String _normalizedComparable(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0980-\u09ff]+'), '');

String _normalizeHostPrimaryLabel(String? rawUrl) {
  final parsed = Uri.tryParse((rawUrl ?? '').trim());
  final host = (parsed?.host ?? '').toLowerCase();
  if (host.isEmpty) return '';
  final cleaned = host
      .replaceFirst(RegExp(r'^www\.'), '')
      .replaceFirst(RegExp(r'^m\.'), '')
      .replaceFirst(RegExp(r'^amp\.'), '');
  final primary = cleaned.split('.').first;
  return _normalizedComparable(primary);
}

bool isLikelyBrandingTitle(
  String title, {
  String? siteName,
  String? sourceUrl,
}) {
  final cleaned = _compactWhitespace(title);
  if (cleaned.isEmpty) return false;

  final comparable = _normalizedComparable(cleaned);
  if (comparable.isEmpty) return false;

  final siteComparable = _normalizedComparable(siteName ?? '');
  if (siteComparable.isNotEmpty &&
      (comparable == siteComparable ||
          comparable.contains(siteComparable) ||
          siteComparable.contains(comparable))) {
    return true;
  }

  final hostComparable = _normalizeHostPrimaryLabel(sourceUrl);
  if (hostComparable.isNotEmpty &&
      (comparable == hostComparable ||
          comparable.contains(hostComparable) ||
          hostComparable.contains(comparable))) {
    return true;
  }

  return false;
}

int titleQualityScore(String title) {
  final cleaned = _compactWhitespace(title);
  if (cleaned.isEmpty) return -999;
  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .length;
  final hasHeadlinePunctuation = RegExp(r'[,;:!?।]').hasMatch(cleaned);
  final hasSiteDelimiter = RegExp(r'\s[-|–—]\s').hasMatch(cleaned);

  var score = cleaned.length.clamp(0, 160);
  if (words >= 4 && words <= 24) {
    score += 45;
  } else if (words <= 2) {
    score -= 40;
  }
  if (hasHeadlinePunctuation) score += 12;
  if (hasSiteDelimiter) score -= 22;

  return score;
}

@visibleForTesting
String resolvePreferredReaderTitle({
  required String extractedTitle,
  required String? titleHint,
  String? siteName,
  String? sourceUrl,
}) {
  final cleanedExtracted = _compactWhitespace(extractedTitle);
  final hinted = _compactWhitespace(titleHint ?? '');

  if (cleanedExtracted.isEmpty && hinted.isEmpty) {
    return 'Reader mode';
  }
  if (cleanedExtracted.isEmpty) return hinted;
  if (hinted.isEmpty) return cleanedExtracted;

  final extractedBranding = isLikelyBrandingTitle(
    cleanedExtracted,
    siteName: siteName,
    sourceUrl: sourceUrl,
  );
  final hintedBranding = isLikelyBrandingTitle(
    hinted,
    siteName: siteName,
    sourceUrl: sourceUrl,
  );

  if (extractedBranding && !hintedBranding) return hinted;
  if (hintedBranding && !extractedBranding) return cleanedExtracted;

  final extractedScore =
      titleQualityScore(cleanedExtracted) - (extractedBranding ? 120 : 0);
  final hintedScore = titleQualityScore(hinted) - (hintedBranding ? 120 : 0);

  if (hintedScore >= extractedScore + 30) return hinted;
  return cleanedExtracted;
}

bool _isDuplicateHeadline(String text, String articleTitle) {
  if (articleTitle.trim().isEmpty) return false;
  final normalizedText = _normalizedComparable(text);
  final normalizedTitle = _normalizedComparable(articleTitle);
  if (normalizedText.isEmpty || normalizedTitle.isEmpty) return false;
  if (normalizedText == normalizedTitle) return true;
  if (normalizedText.length > normalizedTitle.length + 8) return false;
  return normalizedText.contains(normalizedTitle) ||
      normalizedTitle.contains(normalizedText);
}

bool _looksLikeNoisySentence(
  String text,
  ReaderHtmlProcessInput input, {
  bool isHeading = false,
  bool hasNoiseClass = false,
}) {
  if (text.isEmpty) return true;
  final lower = text.toLowerCase();
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final hasSentencePunctuation = RegExp(r'[.!?।]').hasMatch(text);

  if (input.noisyPrefixes.any(lower.startsWith)) return true;
  if (kUrlPattern.hasMatch(text)) return true;
  if (kMetadataLinePattern.hasMatch(lower) && text.length < 180) return true;
  if (_isDuplicateHeadline(text, input.articleTitle) &&
      words <= 14 &&
      text.length <= input.articleTitle.length + 24) {
    return true;
  }
  if (hasNoiseClass &&
      text.length < 180 &&
      !hasSentencePunctuation &&
      words <= 18) {
    return true;
  }

  if (isHeading) {
    if (_isDuplicateHeadline(text, input.articleTitle)) return true;
    if (!hasNoiseClass && words <= 14 && text.length >= 6) return false;
  }

  if (words < 1) return true;
  if (words <= 1 && text.length < 8 && !text.contains(RegExp(r'[.!?।]'))) {
    return true;
  }
  if (!isHeading &&
      RegExp(r'^[A-Z0-9\s|:/_-]{2,}$').hasMatch(text) &&
      text.length < 90) {
    return true;
  }

  final alphaNumCount = RegExp(
    r'[A-Za-z0-9\u0980-\u09ff]',
  ).allMatches(text).length;
  if (alphaNumCount > 0 &&
      (text.length - alphaNumCount) / text.length > 0.55 &&
      text.length < 140) {
    return true;
  }

  return false;
}

bool _looksLikeHeadlineListBlock({
  required String text,
  required int anchorCount,
  required int shortAnchorCount,
  required int listItemCount,
  required double linkDensity,
}) {
  if (anchorCount < 2) return false;
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final headlineLike = !RegExp(r'[.!?।]').hasMatch(text) && words <= 20;
  if (headlineLike && shortAnchorCount >= 2) return true;
  if (listItemCount >= 3 && shortAnchorCount >= 2) return true;
  if (linkDensity > 0.60 && shortAnchorCount >= 2) return true;
  return false;
}

double _estimateChunkContaminationScore(
  List<TtsChunk> chunks,
  ReaderHtmlProcessInput input,
) {
  if (chunks.isEmpty) return 1.0;
  final sample = chunks.take(12);
  var total = 0;
  var contaminated = 0;
  var punctuated = 0;
  var headlineLikeCount = 0;

  for (final chunk in sample) {
    final text = _compactWhitespace(chunk.text);
    if (text.isEmpty) continue;
    total++;
    final lower = text.toLowerCase();
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasPunctuation = RegExp(r'[.!?।]').hasMatch(text);
    if (hasPunctuation) {
      punctuated++;
    }
    final looksHeadline = !hasPunctuation && words >= 2 && words <= 16;
    if (looksHeadline) {
      headlineLikeCount++;
    }
    final hasNoise =
        input.noiseTokens.any(lower.contains) ||
        _kMetadataMarkers.any(lower.contains) ||
        kMetadataLinePattern.hasMatch(lower);
    if (hasNoise || looksHeadline) contaminated++;
  }

  if (total == 0) return 1.0;
  final baseScore = contaminated / total;
  final punctuationRatio = punctuated / total;
  final headlineRatio = headlineLikeCount / total;

  var adjusted = baseScore;
  if (punctuationRatio < 0.20) adjusted += 0.22;
  if (headlineRatio > 0.55) adjusted += 0.22;
  if (punctuationRatio < 0.10 && headlineRatio > 0.45) {
    adjusted += 0.20;
  }

  return adjusted.clamp(0.0, 1.0);
}

_ReaderRemovalStats removeNoiseAndMetadata(
  dom.DocumentFragment document,
  ReaderHtmlProcessInput input,
) {
  var removedElements = 0;
  var linkHeavyRemoved = 0;
  var headlineListRemoved = 0;

  document
      .querySelectorAll(
        'script,style,iframe,nav,aside,footer,form,noscript,button,svg,canvas,header,'
        '.ads,.advertisement,.social-share,.share-tools,.related,.recommended,'
        '.trending,.newsletter,.comments,.comment,[role="navigation"],[role="complementary"]',
      )
      .forEach((e) {
        e.remove();
        removedElements++;
      });

  final allElements = List<dom.Element>.from(document.querySelectorAll('*'));
  for (final element in allElements) {
    final marker = _compactWhitespace(
      '${element.className.toLowerCase()} ${element.id.toLowerCase()} '
      '${(element.attributes['role'] ?? '').toLowerCase()} '
      '${(element.attributes['aria-label'] ?? '').toLowerCase()}',
    );
    final text = _compactWhitespace(element.text);
    final textLower = text.toLowerCase();
    final tag = (element.localName ?? '').toLowerCase();
    final isHeading = tag.startsWith('h');
    if (text.isEmpty) continue;

    final anchors = element.querySelectorAll('a');
    final anchorCount = anchors.length;
    final shortAnchorCount = anchors
        .where(
          (a) =>
              _compactWhitespace(
                a.text,
              ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <=
              8,
        )
        .length;
    final anchorTextLength = anchors.fold<int>(
      0,
      (sum, a) => sum + _compactWhitespace(a.text).length,
    );
    final linkDensity = anchorTextLength / text.length.clamp(1, 1 << 20);
    final listItemCount = element.querySelectorAll('li').length;

    final hasNoiseMarker =
        input.noiseTokens.any(marker.contains) ||
        _kMetadataMarkers.any(marker.contains);
    final isMetadataLine =
        text.length <= 140 &&
        (kMetadataLinePattern.hasMatch(textLower) ||
            _kBreadcrumbPattern.hasMatch(text));
    final isCategoryLike =
        text.length <= 60 &&
        (marker.contains('category') ||
            marker.contains('tag') ||
            marker.contains('topic'));
    final isDuplicateTitle =
        text.length <= input.articleTitle.length + 16 &&
        _isDuplicateHeadline(text, input.articleTitle) &&
        (isHeading || marker.contains('title') || marker.contains('headline'));
    final isNoisySentence = _looksLikeNoisySentence(
      text,
      input,
      isHeading: isHeading,
      hasNoiseClass: hasNoiseMarker,
    );
    final isBoilerplateBlock =
        hasNoiseMarker &&
        (text.length <= 260 || tag == 'section' || tag == 'div' || tag == 'ul');
    final isLinkHeavyBlock =
        anchorCount >= 3 &&
        shortAnchorCount >= 2 &&
        ((input.strictMode && linkDensity >= 0.45) ||
            (!input.strictMode && linkDensity >= 0.75));
    final isHeadlineListBlock = _looksLikeHeadlineListBlock(
      text: text,
      anchorCount: anchorCount,
      shortAnchorCount: shortAnchorCount,
      listItemCount: listItemCount,
      linkDensity: linkDensity,
    );
    final isSuspiciousHeading =
        input.strictMode &&
        isHeading &&
        text.length <= 120 &&
        !_isDuplicateHeadline(text, input.articleTitle) &&
        (anchorCount > 0 || hasNoiseMarker || isHeadlineListBlock);

    if ((tag != 'article' && tag != 'main') &&
        (tag == 'label' ||
            isDuplicateTitle ||
            isCategoryLike ||
            isMetadataLine ||
            isNoisySentence ||
            isBoilerplateBlock ||
            isSuspiciousHeading ||
            isLinkHeavyBlock ||
            isHeadlineListBlock)) {
      if (isLinkHeavyBlock) linkHeavyRemoved++;
      if (isHeadlineListBlock) headlineListRemoved++;
      element.remove();
      removedElements++;
    }
  }

  return _ReaderRemovalStats(
    removedElements: removedElements,
    linkHeavyRemoved: linkHeavyRemoved,
    headlineListRemoved: headlineListRemoved,
  );
}

void _appendInlineStyle(dom.Element element, String style) {
  final current = element.attributes['style']?.trim() ?? '';
  if (current.isEmpty) {
    element.attributes['style'] = style;
    return;
  }
  final separator = current.endsWith(';') ? '' : ';';
  element.attributes['style'] = '$current$separator$style';
}

void normalizeForMobileReadability(dom.DocumentFragment document) {
  for (final p in document.querySelectorAll('p,li,blockquote')) {
    _appendInlineStyle(
      p,
      'text-align:justify;line-height:1.75;word-break:break-word;overflow-wrap:anywhere;margin:0 0 1em 0;',
    );
  }
  for (final heading in document.querySelectorAll('h1,h2,h3')) {
    _appendInlineStyle(
      heading,
      'line-height:1.3;margin:1.1em 0 0.45em 0;font-weight:700;',
    );
  }
  for (final list in document.querySelectorAll('ul,ol')) {
    _appendInlineStyle(list, 'padding-left:1.2em;margin:0.2em 0 1em 0;');
  }
  for (final img in document.querySelectorAll('img')) {
    _appendInlineStyle(
      img,
      'max-width:100%;height:auto;display:block;margin:16px auto;border-radius:8px;',
    );
  }
  for (final table in document.querySelectorAll('table')) {
    _appendInlineStyle(table, 'display:block;overflow-x:auto;width:100%;');
  }
  for (final label in document.querySelectorAll(
    '.category,.categories,[class*="category"],[class*="tag"],[class*="label"],'
    '[class*="badge"],[id*="category"],[id*="tag"]',
  )) {
    _appendInlineStyle(
      label,
      'position:static;top:auto;right:auto;bottom:auto;left:auto;transform:none;',
    );
  }
}

// ─────────────────────────────────────────────
// NOISE CONSTANTS  (defined once at module level)
// ─────────────────────────────────────────────
const kNoiseTokens = <String>[
  'related',
  'recommend',
  'recommended',
  'trending',
  'popular',
  'newsletter',
  'subscribe',
  'comment',
  'share',
  'sponsored',
  'advert',
  'read-more',
  'more-news',
  'also-read',
  'you-may-like',
  'more-from',
  'more-stories',
  'আরও-পড়ুন',
  'আরও-সংবাদ',
  'সম্পর্কিত',
  'সংশ্লিষ্ট',
  'জনপ্রিয়',
  'ট্রেন্ডিং',
];

const kNoisyPrefixes = <String>[
  'read more',
  'also read',
  'related news',
  'related articles',
  'you may also like',
  'recommended for you',
  'trending now',
  'more from',
  'follow us',
  'subscribe',
  'comments',
  'advertisement',
  'sponsored',
  'আরও পড়ুন',
  'আরও দেখুন',
  'সম্পর্কিত খবর',
  'সংশ্লিষ্ট খবর',
  'জনপ্রিয়',
  'ট্রেন্ডিং',
];

