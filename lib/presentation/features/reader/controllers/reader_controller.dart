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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

import '../models/reader_article.dart';
import '../../../../core/tts/domain/entities/tts_chunk.dart';
import '../../../../core/tts/presentation/providers/tts_controller.dart';
import '../../../../core/di/providers.dart' show appNetworkServiceProvider;
import '../models/reader_settings.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../providers/app_settings_providers.dart';

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

/// Top-level function required by `compute()` — must not be a closure
/// or instance method so Dart can spawn it in a separate Isolate.
ReaderHtmlProcessOutput processReaderHtmlForTtsIsolate(
  ReaderHtmlProcessInput input,
) {
  final document = html_parser.parseFragment(input.content);
  final List<TtsChunk> chunks = [];
  final seenSentenceFingerprints = <String, int>{};
  int chunkCount = 0;

  final removalStats = _removeNoiseAndMetadata(document, input);
  _normalizeForMobileReadability(document);

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

          final sentenceNode =
              parentTag == 'a' ? dom.Element.tag('span') : dom.Element.tag('a')
                ..attributes['href'] = 'reader://chunk/$chunkCount'
                ..attributes['style'] = 'color:inherit;text-decoration:none;';

          sentenceNode
            ..classes.add('reader-sentence')
            ..classes.add('reader-sentence-anchor')
            ..attributes['data-index'] = chunkCount.toString()
            ..text = finalPart;

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

final RegExp _kMetadataLinePattern = RegExp(
  r'^\s*(published|posted|updated|last updated|source|by|read more|also read|advertisement|sponsored|'
  r'প্রকাশ(?:িত)?|আপডেট|হালনাগাদ|সূত্র|আরও পড়ুন|সংশ্লিষ্ট)\b[\s:–-]*',
  caseSensitive: false,
);

final RegExp _kBreadcrumbPattern = RegExp(r'(\s[>›|/]\s)|(^[>›|/])');
final RegExp _kUrlPattern = RegExp(
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

bool _isLikelyBrandingTitle(
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

int _titleQualityScore(String title) {
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

  final extractedBranding = _isLikelyBrandingTitle(
    cleanedExtracted,
    siteName: siteName,
    sourceUrl: sourceUrl,
  );
  final hintedBranding = _isLikelyBrandingTitle(
    hinted,
    siteName: siteName,
    sourceUrl: sourceUrl,
  );

  if (extractedBranding && !hintedBranding) return hinted;
  if (hintedBranding && !extractedBranding) return cleanedExtracted;

  final extractedScore =
      _titleQualityScore(cleanedExtracted) - (extractedBranding ? 120 : 0);
  final hintedScore = _titleQualityScore(hinted) - (hintedBranding ? 120 : 0);

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
  if (_kUrlPattern.hasMatch(text)) return true;
  if (_kMetadataLinePattern.hasMatch(lower) && text.length < 180) return true;
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
        _kMetadataLinePattern.hasMatch(lower);
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

_ReaderRemovalStats _removeNoiseAndMetadata(
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
        (_kMetadataLinePattern.hasMatch(textLower) ||
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

void _normalizeForMobileReadability(dom.DocumentFragment document) {
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
const _kNoiseTokens = <String>[
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

const _kNoisyPrefixes = <String>[
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

// ─────────────────────────────────────────────
// READER STATE
// ─────────────────────────────────────────────
@immutable
class ReaderState {
  const ReaderState({
    this.isReaderMode = false,
    this.isLoading = false,
    this.article,
    this.errorMessage,
    this.errorCode,
    this.pageType = ReaderPageType.unknown,
    this.titleSource = ReaderTitleSource.fallback,
    this.qualityScore = 0,
    this.chunks = const [],
    this.currentChunkIndex = -1,
    this.processedContent,
    this.fontSize = 16.0,
    this.fontFamily = ReaderFontFamily.serif,
    this.readerTheme = ReaderTheme.system,
  });

  final bool isReaderMode;
  final bool isLoading;
  final ReaderArticle? article;
  final String? errorMessage;
  final String? errorCode; // e.g. 'script_missing', 'parse_fail'
  final ReaderPageType pageType;
  final ReaderTitleSource titleSource;
  final double qualityScore;
  final List<TtsChunk> chunks;
  final int currentChunkIndex;
  final String? processedContent;
  final double fontSize;
  final ReaderFontFamily fontFamily;
  final ReaderTheme readerTheme;

  ReaderState copyWith({
    bool? isReaderMode,
    bool? isLoading,
    ReaderArticle? article,
    String? errorMessage,
    String? errorCode,
    ReaderPageType? pageType,
    ReaderTitleSource? titleSource,
    double? qualityScore,
    List<TtsChunk>? chunks,
    int? currentChunkIndex,
    String? processedContent,
    double? fontSize,
    ReaderFontFamily? fontFamily,
    ReaderTheme? readerTheme,
  }) {
    return ReaderState(
      isReaderMode: isReaderMode ?? this.isReaderMode,
      isLoading: isLoading ?? this.isLoading,
      article: article ?? this.article,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
      pageType: pageType ?? this.pageType,
      titleSource: titleSource ?? this.titleSource,
      qualityScore: qualityScore ?? this.qualityScore,
      chunks: chunks ?? this.chunks,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      processedContent: processedContent ?? this.processedContent,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      readerTheme: readerTheme ?? this.readerTheme,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderState &&
      other.isReaderMode == isReaderMode &&
      other.isLoading == isLoading &&
      other.article == article &&
      other.errorMessage == errorMessage &&
      other.errorCode == errorCode &&
      other.pageType == pageType &&
      other.titleSource == titleSource &&
      other.qualityScore == qualityScore &&
      other.chunks == chunks &&
      other.currentChunkIndex == currentChunkIndex &&
      other.processedContent == processedContent &&
      other.fontSize == fontSize &&
      other.fontFamily == fontFamily &&
      other.readerTheme == readerTheme;

  @override
  int get hashCode => Object.hash(
    isReaderMode,
    isLoading,
    article,
    errorMessage,
    errorCode,
    pageType,
    titleSource,
    qualityScore,
    chunks,
    currentChunkIndex,
    processedContent,
    fontSize,
    fontFamily,
    readerTheme,
  );
}

// ─────────────────────────────────────────────
// LRU ARTICLE CACHE
// ─────────────────────────────────────────────
class _ArticleCacheEntry {
  _ArticleCacheEntry({
    required this.article,
    required this.processedContent,
    required this.chunks,
  });
  final ReaderArticle article;
  final String processedContent;
  final List<TtsChunk> chunks;
}

class _LruArticleCache {
  static const int _capacity = 5;
  final _store = <String, _ArticleCacheEntry>{};

  _ArticleCacheEntry? get(String url) {
    final entry = _store.remove(url);
    if (entry != null) _store[url] = entry; // move to end (most-recent)
    return entry;
  }

  void put(String url, _ArticleCacheEntry entry) {
    if (_store.containsKey(url)) _store.remove(url);
    if (_store.length >= _capacity) {
      _store.remove(_store.keys.first);
    }
    _store[url] = entry;
  }

  bool contains(String url) => _store.containsKey(url);
}

// ─────────────────────────────────────────────
// READABILITY SCRIPT – module-level singleton
// ─────────────────────────────────────────────
String? _readabilityScriptSingleton;

Future<String?> _loadReadabilityScript() async {
  if (_readabilityScriptSingleton != null) return _readabilityScriptSingleton;
  try {
    _readabilityScriptSingleton = await rootBundle.loadString(
      'assets/js/readability.js',
    );
    return _readabilityScriptSingleton;
  } catch (e) {
    debugPrint('[ReaderController] Failed to load readability.js: $e');
    return null;
  }
}

// ─────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────
class ReaderController extends StateNotifier<ReaderState> {
  ReaderController(this.ref) : super(const ReaderState()) {
    _ttsSubscription = ref.listen(ttsControllerProvider, (_, next) {
      // Only notify listeners when chunk index actually changes.
      if (state.isReaderMode &&
          state.chunks.isNotEmpty &&
          next.currentChunk != state.currentChunkIndex) {
        state = state.copyWith(currentChunkIndex: next.currentChunk);
      }
    });
    _loadSettings();
  }

  final Ref ref;
  late final SettingsRepository _repository = ref.read(
    settingsRepositoryProvider,
  );
  ProviderSubscription? _ttsSubscription;
  InAppWebViewController? _webViewController;

  // In-flight extraction cancellation token.
  bool _extractionCancelled = false;

  // Debounce timers for settings persistence.
  Timer? _fontSizeDebounce;
  Timer? _fontFamilyDebounce;
  Timer? _themeDebounce;

  // Article LRU cache.
  final _cache = _LruArticleCache();

  @override
  void dispose() {
    stopTts();
    _ttsSubscription?.close();
    _fontSizeDebounce?.cancel();
    _fontFamilyDebounce?.cancel();
    _themeDebounce?.cancel();
    _extractionCancelled = true;
    super.dispose();
  }

  // ── Web view ─────────────────────────────────
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  // ── Toggle ───────────────────────────────────
  Future<void> toggleReaderMode({String? urlHint, String? titleHint}) async {
    if (state.isReaderMode) {
      state = state.copyWith(isReaderMode: false);
      stopTts();
    } else {
      if (state.article != null) {
        state = state.copyWith(isReaderMode: true);
        return;
      }
      await extractContent(urlHint: urlHint, titleHint: titleHint);
    }
  }

  void clearState() {
    state = ReaderState(
      isReaderMode: state.isReaderMode,
      isLoading: true,
      pageType: ReaderPageType.unknown,
      titleSource: ReaderTitleSource.fallback,
      qualityScore: 0,
      fontSize: state.fontSize,
      fontFamily: state.fontFamily,
      readerTheme: state.readerTheme,
    );
  }

  void markExtractionFailure({required String message, String? errorCode}) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: message,
      errorCode: errorCode ?? 'reader_load_failure',
      pageType: ReaderPageType.unknown,
      titleSource: ReaderTitleSource.fallback,
      qualityScore: 0,
    );
  }

  // ── Content extraction ───────────────────────
  Future<void> extractContent({String? urlHint, String? titleHint}) async {
    if (_webViewController == null) {
      state = state.copyWith(
        isReaderMode: false,
        isLoading: false,
        errorMessage:
            'Page is still loading. Please wait and try Reader mode again.',
        errorCode: 'webview_not_ready',
      );
      return;
    }

    // Cancel any previous in-flight extraction.
    _extractionCancelled = true;
    await Future.microtask(() {}); // yield to event loop
    _extractionCancelled = false;

    // Check cache first.
    if (urlHint != null && _cache.contains(urlHint)) {
      final cached = _cache.get(urlHint)!;
      state = state.copyWith(
        isReaderMode: true,
        isLoading: false,
        article: cached.article,
        processedContent: cached.processedContent,
        chunks: cached.chunks,
        pageType: ReaderPageType.article,
        titleSource: ReaderTitleSource.fallback,
        qualityScore: 1.0,
        errorCode: null,
        errorMessage: null,
      );
      return;
    }

    // Clear old state before starting new extraction to avoid ghosting.
    clearState();

    try {
      final script = await _loadReadabilityScript();
      if (script == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Could not load Readability script.',
          errorCode: 'script_missing',
        );
        return;
      }
      if (_extractionCancelled) return;

      final preflightMeta = await _runPageClassification(
        urlHint: urlHint,
        titleHint: titleHint,
      );
      if (_extractionCancelled) return;
      if (preflightMeta != null && !preflightMeta.isSupportedArticle) {
        _setUnsupportedPageState(preflightMeta);
        return;
      }

      final strictPayload = await _runReadabilityExtractionPass(
        readabilityScript: script,
        strictMode: true,
        titleHint: titleHint,
        timeout: _adaptiveExtractionTimeout(strictMode: true, urlHint: urlHint),
        urlHint: urlHint,
      );
      if (_extractionCancelled) return;
      final strictMeta = ReaderExtractionMeta.fromPayload(strictPayload);
      if (strictPayload != null && !strictMeta.isSupportedArticle) {
        _setUnsupportedPageState(strictMeta);
        return;
      }

      final strictArticle = strictPayload == null
          ? null
          : _readerArticleFromPayload(
              strictPayload,
              titleHint: titleHint,
              urlHint: urlHint,
            );
      final strictProcessed = strictArticle == null
          ? null
          : await _processArticleForTts(
              article: strictArticle,
              strictMode: true,
            );
      if (_extractionCancelled) return;

      final softPayload =
          (strictProcessed == null ||
              !passesReaderQualityGate(
                contentLength: strictProcessed.contentLength,
                contaminationScore: strictProcessed.contaminationScore,
                strict: true,
              ))
          ? await _runReadabilityExtractionPass(
              readabilityScript: script,
              strictMode: false,
              titleHint: titleHint,
              timeout: _adaptiveExtractionTimeout(
                strictMode: false,
                urlHint: urlHint,
              ),
              urlHint: urlHint,
            )
          : null;
      if (_extractionCancelled) return;
      final softMeta = ReaderExtractionMeta.fromPayload(softPayload);
      if (softPayload != null && !softMeta.isSupportedArticle) {
        _setUnsupportedPageState(softMeta);
        return;
      }

      final softArticle = softPayload == null
          ? null
          : _readerArticleFromPayload(
              softPayload,
              titleHint: titleHint,
              urlHint: urlHint,
            );
      final softProcessed = softArticle == null
          ? null
          : await _processArticleForTts(
              article: softArticle,
              strictMode: false,
            );
      if (_extractionCancelled) return;

      ReaderArticle? article = strictArticle ?? softArticle;
      ReaderHtmlProcessOutput? processed = strictProcessed ?? softProcessed;
      ReaderExtractionMeta selectedMeta = strictPayload != null
          ? strictMeta
          : (softPayload != null
                ? softMeta
                : const ReaderExtractionMeta(
                    pageType: ReaderPageType.article,
                    titleSource: ReaderTitleSource.fallback,
                    qualityScore: 0,
                  ));
      var selectedPass = 'fallback';
      if (strictProcessed != null && softProcessed != null) {
        selectedPass = chooseReaderExtractionPass(
          strictOutput: strictProcessed,
          softOutput: softProcessed,
        );
      } else if (strictProcessed != null &&
          passesReaderQualityGate(
            contentLength: strictProcessed.contentLength,
            contaminationScore: strictProcessed.contaminationScore,
            strict: true,
          )) {
        selectedPass = 'strict';
      } else if (softProcessed != null &&
          passesReaderQualityGate(
            contentLength: softProcessed.contentLength,
            contaminationScore: softProcessed.contaminationScore,
            strict: false,
          )) {
        selectedPass = 'soft';
      }

      if (selectedPass == 'strict' &&
          strictArticle != null &&
          strictProcessed != null) {
        article = strictArticle;
        processed = strictProcessed;
        selectedMeta = strictMeta;
      } else if (selectedPass == 'soft' &&
          softArticle != null &&
          softProcessed != null) {
        article = softArticle;
        processed = softProcessed;
        selectedMeta = softMeta;
      }

      if ((article == null || processed == null) ||
          selectedPass == 'fallback') {
        Map<String, dynamic>? fallbackPayload;
        ReaderExtractionMeta fallbackMeta = const ReaderExtractionMeta(
          pageType: ReaderPageType.article,
          titleSource: ReaderTitleSource.fallback,
          qualityScore: 0,
        );
        if (article == null) {
          final lightweight = await _extractContentWithLightweightFallback();
          fallbackPayload = _decodeExtractionPayload(lightweight);
          fallbackMeta = ReaderExtractionMeta.fromPayload(fallbackPayload);
          if (fallbackPayload != null && !fallbackMeta.isSupportedArticle) {
            _setUnsupportedPageState(fallbackMeta);
            return;
          }
          if (fallbackPayload != null) {
            article = _readerArticleFromPayload(
              fallbackPayload,
              titleHint: titleHint,
              urlHint: urlHint,
            );
          }
        }

        if (article == null) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Page content could not be extracted.',
            errorCode: 'parse_fail',
          );
          return;
        }

        final fallbackChunks = _buildFallbackChunks(article.textContent);
        final fallbackQualityScore = _scoreChunkBodyQuality(
          fallbackChunks,
          article.textContent,
        );
        if (fallbackQualityScore < 0.52 ||
            article.textContent.length < _kSoftMinContentLength) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Reader mode could not isolate article-only content.',
            errorCode: 'reader_quality_fail',
            pageType: ReaderPageType.article,
            titleSource: ReaderTitleSource.fallback,
            qualityScore: fallbackQualityScore,
          );
          return;
        }

        processed = ReaderHtmlProcessOutput(
          html: article.content,
          chunks: fallbackChunks,
          removedElements: 0,
          linkHeavyRemoved: 0,
          headlineListRemoved: 0,
          contaminationScore: 1.0,
          contentLength: article.textContent.length,
        );
        selectedPass = 'fallback';
        selectedMeta = fallbackPayload != null
            ? fallbackMeta
            : ReaderExtractionMeta(
                pageType: ReaderPageType.article,
                titleSource: ReaderTitleSource.fallback,
                qualityScore: fallbackQualityScore,
              );
      }

      _logExtractionTelemetry(
        selectedPass: selectedPass,
        processed: processed,
        meta: selectedMeta,
      );

      if (_extractionCancelled) return;

      // Populate cache.
      final cacheKey = (urlHint ?? '').trim();
      if (cacheKey.isNotEmpty) {
        _cache.put(
          cacheKey,
          _ArticleCacheEntry(
            article: article,
            processedContent: processed.html,
            chunks: processed.chunks,
          ),
        );
      }

      state = state.copyWith(
        isReaderMode: true,
        isLoading: false,
        article: article,
        processedContent: processed.html,
        chunks: processed.chunks,
        pageType: selectedMeta.pageType,
        titleSource: selectedMeta.titleSource,
        qualityScore: selectedMeta.qualityScore,
        errorCode: selectedMeta.failureCode,
        errorMessage: null,
      );
    } catch (e, s) {
      if (_extractionCancelled) return;
      debugPrint('[ReaderController] extractContent error: $e\n$s');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error during extraction: $e',
        errorCode: 'unknown',
        pageType: ReaderPageType.unknown,
        titleSource: ReaderTitleSource.fallback,
        qualityScore: 0,
      );
    }
  }

  Map<String, dynamic>? _decodeExtractionPayload(Object? result) {
    if (result == null || result == 'null') return null;
    final payload = result is String ? result : result.toString();
    dynamic decoded;
    try {
      decoded = json.decode(payload);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final jsonMap = Map<String, dynamic>.from(decoded);
    if (jsonMap.containsKey('error')) {
      debugPrint('[ReaderController] JS extraction error: ${jsonMap['error']}');
      return null;
    }
    return jsonMap;
  }

  Future<ReaderExtractionMeta?> _runPageClassification({
    required String? urlHint,
    required String? titleHint,
  }) async {
    if (_webViewController == null) return null;
    try {
      final result = await _webViewController!
          .evaluateJavascript(
            source: _buildPageClassificationScript(
              urlHint: urlHint,
              titleHint: titleHint,
            ),
          )
          .timeout(
            _adaptiveExtractionTimeout(strictMode: true, urlHint: urlHint),
          );
      final payload = _decodeExtractionPayload(result);
      return ReaderExtractionMeta.fromPayload(payload);
    } on TimeoutException {
      return null;
    } catch (e) {
      debugPrint('[ReaderController] page classification failed: $e');
      return null;
    }
  }

  void _setUnsupportedPageState(ReaderExtractionMeta meta) {
    final pageLabel = switch (meta.pageType) {
      ReaderPageType.liveFeed => 'live update pages',
      ReaderPageType.listing => 'collection pages',
      ReaderPageType.article => 'this page',
      ReaderPageType.unknown => 'this page',
    };
    state = ReaderState(
      isReaderMode: false,
      isLoading: false,
      errorCode: meta.failureCode ?? 'reader_unsupported_page_type',
      errorMessage:
          'Reader mode supports single-article pages only. This looks like $pageLabel.',
      pageType: meta.pageType,
      titleSource: meta.titleSource,
      qualityScore: meta.qualityScore,
      fontSize: state.fontSize,
      fontFamily: state.fontFamily,
      readerTheme: state.readerTheme,
    );
  }

  String _buildPageClassificationScript({
    required String? urlHint,
    required String? titleHint,
  }) {
    final urlHintLiteral = jsonEncode((urlHint ?? '').trim());
    final titleHintLiteral = jsonEncode((titleHint ?? '').trim());
    return '''
(() => {
  const URL_HINT = $urlHintLiteral;
  const TITLE_HINT = $titleHintLiteral;
  const normalize = (value) => String(value || '').replace(/\\u00a0/g, ' ').replace(/\\s+/g, ' ').trim();

  const collectTypes = (node, out) => {
    if (!node) return;
    if (Array.isArray(node)) {
      node.forEach((item) => collectTypes(item, out));
      return;
    }
    if (typeof node === 'object') {
      const t = node['@type'];
      if (typeof t === 'string') out.add(t.toLowerCase());
      if (Array.isArray(t)) t.forEach((x) => out.add(String(x).toLowerCase()));
      collectTypes(node['@graph'], out);
      collectTypes(node.mainEntity, out);
      collectTypes(node.itemListElement, out);
    }
  };

  const jsonLdTypes = new Set();
  document.querySelectorAll('script[type="application/ld+json"]').forEach((el) => {
    const raw = (el.textContent || '').trim();
    if (!raw) return;
    try {
      collectTypes(JSON.parse(raw), jsonLdTypes);
    } catch (_) {}
  });

  const hasLiveType = Array.from(jsonLdTypes).some((t) => t.includes('liveblog'));
  const hasListingType = Array.from(jsonLdTypes).some((t) =>
    t.includes('itemlist') || t.includes('collectionpage')
  );
  const hasArticleType = Array.from(jsonLdTypes).some((t) =>
    t.includes('newsarticle') || t.includes('article') || t.includes('reportagenewsarticle')
  );

  const bodyText = normalize(document.body?.innerText || '');
  const allAnchors = Array.from(document.querySelectorAll('a'));
  const totalAnchorText = allAnchors.reduce((sum, a) => sum + normalize(a.innerText || a.textContent || '').length, 0);
  const linkDensity = totalAnchorText / Math.max(bodyText.length, 1);

  const headlineAnchors = Array.from(
    document.querySelectorAll(
      'article h2 a, article h3 a, [class*="headline"] a, [class*="story"] a, [class*="card"] h2 a, [class*="card"] h3 a'
    )
  ).filter((a) => normalize(a.innerText || a.textContent || '').length >= 18);

  const shortHeadlineAnchors = headlineAnchors.filter(
    (a) => normalize(a.innerText || a.textContent || '').split(/\\s+/).filter(Boolean).length <= 14
  );
  const timestampNodes = document.querySelectorAll(
    'time,[datetime],[class*="timestamp"],[class*="updated"],[class*="time"],[id*="time"]'
  ).length;
  const updateMentions = (bodyText.match(/updated|live|minute|min ago|আপডেট|হালনাগাদ|লাইভ/gi) || []).length;
  const paragraphCount = document.querySelectorAll('article p, main p, p').length;
  const h1Text = normalize(document.querySelector('h1')?.innerText || '');

  let pageType = 'unknown';
  let qualityScore = 0.35;

  const liveSignal = hasLiveType ||
    ((timestampNodes >= 8 || updateMentions >= 6) && headlineAnchors.length >= 5 && linkDensity >= 0.16);
  const listingSignal = hasListingType ||
    (headlineAnchors.length >= 8 && shortHeadlineAnchors.length >= 6 && linkDensity >= 0.18);
  const articleSignal = hasArticleType || (h1Text.length >= 12 && paragraphCount >= 3 && linkDensity < 0.45);

  if (liveSignal) {
    pageType = 'live_feed';
    qualityScore = 0.95;
  } else if (listingSignal) {
    pageType = 'listing';
    qualityScore = 0.92;
  } else if (articleSignal) {
    pageType = 'article';
    qualityScore = 0.84;
  } else if (h1Text.length >= 10 && paragraphCount >= 2) {
    pageType = 'article';
    qualityScore = 0.64;
  }

  const failureCode = pageType === 'article' ? null : 'reader_unsupported_page_type';
  return JSON.stringify({
    pageType,
    titleSource: normalize(TITLE_HINT).length > 0 ? 'hint' : 'fallback',
    qualityScore,
    failureCode,
    url: URL_HINT || location.href
  });
})();
''';
  }

  Future<Map<String, dynamic>?> _runReadabilityExtractionPass({
    required String readabilityScript,
    required bool strictMode,
    required String? titleHint,
    required Duration timeout,
    required String? urlHint,
  }) async {
    if (_webViewController == null) return null;
    try {
      final result = await _webViewController!
          .evaluateJavascript(
            source: _buildReadabilityExtractionScript(
              readabilityScript: readabilityScript,
              strictMode: strictMode,
              titleHint: titleHint,
              urlHint: urlHint,
            ),
          )
          .timeout(timeout);
      return _decodeExtractionPayload(result);
    } on TimeoutException {
      debugPrint(
        '[ReaderController] ${strictMode ? 'strict' : 'soft'} extraction timed out.',
      );
      return null;
    } catch (e) {
      debugPrint(
        '[ReaderController] ${strictMode ? 'strict' : 'soft'} extraction failed: $e',
      );
      return null;
    }
  }

  Duration _adaptiveExtractionTimeout({
    required bool strictMode,
    required String? urlHint,
  }) {
    var timeout = ref.read(appNetworkServiceProvider).getAdaptiveTimeout();
    if (strictMode) {
      timeout += const Duration(seconds: 1);
    }
    final host = (Uri.tryParse(urlHint ?? '')?.host ?? '').toLowerCase();
    if (host.contains('bd-pratidin.com') ||
        host.contains('thedailystar.net') ||
        host.contains('prothomalo.com')) {
      timeout += const Duration(seconds: 2);
    }

    if (timeout < const Duration(seconds: 6)) {
      return const Duration(seconds: 6);
    }
    if (timeout > const Duration(seconds: 22)) {
      return const Duration(seconds: 22);
    }
    return timeout;
  }

  String _buildReadabilityExtractionScript({
    required String readabilityScript,
    required bool strictMode,
    required String? titleHint,
    required String? urlHint,
  }) {
    final strictLiteral = strictMode ? 'true' : 'false';
    final titleHintLiteral = jsonEncode((titleHint ?? '').trim());
    final urlHintLiteral = jsonEncode((urlHint ?? '').trim());
    return '''
(function() {
  const STRICT_MODE = $strictLiteral;
  const TITLE_HINT = $titleHintLiteral;
  const URL_HINT = $urlHintLiteral;

  const normalize = (value) => String(value || '')
    .replace(/\\u00a0/g, ' ')
    .replace(/[ \\t]+/g, ' ')
    .replace(/\\n{3,}/g, '\\n\\n')
    .trim();

  const normalizeComparable = (value) =>
    normalize(value).toLowerCase().replace(/[^a-z0-9\\u0980-\\u09ff]+/g, '');

  let host = '';
  let hostComparable = '';
  try {
    host = new URL(URL_HINT || location.href).hostname.toLowerCase();
    hostComparable = normalizeComparable(
      host.replace(/^www\\./, '').replace(/^m\\./, '').replace(/^amp\\./, '').split('.')[0]
    );
  } catch (_) {}

  const hostAdapter = (() => {
    if (host.includes('prothomalo.com')) {
      return {
        rootSelectors: ['article', 'div[itemprop="articleBody"]', '.story-element.story-element-text', '.story-content', '.story-body'],
        titleSelectors: ['h1', 'meta[property="og:title"]', 'meta[name="twitter:title"]'],
        removeSelectors: ['.share', '.share-tools', '.related', '.more-news', '.read-more', '.live-update', '.story-tags']
      };
    }
    if (host.includes('bd-pratidin.com')) {
      return {
        rootSelectors: ['article', '.details', '.news-content', '[itemprop="articleBody"]'],
        titleSelectors: ['h1', '.headline', 'meta[property="og:title"]'],
        removeSelectors: ['.share', '.related', '.top-news', '.latest-news']
      };
    }
    if (host.includes('thedailystar.net')) {
      return {
        rootSelectors: ['article', '.article-body', '.section-content'],
        titleSelectors: ['h1', '.article-title'],
        removeSelectors: ['.more-from-this-section', '.related-articles', '.social-share']
      };
    }
    if (host.includes('banglanews24.com')) {
      return {
        rootSelectors: ['article', '.news-article-content', '.article-details'],
        titleSelectors: ['h1', '.news-title'],
        removeSelectors: ['.social-share', '.related-news', '.tags']
      };
    }
    if (host.includes('bbc.com') || host.includes('bbc.co.uk')) {
      return {
        rootSelectors: ['article', '[data-component="text-block"]', '.story-body__inner'],
        titleSelectors: ['h1', '.story-body__h1'],
        removeSelectors: ['.social-embed', '.related-links', '.share-tools']
      };
    }
    return null;
  })();

  const sourceBonuses = {
    hint: 46,
    meta_og: 72,
    meta_twitter: 58,
    jsonld: 66,
    h1: 62,
    document_title: 38,
    fallback: 0
  };

  const looksLikeBrandTitle = (value, siteName) => {
    const candidate = normalize(value);
    if (!candidate) return false;
    const candidateComparable = normalizeComparable(candidate);
    if (!candidateComparable) return false;
    const siteComparable = normalizeComparable(siteName || '');
    if (siteComparable &&
        (candidateComparable === siteComparable ||
         candidateComparable.includes(siteComparable) ||
         siteComparable.includes(candidateComparable))) {
      return true;
    }
    if (hostComparable &&
        (candidateComparable === hostComparable ||
         candidateComparable.includes(hostComparable) ||
         hostComparable.includes(candidateComparable))) {
      return true;
    }
    return false;
  };

  const collectTypes = (node, out) => {
    if (!node) return;
    if (Array.isArray(node)) {
      node.forEach((item) => collectTypes(item, out));
      return;
    }
    if (typeof node === 'object') {
      const type = node['@type'];
      if (typeof type === 'string') out.add(type.toLowerCase());
      if (Array.isArray(type)) type.forEach((v) => out.add(String(v).toLowerCase()));
      collectTypes(node['@graph'], out);
      collectTypes(node.mainEntity, out);
      collectTypes(node.itemListElement, out);
    }
  };

  const extractJsonLdHeadline = () => {
    let headline = '';
    document.querySelectorAll('script[type="application/ld+json"]').forEach((el) => {
      if (headline) return;
      const raw = (el.textContent || '').trim();
      if (!raw) return;
      try {
        const parsed = JSON.parse(raw);
        const queue = [parsed];
        while (queue.length && !headline) {
          const node = queue.shift();
          if (!node) continue;
          if (Array.isArray(node)) {
            queue.push(...node);
            continue;
          }
          if (typeof node !== 'object') continue;
          if (typeof node.headline === 'string' && normalize(node.headline).length >= 10) {
            headline = normalize(node.headline);
            break;
          }
          if (node['@graph']) queue.push(node['@graph']);
          if (node.mainEntity) queue.push(node.mainEntity);
          if (node.itemListElement) queue.push(node.itemListElement);
        }
      } catch (_) {}
    });
    return headline;
  };

  const classifyPageType = () => {
    const jsonLdTypes = new Set();
    document.querySelectorAll('script[type="application/ld+json"]').forEach((el) => {
      const raw = (el.textContent || '').trim();
      if (!raw) return;
      try {
        collectTypes(JSON.parse(raw), jsonLdTypes);
      } catch (_) {}
    });

    const hasLiveType = Array.from(jsonLdTypes).some((t) => t.includes('liveblog'));
    const hasListingType = Array.from(jsonLdTypes).some((t) =>
      t.includes('itemlist') || t.includes('collectionpage')
    );
    const hasArticleType = Array.from(jsonLdTypes).some((t) =>
      t.includes('newsarticle') || t.includes('article') || t.includes('reportagenewsarticle')
    );

    const bodyText = normalize(document.body?.innerText || '');
    const allAnchors = Array.from(document.querySelectorAll('a'));
    const totalAnchorText = allAnchors.reduce((sum, a) => sum + normalize(a.innerText || a.textContent || '').length, 0);
    const linkDensity = totalAnchorText / Math.max(bodyText.length, 1);

    const headlineAnchors = Array.from(document.querySelectorAll(
      'article h2 a, article h3 a, [class*="headline"] a, [class*="story"] a, [class*="card"] h2 a, [class*="card"] h3 a'
    )).filter((a) => normalize(a.innerText || a.textContent || '').length >= 16);

    const shortHeadlineAnchors = headlineAnchors.filter(
      (a) => normalize(a.innerText || a.textContent || '').split(/\\s+/).filter(Boolean).length <= 14
    );
    const timestampNodes = document.querySelectorAll(
      'time,[datetime],[class*="timestamp"],[class*="updated"],[class*="time"],[id*="time"]'
    ).length;
    const updateMentions = (bodyText.match(/updated|live|minute|min ago|আপডেট|হালনাগাদ|লাইভ/gi) || []).length;
    const paragraphCount = document.querySelectorAll('article p, main p, p').length;
    const h1Text = normalize(document.querySelector('h1')?.innerText || '');

    const liveSignal = hasLiveType ||
      ((timestampNodes >= 8 || updateMentions >= 6) && headlineAnchors.length >= 5 && linkDensity >= 0.16);
    const listingSignal = hasListingType ||
      (headlineAnchors.length >= 8 && shortHeadlineAnchors.length >= 6 && linkDensity >= 0.18);
    const articleSignal = hasArticleType || (h1Text.length >= 12 && paragraphCount >= 3 && linkDensity < 0.45);

    if (liveSignal) return { pageType: 'live_feed', qualityScore: 0.96 };
    if (listingSignal) return { pageType: 'listing', qualityScore: 0.93 };
    if (articleSignal) return { pageType: 'article', qualityScore: 0.84 };
    if (h1Text.length >= 10 && paragraphCount >= 2) {
      return { pageType: 'article', qualityScore: 0.64 };
    }
    return { pageType: 'unknown', qualityScore: 0.35 };
  };

  const baseSelectors = [
    'script', 'style', 'nav', 'footer', 'aside', 'noscript', 'header',
    'form', 'button', 'svg', 'canvas', '.ads', '.ad', '.advertisement',
    '.advert', '.promo', '.sponsored', '.social-share', '.share-tools',
    '.newsletter', '.comments', '.comment-section', '.cookie-banner',
    '.consent', '[role="navigation"]', '[role="complementary"]',
    '[class*="overlay"]', '[class*="popup"]', '[id*="overlay"]', '[id*="popup"]',
    '[id*="taboola"]', '[id*="outbrain"]'
  ];
  const strictSelectors = [
    '.related', '.related-posts', '.related-news', '.recommended',
    '.trending', '.most-popular', '.most-read', '.also-read',
    '.more-news', '.similar-news', '.story-list'
  ];
  const selectorsToRemove = STRICT_MODE
    ? baseSelectors.concat(strictSelectors)
    : baseSelectors.concat(['.related', '.recommended', '.trending']);

  if (hostAdapter?.removeSelectors) {
    hostAdapter.removeSelectors.forEach((selector) => selectorsToRemove.push(selector));
  }

  const noiseMarkerPattern = /(related|recommend|trending|popular|comment|share|newsletter|subscribe|more-news|also-read|you-may-like|আরও পড়ুন|সম্পর্কিত|সংশ্লিষ্ট|লাইভ আপডেট)/i;
  const noisyLeadPattern = /^(read more|also read|related news|recommended|trending|আরও পড়ুন|সম্পর্কিত|সংশ্লিষ্ট|লাইভ আপডেট)/i;

  const cleanup = (root) => {
    if (!root || !root.querySelectorAll) return;
    selectorsToRemove.forEach((selector) => {
      root.querySelectorAll(selector).forEach((el) => el.remove());
    });
    root.querySelectorAll('[class*="ad-"],[id*="ad-"],[class*="sponsor"],[id*="sponsor"]').forEach((el) => el.remove());
    root.querySelectorAll('section,div,aside,ul,ol,header').forEach((el) => {
      const text = normalize(el.innerText || el.textContent || '');
      if (!text || text.length < 20) return;
      const marker = String((el.className || '') + ' ' + (el.id || '') + ' ' + (el.getAttribute('aria-label') || '')).toLowerCase();
      const anchors = Array.from(el.querySelectorAll('a'));
      const anchorCount = anchors.length;
      const shortAnchors = anchors.filter((a) => normalize(a.innerText || '').split(/\\s+/).filter(Boolean).length <= 9).length;
      const anchorTextLen = anchors.reduce((sum, a) => sum + normalize(a.innerText || '').length, 0);
      const linkDensity = anchorTextLen / Math.max(text.length, 1);
      const listItemCount = el.querySelectorAll('li').length;
      const words = text.split(/\\s+/).filter(Boolean).length;
      const headlineLike = !/[.!?।]/.test(text) && words <= 18;
      const repeatedHeadlineBlock = headlineLike && (anchorCount >= 3 || listItemCount >= 3);
      const hasNoiseMarker = noiseMarkerPattern.test(marker);
      const hasNoisyLead = noisyLeadPattern.test(text);
      if ((STRICT_MODE && repeatedHeadlineBlock) ||
          (STRICT_MODE && anchorCount >= 3 && shortAnchors >= 3 && linkDensity >= 0.45) ||
          (!STRICT_MODE && anchorCount >= 4 && shortAnchors >= 3 && linkDensity >= 0.68) ||
          hasNoiseMarker ||
          (STRICT_MODE && hasNoisyLead && text.length < 220 && !/[.!?।]/.test(text))) {
        el.remove();
      }
    });
  };

  const scoreCandidate = (node) => {
    if (!node) return -1;
    const text = normalize(node.innerText || node.textContent || '');
    if (text.length < 180) return -1;
    const pCount = node.querySelectorAll ? node.querySelectorAll('p').length : 0;
    const links = node.querySelectorAll ? Array.from(node.querySelectorAll('a')) : [];
    const shortAnchors = links.filter((a) => normalize(a.innerText).split(/\\s+/).filter(Boolean).length <= 9).length;
    const listItems = node.querySelectorAll ? node.querySelectorAll('li').length : 0;
    const linkTextLen = links.reduce((sum, a) => sum + normalize(a.innerText).length, 0);
    const linkDensity = linkTextLen / Math.max(text.length, 1);
    const marker = String((node.className || '') + ' ' + (node.id || '')).toLowerCase();
    const markerPenalty = noiseMarkerPattern.test(marker) ? (STRICT_MODE ? 540 : 280) : 0;
    const densityPenalty = Math.round(linkDensity * (STRICT_MODE ? 1320 : 860));
    const shortAnchorPenalty = shortAnchors * (STRICT_MODE ? 82 : 44);
    const listPenalty = listItems * (STRICT_MODE ? 38 : 18);
    return text.length + (pCount * 145) - densityPenalty - shortAnchorPenalty - listPenalty - markerPenalty;
  };

  const collectRootCandidates = () => {
    const selectors = [
      'article',
      'main',
      '[role="main"]',
      '[itemprop*="articleBody"]',
      '[class*="article"]',
      '[class*="story"]',
      '[class*="content"]'
    ];
    if (hostAdapter?.rootSelectors) {
      selectors.unshift(...hostAdapter.rootSelectors);
    }
    const seen = new Set();
    const result = [];
    selectors.forEach((selector) => {
      document.querySelectorAll(selector).forEach((el) => {
        if (!el || seen.has(el)) return;
        seen.add(el);
        result.push(el);
      });
    });
    return result;
  };

  const resolveTitle = (articleRoot, siteName) => {
    const candidates = [];
    const addCandidate = (value, source) => {
      const text = normalize(value);
      if (!text || text.length < 6) return;
      candidates.push({ text, source });
    };

    addCandidate(TITLE_HINT, 'hint');
    addCandidate(document.querySelector('meta[property="og:title"]')?.content, 'meta_og');
    addCandidate(document.querySelector('meta[name="twitter:title"]')?.content, 'meta_twitter');
    addCandidate(extractJsonLdHeadline(), 'jsonld');

    if (hostAdapter?.titleSelectors) {
      hostAdapter.titleSelectors.forEach((selector) => {
        if (selector.startsWith('meta[')) {
          addCandidate(document.querySelector(selector)?.content, 'h1');
        } else {
          addCandidate(document.querySelector(selector)?.innerText, 'h1');
        }
      });
    }
    addCandidate(document.querySelector('h1')?.innerText, 'h1');

    const docTitle = normalize(document.title || '');
    if (docTitle) {
      addCandidate(docTitle, 'document_title');
      docTitle.split(/\\s[-|–—]\\s/).forEach((part) => addCandidate(part, 'document_title'));
    }

    const deduped = [];
    const seenComparable = new Set();
    candidates.forEach((candidate) => {
      const comparable = normalizeComparable(candidate.text);
      if (!comparable || seenComparable.has(comparable)) return;
      seenComparable.add(comparable);
      deduped.push(candidate);
    });

    const rootTextSample = normalize(articleRoot?.innerText || articleRoot?.textContent || '').slice(0, 1600).toLowerCase();
    const scoreTitle = (candidate) => {
      const text = candidate.text;
      const words = text.split(/\\s+/).filter(Boolean).length;
      const hasPunctuation = /[,;:!?।]/.test(text);
      const hasDelimiter = /\\s[-|–—]\\s/.test(text);
      const comparable = normalizeComparable(text);
      let score = Math.min(text.length, 180);
      if (words >= 4 && words <= 24) score += 42;
      if (words <= 2) score -= 46;
      if (words <= 3 && !hasPunctuation) score -= 38;
      if (hasPunctuation) score += 10;
      if (hasDelimiter) score -= 28;
      score += sourceBonuses[candidate.source] || 0;
      if (looksLikeBrandTitle(text, siteName)) score -= 240;
      if (rootTextSample && text.length >= 10 && rootTextSample.includes(text.toLowerCase().slice(0, Math.min(text.length, 42)))) {
        score += 35;
      }
      if (comparable === hostComparable) score -= 120;
      return score;
    };

    let best = null;
    let bestScore = -10000;
    deduped.forEach((candidate) => {
      const score = scoreTitle(candidate);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    });

    if (!best) {
      return { title: normalize(TITLE_HINT || document.title || 'Reader mode'), source: 'fallback' };
    }
    return { title: best.text, source: best.source || 'fallback' };
  };

  try {
    if (typeof Readability === 'undefined') {
      $readabilityScript
    }

    const pageMeta = classifyPageType();
    if (pageMeta.pageType !== 'article') {
      return JSON.stringify({
        pageType: pageMeta.pageType,
        titleSource: normalize(TITLE_HINT).length > 0 ? 'hint' : 'fallback',
        qualityScore: pageMeta.qualityScore,
        failureCode: 'reader_unsupported_page_type'
      });
    }

    let article = null;
    let workingRoot = null;
    if (typeof Readability !== 'undefined') {
      const clone = document.cloneNode(true);
      cleanup(clone);
      article = new Readability(clone).parse();
      if (article && article.content) {
        const holder = document.createElement('div');
        holder.innerHTML = article.content;
        workingRoot = holder;
        article.textContent = normalize(holder.innerText || holder.textContent || article.textContent || '');
      }
      if (article && (!article.textContent || article.textContent.length < (STRICT_MODE ? 260 : 180))) {
        article = null;
      }
    }

    if (!article) {
      const candidates = collectRootCandidates();
      let bestNode = null;
      let bestScore = -1;
      candidates.forEach((candidate) => {
        const clone = candidate.cloneNode(true);
        cleanup(clone);
        const score = scoreCandidate(clone);
        if (score > bestScore) {
          bestScore = score;
          bestNode = clone;
        }
      });
      if (!bestNode) return "null";
      const textContent = normalize(bestNode.innerText || bestNode.textContent || '');
      if (textContent.length < (STRICT_MODE ? 220 : 160)) return "null";
      workingRoot = bestNode;
      const titlePick = resolveTitle(bestNode, '');
      article = {
        title: titlePick.title,
        titleSource: titlePick.source,
        content: bestNode.innerHTML || '',
        textContent,
        excerpt: textContent.substring(0, Math.min(textContent.length, 280)),
        byline: '',
        siteName: '',
        length: textContent.length
      };
    } else {
      const titlePick = resolveTitle(workingRoot, article.siteName || '');
      article.title = titlePick.title || normalize(article.title || '');
      article.titleSource = titlePick.source || 'fallback';
      article.content = article.content || '';
      article.textContent = normalize(article.textContent || '');
      article.length = article.textContent.length;
      article.excerpt = normalize(article.excerpt || article.textContent.substring(0, Math.min(article.textContent.length, 280)));
    }

    const contaminationPenalty = (() => {
      const text = normalize(workingRoot?.innerText || workingRoot?.textContent || article.textContent || '');
      if (!text) return 0.35;
      const anchors = Array.from((workingRoot || document).querySelectorAll('a'));
      const anchorTextLen = anchors.reduce((sum, a) => sum + normalize(a.innerText || '').length, 0);
      const density = anchorTextLen / Math.max(text.length, 1);
      const headlineClusters = (text.match(/(^|\\n)([^\\n.!?।]{12,120})(?=\\n|\$)/g) || []).length;
      let penalty = density * 0.40;
      if (headlineClusters > 8) penalty += 0.18;
      return penalty;
    })();

    article.pageType = 'article';
    article.failureCode = null;
    article.qualityScore = Math.max(0.05, Math.min(1, pageMeta.qualityScore - contaminationPenalty));
    article.titleSource = article.titleSource || 'fallback';
    article.url = URL_HINT || location.href;

    return JSON.stringify(article);
  } catch(e) {
    return JSON.stringify({error: e.toString()});
  }
})();
''';
  }

  Future<ReaderHtmlProcessOutput?> _processArticleForTts({
    required ReaderArticle article,
    required bool strictMode,
  }) async {
    try {
      return await compute(
        processReaderHtmlForTtsIsolate,
        ReaderHtmlProcessInput(
          content: article.content,
          articleTitle: article.title,
          noiseTokens: _kNoiseTokens,
          noisyPrefixes: _kNoisyPrefixes,
          strictMode: strictMode,
        ),
      ).timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint(
        '[ReaderController] ${strictMode ? 'strict' : 'soft'} HTML post-processing timed out.',
      );
      return null;
    }
  }

  void _logExtractionTelemetry({
    required String selectedPass,
    required ReaderHtmlProcessOutput processed,
    required ReaderExtractionMeta meta,
  }) {
    debugPrint(
      '[ReaderController] extraction pass=$selectedPass '
      '| pageType=${meta.pageType.wireValue} '
      '| titleSource=${meta.titleSource.wireValue} '
      '| score=${meta.qualityScore.toStringAsFixed(2)} '
      '${meta.failureCode == null ? '' : '| failure=${meta.failureCode} '}'
      '| chunks=${processed.chunks.length} '
      '| len=${processed.contentLength} '
      '| contamination=${processed.contaminationScore.toStringAsFixed(2)} '
      '| removed=${processed.removedElements} '
      '| linkHeavy=${processed.linkHeavyRemoved} '
      '| headlineList=${processed.headlineListRemoved}',
    );
  }

  Future<Object?> _extractContentWithLightweightFallback() async {
    if (_webViewController == null) return null;
    return _webViewController!
        .evaluateJavascript(
          source: '''
(() => {
  const normalize = (value) => String(value || '')
    .replace(/\\u00a0/g, ' ')
    .replace(/[ \\t]+/g, ' ')
    .replace(/\\n{3,}/g, '\\n\\n')
    .trim();
  try {
    const root =
      document.querySelector('article') ||
      document.querySelector('main') ||
      document.body;
    const textContent = normalize(root?.innerText || root?.textContent || '');
    if (textContent.length < 120) return "null";

    const title = normalize(document.title || '');
    const lines = textContent
      .split(/\\n+/)
      .map((line) => normalize(line))
      .filter((line) => line.length > 12)
      .slice(0, 120);
    const content = lines.map((line) => '<p>' + line + '</p>').join('');

    return JSON.stringify({
      title,
      titleSource: 'document_title',
      content,
      textContent,
      excerpt: textContent.substring(0, Math.min(textContent.length, 280)),
      byline: '',
      siteName: location?.hostname || '',
      length: textContent.length,
      pageType: 'article',
      qualityScore: 0.58,
      failureCode: null
    });
  } catch (e) {
    return JSON.stringify({error: e.toString()});
  }
})();
''',
        )
        .timeout(const Duration(seconds: 4), onTimeout: () => 'null');
  }

  String _resolvePreferredTitle({
    required String extractedTitle,
    required String? titleHint,
    String? siteName,
    String? sourceUrl,
  }) => resolvePreferredReaderTitle(
    extractedTitle: extractedTitle,
    titleHint: titleHint,
    siteName: siteName,
    sourceUrl: sourceUrl,
  );

  ReaderArticle _readerArticleFromPayload(
    Map<String, dynamic> payload, {
    String? titleHint,
    String? urlHint,
  }) {
    final dynamic textRaw = payload['textContent'] ?? payload['text'] ?? '';
    final String textContent = _compactWhitespace(textRaw.toString());

    var content = (payload['content'] as String? ?? '').trim();
    if (content.isEmpty && textContent.isNotEmpty) {
      content = _plainTextToReaderHtml(textContent);
    }

    var titleCandidate = _resolvePreferredTitle(
      extractedTitle: (payload['title'] as String? ?? '').trim(),
      titleHint: titleHint,
      siteName: (payload['siteName'] ?? '').toString().trim(),
      sourceUrl: (payload['url'] ?? urlHint ?? '').toString().trim(),
    );
    final titleComparable = _normalizedComparable(titleCandidate);
    final filteredText = textContent
        .split(RegExp(r'\n+'))
        .map(_compactWhitespace)
        .where((line) {
          if (line.isEmpty) return false;
          final comparable = _normalizedComparable(line);
          if (comparable.isEmpty || titleComparable.isEmpty) return true;
          return !(comparable == titleComparable ||
              comparable.contains(titleComparable));
        })
        .join('\n');
    var decontaminatedText = _stripLeadingReaderNoise(filteredText);
    titleCandidate = _repairReaderTitle(
      currentTitle: titleCandidate,
      bodyText: decontaminatedText,
      siteName: (payload['siteName'] ?? '').toString().trim(),
      sourceUrl: (payload['url'] ?? urlHint ?? '').toString().trim(),
    );
    decontaminatedText = _stripLeadingDuplicateTitle(
      decontaminatedText,
      titleCandidate,
    );

    final excerptCandidate = (payload['excerpt'] as String? ?? '').trim();
    final excerpt = excerptCandidate.isNotEmpty
        ? excerptCandidate
        : _excerptFromText(decontaminatedText);

    return ReaderArticle(
      title: titleCandidate,
      content: content,
      textContent: decontaminatedText,
      excerpt: excerpt,
      length: (payload['length'] as num?)?.toInt() ?? decontaminatedText.length,
    );
  }

  String _repairReaderTitle({
    required String currentTitle,
    required String bodyText,
    String? siteName,
    String? sourceUrl,
  }) {
    final normalizedCurrent = _compactWhitespace(currentTitle);
    final bodyCandidate = _extractBodyLeadingTitleCandidate(bodyText);
    if (bodyCandidate == null) {
      return normalizedCurrent.isEmpty ? 'Reader mode' : normalizedCurrent;
    }

    final currentBranding = _isLikelyBrandingTitle(
      normalizedCurrent,
      siteName: siteName,
      sourceUrl: sourceUrl,
    );
    final bodyBranding = _isLikelyBrandingTitle(
      bodyCandidate,
      siteName: siteName,
      sourceUrl: sourceUrl,
    );
    final currentScore =
        _titleQualityScore(normalizedCurrent) - (currentBranding ? 140 : 0);
    final bodyScore =
        _titleQualityScore(bodyCandidate) - (bodyBranding ? 140 : 0);
    final currentWords = normalizedCurrent
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    final shouldReplace =
        normalizedCurrent.isEmpty ||
        (currentBranding && !bodyBranding) ||
        currentWords <= 2 ||
        bodyScore >= currentScore + 24;

    if (!shouldReplace) {
      return normalizedCurrent;
    }
    return bodyCandidate;
  }

  String? _extractBodyLeadingTitleCandidate(String bodyText) {
    final lines = bodyText
        .split(RegExp(r'\n+'))
        .map(_compactWhitespace)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return null;

    for (final line in lines.take(6)) {
      final lower = line.toLowerCase();
      if (_kNoisyPrefixes.any(lower.startsWith) ||
          _kNoiseTokens.any(lower.contains) ||
          _kMetadataLinePattern.hasMatch(lower) ||
          _kUrlPattern.hasMatch(lower)) {
        continue;
      }
      final words = line
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      if (words < 4 || words > 26) continue;
      if (line.length < 20 || line.length > 180) continue;
      if (!RegExp(r'[!?,:;।]').hasMatch(line) && words < 6) continue;
      return line;
    }
    return null;
  }

  String _stripLeadingDuplicateTitle(String bodyText, String title) {
    final titleComparable = _normalizedComparable(title);
    if (titleComparable.isEmpty) return bodyText;
    final lines = bodyText
        .split(RegExp(r'\n+'))
        .map(_compactWhitespace)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return bodyText;

    var start = 0;
    while (start < lines.length) {
      final comparable = _normalizedComparable(lines[start]);
      if (comparable.isEmpty) {
        start++;
        continue;
      }
      final duplicated =
          comparable == titleComparable ||
          comparable.contains(titleComparable) ||
          titleComparable.contains(comparable);
      if (!duplicated || lines[start].length > title.length + 36) {
        break;
      }
      start++;
    }

    if (start <= 0) return bodyText;
    if (start >= lines.length) return '';
    return lines.sublist(start).join('\n');
  }

  String _stripLeadingReaderNoise(String text) {
    final lines = text
        .split(RegExp(r'\n+'))
        .map(_compactWhitespace)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return text;

    bool isLikelyNoiseLine(String candidate) {
      final lower = candidate.toLowerCase();
      final words = candidate
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      final hasSentencePunctuation = RegExp(r'[.!?।]').hasMatch(candidate);
      final headlineLike = !hasSentencePunctuation && words <= 14;
      final hasNoisePrefix =
          _kNoisyPrefixes.any(lower.startsWith) ||
          lower.startsWith('আরও পড়ুন') ||
          lower.startsWith('সম্পর্কিত') ||
          lower.startsWith('related') ||
          lower.startsWith('recommended');
      final hasNoiseToken = _kNoiseTokens.any(lower.contains);
      if (hasNoisePrefix) return true;
      if (hasNoiseToken &&
          (!hasSentencePunctuation || words <= 18 || candidate.length < 90)) {
        return true;
      }
      if (headlineLike && words <= 5 && candidate.length < 56) return true;
      return false;
    }

    var firstBodyIndex = 0;
    var foundBody = false;
    for (var i = 0; i < lines.length; i++) {
      final candidate = lines[i];
      if (!isLikelyNoiseLine(candidate)) {
        firstBodyIndex = i;
        foundBody = true;
        break;
      }
      firstBodyIndex = i + 1;
    }

    if (!foundBody) {
      // Entire extraction looks like a headline dump; force fallback path.
      return '';
    }
    if (firstBodyIndex <= 0 || firstBodyIndex >= lines.length) {
      return lines.join('\n');
    }

    final bodyLines = lines
        .sublist(firstBodyIndex)
        .where((line) {
          final lower = line.toLowerCase();
          final noisyMarker =
              _kNoisyPrefixes.any(lower.startsWith) ||
              _kNoiseTokens.any(lower.contains) ||
              _kMetadataLinePattern.hasMatch(lower);
          if (!noisyMarker) return true;
          final hasSentencePunctuation = RegExp(r'[.!?।]').hasMatch(line);
          return hasSentencePunctuation && line.length > 70;
        })
        .toList(growable: false);

    if (bodyLines.isEmpty) {
      return '';
    }
    return bodyLines.join('\n');
  }

  String _plainTextToReaderHtml(String text) {
    final escaper = const HtmlEscape();
    final paragraphs = text
        .split(RegExp(r'\n+'))
        .map(_compactWhitespace)
        .where((line) => line.length >= 12)
        .take(120)
        .map((line) => '<p>${escaper.convert(line)}</p>')
        .toList(growable: false);

    if (paragraphs.isEmpty) {
      return '<p>${escaper.convert(text)}</p>';
    }
    return paragraphs.join('\n');
  }

  double _scoreChunkBodyQuality(List<TtsChunk> chunks, String bodyText) {
    if (chunks.isEmpty) return 0;
    final sample = chunks.take(24).toList(growable: false);
    if (sample.isEmpty) return 0;

    var punctuated = 0;
    var longEnough = 0;
    var noisy = 0;
    for (final chunk in sample) {
      final line = _compactWhitespace(chunk.text);
      if (line.isEmpty) continue;
      final hasPunctuation = RegExp(r'[.!?।]').hasMatch(line);
      final words = line
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      if (hasPunctuation) punctuated++;
      if (line.length >= 45 && words >= 8) longEnough++;
      final lower = line.toLowerCase();
      final hasNoise =
          _kNoisyPrefixes.any(lower.startsWith) ||
          _kNoiseTokens.any(lower.contains) ||
          _kMetadataLinePattern.hasMatch(lower);
      if (hasNoise) noisy++;
    }
    final total = sample.length;
    final punctuationRatio = punctuated / total;
    final longRatio = longEnough / total;
    final noisyRatio = noisy / total;
    final bodyLengthBonus = (bodyText.length / 1200).clamp(0.0, 1.0) * 0.22;

    final score =
        (punctuationRatio * 0.42) +
        (longRatio * 0.36) +
        ((1 - noisyRatio) * 0.22) +
        bodyLengthBonus;
    return score.clamp(0.0, 1.0);
  }

  List<TtsChunk> _buildFallbackChunks(String text) {
    final normalized = text
        .split(RegExp(r'\n+'))
        .map(_compactWhitespace)
        .where((line) {
          if (line.isEmpty) return false;
          final lower = line.toLowerCase();
          final noisyPrefix = _kNoisyPrefixes.any(lower.startsWith);
          final noisyToken = _kNoiseTokens.any(lower.contains);
          final metadataLike = _kMetadataLinePattern.hasMatch(lower);
          if (!(noisyPrefix || noisyToken || metadataLike)) return true;
          final hasSentencePunctuation = RegExp(r'[.!?।]').hasMatch(line);
          return hasSentencePunctuation && line.length > 80;
        })
        .join(' ');
    if (normalized.isEmpty) return const <TtsChunk>[];
    final sentences = normalized
        .split(RegExp(r'(?<=[.!?।])\s+'))
        .map(_compactWhitespace)
        .where((part) {
          if (part.length <= 1) return false;
          final lower = part.toLowerCase();
          final noisyPrefix = _kNoisyPrefixes.any(lower.startsWith);
          final noisyToken = _kNoiseTokens.any(lower.contains);
          final metadataLike = _kMetadataLinePattern.hasMatch(lower);
          if (!(noisyPrefix || noisyToken || metadataLike)) return true;
          return part.length > 90 && RegExp(r'[.!?।]').hasMatch(part);
        })
        .take(180);

    var index = 0;
    return sentences
        .map(
          (sentence) => TtsChunk(
            index: index++,
            text: sentence,
            estimatedDuration: Duration(milliseconds: sentence.length * 40),
          ),
        )
        .toList(growable: false);
  }

  String? _excerptFromText(String text) {
    if (text.isEmpty) return null;
    final limit = text.length > 280 ? 280 : text.length;
    return text.substring(0, limit);
  }

  // ── TTS controls ──────────────────────────────
  Future<void> playFullArticle() async {
    if (state.chunks.isEmpty) return;
    final ttsController = ref.read(ttsControllerProvider.notifier);
    await ttsController.playChunks(state.chunks);
  }

  Future<void> seekToChunk(int chunkIndex) async {
    if (chunkIndex < 0 || chunkIndex >= state.chunks.length) return;
    final ttsController = ref.read(ttsControllerProvider.notifier);
    await ttsController.seekToChunk(chunkIndex);
    if (state.currentChunkIndex != chunkIndex) {
      state = state.copyWith(currentChunkIndex: chunkIndex);
    }
  }

  void pauseTts() => ref.read(ttsControllerProvider.notifier).pause();

  void resumeTts() => ref.read(ttsControllerProvider.notifier).resume();

  void stopTts() {
    try {
      ref.read(ttsControllerProvider.notifier).stop();
    } catch (_) {
      // Provider may already be disposed during teardown.
    }
    if (state.currentChunkIndex != -1) {
      state = state.copyWith(currentChunkIndex: -1);
    }
  }

  // ── Personalisation – debounced disk writes ───
  Future<void> _loadSettings() async {
    // Parallel fetch – avoids sequential await round-trips.
    final results = await Future.wait([
      _repository.getReaderFontSize(),
      _repository.getReaderFontFamily(),
      _repository.getReaderTheme(),
    ]);

    final fontSizeResult = results[0] as dynamic;
    final fontFamilyResult = results[1] as dynamic;
    final themeResult = results[2] as dynamic;

    state = state.copyWith(
      fontSize: fontSizeResult.fold((_) => 16.0, (r) => r as double),
      fontFamily: fontFamilyResult.fold(
        (_) => ReaderFontFamily.serif,
        (r) => ReaderFontFamily.values[r as int],
      ),
      readerTheme: themeResult.fold(
        (_) => ReaderTheme.system,
        (r) => ReaderTheme.values[r as int],
      ),
    );
  }

  Future<void> setFontSize(double size) async {
    if (state.fontSize == size) return;
    state = state.copyWith(fontSize: size);
    _fontSizeDebounce?.cancel();
    _fontSizeDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _repository.setReaderFontSize(size),
    );
  }

  Future<void> setFontFamily(ReaderFontFamily family) async {
    if (state.fontFamily == family) return;
    state = state.copyWith(fontFamily: family);
    _fontFamilyDebounce?.cancel();
    _fontFamilyDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _repository.setReaderFontFamily(family.index),
    );
  }

  Future<void> setReaderTheme(ReaderTheme theme) async {
    if (state.readerTheme == theme) return;
    state = state.copyWith(readerTheme: theme);
    _themeDebounce?.cancel();
    _themeDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _repository.setReaderTheme(theme.index),
    );
  }
}

// ─────────────────────────────────────────────
// PROVIDER
// autoDispose → frees memory when reader is closed
// ─────────────────────────────────────────────
final readerControllerProvider =
    StateNotifierProvider.autoDispose<ReaderController, ReaderState>(
      (ref) => ReaderController(ref),
    );
