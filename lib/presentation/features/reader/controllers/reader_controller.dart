import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../domain/entities/news_article.dart';
import '../../../../domain/repositories/news_repository.dart';
import '../../../../infrastructure/services/html/reader_html_parser.dart';
import '../models/reader_article.dart';
import '../models/reader_settings.dart';
import '../../../../core/tts/domain/entities/tts_chunk.dart';
import '../../../../core/tts/presentation/providers/tts_controller.dart';
import '../../../../core/di/providers.dart' show appNetworkServiceProvider, articleScraperServiceProvider;
import '../../../../domain/repositories/settings_repository.dart';
import '../../../providers/app_settings_providers.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
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
String _compactWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

String _normalizedComparable(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0980-\u09ff]+'), '');
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

  // In-flight extraction generation token.
  int _extractionGeneration = 0;
  String? _lastExtractedUrl;

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
    _cancelActiveExtraction();
    super.dispose();
  }

  // ── Web view ─────────────────────────────────
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  // ── Toggle ───────────────────────────────────
  Future<void> toggleReaderMode({
    String? urlHint,
    String? titleHint,
    bool allowPublisherFallback = false,
    String? rawHtmlHint,
  }) async {
    final normalizedUrl = (urlHint ?? '').trim();
    if (state.isReaderMode) {
      _cancelActiveExtraction();
      state = ReaderState(
        article: state.article,
        pageType: state.pageType,
        titleSource: state.titleSource,
        qualityScore: state.qualityScore,
        chunks: state.chunks,
        processedContent: state.processedContent,
        fontSize: state.fontSize,
        fontFamily: state.fontFamily,
        readerTheme: state.readerTheme,
      );
      stopTts();
    } else {
      final hasReusableArticle =
          state.article != null &&
          state.chunks.isNotEmpty &&
          normalizedUrl.isNotEmpty &&
          normalizedUrl == _lastExtractedUrl;
      if (hasReusableArticle) {
        // Stop any in-flight TTS from the previous reader session and reset
        // the chunk position so the subscription listener doesn't carry over
        // stale indices into the new session.
        stopTts();
        state = ReaderState(
          isReaderMode: true,
          article: state.article,
          pageType: state.pageType,
          titleSource: state.titleSource,
          qualityScore: state.qualityScore,
          chunks: state.chunks,
          processedContent: state.processedContent,
          fontSize: state.fontSize,
          fontFamily: state.fontFamily,
          readerTheme: state.readerTheme,
        );
        return;
      }
      await extractContent(
        urlHint: urlHint,
        titleHint: titleHint,
        allowPublisherFallback: allowPublisherFallback,
        rawHtmlHint: rawHtmlHint,
      );
    }
  }

  void clearState() {
    _lastExtractedUrl = null;
    state = ReaderState(
      isReaderMode: state.isReaderMode,
      isLoading: true,
      fontSize: state.fontSize,
      fontFamily: state.fontFamily,
      readerTheme: state.readerTheme,
    );
  }

  void markExtractionFailure({required String message, String? errorCode}) {
    _lastExtractedUrl = null;
    state = state.copyWith(
      isLoading: false,
      errorMessage: message,
      errorCode: errorCode ?? 'reader_load_failure',
      pageType: ReaderPageType.unknown,
      titleSource: ReaderTitleSource.fallback,
      qualityScore: 0,
    );
  }

  void invalidateForPageChange({bool keepReaderMode = false}) {
    _cancelActiveExtraction();
    _lastExtractedUrl = null;
    state = ReaderState(
      isReaderMode: keepReaderMode,
      fontSize: state.fontSize,
      fontFamily: state.fontFamily,
      readerTheme: state.readerTheme,
    );
  }

  // ── Content extraction ───────────────────────
  Future<void> extractContent({
    String? urlHint,
    String? titleHint,
    bool allowPublisherFallback = false,
    String? rawHtmlHint,
  }) async {
    final extractionToken = _beginExtraction();
    if (_webViewController == null) {
      debugPrint(
        '[ReaderController] extractContent aborted: webViewController=null',
      );
      state = state.copyWith(
        isReaderMode: false,
        isLoading: false,
        errorMessage:
            'Page is still loading. Please wait and try Reader mode again.',
        errorCode: 'webview_not_ready',
      );
      return;
    }

    // Check cache first.
    if (urlHint != null && _cache.contains(urlHint)) {
      final cached = _cache.get(urlHint)!;
      debugPrint(
        '[ReaderController] cache hit '
        '| url=$urlHint '
        '| chunks=${cached.chunks.length} '
        '| textLen=${cached.article.textContent.length}',
      );
      _lastExtractedUrl = urlHint.trim();
      state = state.copyWith(
        isReaderMode: true,
        isLoading: false,
        article: cached.article,
        processedContent: cached.processedContent,
        chunks: cached.chunks,
        pageType: ReaderPageType.article,
        titleSource: ReaderTitleSource.fallback,
        qualityScore: 1.0,
      );
      return;
    }

    // Clear old state before starting new extraction to avoid ghosting.
    clearState();
    ReaderExtractionMeta? unsupportedMeta;
    final extractionUrl = (urlHint ?? '').trim();
    final likelyArticleUrl = looksLikeReaderArticleUrl(extractionUrl);
    final trustedArticleHost = _isTrustedReaderFallbackHost(extractionUrl);
    var allowUnsupportedAttempt = false;
    var allowUnsupportedRecovery = false;
    debugPrint(
      '[ReaderController] extractContent start '
      '| url=$extractionUrl '
      '| titleHint=${(titleHint ?? '').trim()} '
      '| likelyArticleUrl=$likelyArticleUrl '
      '| trustedHost=$trustedArticleHost '
      '| publisherFallback=$allowPublisherFallback',
    );

    try {
      final script = await _loadReadabilityScript();
      if (script == null) {
        debugPrint(
          '[ReaderController] extractContent script missing (readability.js).',
        );
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Could not load Readability script.',
          errorCode: 'script_missing',
        );
        return;
      }
      debugPrint('[ReaderController] readability script loaded.');
      if (_shouldAbortExtraction(extractionToken)) return;

      final preflightMeta = await _runPageClassification(
        urlHint: urlHint,
        titleHint: titleHint,
      );
      if (_shouldAbortExtraction(extractionToken)) return;
      allowUnsupportedAttempt = shouldAttemptUnsupportedReaderExtraction(
        allowPublisherFallback: allowPublisherFallback,
        likelyArticleUrl: likelyArticleUrl,
        classifiedPageType: preflightMeta?.pageType,
      );
      allowUnsupportedRecovery = shouldAllowUnsupportedReaderRecovery(
        allowPublisherFallback: allowPublisherFallback,
        likelyArticleUrl: likelyArticleUrl,
        trustedArticleHost: trustedArticleHost,
        classifiedPageType: preflightMeta?.pageType,
      );
      debugPrint(
        '[ReaderController] preflight '
        '| pageType=${preflightMeta?.pageType.wireValue ?? 'null'} '
        '| score=${preflightMeta?.qualityScore.toStringAsFixed(2) ?? 'null'} '
        '| failure=${preflightMeta?.failureCode ?? 'none'} '
        '| allowUnsupportedAttempt=$allowUnsupportedAttempt '
        '| allowUnsupportedRecovery=$allowUnsupportedRecovery',
      );
      if (preflightMeta != null && !preflightMeta.isSupportedArticle) {
        unsupportedMeta = preflightMeta;
        if (!allowUnsupportedAttempt && !allowUnsupportedRecovery) {
          _setUnsupportedPageState(preflightMeta);
          return;
        }
      }

      final strictPayload = await _runReadabilityExtractionPass(
        readabilityScript: script,
        strictMode: true,
        titleHint: titleHint,
        timeout: _adaptiveExtractionTimeout(strictMode: true, urlHint: urlHint),
        urlHint: urlHint,
        allowUnsupportedPageAttempt: allowUnsupportedAttempt,
      );
      if (_shouldAbortExtraction(extractionToken)) return;
      final strictMeta = ReaderExtractionMeta.fromPayload(strictPayload);
      if (strictPayload != null && !strictMeta.isSupportedArticle) {
        unsupportedMeta ??= strictMeta;
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
      debugPrint(
        '[ReaderController] strict pass '
        '| payload=${strictPayload == null ? 'null' : 'ok'} '
        '| pageType=${strictMeta.pageType.wireValue} '
        '| score=${strictMeta.qualityScore.toStringAsFixed(2)} '
        '| articleLen=${strictArticle?.textContent.length ?? 0} '
        '| chunks=${strictProcessed?.chunks.length ?? 0} '
        '| contentLen=${strictProcessed?.contentLength ?? 0}',
      );
      if (_shouldAbortExtraction(extractionToken)) return;

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
              allowUnsupportedPageAttempt: allowUnsupportedAttempt,
            )
          : null;
      if (_shouldAbortExtraction(extractionToken)) return;
      final softMeta = ReaderExtractionMeta.fromPayload(softPayload);
      if (softPayload != null && !softMeta.isSupportedArticle) {
        unsupportedMeta ??= softMeta;
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
      debugPrint(
        '[ReaderController] soft pass '
        '| payload=${softPayload == null ? 'null' : 'ok'} '
        '| pageType=${softMeta.pageType.wireValue} '
        '| score=${softMeta.qualityScore.toStringAsFixed(2)} '
        '| articleLen=${softArticle?.textContent.length ?? 0} '
        '| chunks=${softProcessed?.chunks.length ?? 0} '
        '| contentLen=${softProcessed?.contentLength ?? 0}',
      );
      if (_shouldAbortExtraction(extractionToken)) return;

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
      debugPrint(
        '[ReaderController] selected pass pre-fallback | selected=$selectedPass '
        '| articleLen=${article?.textContent.length ?? 0} '
        '| processedLen=${processed?.contentLength ?? 0}',
      );

      if ((article == null || processed == null) ||
          selectedPass == 'fallback') {
        Map<String, dynamic>? fallbackPayload;
        ReaderExtractionMeta fallbackMeta = const ReaderExtractionMeta(
          pageType: ReaderPageType.article,
          titleSource: ReaderTitleSource.fallback,
          qualityScore: 0,
        );
        if (article == null &&
            rawHtmlHint != null &&
            rawHtmlHint.trim().length >= 300) {
          final hintedArticle = _readerArticleFromStoredHtml(
            htmlContent: rawHtmlHint,
            titleHint: titleHint,
            urlHint: urlHint,
          );
          debugPrint(
            '[ReaderController] html-hint fallback '
            '| article=${hintedArticle == null ? 'null' : 'ok'} '
            '| textLen=${hintedArticle?.textContent.length ?? 0}',
          );
          if (hintedArticle != null) {
            article = hintedArticle;
            selectedPass = 'html_hint';
          }
        }

        if (article == null) {
          final lightweight = await _extractContentWithLightweightFallback();
          fallbackPayload = _decodeExtractionPayload(lightweight);
          fallbackMeta = ReaderExtractionMeta.fromPayload(fallbackPayload);
          debugPrint(
            '[ReaderController] lightweight fallback '
            '| payload=${fallbackPayload == null ? 'null' : 'ok'} '
            '| pageType=${fallbackMeta.pageType.wireValue} '
            '| score=${fallbackMeta.qualityScore.toStringAsFixed(2)}',
          );
          if (fallbackPayload != null && !fallbackMeta.isSupportedArticle) {
            unsupportedMeta ??= fallbackMeta;
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
          var bestEffortArticle = await _extractBestEffortReaderArticle(
            titleHint: titleHint,
            urlHint: urlHint,
          );
          if (allowPublisherFallback &&
              (bestEffortArticle == null ||
                  bestEffortArticle.textContent.length < 90)) {
            await Future<void>.delayed(const Duration(milliseconds: 550));
            final retryBestEffortArticle =
                await _extractBestEffortReaderArticle(
                  titleHint: titleHint,
                  urlHint: urlHint,
                );
            if (retryBestEffortArticle != null &&
                retryBestEffortArticle.textContent.length >
                    (bestEffortArticle?.textContent.length ?? 0)) {
              bestEffortArticle = retryBestEffortArticle;
            }
          }
          debugPrint(
            '[ReaderController] best-effort fallback '
            '| article=${bestEffortArticle == null ? 'null' : 'ok'} '
            '| textLen=${bestEffortArticle?.textContent.length ?? 0}',
          );
          if (bestEffortArticle != null) {
            article = bestEffortArticle;
          }
        }

        if (article == null &&
            extractionUrl.isNotEmpty &&
            ref
                .read(articleScraperServiceProvider)
                .canScrapeUrl(extractionUrl) &&
            (allowPublisherFallback ||
                likelyArticleUrl ||
                trustedArticleHost)) {
          final scrapedHtml = await ref
              .read(articleScraperServiceProvider)
              .extractArticleContent(extractionUrl)
              .timeout(const Duration(seconds: 8), onTimeout: () => null);
          final scrapedArticle = scrapedHtml == null
              ? null
              : _readerArticleFromStoredHtml(
                  htmlContent: scrapedHtml,
                  titleHint: titleHint,
                  urlHint: urlHint,
                );
          debugPrint(
            '[ReaderController] network-scrape fallback '
            '| html=${scrapedHtml == null ? 'null' : 'ok'} '
            '| article=${scrapedArticle == null ? 'null' : 'ok'} '
            '| textLen=${scrapedArticle?.textContent.length ?? 0}',
          );
          if (scrapedArticle != null) {
            article = scrapedArticle;
            selectedPass = 'network_scrape';
          }
        }

        if (article == null) {
          if (unsupportedMeta != null) {
            if (!allowUnsupportedRecovery) {
              _setUnsupportedPageState(unsupportedMeta);
              return;
            }
          }
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Page content could not be extracted.',
            errorCode: 'parse_fail',
          );
          debugPrint(
            '[ReaderController] parse_fail '
            '| unsupported=${unsupportedMeta?.pageType.wireValue ?? 'none'} '
            '| likelyArticleUrl=$likelyArticleUrl '
            '| trustedHost=$trustedArticleHost',
          );
          return;
        }

        final fallbackChunks = _buildFallbackChunks(article.textContent);
        final fallbackHtml = _plainTextToReaderHtml(article.textContent);
        final fallbackQualityScore = _scoreChunkBodyQuality(
          fallbackChunks,
          article.textContent,
        );
        final fallbackReadableBody = looksLikeReaderBodyText(
          article.textContent,
        );
        if (!passesReaderFallbackQualityGate(
          contentLength: article.textContent.length,
          chunkCount: fallbackChunks.length,
          qualityScore: fallbackQualityScore,
          likelyReadableBody: fallbackReadableBody,
          classifiedPageType: unsupportedMeta?.pageType,
          allowFeedLikeRecovery: allowPublisherFallback,
        )) {
          debugPrint(
            '[ReaderController] fallback quality gate failed '
            '| textLen=${article.textContent.length} '
            '| chunkCount=${fallbackChunks.length} '
            '| quality=${fallbackQualityScore.toStringAsFixed(2)} '
            '| readable=$fallbackReadableBody '
            '| unsupported=${unsupportedMeta?.pageType.wireValue ?? 'none'}',
          );
          final rescueChunks = fallbackChunks.isNotEmpty
              ? fallbackChunks
              : _buildEmergencyFallbackChunks(article.textContent);
          final rescueEligible =
              rescueChunks.isNotEmpty &&
              ((unsupportedMeta == null && fallbackReadableBody) ||
                  allowUnsupportedRecovery ||
                  article.textContent.length >= 180);
          if (!rescueEligible) {
            final emergencyArticle = await _extractBestEffortReaderArticle(
              titleHint: titleHint,
              urlHint: urlHint,
            );
            debugPrint(
              '[ReaderController] emergency best-effort '
              '| article=${emergencyArticle == null ? 'null' : 'ok'} '
              '| textLen=${emergencyArticle?.textContent.length ?? 0}',
            );
            final emergencyChunks = emergencyArticle == null
                ? const <TtsChunk>[]
                : _buildEmergencyFallbackChunks(emergencyArticle.textContent);
            if (emergencyArticle != null && emergencyChunks.isNotEmpty) {
              article = emergencyArticle;
              processed = ReaderHtmlProcessOutput(
                html: _plainTextToReaderHtml(article.textContent),
                chunks: emergencyChunks,
                removedElements: 0,
                linkHeavyRemoved: 0,
                headlineListRemoved: 0,
                contaminationScore: 1.0,
                contentLength: article.textContent.length,
              );
              selectedPass = 'emergency_rescue';
              selectedMeta = const ReaderExtractionMeta(
                pageType: ReaderPageType.article,
                titleSource: ReaderTitleSource.fallback,
                qualityScore: 0.42,
              );
              _logExtractionTelemetry(
                selectedPass: selectedPass,
                processed: processed,
                meta: selectedMeta,
              );
              if (_shouldAbortExtraction(extractionToken)) return;
              _lastExtractedUrl = extractionUrl;
              state = state.copyWith(
                isReaderMode: true,
                isLoading: false,
                article: article,
                processedContent: processed.html,
                chunks: processed.chunks,
                pageType: selectedMeta.pageType,
                titleSource: selectedMeta.titleSource,
                qualityScore: selectedMeta.qualityScore,
              );
              return;
            }
            if (unsupportedMeta != null) {
              if (!allowUnsupportedRecovery) {
                _setUnsupportedPageState(unsupportedMeta);
                return;
              }
            }
            debugPrint(
              '[ReaderController] fallback rejected '
              '| len=${article.textContent.length} '
              '| chunks=${fallbackChunks.length} '
              '| score=${fallbackQualityScore.toStringAsFixed(2)} '
              '| readable=$fallbackReadableBody '
              '| likelyArticleUrl=$likelyArticleUrl '
              '| trustedArticleHost=$trustedArticleHost '
              '| unsupported=${unsupportedMeta?.pageType.wireValue ?? 'none'}',
            );
            state = state.copyWith(
              isLoading: false,
              errorMessage:
                  'Reader mode could not isolate article-only content.',
              errorCode: 'reader_quality_fail',
              pageType: ReaderPageType.article,
              titleSource: ReaderTitleSource.fallback,
              qualityScore: fallbackQualityScore,
            );
            return;
          }

          processed = ReaderHtmlProcessOutput(
            html: fallbackHtml,
            chunks: rescueChunks,
            removedElements: 0,
            linkHeavyRemoved: 0,
            headlineListRemoved: 0,
            contaminationScore: 1.0,
            contentLength: article.textContent.length,
          );
          selectedPass = 'fallback_rescue';
          selectedMeta = ReaderExtractionMeta(
            pageType: ReaderPageType.article,
            titleSource: ReaderTitleSource.fallback,
            qualityScore: fallbackQualityScore.clamp(0.28, 0.72),
          );
          _logExtractionTelemetry(
            selectedPass: selectedPass,
            processed: processed,
            meta: selectedMeta,
          );
          if (_shouldAbortExtraction(extractionToken)) return;
          _lastExtractedUrl = extractionUrl;
          state = state.copyWith(
            isReaderMode: true,
            isLoading: false,
            article: article,
            processedContent: processed.html,
            chunks: processed.chunks,
            pageType: selectedMeta.pageType,
            titleSource: selectedMeta.titleSource,
            qualityScore: selectedMeta.qualityScore,
          );
          return;
        }

        processed = ReaderHtmlProcessOutput(
          html: fallbackHtml,
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

      if (_shouldAbortExtraction(extractionToken)) return;

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
      _lastExtractedUrl = cacheKey.isNotEmpty ? cacheKey : null;

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
      );
    } catch (e, s) {
      if (_shouldAbortExtraction(extractionToken)) return;
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
  let pagePath = '';
  let host = '';
  try {
    const currentUrl = new URL(URL_HINT || location.href);
    pagePath = currentUrl.pathname.toLowerCase();
    host = currentUrl.hostname.toLowerCase();
  } catch (_) {}

  const hostAdapter = (() => {
    if (host.includes('prothomalo.com')) {
      return {
        rootSelectors: ['article', 'div[itemprop="articleBody"]', '.story-content', '.story-body', '.story-element.story-element-text']
      };
    }
    if (host.includes('bd-pratidin.com')) {
      return {
        rootSelectors: ['article', '.details', '.news-content', '[itemprop="articleBody"]']
      };
    }
    if (host.includes('thedailystar.net')) {
      return {
        rootSelectors: ['article', '.article-body', '.section-content']
      };
    }
    if (host.includes('banglanews24.com')) {
      return {
        rootSelectors: ['article', '.news-article-content', '.article-details']
      };
    }
    if (host.includes('bbc.com') || host.includes('bbc.co.uk')) {
      return {
        rootSelectors: ['article', '[data-component="text-block"]', '.story-body__inner']
      };
    }
    return null;
  })();

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
  const liveUrlPattern = /(?:^|\\/)(live|live-updates?|liveblog|live-blog|minute-by-minute)(?:[-_/]|\\/|\$)/i;
  const timestampSelector =
    'time,[datetime],[class*="timestamp"],[class*="updated"],[class*="time"],[id*="time"]';
  const updatePattern = /updated|live|minute|min ago|আপডেট|হালনাগাদ|লাইভ/gi;
  const rootNoisePattern =
    /(related|recommend|trending|popular|share|comment|more-news|also-read|top-news|latest|story-list|newsletter|subscribe)/i;

  const prepareRootClone = (node) => {
    if (!node) return null;
    const clone = node.cloneNode(true);
    const noiseSelectors = [
      'script', 'style', 'nav', 'footer', 'aside', 'noscript', 'header',
      '.related', '.related-news', '.recommended', '.trending', '.most-read',
      '.most-popular', '.more-news', '.also-read', '.share', '.share-tools',
      '.comments', '.newsletter', '[class*="stock"]', '[class*="ticker"]',
      '[class*="marquee"]', '[class*="liveData"]', '[class*="live-data"]',
      '[id*="stock"]', '[id*="ticker"]', '[id*="taboola"]', '[id*="outbrain"]',
      '[role="navigation"]', '[role="complementary"]'
    ];
    noiseSelectors.forEach((sel) => {
      try {
        clone.querySelectorAll(sel).forEach((el) => el.remove());
      } catch (_) {}
    });
    return clone;
  };

  const pickPrimaryRoot = () => {
    const selectors = [
      'article',
      'main article',
      '[itemprop*="articleBody"]',
      '[role="main"] article',
      '.article-body',
      '.articleBody',
      '.story-body',
      '.story-content',
      '.news-content',
      '.section-content',
      'main',
      '[role="main"]',
      '[class*="article"]',
      '[class*="story"]',
      '[class*="content"]'
    ];
    if (hostAdapter?.rootSelectors) {
      selectors.unshift(...hostAdapter.rootSelectors);
    }
    const seen = new Set();
    let best = null;
    let bestScore = -1;
    selectors.forEach((selector) => {
      document.querySelectorAll(selector).forEach((el) => {
        if (!el || seen.has(el)) return;
        seen.add(el);
        const candidate = prepareRootClone(el);
        const text = normalize(candidate?.innerText || candidate?.textContent || '');
        if (text.length < 140) return;
        const paragraphCount = candidate?.querySelectorAll('p').length || 0;
        const anchors = Array.from(candidate?.querySelectorAll('a') || []);
        const shortAnchors = anchors.filter(
          (a) => normalize(a.innerText || a.textContent || '').split(/\\s+/).filter(Boolean).length <= 9
        ).length;
        const anchorTextLen = anchors.reduce(
          (sum, a) => sum + normalize(a.innerText || a.textContent || '').length,
          0
        );
        const localLinkDensity = anchorTextLen / Math.max(text.length, 1);
        const listItems = candidate?.querySelectorAll('li').length || 0;
        const marker = String((el.className || '') + ' ' + (el.id || '')).toLowerCase();
        const markerPenalty = rootNoisePattern.test(marker) ? 260 : 0;
        const score =
          text.length +
          (paragraphCount * 135) -
          Math.round(localLinkDensity * 760) -
          (shortAnchors * 22) -
          (listItems * 16) -
          markerPenalty;
        if (score > bestScore) {
          best = candidate;
          bestScore = score;
        }
      });
    });
    return best;
  };

  // Remove stock tickers, marquees, and live-data widgets before measuring
  // link density, as they contain massive numbers of short <a> tags that would
  // otherwise cause legitimate articles to be misclassified as listing pages.
  const bodyClone = document.body ? document.body.cloneNode(true) : null;
  if (bodyClone) {
    const noiseSelectors = [
      'script', 'style', 'nav', 'footer', 'aside', 'noscript', 'header',
      '[class*="stock"]', '[class*="marquee"]', '[class*="ticker"]',
      '[class*="liveData"]', '[class*="live-data"]', '[class*="exchange"]',
      '[id*="stock"]', '[id*="ticker"]', '[id*="taboola"]', '[id*="outbrain"]',
      '[role="navigation"]', '[role="complementary"]'
    ];
    noiseSelectors.forEach((sel) => {
      try { bodyClone.querySelectorAll(sel).forEach((el) => el.remove()); } catch (_) {}
    });
  }
  const bodyText = normalize((bodyClone || document.body)?.innerText || '');
  const allAnchors = Array.from((bodyClone || document.body)?.querySelectorAll('a') || []);
  const totalAnchorText = allAnchors.reduce((sum, a) => sum + normalize(a.innerText || a.textContent || '').length, 0);
  const linkDensity = totalAnchorText / Math.max(bodyText.length, 1);
  const primaryRoot = pickPrimaryRoot();
  const primaryText = normalize(primaryRoot?.innerText || primaryRoot?.textContent || '');
  const primaryParagraphCount = primaryRoot?.querySelectorAll('p').length || 0;
  const primaryAnchors = Array.from(primaryRoot?.querySelectorAll('a') || []);
  const primaryAnchorTextLen = primaryAnchors.reduce(
    (sum, a) => sum + normalize(a.innerText || a.textContent || '').length,
    0
  );
  const primaryLinkDensity = primaryAnchorTextLen / Math.max(primaryText.length, 1);
  const primaryTimestampNodes = primaryRoot?.querySelectorAll(timestampSelector).length || 0;
  const primaryUpdateMentions = (primaryText.match(updatePattern) || []).length;
  const primaryHeadlineAnchors = primaryAnchors.filter(
    (a) => normalize(a.innerText || a.textContent || '').length >= 18
  );
  const primaryShortHeadlineAnchors = primaryHeadlineAnchors.filter(
    (a) => normalize(a.innerText || a.textContent || '').split(/\\s+/).filter(Boolean).length <= 14
  );

  const headlineAnchors = Array.from(
    document.querySelectorAll(
      'article h2 a, article h3 a, [class*="headline"] a, [class*="story"] a, [class*="card"] h2 a, [class*="card"] h3 a'
    )
  ).filter((a) => normalize(a.innerText || a.textContent || '').length >= 18);

  const shortHeadlineAnchors = headlineAnchors.filter(
    (a) => normalize(a.innerText || a.textContent || '').split(/\\s+/).filter(Boolean).length <= 14
  );
  const timestampNodes = document.querySelectorAll(timestampSelector).length;
  const updateMentions = (bodyText.match(updatePattern) || []).length;
  const paragraphCount = document.querySelectorAll('article p, main p, p').length;
  const h1Text = normalize(document.querySelector('h1')?.innerText || '');

  let pageType = 'unknown';
  let qualityScore = 0.35;

  const strongArticleRoot =
    primaryText.length >= 420 &&
    primaryParagraphCount >= 4 &&
    primaryLinkDensity < 0.32;
  const moderateArticleRoot =
    h1Text.length >= 12 &&
    primaryText.length >= 220 &&
    primaryParagraphCount >= 2 &&
    primaryLinkDensity < 0.38;
  const liveUrlSignal =
    liveUrlPattern.test(pagePath) &&
    (primaryTimestampNodes >= 2 || primaryUpdateMentions >= 4 || timestampNodes >= 6);
  const liveRootSignal =
    primaryTimestampNodes >= 5 &&
    primaryUpdateMentions >= 4 &&
    (primaryParagraphCount >= 5 ||
      primaryShortHeadlineAnchors.length >= 2 ||
      primaryLinkDensity >= 0.08);
  const listingSignal =
    hasListingType ||
    ((headlineAnchors.length >= 8 &&
      shortHeadlineAnchors.length >= 6 &&
      linkDensity >= 0.18) &&
      !(strongArticleRoot || moderateArticleRoot));
  const articleSignal =
    hasArticleType ||
    strongArticleRoot ||
    moderateArticleRoot ||
    (h1Text.length >= 12 && paragraphCount >= 3 && linkDensity < 0.45);

  if (hasLiveType || liveUrlSignal || liveRootSignal) {
    pageType = 'live_feed';
    qualityScore = 0.95;
  } else if (articleSignal) {
    pageType = 'article';
    qualityScore = 0.84;
  } else if (listingSignal) {
    pageType = 'listing';
    qualityScore = 0.92;
  } else if (
    h1Text.length >= 10 &&
    (primaryParagraphCount >= 2 || paragraphCount >= 2) &&
    (primaryLinkDensity < 0.42 || linkDensity < 0.34)
  ) {
    pageType = 'article';
    qualityScore = 0.64;
  } else if (
    h1Text.length >= 10 &&
    (primaryParagraphCount >= 1 || paragraphCount >= 1) &&
    (primaryLinkDensity < 0.30 || linkDensity < 0.28)
  ) {
    pageType = 'article';
    qualityScore = 0.56;
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
    bool allowUnsupportedPageAttempt = false,
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
              allowUnsupportedPageAttempt: allowUnsupportedPageAttempt,
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
    required bool allowUnsupportedPageAttempt,
  }) {
    final strictLiteral = strictMode ? 'true' : 'false';
    final titleHintLiteral = jsonEncode((titleHint ?? '').trim());
    final urlHintLiteral = jsonEncode((urlHint ?? '').trim());
    final allowUnsupportedAttemptLiteral = allowUnsupportedPageAttempt
        ? 'true'
        : 'false';
    return '''
(function() {
  const STRICT_MODE = $strictLiteral;
  const TITLE_HINT = $titleHintLiteral;
  const URL_HINT = $urlHintLiteral;
  const ALLOW_UNSUPPORTED_ATTEMPT = $allowUnsupportedAttemptLiteral;

  const normalize = (value) => String(value || '')
    .replace(/\\u00a0/g, ' ')
    .replace(/[ \\t]+/g, ' ')
    .replace(/\\n{3,}/g, '\\n\\n')
    .trim();

  const normalizeComparable = (value) =>
    normalize(value).toLowerCase().replace(/[^a-z0-9\\u0980-\\u09ff]+/g, '');

  let host = '';
  let pagePath = '';
  let hostComparable = '';
  try {
    const currentUrl = new URL(URL_HINT || location.href);
    host = currentUrl.hostname.toLowerCase();
    pagePath = currentUrl.pathname.toLowerCase();
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
    const liveUrlPattern = /(?:^|\\/)(live|live-updates?|liveblog|live-blog|minute-by-minute)(?:[-_/]|\\/|\$)/i;
    const timestampSelector =
      'time,[datetime],[class*="timestamp"],[class*="updated"],[class*="time"],[id*="time"]';
    const updatePattern = /updated|live|minute|min ago|আপডেট|হালনাগাদ|লাইভ/gi;

    const bodyText = normalize(document.body?.innerText || '');
    const allAnchors = Array.from(document.querySelectorAll('a'));
    const totalAnchorText = allAnchors.reduce((sum, a) => sum + normalize(a.innerText || a.textContent || '').length, 0);
    const linkDensity = totalAnchorText / Math.max(bodyText.length, 1);
    const primaryRoot = (() => {
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
      return bestNode;
    })();
    const primaryText = normalize(primaryRoot?.innerText || primaryRoot?.textContent || '');
    const primaryParagraphCount = primaryRoot?.querySelectorAll('p').length || 0;
    const primaryAnchors = Array.from(primaryRoot?.querySelectorAll('a') || []);
    const primaryAnchorTextLen = primaryAnchors.reduce(
      (sum, a) => sum + normalize(a.innerText || a.textContent || '').length,
      0
    );
    const primaryLinkDensity = primaryAnchorTextLen / Math.max(primaryText.length, 1);
    const primaryTimestampNodes = primaryRoot?.querySelectorAll(timestampSelector).length || 0;
    const primaryUpdateMentions = (primaryText.match(updatePattern) || []).length;
    const primaryHeadlineAnchors = primaryAnchors.filter(
      (a) => normalize(a.innerText || a.textContent || '').length >= 16
    );
    const primaryShortHeadlineAnchors = primaryHeadlineAnchors.filter(
      (a) => normalize(a.innerText || a.textContent || '').split(/\\s+/).filter(Boolean).length <= 14
    );

    const headlineAnchors = Array.from(document.querySelectorAll(
      'article h2 a, article h3 a, [class*="headline"] a, [class*="story"] a, [class*="card"] h2 a, [class*="card"] h3 a'
    )).filter((a) => normalize(a.innerText || a.textContent || '').length >= 16);

    const shortHeadlineAnchors = headlineAnchors.filter(
      (a) => normalize(a.innerText || a.textContent || '').split(/\\s+/).filter(Boolean).length <= 14
    );
    const timestampNodes = document.querySelectorAll(timestampSelector).length;
    const updateMentions = (bodyText.match(updatePattern) || []).length;
    const paragraphCount = document.querySelectorAll('article p, main p, p').length;
    const h1Text = normalize(document.querySelector('h1')?.innerText || '');

    const strongArticleRoot =
      primaryText.length >= 420 &&
      primaryParagraphCount >= 4 &&
      primaryLinkDensity < 0.32;
    const moderateArticleRoot =
      h1Text.length >= 12 &&
      primaryText.length >= 220 &&
      primaryParagraphCount >= 2 &&
      primaryLinkDensity < 0.38;
    const liveUrlSignal =
      liveUrlPattern.test(pagePath) &&
      (primaryTimestampNodes >= 2 || primaryUpdateMentions >= 4 || timestampNodes >= 6);
    const liveRootSignal =
      primaryTimestampNodes >= 5 &&
      primaryUpdateMentions >= 4 &&
      (primaryParagraphCount >= 5 ||
        primaryShortHeadlineAnchors.length >= 2 ||
        primaryLinkDensity >= 0.08);
    const listingSignal =
      hasListingType ||
      ((headlineAnchors.length >= 8 &&
        shortHeadlineAnchors.length >= 6 &&
        linkDensity >= 0.18) &&
        !(strongArticleRoot || moderateArticleRoot));
    const articleSignal =
      hasArticleType ||
      strongArticleRoot ||
      moderateArticleRoot ||
      (h1Text.length >= 12 && paragraphCount >= 3 && linkDensity < 0.45);

    if (hasLiveType || liveUrlSignal || liveRootSignal) {
      return { pageType: 'live_feed', qualityScore: 0.96 };
    }
    if (articleSignal) {
      return { pageType: 'article', qualityScore: 0.84 };
    }
    if (listingSignal) {
      return { pageType: 'listing', qualityScore: 0.93 };
    }
    if (
      h1Text.length >= 10 &&
      (primaryParagraphCount >= 2 || paragraphCount >= 2) &&
      (primaryLinkDensity < 0.42 || linkDensity < 0.34)
    ) {
      return { pageType: 'article', qualityScore: 0.64 };
    }
    if (
      h1Text.length >= 10 &&
      (primaryParagraphCount >= 1 || paragraphCount >= 1) &&
      (primaryLinkDensity < 0.30 || linkDensity < 0.28)
    ) {
      return { pageType: 'article', qualityScore: 0.56 };
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
    '[id*="taboola"]', '[id*="outbrain"]',
    // Stock ticker / marquee widgets – contain many <a> tags and inflate link density
    '[class*="stock"]', '[class*="marquee"]', '[class*="ticker"]',
    '[class*="stockMarquee"]', '[id*="stock"]', '[id*="ticker"]',
    '[class*="liveData"]', '[class*="live-data"]', '[class*="exchange"]'
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
    if (text.length < 120) return -1;
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
    if (pageMeta.pageType !== 'article' && !ALLOW_UNSUPPORTED_ATTEMPT) {
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
      if (article && (!article.textContent || article.textContent.length < (STRICT_MODE ? 220 : 140))) {
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
      if (textContent.length < (STRICT_MODE ? 150 : 110)) return "null";
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
          noiseTokens: kNoiseTokens,
          noisyPrefixes: kNoisyPrefixes,
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
    if (textContent.length < 70) return "null";

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

  Future<ReaderArticle?> _extractBestEffortReaderArticle({
    String? titleHint,
    String? urlHint,
  }) async {
    if (_webViewController == null) return null;
    try {
      debugPrint(
        '[ReaderController] running best-effort JS extraction '
        '| url=${(urlHint ?? '').trim()}',
      );
      final result = await _webViewController!
          .evaluateJavascript(
            source:
                '''
(() => {
  const normalize = (value) => String(value || '')
    .replace(/\\u00a0/g, ' ')
    .replace(/[ \\t]+/g, ' ')
    .replace(/\\n{3,}/g, '\\n\\n')
    .trim();
  const normalizeComparable = (value) =>
    normalize(value).toLowerCase().replace(/[^a-z0-9\\u0980-\\u09ff]+/g, '');
  const TITLE_HINT = ${jsonEncode((titleHint ?? '').trim())};
  const URL_HINT = ${jsonEncode((urlHint ?? '').trim())};
  try {
    const selectors = [
      'article',
      '[itemprop*="articleBody"]',
      '.details',
      '.news-content',
      '.story-body',
      '.article-body',
      'main',
      'body'
    ];

    const cleanNode = (node) => {
      if (!node) return null;
      const clone = node.cloneNode(true);
      clone.querySelectorAll('script,style,nav,footer,aside,header,form,button,svg,canvas,iframe,noscript').forEach((el) => el.remove());
      clone.querySelectorAll(
        '.related,.related-news,.related-posts,.recommended,.trending,.popular,.most-read,.more-news,.also-read,.share,.share-tools,.social,.tags,.category,.newsletter,.subscribe,.video-player,.video-wrapper'
      ).forEach((el) => el.remove());
      return clone;
    };

    const scoreNode = (node) => {
      const text = normalize(node?.innerText || node?.textContent || '');
      if (text.length < 60) return -1e9;
      const pCount = node.querySelectorAll ? node.querySelectorAll('p').length : 0;
      const anchors = node.querySelectorAll ? Array.from(node.querySelectorAll('a')) : [];
      const anchorTextLen = anchors.reduce((sum, a) => sum + normalize(a.innerText || '').length, 0);
      const linkDensity = anchorTextLen / Math.max(text.length, 1);
      const shortAnchors = anchors.filter((a) => normalize(a.innerText || '').split(/\\s+/).filter(Boolean).length <= 8).length;
      const headingNodes = node.querySelectorAll ? node.querySelectorAll('h2,h3,h4,li').length : 0;
      return (
        text.length +
        (pCount * 190) -
        (Math.round(linkDensity * 1700)) -
        (shortAnchors * 60) -
        (headingNodes * 14)
      );
    };

    let bestText = '';
    let bestHtml = '';
    let bestScore = -1e9;
    for (const selector of selectors) {
      const candidates = Array.from(document.querySelectorAll(selector));
      for (const candidate of candidates) {
        const cleaned = cleanNode(candidate);
        if (!cleaned) continue;
        const text = normalize(cleaned.innerText || cleaned.textContent || '');
        const score = scoreNode(cleaned);
        if (score > bestScore || (score === bestScore && text.length > bestText.length)) {
          bestScore = score;
          bestText = text;
          bestHtml = String(cleaned.innerHTML || '');
        }
      }
    }

    const collectAggressiveLines = () => {
      const unique = new Set();
      const out = [];
      const skipLine = (line) =>
        /^(share|subscribe|sign in|login|read more|more news|more|advert|sponsored|আরও পড়ুন|সম্পর্কিত|সংশ্লিষ্ট|ভিডিও|ছবি)/i.test(line);
      const pushLine = (line) => {
        const clean = normalize(line);
        if (clean.length < 16) return;
        if (skipLine(clean)) return;
        const key = clean.toLowerCase();
        if (unique.has(key)) return;
        unique.add(key);
        out.push(clean);
      };

      if (TITLE_HINT) {
        pushLine(TITLE_HINT);
      }

      const primaryBlocks = document.querySelectorAll(
        'main p,main h1,main h2,main h3,article p,article h1,article h2,article h3,[itemprop*="headline"],[itemprop*="description"],[class*="headline"],[class*="title"],[class*="summary"],[class*="story"] p,[class*="story"] h2,[class*="story"] h3'
      );
      primaryBlocks.forEach((node) => {
        const text = normalize(node?.innerText || node?.textContent || '');
        if (!text) return;
        text.split(/\\n+/).forEach(pushLine);
      });

      const titleComparable = normalizeComparable(TITLE_HINT);
      if (titleComparable.length >= 8) {
        const anchors = Array.from(document.querySelectorAll('a[href]'));
        anchors.forEach((a) => {
          const anchorText = normalize(a?.innerText || a?.textContent || '');
          if (anchorText.length < 8) return;
          const anchorComparable = normalizeComparable(anchorText);
          if (!anchorComparable) return;
          const isTitleMatch =
            anchorComparable.includes(titleComparable) ||
            titleComparable.includes(anchorComparable);
          if (!isTitleMatch) return;
          const container =
            a.closest('article,section,main,div,li') ||
            a.parentElement;
          const contextText = normalize(
            container?.innerText || container?.textContent || anchorText
          );
          contextText.split(/\\n+/).forEach(pushLine);
        });
      }

      return out.slice(0, 260);
    };

    if (bestText.length < 40) {
      const bodyText = normalize(document.body?.innerText || document.body?.textContent || '');
      let lines = bodyText
        .split(/\\n+/)
        .map((line) => normalize(line))
        .filter((line) => line.length >= 12)
        .slice(0, 220);

      if (bodyText.length < 80 || lines.length < 4) {
        const aggressiveLines = collectAggressiveLines();
        if (aggressiveLines.length > lines.length) {
          lines = aggressiveLines;
        }
      }

      bestText = lines.join('\\n');
      if (!bestHtml || bestHtml.length < 20) {
        bestHtml = lines.map((line) => '<p>' + line + '</p>').join('');
      }
    }

    if (bestText.length < 40) return "null";

    if (!bestHtml) {
      const lines = bestText
        .split(/\\n+/)
        .map((line) => normalize(line))
        .filter((line) => line.length >= 12)
        .slice(0, 220);
      bestHtml = lines.map((line) => '<p>' + line + '</p>').join('');
    }

    const title = normalize(
      TITLE_HINT ||
      document.querySelector('meta[property="og:title"]')?.content ||
      document.querySelector('meta[name="twitter:title"]')?.content ||
      document.querySelector('h1')?.innerText ||
      document.title ||
      'Reader mode'
    );

    return JSON.stringify({
      title,
      titleSource: TITLE_HINT ? 'hint' : 'fallback',
      content: bestHtml,
      textContent: bestText,
      excerpt: bestText.substring(0, Math.min(bestText.length, 280)),
      byline: '',
      siteName: location?.hostname || '',
      length: bestText.length,
      pageType: 'article',
      qualityScore: 0.42,
      failureCode: null,
      url: URL_HINT || location.href
    });
  } catch (e) {
    return "null";
  }
})();
''',
          )
          .timeout(const Duration(seconds: 4), onTimeout: () => 'null');
      final payload = _decodeExtractionPayload(result);
      if (payload == null) {
        debugPrint('[ReaderController] best-effort JS payload null');
        return null;
      }
      final article = _readerArticleFromPayload(
        payload,
        titleHint: titleHint,
        urlHint: urlHint,
      );
      if (article.textContent.length < 40) {
        debugPrint(
          '[ReaderController] best-effort JS discarded: text too short '
          '| textLen=${article.textContent.length}',
        );
        return null;
      }
      debugPrint(
        '[ReaderController] best-effort JS success '
        '| textLen=${article.textContent.length} '
        '| title=${article.title}',
      );
      return article;
    } catch (_) {
      debugPrint('[ReaderController] best-effort JS extraction threw.');
      return null;
    }
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
    final String textContent = _normalizeReaderText(textRaw.toString());

    var content = (payload['content'] as String? ?? '').trim();

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
    if (decontaminatedText.isEmpty && textContent.isNotEmpty) {
      decontaminatedText = _stripLeadingReaderNoise(textContent);
    }
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
    if (content.isEmpty && decontaminatedText.isNotEmpty) {
      content = _plainTextToReaderHtml(decontaminatedText);
    }

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

  ReaderArticle? _readerArticleFromStoredHtml({
    required String htmlContent,
    String? titleHint,
    String? urlHint,
  }) {
    final trimmed = htmlContent.trim();
    if (trimmed.isEmpty) return null;

    final parsedDocument = html_parser.parse(trimmed);
    final fragment = html_parser.parseFragment(
      parsedDocument.body?.innerHtml ?? trimmed,
    );
    final siteName =
        parsedDocument
            .querySelector('meta[property="og:site_name"]')
            ?.attributes['content']
            ?.trim() ??
        Uri.tryParse(urlHint ?? '')?.host ??
        '';
    final extractedTitle =
        parsedDocument.querySelector('h1')?.text.trim() ??
        parsedDocument.querySelector('title')?.text.trim() ??
        '';

    removeNoiseAndMetadata(
      fragment,
      ReaderHtmlProcessInput(
        content: trimmed,
        articleTitle: (titleHint ?? '').trim(),
        noiseTokens: kNoiseTokens,
        noisyPrefixes: kNoisyPrefixes,
        strictMode: false,
      ),
    );
    normalizeForMobileReadability(fragment);

    final rawText = _normalizeReaderText(fragment.text ?? '');
    if (rawText.length < 140) {
      return null;
    }

    var titleCandidate = _resolvePreferredTitle(
      extractedTitle: extractedTitle,
      titleHint: titleHint,
      siteName: siteName,
      sourceUrl: urlHint,
    );
    var decontaminatedText = _stripLeadingReaderNoise(rawText);
    titleCandidate = _repairReaderTitle(
      currentTitle: titleCandidate,
      bodyText: decontaminatedText,
      siteName: siteName,
      sourceUrl: urlHint,
    );
    decontaminatedText = _stripLeadingDuplicateTitle(
      decontaminatedText,
      titleCandidate,
    );
    if (decontaminatedText.length < 120) {
      return null;
    }

    var content = fragment.outerHtml.trim();
    if (content.isEmpty) {
      content = _plainTextToReaderHtml(decontaminatedText);
    }

    return ReaderArticle(
      title: titleCandidate,
      content: content,
      textContent: decontaminatedText,
      excerpt: _excerptFromText(decontaminatedText),
      siteName: siteName,
      length: decontaminatedText.length,
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

    final currentBranding = isLikelyBrandingTitle(
      normalizedCurrent,
      siteName: siteName,
      sourceUrl: sourceUrl,
    );
    final bodyBranding = isLikelyBrandingTitle(
      bodyCandidate,
      siteName: siteName,
      sourceUrl: sourceUrl,
    );
    final currentScore =
        titleQualityScore(normalizedCurrent) - (currentBranding ? 140 : 0);
    final bodyScore =
        titleQualityScore(bodyCandidate) - (bodyBranding ? 140 : 0);
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
      if (kNoisyPrefixes.any(lower.startsWith) ||
          kNoiseTokens.any(lower.contains) ||
          kMetadataLinePattern.hasMatch(lower) ||
          kUrlPattern.hasMatch(lower)) {
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
    final lines = _sanitizeReaderBodyLines(text, aggressive: true);
    if (lines.isEmpty) {
      return '';
    }
    return lines.join('\n');
  }

  String _normalizeReaderText(String text) {
    final normalized = text
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
    return normalized
        .split('\n')
        .map((line) => line.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  bool _isLikelyReaderNoiseLine(String line) {
    final lower = line.toLowerCase();
    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasSentencePunctuation = RegExp(r'[.!?।]').hasMatch(line);
    final hasNoisePrefix =
        kNoisyPrefixes.any(lower.startsWith) ||
        lower.startsWith('আরও পড়ুন') ||
        lower.startsWith('সম্পর্কিত') ||
        lower.startsWith('related') ||
        lower.startsWith('recommended') ||
        lower.startsWith('more news');
    final hasNoiseToken = kNoiseTokens.any(lower.contains);
    if (hasNoisePrefix) return true;
    if (kMetadataLinePattern.hasMatch(lower) || kUrlPattern.hasMatch(lower)) {
      return true;
    }
    if (hasNoiseToken &&
        (!hasSentencePunctuation || words <= 18 || line.length < 90)) {
      return true;
    }
    return false;
  }

  bool _isLikelyBodyLine(String line) {
    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasSentencePunctuation = RegExp(r'[.!?।]').hasMatch(line);
    if (words >= 10 && line.length >= 80) return true;
    if (words >= 8 && hasSentencePunctuation && line.length >= 48) return true;
    return false;
  }

  bool _isLikelyHeadlineDumpLine(String line) {
    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final hasSentencePunctuation = RegExp(r'[.!?।]').hasMatch(line);
    if (hasSentencePunctuation) return false;
    if (words < 3 || words > 16) return false;
    return line.length >= 16 && line.length <= 140;
  }

  List<String> _sanitizeReaderBodyLines(
    String text, {
    bool aggressive = false,
  }) {
    final lines = _normalizeReaderText(text)
        .split(RegExp(r'\n+'))
        .map(_compactWhitespace)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return const <String>[];

    final firstBodyIndex = lines.indexWhere(_isLikelyBodyLine);
    final startIndex = firstBodyIndex < 0 ? 0 : firstBodyIndex;
    final cleaned = <String>[];

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      if (_isLikelyReaderNoiseLine(line)) {
        continue;
      }
      final headlineLike = _isLikelyHeadlineDumpLine(line);
      if (headlineLike) {
        final prevBody = i > startIndex && _isLikelyBodyLine(lines[i - 1]);
        final nextBody =
            i + 1 < lines.length && _isLikelyBodyLine(lines[i + 1]);
        if (!prevBody && !nextBody) {
          if (aggressive || line.length < 92) {
            continue;
          }
        }
      }
      cleaned.add(line);
    }

    if (cleaned.isEmpty) return const <String>[];

    while (cleaned.length > 2 &&
        (_isLikelyReaderNoiseLine(cleaned.first) ||
            (_isLikelyHeadlineDumpLine(cleaned.first) &&
                !_isLikelyBodyLine(cleaned.first)))) {
      cleaned.removeAt(0);
    }
    while (cleaned.length > 2 &&
        (_isLikelyReaderNoiseLine(cleaned.last) ||
            (_isLikelyHeadlineDumpLine(cleaned.last) &&
                !_isLikelyBodyLine(cleaned.last)))) {
      cleaned.removeLast();
    }

    return cleaned;
  }

  String _plainTextToReaderHtml(String text) {
    final escaper = const HtmlEscape();
    final paragraphs = _sanitizeReaderBodyLines(text)
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
          kNoisyPrefixes.any(lower.startsWith) ||
          kNoiseTokens.any(lower.contains) ||
          kMetadataLinePattern.hasMatch(lower);
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
    final cleanLines = _sanitizeReaderBodyLines(text);
    final normalized = cleanLines.join(' ');
    if (normalized.isEmpty) return const <TtsChunk>[];

    final sentenceParts = normalized
        .split(RegExp(r'(?<=[.!?।])\s+'))
        .map(_compactWhitespace)
        .where((part) {
          if (part.length <= 1) return false;
          final lower = part.toLowerCase();
          final noisyPrefix = kNoisyPrefixes.any(lower.startsWith);
          final noisyToken = kNoiseTokens.any(lower.contains);
          final metadataLike = kMetadataLinePattern.hasMatch(lower);
          if (!(noisyPrefix || noisyToken || metadataLike)) return true;
          return part.length > 90 && RegExp(r'[.!?।]').hasMatch(part);
        })
        .toList(growable: false);

    List<String> chunkParts;
    final hasSentenceBoundaries = sentenceParts.length > 1;
    final oversizedSingleSentence =
        sentenceParts.length == 1 && sentenceParts.first.length >= 520;
    if (hasSentenceBoundaries && !oversizedSingleSentence) {
      chunkParts = sentenceParts;
    } else {
      chunkParts = cleanLines
          .where((line) => line.length >= 24)
          .take(180)
          .toList(growable: false);
      if (chunkParts.isEmpty) {
        chunkParts = sentenceParts;
      }
    }

    var index = 0;
    return chunkParts
        .map(
          (sentence) => TtsChunk(
            index: index++,
            text: sentence,
            estimatedDuration: Duration(milliseconds: sentence.length * 40),
          ),
        )
        .toList(growable: false);
  }

  List<TtsChunk> _buildEmergencyFallbackChunks(String text) {
    final lines = _sanitizeReaderBodyLines(
      text,
      aggressive: true,
    ).where((line) => line.length >= 20).toList(growable: false);
    final parts = <String>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      final noisyLine =
          kNoisyPrefixes.any(lower.startsWith) ||
          kNoiseTokens.any(lower.contains) ||
          kMetadataLinePattern.hasMatch(lower);
      if (!noisyLine) {
        parts.add(line);
      }
    }

    if (parts.isEmpty) {
      final normalized = _compactWhitespace(text);
      if (normalized.length >= 20) {
        parts.addAll(
          normalized
              .split(RegExp(r'(?<=[.!?।])\s+'))
              .map(_compactWhitespace)
              .where((line) => line.length >= 20),
        );
      }
    }

    if (parts.isEmpty) return const <TtsChunk>[];
    var index = 0;
    return parts
        .take(180)
        .map(
          (line) => TtsChunk(
            index: index++,
            text: line,
            estimatedDuration: Duration(milliseconds: line.length * 40),
          ),
        )
        .toList(growable: false);
  }

  bool _isTrustedReaderFallbackHost(String url) {
    final uri = Uri.tryParse(url.trim());
    final host = (uri?.host ?? '').toLowerCase();
    if (host.isEmpty) return false;
    return host.contains('bd-pratidin.com') ||
        host.contains('prothomalo.com') ||
        host.contains('thedailystar.net') ||
        host.contains('banglanews24.com') ||
        host.contains('jugantor.com') ||
        host.contains('kalerkantho.com');
  }

  String? _excerptFromText(String text) {
    if (text.isEmpty) return null;
    final limit = text.length > 280 ? 280 : text.length;
    return text.substring(0, limit);
  }

  // ── TTS controls ──────────────────────────────
  Future<void> playFullArticle({
    String category = 'general',
    String language = 'en',
    String? introAnnouncement,
  }) async {
    if (state.chunks.isEmpty) return;
    final ttsController = ref.read(ttsControllerProvider.notifier);
    await ttsController.playChunks(
      state.chunks,
      category: category,
      language: language,
      title: state.article?.title,
      author: state.article?.byline,
      imageSource: state.article?.siteName,
      introAnnouncement: introAnnouncement,
    );
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

  int _beginExtraction() {
    _extractionGeneration += 1;
    return _extractionGeneration;
  }

  void _cancelActiveExtraction() {
    _extractionGeneration += 1;
  }

  bool _shouldAbortExtraction(int token) => token != _extractionGeneration;
}

// ─────────────────────────────────────────────
// PROVIDER
// autoDispose → frees memory when reader is closed
// ─────────────────────────────────────────────
final readerControllerProvider =
    StateNotifierProvider.autoDispose<ReaderController, ReaderState>(
      (ref) => ReaderController(ref),
    );
