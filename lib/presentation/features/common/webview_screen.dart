// lib/features/webview/webview_screen.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  PREMIUM WEBVIEW READER – ANDROID-OPTIMISED v2           ║
// ║                                                          ║
// ║  Optimisation layers applied                             ║
// ║  • ValueNotifier hot-paths (progress, header opacity)    ║
// ║    → eliminates full-tree setState on every scroll/load  ║
// ║  • RepaintBoundary around every independently-animated   ║
// ║    subtree (header, progress bar, bottom bar)            ║
// ║  • Android WebView: adaptive composition pipeline         ║
// ║    (hybrid on constrained/problematic hosts)             ║
// ║  • Hardware-accel flags + DOM/DB storage + safe browsing ║
// ║  • Throttled progress updates (≤16 ms cadence)           ║
// ║  • Debounced scroll-position saves (500 ms)              ║
// ║  • compute() isolate for ad-pattern JS injection         ║
// ║  • SchedulerBinding.addPostFrameCallback for restore     ║
// ║  • const constructors end-to-end                         ║
// ║  • Weak-ref diagnostics (no GC-retain)                   ║
// ║  • PopScope double-back on Android back gesture          ║
// ║  • Proper cancellation: timers, streams, subscriptions   ║
// ╚══════════════════════════════════════════════════════════╝

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/performance_config.dart';
import '../../../core/di/providers.dart'
    show
        appNetworkServiceProvider,
        debugDiagnosticsServiceProvider,
        structuredLoggerProvider;
import '../../../core/navigation/url_safety_policy.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/news_article.dart';
import '../../../core/utils/webview_blocking.dart';
import '../../../core/tts/data/extractors/webview_text_extractor.dart';
import '../../../core/telemetry/debug_diagnostics_service.dart';
import '../../../core/tts/domain/entities/tts_state.dart';
import '../../providers/premium_providers.dart'
    show isPremiumStateProvider, shouldShowAdsProvider;
import '../../providers/favorites_providers.dart' show favoritesProvider;
import '../../providers/saved_articles_provider.dart'
    show savedArticlesProvider;
import '../../providers/feature_providers.dart'
    show ttsManagerProvider, userInterestProvider;
import '../../providers/app_settings_providers.dart' show dataSaverProvider;
import '../../../application/ai/ranking/user_interest_service.dart';
import '../reader/controllers/reader_controller.dart';
import '../reader/ui/native_reader_view.dart';
import '../../../core/tts/presentation/providers/tts_controller.dart';
import '../tts/domain/models/speech_chunk.dart';
import '../tts/domain/models/tts_session.dart';
import '../tts/services/tts_manager.dart';
import '../tts/ui/mini_player_widget.dart';
import '../tts/ui/tts_settings_sheet.dart';
import 'webview_args.dart';
import 'widgets/webview_tokens.dart';
import 'widgets/webview_header.dart';
import 'widgets/webview_bottom_toolbar.dart';
import 'widgets/webview_translate_sheet.dart';

enum _FeedNavDirection { next, previous }

enum _FeedNavTtsCarryState { inactive, playing, paused }

// Tokens moved to WebviewTokens

// ─────────────────────────────────────────────
// CONTENT SCRIPT – built once via compute()
// ─────────────────────────────────────────────
String _buildBaseContentScript(Object? _) => '''
(function() {
  if (window.__bdBaseScriptApplied) return;
  window.__bdBaseScriptApplied = true;

  const safeAppendStyle = (id, css) => {
    const append = () => {
      const parent = document.head || document.documentElement || document.body;
      if (!parent) return false;
      if (id && document.getElementById(id)) return true;
      const style = document.createElement('style');
      if (id) style.id = id;
      style.textContent = css;
      parent.appendChild(style);
      return true;
    };
    if (!append()) {
      window.addEventListener('DOMContentLoaded', append, { once: true });
      window.addEventListener('load', append, { once: true });
    }
  };

  if (!window.__bdSensorPatchApplied) {
    window.__bdSensorPatchApplied = true;
    window.__bdSensorBlockPatched = true;
    const blockedSensorEvents = new Set([
      'deviceorientation',
      'deviceorientationabsolute',
      'devicemotion'
    ]);
    const originalAddEventListener = EventTarget.prototype.addEventListener;
    EventTarget.prototype.addEventListener = function(type, listener, options) {
      const normalized = String(type || '').toLowerCase();
      if (blockedSensorEvents.has(normalized)) return;
      return originalAddEventListener.call(this, type, listener, options);
    };
    window.ondeviceorientation = null;
    window.ondeviceorientationabsolute = null;
    window.ondevicemotion = null;
  }

  safeAppendStyle('bd-reader-base-style', `
    body { -webkit-font-smoothing: antialiased; }
    p, li, article, .article-body, .story-body {
      text-align: justify !important;
      line-height: 1.65 !important;
      overflow-wrap: break-word;
    }
    .category,.categories,[class*="category"],[class*="tag"],[class*="label"],
    [class*="badge"],[id*="category"],[id*="tag"] {
      position: static !important;
      top: auto !important;
      right: auto !important;
      bottom: auto !important;
      left: auto !important;
      transform: none !important;
    }
    img { max-width: 100% !important; height: auto !important; }
    h1, h2, h3 { line-height: 1.3 !important; margin: 1.2em 0 0.4em !important; }
  `);

  const throttleMedia = () => {
    try {
      document.querySelectorAll('video,audio').forEach((m) => {
        try {
          m.autoplay = false;
          m.preload = 'none';
          if (typeof m.pause === 'function') m.pause();
        } catch (_) {}
      });
    } catch (_) {}
  };
  throttleMedia();
  setTimeout(throttleMedia, 1200);

  try { window.open = () => null; } catch (_) {}
})();
''';

/// Premium-only aggressive ad cleanup script.
String _buildPremiumContentScript(Object? _) =>
    '''
(function() {
  if (window.__bdPremiumScriptApplied) return;
  window.__bdPremiumScriptApplied = true;

  const safeAppendStyle = (id, css) => {
    const append = () => {
      const parent = document.head || document.documentElement || document.body;
      if (!parent) return false;
      if (id && document.getElementById(id)) return true;
      const style = document.createElement('style');
      if (id) style.id = id;
      style.textContent = css;
      parent.appendChild(style);
      return true;
    };
    if (!append()) {
      window.addEventListener('DOMContentLoaded', append, { once: true });
      window.addEventListener('load', append, { once: true });
    }
  };

  if (!window.__bdSensorPatchApplied) {
    window.__bdSensorPatchApplied = true;
    window.__bdSensorBlockPatched = true;
    const blockedSensorEvents = new Set([
      'deviceorientation',
      'deviceorientationabsolute',
      'devicemotion'
    ]);
    const originalAddEventListener = EventTarget.prototype.addEventListener;
    EventTarget.prototype.addEventListener = function(type, listener, options) {
      const normalized = String(type || '').toLowerCase();
      if (blockedSensorEvents.has(normalized)) return;
      return originalAddEventListener.call(this, type, listener, options);
    };
    window.ondeviceorientation = null;
    window.ondeviceorientationabsolute = null;
    window.ondevicemotion = null;
  }

  safeAppendStyle('bd-reader-base-style', `
    body { -webkit-font-smoothing: antialiased; }
    p, li, article, .article-body, .story-body {
      text-align: justify !important;
      line-height: 1.65 !important;
      overflow-wrap: break-word;
    }
    .category,.categories,[class*="category"],[class*="tag"],[class*="label"],
    [class*="badge"],[id*="category"],[id*="tag"] {
      position: static !important;
      top: auto !important;
      right: auto !important;
      bottom: auto !important;
      left: auto !important;
      transform: none !important;
    }
    img { max-width: 100% !important; height: auto !important; }
    h1, h2, h3 { line-height: 1.3 !important; margin: 1.2em 0 0.4em !important; }
  `);

  safeAppendStyle('bd-premium-ad-style', `
    $kPremiumAdCssSelectors {
      display:none!important;height:0!important;pointer-events:none!important;
    }
  `);

  const throttleMedia = () => {
    try {
      document.querySelectorAll('video,audio').forEach((m) => {
        try {
          m.autoplay = false;
          m.preload = 'none';
          if (typeof m.pause === 'function') m.pause();
        } catch (_) {}
      });
    } catch (_) {}
  };
  throttleMedia();
  setTimeout(throttleMedia, 1200);

  try { window.open = () => null; } catch (_) {}

  const startObserver = () => {
    if (!document.body) return false;
    const adHostHints = [
      'doubleclick', 'googlesyndication', 'googleadservices', 'taboola',
      'outbrain', 'mgid', 'teads', 'adnxs', 'adservice', 'adserver', 'pubmatic'
    ];

    const looksLikeAdElement = (node) => {
      if (!node || node.nodeType !== 1) return false;
      const el = node;
      const id = String(el.id || '').toLowerCase();
      const cls = String(el.className || '').toLowerCase();
      const role = String(
        (el.getAttribute && el.getAttribute('role')) || '',
      ).toLowerCase();
      const aria = String(
        (el.getAttribute && el.getAttribute('aria-label')) || '',
      ).toLowerCase();
      const dataset = String(
        (el.getAttribute && el.getAttribute('data-testid')) || '',
      ).toLowerCase();
      const raw = [id, cls, role, aria, dataset].join(' ');

      if (raw.includes('sponsor') || raw.includes('advert') || raw.includes('ad-slot') || raw.includes(' ad ')) {
        return true;
      }
      if (raw.startsWith('ad-') || raw.startsWith('ad_') || raw.includes(' ad-') || raw.includes(' ad_')) {
        return true;
      }

      if (el.tagName === 'IFRAME') {
        const src = String(el.getAttribute('src') || '').toLowerCase();
        if (adHostHints.some((hint) => src.includes(hint))) return true;
      }

      const src = String(
        (el.getAttribute && el.getAttribute('src')) || '',
      ).toLowerCase();
      if (adHostHints.some((hint) => src.includes(hint))) return true;
      return false;
    };

    const hideNode = (node) => {
      if (!node || !node.style) return;
      try {
        node.style.setProperty('display', 'none', 'important');
        node.style.setProperty('height', '0', 'important');
        node.style.setProperty('min-height', '0', 'important');
        node.style.setProperty('max-height', '0', 'important');
        node.style.setProperty('margin', '0', 'important');
        node.style.setProperty('padding', '0', 'important');
        node.style.setProperty('border', '0', 'important');
        node.style.setProperty('overflow', 'hidden', 'important');
        node.style.setProperty('pointer-events', 'none', 'important');
        node.style.setProperty('opacity', '0', 'important');
      } catch (_) {}
    };

    const collapseEmptyParents = (node) => {
      let parent = node && node.parentElement;
      let depth = 0;
      while (parent && depth < 3) {
        const text = String(parent.textContent || '').trim();
        const hasAnchoredContent = !!parent.querySelector(
          'article,main,p,h1,h2,h3,h4,img,video'
        );
        if (!hasAnchoredContent && text.length === 0) {
          hideNode(parent);
        }
        parent = parent.parentElement;
        depth += 1;
      }
    };

    const hideAdResidue = (root) => {
      if (!root || !root.querySelectorAll) return;
      const nodes = root.querySelectorAll(
        '[id*="ad-"],[id^="ad_"],[class*=" ad-"],[class^="ad_"],[class*="advert"],[class*="sponsor"],[id*="sponsor"],[class*="ad-placeholder"],[id*="ad-placeholder"],[class*="dfp"],[id*="dfp"],[class*="google_ads"],[id*="google_ads"],iframe,ins.adsbygoogle'
      );
      nodes.forEach((node) => {
        if (looksLikeAdElement(node)) {
          hideNode(node);
          collapseEmptyParents(node);
        }
      });
    };

    hideAdResidue(document);

    let mutationCount = 0;
    const maxMutations = 120;
    const obs = new MutationObserver(ms => {
      mutationCount += ms.length;
      if (mutationCount > maxMutations) {
        obs.disconnect();
        return;
      }
      ms.forEach(m => m.addedNodes.forEach(n => {
        if (looksLikeAdElement(n)) hideNode(n);
        if (n && n.querySelectorAll) hideAdResidue(n);
      }));
    });
    obs.observe(document.body, { childList:true, subtree:true });
    setTimeout(() => obs.disconnect(), 6000);
    return true;
  };

  if (!startObserver()) {
    window.addEventListener('DOMContentLoaded', startObserver, { once: true });
  }
})();
''';

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({required this.args, super.key});

  final WebViewArgs args;

  String get url => args.url.toString();
  String get title => args.title;
  List<NewsArticle>? get articles => args.hasFeedContext ? args.articles : null;
  int? get initialIndex => args.hasFeedContext ? args.initialIndex : null;

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Controllers ─────────────────────────────
  InAppWebViewController? _ctrl;
  late PullToRefreshController _ptrCtrl;
  late UserInterestService _userInterest;
  late TtsManager _ttsManager;
  final WebViewTextExtractor _webViewTextExtractor = WebViewTextExtractor();
  StreamSubscription<SpeechChunk?>? _ttsSubscription;

  // ── Hot-path ValueNotifiers (no full rebuild) ──
  final _progressNotifier = ValueNotifier<double>(0.0);

  // ── State ────────────────────────────────────
  DateTime? _startTime;
  DateTime? _lastBackPressed;
  late int _currentIndex;
  late NewsArticle _currentArticle;
  bool _showFindBar = false;
  bool _showScrollToTop = false;
  final TextEditingController _findController = TextEditingController();
  int _findMatchesCount = 0;
  int _findActiveMatchIndex = 0;
  bool _navInFlight = false;
  int _navTransactionToken = 0;

  // ── Debounce ─────────────────────────────────
  Timer? _scrollSaveTimer;
  String? _scheduledScrollSaveUrl;
  int _lastProgressUpdateMs = 0; // throttle guard

  // ── Diagnostics (weak-ish via nullable ref) ──
  final String _diagnosticWebViewId =
      'webview_${DateTime.now().microsecondsSinceEpoch}';
  DebugDiagnosticsService? _diagnostics;
  bool _diagnosticRegistered = false;

  // ── Reader / TTS nav flags ───────────────────
  bool _pendingReaderRefreshAfterArticleNav = false;
  bool _pendingTtsRestartAfterArticleNav = false;
  bool _pendingReaderRefreshInFlight = false;
  Completer<void>? _pendingPageLoadCompleter;
  String? _pendingPageLoadUrl;
  bool? _lastKnownDataSaver;
  bool? _lastKnownAdFreeState;
  String? _lastAppliedWebViewPolicyKey;
  String? _lastLoggedRenderPolicyKey;
  Uri? _lastPolicyUri;

  // ── Pre-computed JS (generated once off-thread) ──
  String? _cachedBaseContentScript;
  String? _cachedPremiumContentScript;

  // ── Android-tuned WebView settings ───────────
  InAppWebViewSettings _buildWebViewSettings({
    required bool isPremium,
    required PerformanceConfig perf,
    required bool dataSaver,
    Uri? currentUri,
  }) {
    final conservativePolicy = _shouldUseConservativePolicy(currentUri);
    final blockers = buildWebViewContentBlockers(
      isPremium: isPremium,
      conservative: conservativePolicy,
      dataSaver: dataSaver,
    );
    final useHybridComposition =
        perf.isEmulator ||
        perf.isLowEndDevice ||
        perf.lowPowerMode ||
        conservativePolicy;

    final renderPolicyKey =
        'host=${(currentUri?.host ?? '').toLowerCase()}|hybrid=$useHybridComposition|emulator=${perf.isEmulator}|lowEnd=${perf.isLowEndDevice}|lowPower=${perf.lowPowerMode}|conservative=$conservativePolicy';
    if (_lastLoggedRenderPolicyKey != renderPolicyKey) {
      _lastLoggedRenderPolicyKey = renderPolicyKey;
      ref
          .read(structuredLoggerProvider)
          .info('WebView rendering policy', <String, dynamic>{
            'host': (currentUri?.host ?? '').toLowerCase(),
            'useHybridComposition': useHybridComposition,
            'isEmulator': perf.isEmulator,
            'isLowEnd': perf.isLowEndDevice,
            'lowPowerMode': perf.lowPowerMode,
            'conservativePolicy': conservativePolicy,
          });
    }

    return InAppWebViewSettings(
      // ── Rendering ────────────────────────────────────────────
      preferredContentMode: UserPreferredContentMode.MOBILE,
      useHybridComposition: useHybridComposition,
      // blockNetworkImages: dataSaver, // Removed - unsupported parameter

      // ── Storage / capabilities ───────────────────────────────
      allowFileAccess: false,
      allowContentAccess: false,

      // ── Safe browsing + mixed content ────────────────────────
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      thirdPartyCookiesEnabled: !isPremium,

      // ── Viewport ─────────────────────────────────────────────
      supportZoom: false,

      // ── Disable unneeded features ────────────────────────────
      disableDefaultErrorPage: true,

      // ── Ad content blocking ──────────────────────────────────
      useShouldInterceptRequest: blockers.isNotEmpty,
      contentBlockers: blockers,
    );
  }

  // ─────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex ?? -1;
    final articles = widget.articles;
    if (articles != null) {
      if (articles.isEmpty) {
        _currentIndex = -1;
      } else if (_currentIndex < 0 || _currentIndex >= articles.length) {
        _currentIndex = 0;
      }
    }
    _currentArticle = _resolveArticle();

    _ptrCtrl = PullToRefreshController(
      settings: PullToRefreshSettings(color: WT.progressGold),
      onRefresh: () async => _ctrl?.reload(),
    );

    // Generate content-injection scripts off the main thread.
    compute(_buildBaseContentScript, null).then((script) {
      _cachedBaseContentScript = script;
    });
    compute(_buildPremiumContentScript, null).then((script) {
      _cachedPremiumContentScript = script;
    });

    if (kDebugMode || kProfileMode) {
      _diagnostics = ref.read(debugDiagnosticsServiceProvider);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe to call ref.read after first frame; avoids initState ref pitfalls.
    _userInterest = ref.read(userInterestProvider);
    _ttsManager = ref.read(ttsManagerProvider);
    _lastKnownAdFreeState ??= !ref.read(shouldShowAdsProvider);
    _syncTtsFeedNavigationHooks();
    _ttsSubscription ??= _ttsManager.currentChunk.listen((SpeechChunk? chunk) {
      if (!mounted) return;
      if (chunk != null && _ctrl != null) {
        unawaited(_highlightText(chunk.text));
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_pendingPageLoadCompleter != null &&
        !_pendingPageLoadCompleter!.isCompleted) {
      _pendingPageLoadCompleter!.complete();
    }
    _scrollSaveTimer?.cancel();
    _saveScrollPositionSync(); // best-effort; no await in dispose
    _recordReadingSession();
    _ttsSubscription?.cancel();
    _progressNotifier.dispose();
    _ttsManager
      ..clearFeedNavigation()
      ..stop();
    _diagUnregisterWebView();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _scheduleScrollSave();
        _ctrl?.pauseTimers();
        break;
      case AppLifecycleState.resumed:
        _ctrl?.resumeTimers();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  NewsArticle _resolveArticle() {
    if (widget.articles != null &&
        _currentIndex >= 0 &&
        _currentIndex < widget.articles!.length) {
      return widget.articles![_currentIndex];
    }
    return NewsArticle(
      title: widget.title.isNotEmpty ? widget.title : 'Article',
      url: widget.url,
      source: '',
      publishedAt: DateTime.now(),
    );
  }

  Uri? _safeUri(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  String _normalizeComparable(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9\u0980-\u09ff]+'),
      '',
    );
  }

  String _hostPrimaryLabel(String rawUrl) {
    final host = (Uri.tryParse(rawUrl)?.host ?? '').toLowerCase();
    if (host.isEmpty) return '';
    final cleaned = host
        .replaceFirst(RegExp(r'^www\.'), '')
        .replaceFirst(RegExp(r'^m\.'), '')
        .replaceFirst(RegExp(r'^amp\.'), '');
    return _normalizeComparable(cleaned.split('.').first);
  }

  bool _looksLikePublisherTitle(String title, String rawUrl) {
    final normalized = _normalizeComparable(title.trim());
    if (normalized.isEmpty) return false;
    final hostPrimary = _hostPrimaryLabel(rawUrl);
    final sourceNormalized = _normalizeComparable(_currentArticle.source);
    if (hostPrimary.isNotEmpty &&
        (normalized == hostPrimary ||
            normalized.contains(hostPrimary) ||
            hostPrimary.contains(normalized))) {
      return true;
    }
    if (sourceNormalized.isNotEmpty &&
        (normalized == sourceNormalized ||
            normalized.contains(sourceNormalized) ||
            sourceNormalized.contains(normalized))) {
      return true;
    }
    return false;
  }

  int _titleHintScore(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return -1000;
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    var score = cleaned.length.clamp(0, 170);
    if (words >= 4 && words <= 24) {
      score += 44;
    } else if (words <= 2) {
      score -= 40;
    }
    if (RegExp(r'[,;:!?।]').hasMatch(cleaned)) {
      score += 10;
    }
    if (RegExp(r'\s[-|–—]\s').hasMatch(cleaned)) {
      score -= 24;
    }
    return score;
  }

  String _pickReaderTitleHint({
    required String rawUrl,
    required String fallbackTitle,
    required Map<String, dynamic> payload,
  }) {
    final candidates = <({String title, int bonus})>[
      (title: payload['og']?.toString().trim() ?? '', bonus: 72),
      (title: payload['twitter']?.toString().trim() ?? '', bonus: 58),
      (title: payload['jsonld']?.toString().trim() ?? '', bonus: 66),
      (title: payload['h1']?.toString().trim() ?? '', bonus: 62),
      (title: payload['articleH2']?.toString().trim() ?? '', bonus: 54),
      (title: payload['doc']?.toString().trim() ?? '', bonus: 40),
      (title: fallbackTitle.trim(), bonus: 36),
    ];

    String best = fallbackTitle.trim();
    var bestScore = -10000;

    for (final candidate in candidates) {
      final text = candidate.title.trim();
      if (text.isEmpty) continue;
      var score = _titleHintScore(text) + candidate.bonus;
      if (_looksLikePublisherTitle(text, rawUrl)) {
        score -= 140;
      }
      if (score > bestScore) {
        best = text;
        bestScore = score;
      }
    }

    return best.isEmpty ? fallbackTitle : best;
  }

  Future<String> _resolveReaderTitleHint() async {
    final fallback = _currentArticle.title.trim().isEmpty
        ? 'Article'
        : _currentArticle.title.trim();
    final currentUrl = _currentArticle.url;
    if (_ctrl == null) return fallback;
    try {
      final result = await _ctrl!
          .evaluateJavascript(
            source: '''
(() => {
  const normalize = (v) => String(v || '').replace(/\\u00a0/g, ' ').replace(/\\s+/g, ' ').trim();
  let jsonld = '';
  document.querySelectorAll('script[type="application/ld+json"]').forEach((el) => {
    if (jsonld) return;
    const raw = (el.textContent || '').trim();
    if (!raw) return;
    try {
      const parsed = JSON.parse(raw);
      const queue = [parsed];
      while (queue.length && !jsonld) {
        const node = queue.shift();
        if (!node) continue;
        if (Array.isArray(node)) {
          queue.push(...node);
          continue;
        }
        if (typeof node !== 'object') continue;
        if (typeof node.headline === 'string' && normalize(node.headline).length >= 8) {
          jsonld = normalize(node.headline);
          break;
        }
        if (node['@graph']) queue.push(node['@graph']);
        if (node.mainEntity) queue.push(node.mainEntity);
        if (node.itemListElement) queue.push(node.itemListElement);
      }
    } catch (_) {}
  });

  return JSON.stringify({
    og: normalize(document.querySelector('meta[property="og:title"]')?.content || ''),
    twitter: normalize(document.querySelector('meta[name="twitter:title"]')?.content || ''),
    h1: normalize(document.querySelector('h1')?.innerText || ''),
    articleH2: normalize(document.querySelector('article h2, main h2, [itemprop="headline"], [class*="headline"] h2')?.innerText || ''),
    doc: normalize(document.title || ''),
    jsonld
  });
})();
''',
          )
          .timeout(const Duration(milliseconds: 900));
      final decoded = jsonDecode(result?.toString() ?? '{}');
      if (decoded is! Map) return fallback;
      final payload = Map<String, dynamic>.from(decoded);
      return _pickReaderTitleHint(
        rawUrl: currentUrl,
        fallbackTitle: fallback,
        payload: payload,
      );
    } catch (_) {
      return fallback;
    }
  }

  bool get _isSavedArticleOrigin =>
      widget.args.origin == WebViewOrigin.savedArticle;

  String? _offlineSnapshotHtml(NewsArticle article) {
    final raw = article.fullContent.trim();
    if (raw.isEmpty) return null;

    final content = _normalizeSnapshotPayload(raw);
    if (content.trim().isEmpty) return null;

    final hasHtmlDocument = RegExp(
      r'<\s*html[\s>]',
      caseSensitive: false,
    ).hasMatch(content);
    if (hasHtmlDocument) return content;

    final esc = const HtmlEscape();
    final safeTitle = esc.convert(article.title);
    final safeSource = esc.convert(article.url);

    return '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$safeTitle</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 16px; line-height: 1.65; color: #121212; }
      .offline-badge { display: inline-block; padding: 6px 10px; border-radius: 999px; background: #eef7f0; color: #17653a; font-size: 12px; font-weight: 700; margin-bottom: 10px; }
      .source-link { font-size: 12px; color: #335f9f; margin-bottom: 12px; word-break: break-all; }
      img { max-width: 100%; height: auto; border-radius: 8px; }
    </style>
  </head>
  <body>
    <div class="offline-badge">Offline snapshot</div>
    <div class="source-link">Source: <a href="$safeSource">$safeSource</a></div>
    $content
  </body>
</html>
''';
  }

  String _normalizeSnapshotPayload(String payload) {
    final trimmed = payload.trim();
    if (trimmed.length >= 2 &&
        ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
            (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) return decoded;
      } catch (_) {
        // Keep original payload if it is not JSON-encoded.
      }
    }
    return payload;
  }

  InAppWebViewInitialData? _initialSavedArticleData() {
    if (!_isSavedArticleOrigin) return null;
    final html = _offlineSnapshotHtml(_currentArticle);
    if (html == null) return null;
    final base = _safeUri(_currentArticle.url);
    if (base == null) return null;
    return InAppWebViewInitialData(
      data: html,
      baseUrl: WebUri(base.toString()),
      historyUrl: WebUri(base.toString()),
    );
  }

  Future<bool> _loadSavedArticleSnapshotIfAvailable() async {
    if (!_isSavedArticleOrigin || _ctrl == null) return false;
    final html = _offlineSnapshotHtml(_currentArticle);
    final base = _safeUri(_currentArticle.url);
    if (html == null || base == null) return false;

    try {
      await _ctrl!.loadData(
        data: html,
        baseUrl: WebUri(base.toString()),
        historyUrl: WebUri(base.toString()),
      );
      return true;
    } catch (e, s) {
      ref
          .read(structuredLoggerProvider)
          .warning('Failed to load offline snapshot', e, s);
      return false;
    }
  }

  bool _shouldUseConservativePolicy(Uri? uri) {
    final host = (uri?.host ?? '').toLowerCase();
    return host == 'kalerkantho.com' ||
        host.endsWith('.kalerkantho.com') ||
        host == 'prothomalo.com' ||
        host.endsWith('.prothomalo.com') ||
        host == 'thedailystar.net' ||
        host.endsWith('.thedailystar.net') ||
        host == 'bdnews24.com' ||
        host.endsWith('.bdnews24.com') ||
        host == 'dhakatribune.com' ||
        host.endsWith('.dhakatribune.com') ||
        host == 'banglatribune.com' ||
        host.endsWith('.banglatribune.com') ||
        host == 'jugantor.com' ||
        host.endsWith('.jugantor.com') ||
        host == 'manabzamin.com' ||
        host.endsWith('.manabzamin.com') ||
        host == 'tbsnews.net' ||
        host.endsWith('.tbsnews.net') ||
        host == 'engadget.com' ||
        host.endsWith('.engadget.com') ||
        host == 'techcrunch.com' ||
        host.endsWith('.techcrunch.com') ||
        host == 'yahoo.com' ||
        host.endsWith('.yahoo.com');
  }

  String _buildSiteSpecificScript(Uri? uri) {
    final host = (uri?.host ?? '').toLowerCase();
    if (host.isEmpty) return '';
    final hostSpecificSelectors = <String>[
      '[class*="ad-placeholder"]',
      '[id*="ad-placeholder"]',
      '[class*="adblock"]',
      '[id*="adblock"]',
      '[class*="google_ads"]',
      '[id*="google_ads"]',
      '[class*="dfp"]',
      '[id*="dfp"]',
      '[class*="sponsor"]',
      '[id*="sponsor"]',
    ];

    if (host.contains('bd-pratidin.com')) {
      hostSpecificSelectors.addAll(<String>[
        '.widget-ad',
        '.adblock',
        '.header-ad',
        '.article-ad',
      ]);
    }
    if (host.contains('kalerkantho.com') || host.contains('prothomalo.com')) {
      hostSpecificSelectors.addAll(<String>[
        '.google-ads',
        '.ad-wrapper',
        '.sponsor-box',
      ]);
    }
    if (host.contains('thedailystar.net') ||
        host.contains('dhakatribune.com')) {
      hostSpecificSelectors.addAll(<String>[
        '.dfp-ad',
        '.ad-placeholder',
        '.ad-label',
      ]);
    }
    final hostSpecificSelectorsJs = hostSpecificSelectors
        .map((selector) => "'$selector'")
        .join(',\n          ');

    // Compatibility cleanup for high-noise news pages.
    return '''
      (function() {
        if (window.__bdSitePolicyApplied) return;
        window.__bdSitePolicyApplied = true;

        const consentContainerSelectors = [
          '[id*="cookie"]', '[class*="cookie"]',
          '[id*="consent"]', '[class*="consent"]',
          '[id*="gdpr"]', '[class*="gdpr"]',
          '[id*="cmp"]', '[class*="cmp"]',
          '[id*="onetrust"]', '[class*="onetrust"]',
          '[id*="didomi"]', '[class*="didomi"]',
          '[id*="sp_message_container"]', '[class*="sp_message"]',
          '[aria-label*="cookie"]', '[aria-label*="consent"]',
          '[role="dialog"]'
        ];

        const consentActionSelectors = [
          'button',
          '[role="button"]',
          'input[type="button"]',
          'input[type="submit"]',
          'a'
        ];

        const consentAcceptWords = [
          'accept', 'accept all', 'agree', 'i agree', 'allow all', 'allow',
          'ok', 'okay', 'got it', 'continue',
          'গ্রহণ', 'সম্মতি', 'রাজি', 'ঠিক আছে', 'স্বীকার', 'অনুমতি'
        ];

        const consentRejectWords = [
          'reject', 'decline', 'deny', 'disagree', 'manage', 'preferences',
          'settings', 'customize', 'options', 'না', 'প্রত্যাখ্যান', 'না ধন্যবাদ'
        ];

        const removableSelectors = [
          '.cookie-banner', '.cookie-consent', '.consent', '.gdpr', '.newsletter',
          '.subscribe', '.social-share', '.share-tools', '.related', '.recommended',
          '.trending', '.most-popular', '.comments', '.comment-section',
          '.ad', '.ads', '.advertisement', '.sponsored', '.promo', '.ad-slot',
          '.ad-banner', '.ad-container', '.ad-wrapper', '.outbrain', '.taboola',
          '.teads', '.mgid',
          '[role="complementary"]', '[aria-label*="cookie"]', '[aria-label*="consent"]',
          '[class*="overlay"]', '[class*="popup"]', '[id*="overlay"]', '[id*="popup"]',
          '[id*="ad-"]', '[id^="ad_"]', '[id*="sponsored"]',
          '[class*=" ad-"]', '[class^="ad_"]', '[class*="sponsor"]',
          'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]',
          'iframe[src*="taboola"]', 'iframe[src*="outbrain"]', 'iframe[src*="ads"]'
        ];
        const hostSpecificSelectors = [
          $hostSpecificSelectorsJs
        ];
        removableSelectors.push(...hostSpecificSelectors);

        const normalize = (value) => String(value || '').toLowerCase().replace(/\\s+/g, ' ').trim();
        const hasAny = (haystack, needles) => needles.some((n) => haystack.includes(n));

        const hideElement = (el) => {
          if (!el || !el.style) return;
          try {
            el.style.setProperty('display', 'none', 'important');
            el.style.setProperty('pointer-events', 'none', 'important');
            el.style.setProperty('height', '0', 'important');
            el.style.setProperty('min-height', '0', 'important');
            el.style.setProperty('max-height', '0', 'important');
            el.style.setProperty('margin', '0', 'important');
            el.style.setProperty('padding', '0', 'important');
            el.style.setProperty('border', '0', 'important');
            el.style.setProperty('overflow', 'hidden', 'important');
            el.style.setProperty('opacity', '0', 'important');
            el.style.setProperty('visibility', 'hidden', 'important');
          } catch (_) {}
        };

        const collapseEmptyParents = (node) => {
          let parent = node && node.parentElement;
          let depth = 0;
          while (parent && depth < 3) {
            const text = String(parent.textContent || '').trim();
            const hasAnchorContent = !!parent.querySelector(
              'article,main,p,h1,h2,h3,h4,img,video'
            );
            if (!hasAnchorContent && text.length === 0) {
              hideElement(parent);
            }
            parent = parent.parentElement;
            depth += 1;
          }
        };

        const autoAcceptConsent = () => {
          let clicked = false;
          consentContainerSelectors.forEach((selector) => {
            document.querySelectorAll(selector).forEach((container) => {
              const scoped = [];
              consentActionSelectors.forEach((actionSel) => {
                container.querySelectorAll(actionSel).forEach((el) => scoped.push(el));
              });

              scoped.forEach((candidate) => {
                const text = normalize(
                  candidate.innerText ||
                  candidate.textContent ||
                  candidate.value ||
                  candidate.getAttribute('aria-label') ||
                  candidate.getAttribute('title')
                );
                if (!text) return;
                if (hasAny(text, consentRejectWords)) return;
                if (!hasAny(text, consentAcceptWords)) return;
                try {
                  candidate.click();
                  clicked = true;
                } catch (_) {}
              });
            });
          });
          return clicked;
        };

        const hideNoise = () => {
          removableSelectors.forEach((selector) => {
            document.querySelectorAll(selector).forEach((el) => {
              hideElement(el);
              collapseEmptyParents(el);
            });
          });

          document.querySelectorAll(
            '[id*="cookie"],[class*="cookie"],[id*="consent"],[class*="consent"],[id*="newsletter"],[class*="newsletter"],[id*="privacy"],[class*="privacy"],[id*="onetrust"],[class*="onetrust"],[id*="didomi"],[class*="didomi"]'
          ).forEach((el) => {
            hideElement(el);
            collapseEmptyParents(el);
          });
        };

        autoAcceptConsent();
        hideNoise();

        // Re-attempt consent click after early-render banners mount.
        setTimeout(() => {
          autoAcceptConsent();
          hideNoise();
        }, 450);

        const startObserver = () => {
          if (!document.body) return false;
          let mutations = 0;
          const maxMutations = 260;
          const observer = new MutationObserver((records) => {
            mutations += records.length;
            autoAcceptConsent();
            hideNoise();
            if (mutations >= maxMutations) {
              observer.disconnect();
            }
          });
          observer.observe(document.body, { childList: true, subtree: true });
          setTimeout(() => observer.disconnect(), 12000);
          return true;
        };

        if (!startObserver()) {
          window.addEventListener('DOMContentLoaded', startObserver, { once: true });
        }
      })();
    ''';
  }

  String _buildWebViewPolicyKey({required bool isPremium, Uri? uri}) {
    final host = (uri?.host ?? '').toLowerCase();
    final conservative = _shouldUseConservativePolicy(uri);
    return 'premium=$isPremium|host=$host|conservative=$conservative';
  }

  String _resolvePolicyScript({
    required bool isPremium,
    required bool dataSaver,
    Uri? uri,
  }) {
    final baseScript =
        _cachedBaseContentScript ?? _buildBaseContentScript(null);
    final premiumScript =
        _cachedPremiumContentScript ?? _buildPremiumContentScript(null);

    // CSS-based ad-blocking style (safe for all hosts).
    final adBlockingCssStyle = isPremium
        ? '''
(function() {
  const target = document.head || document.documentElement || document.body;
  if (!target) return;
  const existing = document.getElementById('bd-premium-ad-style');
  const adStyle = existing || document.createElement('style');
  adStyle.id = 'bd-premium-ad-style';
  adStyle.textContent = `$kPremiumAdCssSelectors {
    display:none!important;height:0!important;pointer-events:none!important;
  }`;
  if (!existing) target.appendChild(adStyle);
})();
'''
        : '';

    // Premium mode always uses the stronger cleanup script.
    String script = isPremium ? premiumScript : baseScript;

    // Always append the CSS blocking for premium users on ALL hosts.
    script += adBlockingCssStyle;
    script += _buildSiteSpecificScript(uri);

    if (dataSaver) {
      // Inject CSS to hide images and other large media to reduce layout shifts
      // and ensure a "clean" text-only experience.
      script += '''
(function() {
  const dsStyle = document.createElement('style');
  dsStyle.textContent = `
    img, video, audio, iframe, [style*="background-image"] { 
      display: none !important; 
    }
    picture, figure { display: none !important; }
  `;
  (document.head || document.documentElement).appendChild(dsStyle);
})();
''';
    }

    return script;
  }

  // ─────────────────────────────────────────────
  // READING SESSION
  // ─────────────────────────────────────────────
  void _recordReadingSession() {
    if (_startTime == null) return;
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    if (duration < 5) return;
    _userInterest.recordInteraction(
      article: _currentArticle,
      type: InteractionType.view,
    );
    // Fire-and-forget; no awaiting in dispose.
    _persistReadingHistory(duration);
  }

  Future<void> _persistReadingHistory(int durationSec) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('reading_history') ?? [];
    history.insert(
      0,
      json.encode({
        'url': _currentArticle.url,
        'title': _currentArticle.title,
        'timestamp': DateTime.now().toIso8601String(),
        'duration': durationSec,
      }),
    );
    if (history.length > 50) history.removeLast();
    await prefs.setStringList('reading_history', history);
  }

  /// Debounced – coalesces rapid scroll events into a single write.
  void _scheduleScrollSaveFor(String articleUrl) {
    _scheduledScrollSaveUrl = articleUrl;
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(
      WT.scrollSaveDebounce,
      () => _saveScrollPositionSync(articleUrl: _scheduledScrollSaveUrl),
    );
  }

  void _scheduleScrollSave() {
    _scheduleScrollSaveFor(_currentArticle.url);
  }

  void _saveScrollPositionSync({String? articleUrl}) {
    final targetUrl = articleUrl ?? _currentArticle.url;
    _ctrl?.getScrollY().then((y) async {
      if (y == null || y <= 0) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('scroll_$targetUrl', y);
    });
  }

  void _syncTtsFeedNavigationHooks() {
    _ttsManager.configureFeedNavigation(
      onPreviousFeedArticle: () async => _goToPrev(fromTtsControls: true),
      onNextFeedArticle: () async => _goToNext(fromTtsControls: true),
      canPreviousFeedArticle: () =>
          !_navInFlight && widget.articles != null && _currentIndex > 0,
      canNextFeedArticle: () =>
          !_navInFlight &&
          widget.articles != null &&
          _currentIndex < (widget.articles!.length - 1),
    );
  }

  Future<void> _restoreScrollPosition({String? articleUrl}) async {
    final targetUrl = articleUrl ?? _currentArticle.url;
    final prefs = await SharedPreferences.getInstance();
    final y = prefs.getInt('scroll_$targetUrl');
    if (y != null && y > 0) {
      // Schedule after layout so WebView has finished painting.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _ctrl?.scrollTo(x: 0, y: y, animated: true);
      });
    }
  }

  Future<void> _syncPremiumWebViewPolicy(
    bool isPremium,
    bool dataSaver, {
    bool force = false,
    Uri? policyUri,
  }) async {
    final controller = _ctrl;
    if (controller == null) return;
    final effectiveUri =
        policyUri ??
        _lastPolicyUri ??
        _safeUri(_currentArticle.url) ??
        _safeUri(widget.url);
    final policyKey =
        '${_buildWebViewPolicyKey(isPremium: isPremium, uri: effectiveUri)}|ds=$dataSaver';

    if (!force && _lastAppliedWebViewPolicyKey == policyKey) return;

    _lastKnownAdFreeState = isPremium;
    _lastKnownDataSaver = dataSaver;
    _lastPolicyUri = effectiveUri;
    _lastAppliedWebViewPolicyKey = policyKey;
    final conservativePolicy = _shouldUseConservativePolicy(effectiveUri);
    final blockers = buildWebViewContentBlockers(
      isPremium: isPremium,
      conservative: conservativePolicy,
      dataSaver: dataSaver,
    );
    if (kDebugMode) {
      ref
          .read(structuredLoggerProvider)
          .info('WebView ad policy synced', <String, dynamic>{
            'premium': isPremium,
            'host': effectiveUri?.host ?? '',
            'conservative': conservativePolicy,
            'dataSaver': dataSaver,
            'blockerCount': blockers.length,
          });
    }
    try {
      await controller.setSettings(
        settings: InAppWebViewSettings(
          useShouldInterceptRequest: blockers.isNotEmpty,
          contentBlockers: blockers,
          thirdPartyCookiesEnabled: !isPremium,
          // blockNetworkImages: dataSaver, // Removed - unsupported parameter
        ),
      );

      final script = _resolvePolicyScript(
        isPremium: isPremium,
        dataSaver: dataSaver,
        uri: effectiveUri,
      );
      await controller.evaluateJavascript(source: script);
    } catch (e, s) {
      ref
          .read(structuredLoggerProvider)
          .warning('Failed to sync premium WebView policy', e, s);
    }
  }

  // ─────────────────────────────────────────────
  // DIAGNOSTICS
  // ─────────────────────────────────────────────
  void _diagRegisterWebView(String url) {
    if (_diagnosticRegistered) return;
    _diagnostics?.registerWebView(_diagnosticWebViewId, url: url);
    _diagnosticRegistered = true;
  }

  void _diagMarkNavigation(String? url) {
    if (url == null) return;
    if (!_diagnosticRegistered) {
      _diagnostics?.registerWebView(_diagnosticWebViewId, url: url);
      _diagnosticRegistered = true;
    } else {
      _diagnostics?.markWebViewNavigation(_diagnosticWebViewId, url: url);
    }
  }

  void _diagUnregisterWebView() {
    if (!_diagnosticRegistered) return;
    _diagnosticRegistered = false;
    _diagnostics?.unregisterWebView(_diagnosticWebViewId);
  }

  // ─────────────────────────────────────────────
  // TTS HIGHLIGHT
  // ─────────────────────────────────────────────
  Future<void> _highlightText(String text) async {
    if (_ctrl == null) return;
    final safe = text
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', ' ')
        .trim();
    final snippet = safe.length > 60 ? safe.substring(0, 60) : safe;

    const jsTemplate = r"""
(function(snippet) {
  const prev = document.querySelector('.tts-highlight');
  if (prev) {
    prev.classList.remove('tts-highlight');
    prev.style.backgroundColor = 'transparent';
  }
  const walker = document.createTreeWalker(
    document.body, NodeFilter.SHOW_TEXT);
  let node;
  while (node = walker.nextNode()) {
    if (node.textContent.includes(snippet)) {
      const p = node.parentElement;
      if (p && !['SCRIPT','STYLE'].includes(p.tagName)) {
        p.classList.add('tts-highlight');
        p.style.backgroundColor = 'rgba(212,168,83,0.30)';
        p.style.transition = 'background-color 0.4s ease';
        p.scrollIntoView({ behavior:'smooth', block:'center' });
        break;
      }
    }
  }
})('""";

    try {
      await _ctrl!.evaluateJavascript(source: "$jsTemplate$snippet');");
    } catch (e, s) {
      ref.read(structuredLoggerProvider).warning('TTS highlight failed', e, s);
    }
  }

  // ─────────────────────────────────────────────
  // FIND IN PAGE & NAVIGATION UTILS
  // ─────────────────────────────────────────────
  void _showFindInPage() {
    setState(() {
      _showFindBar = true;
    });
  }

  void _findNext() {
    _ctrl?.findNext(forward: true);
  }

  void _findPrevious() {
    _ctrl?.findNext(forward: false);
  }

  void _closeFind() {
    _ctrl?.clearMatches();
    setState(() {
      _showFindBar = false;
      _findController.clear();
      _findMatchesCount = 0;
      _findActiveMatchIndex = 0;
    });
  }

  void _scrollToTop() {
    _ctrl?.scrollTo(x: 0, y: 0, animated: true);
  }

  Widget _buildFindInPageBar(ColorScheme cs) {
    if (!_showFindBar) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _findController,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Find in page...',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) {
                if (val.isNotEmpty) {
                  _ctrl?.findAllAsync(find: val);
                } else {
                  _ctrl?.clearMatches();
                  setState(() {
                    _findMatchesCount = 0;
                    _findActiveMatchIndex = 0;
                  });
                }
              },
            ),
          ),
          if (_findMatchesCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_findActiveMatchIndex + 1}/$_findMatchesCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            onPressed: _findPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            onPressed: _findNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: _closeFind,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────
  void _shareUrl() =>
      Share.share(_currentArticle.url, subject: _currentArticle.title);

  void _toggleFavorite() {
    ref.read(favoritesProvider.notifier).toggleArticle(_currentArticle);
    ref
        .read(userInterestProvider)
        .recordInteraction(
          article: _currentArticle,
          type: InteractionType.bookmark,
        );
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleOfflineSave() async {
    final notifier = ref.read(savedArticlesProvider.notifier);
    final isSaved = notifier.isSaved(_currentArticle.url);
    final loc = AppLocalizations.of(context);

    if (isSaved) {
      final ok = await notifier.removeArticle(_currentArticle.url);
      _snack(
        ok ? loc.removedFromOffline : loc.failedToRemove,
        ok ? Colors.orange : Colors.red,
      );
    } else {
      _snack(loc.savingForOffline, null, duration: const Duration(seconds: 1));
      String? html;
      try {
        html = await _ctrl?.evaluateJavascript(
          source: 'document.body.innerHTML',
        );
      } catch (_) {}
      final ok = await notifier.saveArticle(
        _currentArticle.copyWith(
          fullContent: html ?? _currentArticle.fullContent,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _snack(
          ok ? loc.articleSavedOffline : loc.failedToSaveArticle,
          ok ? Colors.green : Colors.red,
        );
      }
    }
  }

  void _snack(
    String msg,
    Color? color, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showTranslateSheet() async {
    final isPremium = ref.read(isPremiumStateProvider);
    final loc = AppLocalizations.of(context);
    if (!isPremium) {
      _snack(loc.premiumFeatInfo, null);
      return;
    }
    if (!mounted) return;

    final engine = await showModalBottomSheet<TranslateEngine>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => WebTranslateSheet(url: _currentArticle.url),
    );
    if (engine == null || _ctrl == null) return;

    final u = switch (engine) {
      TranslateEngine.google =>
        'https://translate.google.com/translate?sl=auto&tl=bn&u=${Uri.encodeComponent(_currentArticle.url)}',
      TranslateEngine.bing =>
        'https://www.microsofttranslator.com/bv.aspx?from=auto&to=bn&a=${Uri.encodeComponent(_currentArticle.url)}',
      TranslateEngine.deepl =>
        'https://www.deepl.com/translator#auto/bn/${Uri.encodeComponent(_currentArticle.url)}',
    };
    try {
      await _loadUrlWithPolicy(u);
    } catch (e) {
      _snack('Translate failed: $e', Colors.red);
    }
  }

  bool _hasActiveWebViewTtsSession() {
    final session = _ttsManager.currentSession;
    if (session == null) return false;
    switch (session.state) {
      case TtsSessionState.idle:
      case TtsSessionState.completed:
      case TtsSessionState.stopped:
      case TtsSessionState.error:
        return false;
      case TtsSessionState.preparing:
      case TtsSessionState.chunking:
      case TtsSessionState.generating:
      case TtsSessionState.buffering:
      case TtsSessionState.playing:
      case TtsSessionState.paused:
      case TtsSessionState.recovering:
        return true;
    }
  }

  String _detectLanguageForTts(String text) {
    return RegExp(r'[\u0980-\u09FF]').hasMatch(text) ? 'bn' : 'en';
  }

  String _normalizeExtractedText(String raw) {
    var text = raw.trim();
    if ((text.startsWith('"') && text.endsWith('"')) ||
        (text.startsWith("'") && text.endsWith("'"))) {
      text = text.substring(1, text.length - 1);
    }

    return text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  IconData _resolveHeaderTtsIcon({
    required bool isReaderMode,
    required TtsStatus readerTtsStatus,
  }) {
    if (isReaderMode) {
      if (readerTtsStatus == TtsStatus.playing ||
          readerTtsStatus == TtsStatus.buffering ||
          readerTtsStatus == TtsStatus.loading) {
        return Icons.pause_circle_filled_rounded;
      }
      if (readerTtsStatus == TtsStatus.paused) {
        return Icons.play_circle_filled_rounded;
      }
      return Icons.headset_rounded;
    }

    final session = _ttsManager.currentSession;
    if (session == null) return Icons.headset_rounded;
    switch (session.state) {
      case TtsSessionState.paused:
        return Icons.play_circle_filled_rounded;
      case TtsSessionState.preparing:
      case TtsSessionState.chunking:
      case TtsSessionState.generating:
      case TtsSessionState.buffering:
      case TtsSessionState.playing:
      case TtsSessionState.recovering:
        return Icons.pause_circle_filled_rounded;
      case TtsSessionState.idle:
      case TtsSessionState.completed:
      case TtsSessionState.stopped:
      case TtsSessionState.error:
        return Icons.headset_rounded;
    }
  }

  Future<void> _showTtsSettingsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TtsSettingsSheet(
        articleLanguage: _detectLanguageForTts(_currentArticle.title),
      ),
    );
  }

  Future<void> _toggleTtsIntegration({required bool isReaderMode}) async {
    final isPremium = ref.read(isPremiumStateProvider);
    final loc = AppLocalizations.of(context);
    final reader = ref.read(readerControllerProvider.notifier);
    if (isReaderMode) {
      final readerTtsState = ref.read(ttsControllerProvider);
      if (readerTtsState.status == TtsStatus.playing ||
          readerTtsState.status == TtsStatus.buffering ||
          readerTtsState.status == TtsStatus.loading) {
        reader.pauseTts();
      } else if (readerTtsState.status == TtsStatus.paused) {
        reader.resumeTts();
      } else if (!isPremium) {
        _snack(loc.premiumFeatInfo, null);
      } else {
        await reader.playFullArticle();
      }
      if (mounted) setState(() {});
      return;
    }

    final session = _ttsManager.currentSession;
    if (session != null) {
      switch (session.state) {
        case TtsSessionState.paused:
          await _ttsManager.resume();
          if (mounted) setState(() {});
          return;
        case TtsSessionState.preparing:
        case TtsSessionState.chunking:
        case TtsSessionState.generating:
        case TtsSessionState.buffering:
        case TtsSessionState.playing:
        case TtsSessionState.recovering:
          await _ttsManager.pause();
          if (mounted) setState(() {});
          return;
        case TtsSessionState.idle:
        case TtsSessionState.completed:
        case TtsSessionState.stopped:
        case TtsSessionState.error:
          break;
      }
    }

    if (!isPremium) {
      _snack(loc.premiumFeatInfo, null);
      return;
    }

    if (_ctrl == null) {
      _snack('Page is still loading', Colors.red);
      return;
    }

    String text = _normalizeExtractedText(
      await _webViewTextExtractor.extract(_ctrl),
    );
    if (text.isEmpty) {
      try {
        final fallback = await _ctrl!.evaluateJavascript(
          source: 'document.body?.innerText ?? ""',
        );
        text = _normalizeExtractedText(fallback?.toString() ?? '');
      } catch (_) {}
    }

    if (text.isEmpty) {
      _snack('Could not extract readable text for TTS', Colors.red);
      return;
    }

    await _ttsManager.speakArticle(
      _currentArticle.url,
      _currentArticle.title,
      text,
      language: _detectLanguageForTts(text),
      author: _currentArticle.source.isNotEmpty ? _currentArticle.source : null,
    );
    if (mounted) setState(() {});
  }

  Future<void> _handleReaderToggle() async {
    final isPremium = ref.read(isPremiumStateProvider);
    final loc = AppLocalizations.of(context);
    final readerState = ref.read(readerControllerProvider);
    final enteringReaderMode = !readerState.isReaderMode;
    if (enteringReaderMode && !isPremium) {
      _snack(loc.premiumFeatInfo, null);
      return;
    }
    if (enteringReaderMode && _hasActiveWebViewTtsSession()) {
      await _ttsManager.stop();
    }
    final titleHint = await _resolveReaderTitleHint();
    await ref
        .read(readerControllerProvider.notifier)
        .toggleReaderMode(urlHint: _currentArticle.url, titleHint: titleHint);
    final updatedReader = ref.read(readerControllerProvider);
    if (enteringReaderMode &&
        !updatedReader.isReaderMode &&
        updatedReader.errorCode == 'reader_unsupported_page_type') {
      _snack(
        updatedReader.errorMessage ??
            'Reader mode is unavailable for this page type.',
        Colors.orange,
      );
    }
    if (enteringReaderMode) {
      await _pauseWebViewBackgroundWork();
    } else {
      await _resumeWebViewBackgroundWork();
    }
    if (mounted) setState(() {});
  }

  Future<void> _pauseWebViewBackgroundWork() async {
    final controller = _ctrl;
    if (controller == null) return;
    try {
      await controller.pauseTimers();
    } catch (_) {}
    try {
      await controller.pauseAllMediaPlayback();
    } catch (_) {}
    try {
      await controller.evaluateJavascript(
        source: '''
          (() => {
            try {
              document.querySelectorAll('video,audio').forEach((m) => {
                try { m.pause(); } catch(_) {}
              });
            } catch(_) {}
          })();
        ''',
      );
    } catch (_) {}
  }

  Future<void> _resumeWebViewBackgroundWork() async {
    final controller = _ctrl;
    if (controller == null) return;
    try {
      await controller.resumeTimers();
    } catch (_) {}
  }

  _FeedNavTtsCarryState _captureFeedNavTtsCarryState({
    required bool isReaderMode,
  }) {
    if (isReaderMode) {
      final ttsState = ref.read(ttsControllerProvider);
      if (ttsState.status == TtsStatus.playing) {
        return _FeedNavTtsCarryState.playing;
      }
      if (ttsState.status == TtsStatus.paused) {
        return _FeedNavTtsCarryState.paused;
      }
      final readerState = ref.read(readerControllerProvider);
      if (readerState.currentChunkIndex >= 0) {
        return _FeedNavTtsCarryState.playing;
      }
      return _FeedNavTtsCarryState.inactive;
    }

    final session = _ttsManager.currentSession;
    if (session == null) return _FeedNavTtsCarryState.inactive;
    switch (session.state) {
      case TtsSessionState.paused:
        return _FeedNavTtsCarryState.paused;
      case TtsSessionState.preparing:
      case TtsSessionState.chunking:
      case TtsSessionState.generating:
      case TtsSessionState.buffering:
      case TtsSessionState.playing:
      case TtsSessionState.recovering:
        return _FeedNavTtsCarryState.playing;
      case TtsSessionState.idle:
      case TtsSessionState.completed:
      case TtsSessionState.stopped:
      case TtsSessionState.error:
        return _FeedNavTtsCarryState.inactive;
    }
  }

  Future<void> _prepareReaderNavigationForTts({
    required bool isReaderMode,
    required _FeedNavTtsCarryState carryState,
  }) async {
    _pendingReaderRefreshAfterArticleNav = isReaderMode;
    _pendingTtsRestartAfterArticleNav =
        isReaderMode && carryState == _FeedNavTtsCarryState.playing;

    if (carryState == _FeedNavTtsCarryState.inactive) return;

    if (isReaderMode) {
      ref.read(readerControllerProvider.notifier).stopTts();
    }
    await _ttsManager.stop();
  }

  void _resetPendingReaderNavigationState() {
    _pendingReaderRefreshAfterArticleNav = false;
    _pendingTtsRestartAfterArticleNav = false;
    _pendingReaderRefreshInFlight = false;
  }

  void _beginPendingPageLoad(String targetUrl) {
    if (_pendingPageLoadCompleter != null &&
        !_pendingPageLoadCompleter!.isCompleted) {
      _pendingPageLoadCompleter!.complete();
    }
    _pendingPageLoadUrl = targetUrl;
    _pendingPageLoadCompleter = Completer<void>();
  }

  Future<void> _waitForPendingPageLoad({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final completer = _pendingPageLoadCompleter;
    if (completer == null) return;

    try {
      await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Timed out while loading ${_pendingPageLoadUrl ?? 'page'}',
            timeout,
          );
        },
      );
    } finally {
      if (identical(_pendingPageLoadCompleter, completer)) {
        _pendingPageLoadCompleter = null;
        _pendingPageLoadUrl = null;
      }
    }
  }

  Duration _pendingPageLoadTimeout({String? rawUrl}) {
    final networkTimeout = ref
        .read(appNetworkServiceProvider)
        .getAdaptiveTimeout();
    var timeout = networkTimeout + const Duration(seconds: 2);
    final host = (Uri.tryParse(rawUrl ?? '')?.host ?? '').toLowerCase();
    if (host.contains('bd-pratidin.com') ||
        host.contains('thedailystar.net') ||
        host.contains('prothomalo.com')) {
      timeout += const Duration(seconds: 3);
    }
    if (timeout < const Duration(seconds: 8)) {
      return const Duration(seconds: 8);
    }
    if (timeout > const Duration(seconds: 30)) {
      return const Duration(seconds: 30);
    }
    return timeout;
  }

  void _completePendingPageLoad() {
    final completer = _pendingPageLoadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _failPendingPageLoad(Object error) {
    final completer = _pendingPageLoadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  void _markReaderRefreshFailure(String message) {
    if (!_pendingReaderRefreshAfterArticleNav) return;
    _resetPendingReaderNavigationState();
    ref
        .read(readerControllerProvider.notifier)
        .markExtractionFailure(
          message: message,
          errorCode: 'webview_load_timeout',
        );
  }

  Future<bool> _refreshReaderAfterArticleNav({
    required String trigger,
    bool failIfNoArticle = false,
  }) async {
    if (!_pendingReaderRefreshAfterArticleNav) return true;
    if (_pendingReaderRefreshInFlight) return false;
    _pendingReaderRefreshInFlight = true;
    try {
      final reader = ref.read(readerControllerProvider.notifier);
      final titleHint = await _resolveReaderTitleHint();
      await reader.extractContent(
        urlHint: _currentArticle.url,
        titleHint: titleHint,
      );
      final refreshed = ref.read(readerControllerProvider);
      final hasArticle =
          refreshed.article != null && refreshed.chunks.isNotEmpty;

      if (!hasArticle) {
        if (refreshed.errorCode == 'reader_unsupported_page_type') {
          _resetPendingReaderNavigationState();
          return false;
        }
        if (failIfNoArticle) {
          _markReaderRefreshFailure(
            'Reader mode could not extract this article cleanly. Tap Retry Reader.',
          );
        }
        return false;
      }

      if (_pendingTtsRestartAfterArticleNav) {
        await reader.playFullArticle();
      }
      _resetPendingReaderNavigationState();
      ref.read(structuredLoggerProvider).info(
        'Reader refresh after article navigation succeeded',
        <String, dynamic>{'trigger': trigger, 'url': _currentArticle.url},
      );
      return true;
    } finally {
      _pendingReaderRefreshInFlight = false;
    }
  }

  Future<void> _rollbackFailedFeedNavigation({
    required int previousIndex,
    required NewsArticle previousArticle,
    required bool wasReaderMode,
  }) async {
    if (mounted) {
      setState(() {
        _currentIndex = previousIndex;
        _currentArticle = previousArticle;
        _progressNotifier.value = 0;
      });
    } else {
      _currentIndex = previousIndex;
      _currentArticle = previousArticle;
      _progressNotifier.value = 0;
    }
    _resetPendingReaderNavigationState();
    try {
      await _ctrl?.stopLoading();
    } catch (_) {}

    try {
      await _loadUrlWithPolicy(previousArticle.url);
    } catch (_) {}

    if (!wasReaderMode) return;

    try {
      final reader = ref.read(readerControllerProvider.notifier);
      final titleHint = await _resolveReaderTitleHint();
      await reader.extractContent(
        urlHint: previousArticle.url,
        titleHint: titleHint,
      );
    } catch (_) {}
  }

  Future<void> _navigateFeedArticle({
    required _FeedNavDirection direction,
    bool fromTtsControls = false,
  }) async {
    final articles = widget.articles;
    if (articles == null || articles.isEmpty) return;
    if (_navInFlight) return;

    final delta = direction == _FeedNavDirection.next ? 1 : -1;
    final targetIndex = _currentIndex + delta;
    if (targetIndex < 0 || targetIndex >= articles.length) return;

    final previousIndex = _currentIndex;
    final previousArticle = _currentArticle;
    final targetArticle = articles[targetIndex];
    final navToken = ++_navTransactionToken;
    final isReaderMode = ref.read(readerControllerProvider).isReaderMode;
    final ttsCarryState = _captureFeedNavTtsCarryState(
      isReaderMode: isReaderMode,
    );
    final directionLabel = direction == _FeedNavDirection.next
        ? 'next'
        : 'prev';

    setState(() => _navInFlight = true);

    try {
      if (fromTtsControls || ttsCarryState != _FeedNavTtsCarryState.inactive) {
        await _prepareReaderNavigationForTts(
          isReaderMode: isReaderMode,
          carryState: ttsCarryState,
        );
      } else if (isReaderMode) {
        _pendingReaderRefreshAfterArticleNav = true;
        _pendingReaderRefreshInFlight = false;
      }

      if (isReaderMode) {
        ref.read(readerControllerProvider.notifier).clearState();
      }

      _scheduleScrollSaveFor(previousArticle.url);
      _recordReadingSession();
      setState(() {
        _currentIndex = targetIndex;
        _currentArticle = targetArticle;
        _progressNotifier.value = 0;
      });

      final loadedInApp = await _loadUrlWithRetry(targetArticle.url);
      if (!loadedInApp) {
        await _rollbackFailedFeedNavigation(
          previousIndex: previousIndex,
          previousArticle: previousArticle,
          wasReaderMode: isReaderMode,
        );
        _snack('This article cannot be loaded inside the app.', Colors.orange);
        return;
      }

      if (isReaderMode) {
        final refreshed = await _refreshReaderAfterArticleNav(
          trigger: 'post_navigation_$directionLabel',
          failIfNoArticle: true,
        );
        if (!refreshed) {
          await _rollbackFailedFeedNavigation(
            previousIndex: previousIndex,
            previousArticle: previousArticle,
            wasReaderMode: true,
          );
          _snack(
            'Reader mode could not load this article. Staying on previous article.',
            Colors.orange,
          );
          return;
        }
      }

      _diagMarkNavigation(targetArticle.url);
    } on TimeoutException {
      await _rollbackFailedFeedNavigation(
        previousIndex: previousIndex,
        previousArticle: previousArticle,
        wasReaderMode: isReaderMode,
      );
      _snack(
        'This article is loading too slowly. Please retry or refresh.',
        Colors.orange,
      );
    } catch (e, s) {
      ref
          .read(structuredLoggerProvider)
          .warning('Feed article navigation failed ($directionLabel)', e, s);
      await _rollbackFailedFeedNavigation(
        previousIndex: previousIndex,
        previousArticle: previousArticle,
        wasReaderMode: isReaderMode,
      );
      _snack(
        direction == _FeedNavDirection.next
            ? 'Failed to load the next article.'
            : 'Failed to load the previous article.',
        Colors.red,
      );
    } finally {
      if (mounted && navToken == _navTransactionToken) {
        setState(() => _navInFlight = false);
      } else {
        _navInFlight = false;
      }
    }
  }

  Future<void> _goToNext({bool fromTtsControls = false}) async {
    await _navigateFeedArticle(
      direction: _FeedNavDirection.next,
      fromTtsControls: fromTtsControls,
    );
  }

  Future<void> _goToPrev({bool fromTtsControls = false}) async {
    await _navigateFeedArticle(
      direction: _FeedNavDirection.previous,
      fromTtsControls: fromTtsControls,
    );
  }

  Future<bool> _loadUrlWithRetry(String rawUrl) async {
    try {
      return await _loadUrlWithPolicy(rawUrl, waitForLoadStop: true);
    } on TimeoutException {
      await _ctrl?.stopLoading();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _loadUrlWithPolicy(rawUrl, waitForLoadStop: true);
    }
  }

  Future<bool> _loadUrlWithPolicy(
    String rawUrl, {
    bool waitForLoadStop = false,
  }) async {
    if (await _loadSavedArticleSnapshotIfAvailable()) {
      return true;
    }

    final decision = UrlSafetyPolicy.evaluate(rawUrl);
    switch (decision.disposition) {
      case UrlSafetyDisposition.allowInApp:
        final uri = decision.uri;
        if (_ctrl != null && uri != null) {
          if (waitForLoadStop) {
            _beginPendingPageLoad(uri.toString());
          }
          await _ctrl!.loadUrl(
            urlRequest: URLRequest(url: WebUri(uri.toString())),
          );
          if (waitForLoadStop) {
            await _waitForPendingPageLoad(
              timeout: _pendingPageLoadTimeout(rawUrl: uri.toString()),
            );
          }
          return true;
        }
        return false;
      case UrlSafetyDisposition.openExternal:
        final uri = decision.uri;
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return false;
      case UrlSafetyDisposition.reject:
        _snack('Blocked unsafe link', Colors.red);
        return false;
    }
  }

  Future<NavigationActionPolicy> _handleNavigation(Uri? uri) async {
    if (uri == null) {
      return NavigationActionPolicy.CANCEL;
    }

    final decision = UrlSafetyPolicy.evaluateUri(uri);
    switch (decision.disposition) {
      case UrlSafetyDisposition.allowInApp:
        return NavigationActionPolicy.ALLOW;
      case UrlSafetyDisposition.openExternal:
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationActionPolicy.CANCEL;
      case UrlSafetyDisposition.reject:
        _snack('Blocked unsafe link', Colors.red);
        return NavigationActionPolicy.CANCEL;
    }
  }

  Widget _buildReaderLoadFallback(ColorScheme cs, ReaderState readerState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 30, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              readerState.errorMessage ??
                  'Reader mode is unavailable for this page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => unawaited(() async {
                final titleHint = await _resolveReaderTitleHint();
                await ref
                    .read(readerControllerProvider.notifier)
                    .extractContent(
                      urlHint: _currentArticle.url,
                      titleHint: titleHint,
                    );
              }()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Reader'),
            ),
            TextButton(
              onPressed: () => unawaited(_handleReaderToggle()),
              child: const Text('Show Web Page'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final perf = PerformanceConfig.of(context);
    final readerState = ref.watch(readerControllerProvider);
    final readerTtsStatus = ref.watch(
      ttsControllerProvider.select((state) => state.status),
    );
    final isReader = readerState.isReaderMode;
    final isLoading = readerState.isLoading;
    final shouldShowAds = ref.watch(shouldShowAdsProvider);
    final adFreePolicy = !shouldShowAds;
    final initialSavedData = _initialSavedArticleData();

    final dataSaver = ref.watch(dataSaverProvider);

    // If premium state or data saver flips, we may need to reconsider settings.
    if (_lastKnownAdFreeState != adFreePolicy ||
        _lastKnownDataSaver != dataSaver) {
      _lastKnownAdFreeState = adFreePolicy;
      _lastKnownDataSaver = dataSaver;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncPremiumWebViewPolicy(adFreePolicy, dataSaver, force: true);
      });
    }

    ref.listen<bool>(shouldShowAdsProvider, (prev, next) {
      if (prev == next) return;
      final adFree = !next;
      unawaited(_syncPremiumWebViewPolicy(adFree, dataSaver, force: true));
      // When user becomes ad-free, reload once so old ad payloads cannot linger.
      if (prev == true && next == false && _ctrl != null) {
        unawaited(_ctrl!.reload());
      }
    });

    ref.listen(readerControllerProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _snack(next.errorMessage!, Colors.red);
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final now = DateTime.now();
          if (_lastBackPressed == null ||
              now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
            _lastBackPressed = now;
            _snack(
              AppLocalizations.of(context).swipeAgainToExit,
              null,
              duration: const Duration(milliseconds: 1500),
            );
            return;
          }
          if (context.mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: cs.surface,
          floatingActionButton: _showScrollToTop
              ? FloatingActionButton.small(
                  backgroundColor: cs.primaryContainer.withOpacity(0.9),
                  onPressed: _scrollToTop,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: cs.onPrimaryContainer,
                  ),
                )
              : null,
          // ── Premium bottom toolbar ─────────────────────
          bottomNavigationBar: RepaintBoundary(
            child: WebBottomToolbar(
              article: _currentArticle,
              reduceEffects: perf.reduceEffects || perf.lowPowerMode,
              cs: cs,
              onBack: () async {
                if (isReader) {
                  if (widget.articles != null && _currentIndex > 0) {
                    await _goToPrev();
                    return;
                  }
                  _snack('No previous article', null);
                  return;
                }
                if (await _ctrl?.canGoBack() ?? false) {
                  _ctrl?.goBack();
                  return;
                }
                if (widget.articles != null && _currentIndex > 0) {
                  await _goToPrev();
                  return;
                }
                _snack('No previous page', null);
              },
              onForward: () async {
                if (isReader) {
                  if (widget.articles != null &&
                      _currentIndex < (widget.articles!.length - 1)) {
                    await _goToNext();
                    return;
                  }
                  _snack('No next article', null);
                  return;
                }
                if (await _ctrl?.canGoForward() ?? false) {
                  _ctrl?.goForward();
                  return;
                }
                if (widget.articles != null &&
                    _currentIndex < (widget.articles!.length - 1)) {
                  await _goToNext();
                  return;
                }
                _snack('No next page', null);
              },
              onFavorite: _toggleFavorite,
              onOfflineSave: _toggleOfflineSave,
              onRefresh: () {
                if (_ctrl == null) {
                  _snack('Page is still loading', Colors.orange);
                  return;
                }
                _ctrl?.reload();
              },
              onFind: () {
                if (_ctrl == null) {
                  _snack(
                    'Search is unavailable until page loads',
                    Colors.orange,
                  );
                  return;
                }
                _showFindInPage();
              },
            ),
          ),
          body: Column(
            children: [
              // ── Premium header ─────────────────────────
              RepaintBoundary(
                child: WebHeader(
                  article: _currentArticle,
                  progressNotifier: _progressNotifier,
                  reduceEffects: perf.reduceEffects || perf.lowPowerMode,
                  cs: cs,
                  isReader: isReader,
                  onBack: () => Navigator.of(context).pop(),
                  onReaderToggle: () => unawaited(_handleReaderToggle()),
                  onTtsToggle: () =>
                      unawaited(_toggleTtsIntegration(isReaderMode: isReader)),
                  ttsIcon: _resolveHeaderTtsIcon(
                    isReaderMode: isReader,
                    readerTtsStatus: readerTtsStatus,
                  ),
                  onTtsSettings: () => unawaited(_showTtsSettingsSheet()),
                  onTranslate: isReader ? null : _showTranslateSheet,
                  onShare: _shareUrl,
                ),
              ),

              _buildFindInPageBar(cs),

              // ── Web content ──────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    // WebView – kept alive via Offstage (not rebuild) in
                    // reader mode so page state is preserved.
                    Offstage(
                      offstage: isReader,
                      child: InAppWebView(
                        initialData: initialSavedData,
                        initialUrlRequest: initialSavedData == null
                            ? URLRequest(url: WebUri(widget.url))
                            : null,
                        pullToRefreshController: _ptrCtrl,
                        initialSettings: _buildWebViewSettings(
                          isPremium: adFreePolicy,
                          perf: perf,
                          dataSaver: dataSaver,
                          currentUri: _safeUri(_currentArticle.url),
                        ),
                        onFindResultReceived:
                            (
                              controller,
                              activeMatchIndex,
                              numberOfMatches,
                              isDoneCounting,
                            ) {
                              if (isDoneCounting) {
                                setState(() {
                                  _findMatchesCount = numberOfMatches;
                                  _findActiveMatchIndex = activeMatchIndex;
                                });
                              }
                            },
                        onWebViewCreated: (c) {
                          _ctrl = c;
                          _diagRegisterWebView(_currentArticle.url);
                          unawaited(
                            _syncPremiumWebViewPolicy(
                              adFreePolicy,
                              dataSaver,
                              force: true,
                              policyUri: _safeUri(_currentArticle.url),
                            ),
                          );
                        },
                        onLoadStart: (_, uri) {
                          _startTime = DateTime.now();
                          _progressNotifier.value = 0;
                          final currentUri = _safeUri(uri?.toString());
                          _lastPolicyUri = currentUri;
                          _diagMarkNavigation(uri?.toString());
                          unawaited(
                            _syncPremiumWebViewPolicy(
                              adFreePolicy,
                              dataSaver,
                              policyUri: currentUri,
                            ),
                          );
                        },
                        onProgressChanged: (_, p) {
                          // Throttle: update only once per frame (~16 ms).
                          final nowMs = DateTime.now().millisecondsSinceEpoch;
                          if (nowMs - _lastProgressUpdateMs >=
                              WT.progressThrottleMs) {
                            _lastProgressUpdateMs = nowMs;
                            _progressNotifier.value = p / 100;
                          }
                          if (p >= 100) {
                            _completePendingPageLoad();
                          }
                        },
                        onLoadStop: (controller, uri) async {
                          _ptrCtrl.endRefreshing();
                          _progressNotifier.value = 1.0;
                          _completePendingPageLoad();

                          // Inject style + optional premium cleanup script.
                          final currentUri = _safeUri(uri?.toString());
                          _lastPolicyUri = currentUri;
                          final script = _resolvePolicyScript(
                            isPremium: adFreePolicy,
                            dataSaver: dataSaver,
                            uri: currentUri,
                          );
                          try {
                            await controller.evaluateJavascript(source: script);
                          } catch (e, s) {
                            ref
                                .read(structuredLoggerProvider)
                                .warning(
                                  'WebView policy script inject failed',
                                  e,
                                  s,
                                );
                          }
                          if (ref.read(readerControllerProvider).isReaderMode) {
                            await _pauseWebViewBackgroundWork();
                          }

                          ref
                              .read(readerControllerProvider.notifier)
                              .setWebViewController(controller);
                          await _restoreScrollPosition(
                            articleUrl: uri?.toString(),
                          );

                          _diagMarkNavigation(uri?.toString());
                        },
                        onRenderProcessGone: (_, detail) {
                          _failPendingPageLoad(
                            StateError('WebView render process restarted'),
                          );
                          ref.read(structuredLoggerProvider).warn(
                            'WebView render process gone',
                            <String, dynamic>{
                              'didCrash': detail.didCrash,
                              'host':
                                  (_lastPolicyUri?.host ??
                                          _safeUri(_currentArticle.url)?.host ??
                                          '')
                                      .toLowerCase(),
                              'isEmulator': perf.isEmulator,
                              'useHybridComposition':
                                  perf.isEmulator ||
                                  perf.isLowEndDevice ||
                                  perf.lowPowerMode ||
                                  _shouldUseConservativePolicy(
                                    _lastPolicyUri ??
                                        _safeUri(_currentArticle.url),
                                  ),
                            },
                          );
                          _snack(
                            'WebView restarted for stability',
                            Colors.orange,
                          );
                          final webCtrl = _ctrl;
                          if (webCtrl != null) {
                            unawaited(webCtrl.reload());
                          }
                        },
                        onLoadError: (controller, request, errorType, error) {
                          _failPendingPageLoad(
                            StateError('WebView load error: $errorType'),
                          );
                          ref
                              .read(structuredLoggerProvider)
                              .warn('WebView load error', <String, dynamic>{
                                'errorType': errorType.toString(),
                                'error': error.toString(),
                                'host': request?.host ?? '',
                                'isEmulator': perf.isEmulator,
                              });
                          _markReaderRefreshFailure(
                            'Reader mode failed to load this page. Tap Retry Reader.',
                          );
                          _snack('Failed to load page', Colors.red);
                        },
                        onReceivedHttpError: (controller, request, errorResponse) {
                          _failPendingPageLoad(
                            StateError(
                              'WebView http error: ${errorResponse.statusCode}',
                            ),
                          );
                        },
                        shouldOverrideUrlLoading: (_, action) async {
                          final uri = action.request.url == null
                              ? null
                              : Uri.tryParse(action.request.url.toString());
                          return _handleNavigation(uri);
                        },
                        onScrollChanged: (controller, x, y) {
                          _scheduleScrollSave();
                          if (y > 400) {
                            if (!_showScrollToTop) {
                              setState(() => _showScrollToTop = true);
                            }
                          } else {
                            if (_showScrollToTop) {
                              setState(() => _showScrollToTop = false);
                            }
                          }
                        },
                      ),
                    ),

                    // Native reader mode overlay
                    if (isReader)
                      RepaintBoundary(
                        child: ColoredBox(
                          color: cs.surface,
                          child: readerState.article != null
                              ? NativeReaderView(
                                  article: readerState.article!,
                                  canGoPreviousArticle: _currentIndex > 0,
                                  canGoNextArticle:
                                      widget.articles != null &&
                                      _currentIndex <
                                          (widget.articles!.length - 1),
                                  onPreviousArticle: _currentIndex > 0
                                      ? () => unawaited(
                                          _goToPrev(fromTtsControls: true),
                                        )
                                      : null,
                                  onNextArticle:
                                      widget.articles != null &&
                                          _currentIndex <
                                              (widget.articles!.length - 1)
                                      ? () => unawaited(
                                          _goToNext(fromTtsControls: true),
                                        )
                                      : null,
                                )
                              : readerState.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _buildReaderLoadFallback(cs, readerState),
                        ),
                      ),

                    if (!isReader)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: RepaintBoundary(child: MiniPlayerWidget()),
                      ),

                    // Loading dimmer – rendered only when truly needed.
                    if (isLoading)
                      const ColoredBox(
                        color: Color(0x40000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
