import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'widgets/webview/webview_reader_fallback.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/identity/entitlement_policy.dart';
import '../../../core/config/performance_config.dart';
import '../../../core/di/providers.dart'
    show
        appDatabaseProvider,
        appNetworkServiceProvider,
        debugDiagnosticsServiceProvider,
        rewardedAdServiceProvider,
        subscriptionRepositoryProvider,
        structuredLoggerProvider;
import '../../../core/navigation/navigation_helper.dart';
import '../../../core/navigation/url_safety_policy.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/news_article.dart';
import '../../../domain/entities/tts_quota_status.dart';
import '../../../platform/persistence/app_database.dart' show ArticlesCompanion;
import '../../../core/utils/url_identity.dart';
import '../../../core/utils/webview_blocking.dart';
import '../../../core/utils/webview_policy.dart';
import '../../../core/telemetry/debug_diagnostics_service.dart';
import '../../../core/telemetry/structured_logger.dart';
import '../../../core/tts/domain/entities/tts_state.dart';
import '../../../infrastructure/network/app_network_service.dart'
    show NetworkQuality;
import '../../providers/premium_providers.dart'
    show
        entitlementSnapshotProvider,
        isPremiumStateProvider,
        publisherAdBlockingEnabledProvider,
        shouldShowAdsProvider;
import '../../providers/favorites_providers.dart' show favoritesProvider;
import '../../providers/saved_articles_provider.dart'
    show savedArticlesProvider;
import '../../providers/feature_providers.dart'
    show
        appTtsCoordinatorProvider,
        authServiceProvider,
        localLearningEngineProvider;
import '../../providers/app_settings_providers.dart' show dataSaverProvider;
import '../../widgets/banner_ad_widget.dart';
import '../../../application/ai/ranking/local_learning_engine.dart';
import '../reader/controllers/reader_controller.dart';
import '../reader/ui/native_reader_view.dart';
import '../../../core/tts/presentation/providers/tts_controller.dart';
import '../../../core/tts/presentation/widgets/reader_tts_settings_sheet.dart';
import '../tts/domain/models/speech_chunk.dart';
import '../tts/domain/models/tts_session.dart';
import '../tts/services/app_tts_coordinator.dart';
import '../tts/services/tts_preference_keys.dart';
import 'webview_args.dart';
import 'widgets/webview_tokens.dart';
import 'widgets/webview_header.dart';
import 'widgets/webview_bottom_toolbar.dart';
import 'widgets/webview_translate_sheet.dart';

enum _FeedNavDirection { next, previous }

enum _FeedNavTtsCarryState { inactive, playing, paused }

enum _ReaderTtsUnlockAction { watchAd, goPremium }

@visibleForTesting
bool isReaderSourceReadyForToggle({
  required bool hasController,
  required bool mainFrameLoading,
  required DateTime? lastLoadStopAt,
  required Duration settleDelay,
  required DateTime now,
}) {
  if (!hasController || mainFrameLoading || lastLoadStopAt == null) {
    return false;
  }
  return now.difference(lastLoadStopAt) >= settleDelay;
}

@visibleForTesting
bool shouldShowReaderLoadingOverlay({
  required bool isReader,
  required bool isLoading,
}) {
  return isReader && isLoading;
}

@visibleForTesting
bool shouldUseLightweightWebViewMode({
  required bool isPublisherMode,
  required bool dataSaver,
  required bool lowPowerMode,
  required bool isLowEndDevice,
  required NetworkQuality networkQuality,
}) {
  if (dataSaver || lowPowerMode || isLowEndDevice) {
    return true;
  }
  if (networkQuality == NetworkQuality.poor ||
      networkQuality == NetworkQuality.offline) {
    return true;
  }
  return isPublisherMode && networkQuality == NetworkQuality.fair;
}

@visibleForTesting
bool shouldBlockCleartextSubresource({
  required Uri? pageUri,
  required Uri? requestUri,
}) {
  if (requestUri == null) return false;
  if (requestUri.scheme.toLowerCase() != 'http') return false;
  if (requestUri.host.trim().isEmpty) return false;

  final pageScheme = (pageUri?.scheme ?? '').toLowerCase();
  return pageScheme == 'https';
}

@visibleForTesting
bool shouldAutoAdvanceReaderTts({
  required bool autoPlayEnabled,
  required bool isPublisherOrigin,
  required bool isReaderMode,
  required bool hasNextArticle,
  required bool navigationInFlight,
  required bool unlockPromptInFlight,
}) {
  return autoPlayEnabled &&
      !isPublisherOrigin &&
      isReaderMode &&
      hasNextArticle &&
      !navigationInFlight &&
      !unlockPromptInFlight;
}

@visibleForTesting
bool shouldPromoteWebViewToVisuallyReady({
  required bool mainFrameLoading,
  required double progress,
  required DateTime? loadStartedAt,
  required DateTime? lastProgressChangedAt,
  required Duration plateauDelay,
  required Duration minLoadTime,
  required DateTime now,
}) {
  if (!mainFrameLoading || progress < 0.95) {
    return false;
  }
  if (loadStartedAt == null || lastProgressChangedAt == null) {
    return false;
  }
  if (now.difference(loadStartedAt) < minLoadTime) {
    return false;
  }
  return now.difference(lastProgressChangedAt) >= plateauDelay;
}

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
    html, body, main, #main, #content, [role="main"], .main-content, .body-content {
      background-color: transparent !important;
      background: transparent !important;
      -webkit-font-smoothing: antialiased;
    }
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

/// Aggressive publisher ad/tracker cleanup script.
String _buildAdBlockingContentScript(Object? _) =>
    '''
(function() {
  if (window.__bdAdBlockingScriptApplied) return;
  window.__bdAdBlockingScriptApplied = true;

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
    html, body, main, #main, #content, [role="main"], .main-content, .body-content {
      background-color: transparent !important;
      background: transparent !important;
      -webkit-font-smoothing: antialiased;
    }
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

  safeAppendStyle('bd-webview-ad-style', `
    $kWebViewAdCssSelectors {
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
      'outbrain', 'mgid', 'teads', 'adnxs', 'adservice', 'adserver', 'pubmatic',
      'bilsyndication', 'safeframe', 'googleads', 'googletagservices',
      'vidoomy', '3lift', 'bidswitch', '360yield', 'adform', 'prebid', 'hbopenbid'
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
        '[id*="ad-"],[id^="ad_"],[class*=" ad-"],[class^="ad_"],[class*="advert"],[class*="sponsor"],[id*="sponsor"],[class*="ad-placeholder"],[id*="ad-placeholder"],[class*="dfp"],[id*="dfp"],[class*="google_ads"],[id*="google_ads"],[id*="google_ads_iframe"],[class*="adsbygoogle"],iframe[src*="safeframe"],iframe[src*="bilsyndication"],script[src*="bilsyndication"],iframe[src*="vidoomy"],script[src*="vidoomy"],iframe[src*="pubmatic"],script[src*="pubmatic"],iframe[src*="3lift"],script[src*="3lift"],iframe[src*="bidswitch"],script[src*="bidswitch"],iframe[src*="360yield"],script[src*="360yield"],iframe[src*="adform"],script[src*="adform"],iframe,ins.adsbygoogle'
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
  WebViewOrigin get origin => args.origin;
  List<NewsArticle>? get articles => args.hasFeedContext ? args.articles : null;
  int? get initialIndex => args.hasFeedContext ? args.initialIndex : null;

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static final Set<String> _runtimeHybridCompositionHosts = <String>{};
  static const Duration _readerDomSettleDelay = Duration(milliseconds: 650);
  static const Duration _visualReadyPlateauDelay = Duration(seconds: 2);
  static const Duration _visualReadyMinLoadTime = Duration(seconds: 4);
  static const Duration _autoTtsNextArticleDelay = Duration(seconds: 4);

  // ── Controllers ─────────────────────────────
  InAppWebViewController? _ctrl;
  late PullToRefreshController _ptrCtrl;
  late LocalLearningEngine _learningEngine;
  late AppTtsCoordinator _ttsCoordinator;
  StreamSubscription<SpeechChunk?>? _ttsSubscription;
  StreamSubscription<TtsSession?>? _ttsSessionSubscription;

  // ── Hot-path ValueNotifiers (no full rebuild) ──
  final _progressNotifier = ValueNotifier<double>(0.0);

  // ── State ────────────────────────────────────
  DateTime? _startTime;
  DateTime? _lastBackPressed;
  late int _currentIndex;
  late NewsArticle _currentArticle;
  bool _showFindBar = false;
  bool _showScrollToTop = false;
  bool _isDisposing = false;
  bool _didTrackOpenEvent = false;
  final TextEditingController _findController = TextEditingController();
  int _findMatchesCount = 0;
  int _findActiveMatchIndex = 0;
  bool _navInFlight = false;
  int _navTransactionToken = 0;

  // ── Debounce ─────────────────────────────────
  Timer? _scrollSaveTimer;
  Timer? _snapshotCacheTimer;
  Timer? _webViewBannerRefreshTimer;
  Timer? _visualReadyTimer;
  Timer? _autoTtsNextArticleTimer;
  String? _scheduledScrollSaveUrl;
  int _lastProgressUpdateMs = 0; // throttle guard
  int _webViewBannerRefreshTick = 0;
  static const Duration _webViewBannerRefreshInterval = Duration(minutes: 2);

  // ── Diagnostics (weak-ish via nullable ref) ──
  final String _diagnosticWebViewId =
      'webview_${DateTime.now().microsecondsSinceEpoch}';
  DebugDiagnosticsService? _diagnostics;
  bool _diagnosticRegistered = false;
  final StructuredLogger _safeLogger = StructuredLogger();

  // ── Reader / TTS nav flags ───────────────────
  bool _pendingReaderRefreshAfterArticleNav = false;
  bool _pendingTtsRestartAfterArticleNav = false;
  bool _pendingReaderRefreshInFlight = false;
  Completer<void>? _pendingPageLoadCompleter;
  String? _pendingPageLoadUrl;
  bool? _lastKnownDataSaver;
  bool? _lastKnownAdBlockingState;
  NetworkQuality? _lastKnownNetworkQuality;
  String? _lastAppliedWebViewPolicyKey;
  String? _lastInjectedWebViewPolicyKey;
  String? _lastLoggedRenderPolicyKey;
  Uri? _lastPolicyUri;
  bool _pullToRefreshDisposed = false;
  final Set<String> _cachedSnapshotUrls = <String>{};
  String? _transientRetryBudgetUrl;
  int _transientRetryCount = 0;
  String? _activeMainFrameUrl;
  DateTime? _mainFrameLoadStartedAt;
  DateTime? _lastMainFrameLoadStopAt;
  DateTime? _lastProgressChangedAt;
  bool _mainFrameLoading = true;
  double _lastObservedProgress = 0.0;
  final Set<String> _rewardedTtsUnlocks = <String>{};
  final Set<String> _cleartextHostsWarned = <String>{};
  bool _rewardedUnlockFlowInFlight = false;
  bool _autoTtsAdvanceInFlight = false;
  String? _lastAutoTtsCompletedSessionId;

  bool get _isActiveState => mounted && !_isDisposing;

  StructuredLogger get _runtimeLogger {
    if (!_isActiveState) return _safeLogger;
    try {
      return ref.read(structuredLoggerProvider);
    } catch (_) {
      return _safeLogger;
    }
  }

  PullToRefreshController _createPullToRefreshController() {
    return PullToRefreshController(
      settings: PullToRefreshSettings(color: WT.progressGold),
      onRefresh: _refreshCurrentPage,
    );
  }

  void _recreatePullToRefreshControllerIfNeeded() {
    if (!_pullToRefreshDisposed || _isDisposing) return;
    _ptrCtrl = _createPullToRefreshController();
    _pullToRefreshDisposed = false;
  }

  Future<void> _safeExitScreen() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    await SystemNavigator.pop();
  }

  // ── Pre-computed JS (generated once off-thread) ──
  String? _cachedBaseContentScript;
  String? _cachedAdBlockingContentScript;
  final Map<String, String> _policyScriptCache = <String, String>{};

  static const Set<String> _kAggressiveAdUrlHints = <String>{
    'doubleclick',
    'googlesyndication',
    'googleadservices',
    'googletagservices',
    'bilsyndication',
    'safeframe',
    'taboola',
    'outbrain',
    'mgid',
    'teads',
    'adnxs',
    'adform',
    'pubmatic',
    'vidoomy',
    '3lift',
    'bidswitch',
    '360yield',
    'prebid',
    'hbopenbid',
    'adsbygoogle',
    'amazon-adsystem',
    'criteo',
    'rubiconproject',
    'openx',
  };

  // ── Android-tuned WebView settings ───────────
  bool _computeLightweightWebViewMode({
    required bool dataSaver,
    required NetworkQuality networkQuality,
    PerformanceConfig? perf,
  }) {
    return shouldUseLightweightWebViewMode(
      isPublisherMode: _allowPublisherReaderFallback,
      dataSaver: dataSaver,
      lowPowerMode: perf?.lowPowerMode ?? false,
      isLowEndDevice: perf?.isLowEndDevice ?? false,
      networkQuality: networkQuality,
    );
  }

  InAppWebViewSettings _buildWebViewSettings({
    required bool adBlockingEnabled,
    required PerformanceConfig perf,
    required bool dataSaver,
    required NetworkQuality networkQuality,
    Uri? currentUri,
  }) {
    final publisherMode = _allowPublisherReaderFallback;
    final conservativePolicy = _shouldUseConservativePolicy(currentUri);
    final runtimeHybridFallback = _shouldUseRuntimeHybridFallback(currentUri);
    final lightweightMode = _computeLightweightWebViewMode(
      dataSaver: dataSaver,
      networkQuality: networkQuality,
      perf: perf,
    );
    final blockers = buildWebViewContentBlockers(
      enableAdBlocking: adBlockingEnabled,
      conservative: conservativePolicy,
      dataSaver: dataSaver,
      lightweightMode: lightweightMode,
    );
    final mixedMode = publisherMode
        ? MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE
        : MixedContentMode.MIXED_CONTENT_NEVER_ALLOW;
    final useHybridComposition = shouldUseHybridCompositionForWebView(
      isEmulator: perf.isEmulator,
      isLowEndDevice: perf.isLowEndDevice,
      lowPowerMode: perf.lowPowerMode,
      preferRuntimeHybridComposition: runtimeHybridFallback,
    );

    final renderPolicyKey =
        'host=${(currentUri?.host ?? '').toLowerCase()}|hybrid=$useHybridComposition|emulator=${perf.isEmulator}|lowEnd=${perf.isLowEndDevice}|lowPower=${perf.lowPowerMode}|conservative=$conservativePolicy|runtimeHybrid=$runtimeHybridFallback';
    if (_lastLoggedRenderPolicyKey != renderPolicyKey) {
      _lastLoggedRenderPolicyKey = renderPolicyKey;
      _runtimeLogger.info('WebView rendering policy', <String, dynamic>{
        'host': (currentUri?.host ?? '').toLowerCase(),
        'useHybridComposition': useHybridComposition,
        'isEmulator': perf.isEmulator,
        'isLowEnd': perf.isLowEndDevice,
        'lowPowerMode': perf.lowPowerMode,
        'conservativePolicy': conservativePolicy,
        'runtimeHybridFallback': runtimeHybridFallback,
        'publisherMode': publisherMode,
        'lightweightMode': lightweightMode,
        'networkQuality': networkQuality.name,
      });
    }

    return InAppWebViewSettings(
      // ── Rendering ────────────────────────────────────────────
      preferredContentMode: UserPreferredContentMode.MOBILE,
      useHybridComposition: useHybridComposition,
      layoutAlgorithm: publisherMode
          ? LayoutAlgorithm.TEXT_AUTOSIZING
          : LayoutAlgorithm.NORMAL,
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: true,
      applicationNameForUserAgent: 'BDNewsReader/1.0',
      transparentBackground: true,
      // blockNetworkImages: dataSaver, // Removed - unsupported parameter

      // ── Storage / capabilities ───────────────────────────────
      allowFileAccess: false,
      allowContentAccess: false,

      // ── Safe browsing + mixed content ────────────────────────
      mixedContentMode: mixedMode,
      thirdPartyCookiesEnabled: !(adBlockingEnabled || lightweightMode),

      // ── Viewport ─────────────────────────────────────────────
      supportZoom: false,

      // ── Disable unneeded features ────────────────────────────
      disableDefaultErrorPage: true,

      // ── Ad content blocking ──────────────────────────────────
      useShouldInterceptRequest: blockers.isNotEmpty || lightweightMode,
      contentBlockers: blockers,
    );
  }

  bool _shouldBlockSubresourceRequest(
    WebResourceRequest request, {
    required bool adBlockingEnabled,
    required bool dataSaver,
    required bool lightweightMode,
    Uri? pageUri,
  }) {
    if (!adBlockingEnabled && !dataSaver && !lightweightMode) return false;
    if (request.isForMainFrame ?? false) return false;
    final requestUri = _safeUri(request.url.toString());
    if (shouldBlockCleartextSubresource(
      pageUri: pageUri,
      requestUri: requestUri,
    )) {
      return true;
    }
    final lowerUrl = requestUri?.toString().toLowerCase() ?? '';

    if (adBlockingEnabled &&
        (_kAggressiveAdUrlHints.any(lowerUrl.contains) ||
            RegExp(
              r'[?&](adunit|ad_slot|adslot|ad_id|adtag|ads)=',
            ).hasMatch(lowerUrl))) {
      return true;
    }
    return shouldBlockHeavyThirdPartySubresource(
      pageUri: pageUri,
      requestUri: requestUri,
      adBlockingEnabled: adBlockingEnabled,
      dataSaver: dataSaver,
      lightweightMode: lightweightMode,
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
    _activeMainFrameUrl = _currentArticle.url;

    _ptrCtrl = _createPullToRefreshController();
    _pullToRefreshDisposed = false;

    // Generate content-injection scripts off the main thread.
    compute(_buildBaseContentScript, null).then((script) {
      _cachedBaseContentScript = script;
    });
    compute(_buildAdBlockingContentScript, null).then((script) {
      _cachedAdBlockingContentScript = script;
    });

    if (kDebugMode || kProfileMode) {
      _diagnostics = ref.read(debugDiagnosticsServiceProvider);
    }

    _startWebViewBannerRefreshTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe to call ref.read after first frame; avoids initState ref pitfalls.
    _learningEngine = ref.read(localLearningEngineProvider);
    _ttsCoordinator = ref.read(appTtsCoordinatorProvider);
    if (!_didTrackOpenEvent) {
      _learningEngine.trackOpen(_currentArticle);
      _didTrackOpenEvent = true;
    }
    _lastKnownAdBlockingState ??= ref.read(publisherAdBlockingEnabledProvider);
    _syncTtsFeedNavigationHooks();
    _ttsSubscription ??= _ttsCoordinator.currentChunk.listen((
      SpeechChunk? chunk,
    ) {
      if (!mounted) return;
      if (chunk != null && _ctrl != null) {
        unawaited(_highlightText(chunk.text));
      }
      setState(() {});
    });
    _ttsSessionSubscription ??= _ttsCoordinator.sessionStream.listen(
      _handleTtsSessionUpdate,
    );
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    if (_pendingPageLoadCompleter != null &&
        !_pendingPageLoadCompleter!.isCompleted) {
      _pendingPageLoadCompleter!.complete();
    }
    _visualReadyTimer?.cancel();
    _scrollSaveTimer?.cancel();
    _snapshotCacheTimer?.cancel();
    _webViewBannerRefreshTimer?.cancel();
    _autoTtsNextArticleTimer?.cancel();
    _recordReadingSession();
    _ttsSubscription?.cancel();
    _ttsSessionSubscription?.cancel();
    if (!_pullToRefreshDisposed) {
      try {
        _ptrCtrl.dispose();
      } catch (_) {
        // Best-effort.
      }
      _pullToRefreshDisposed = true;
    }
    _progressNotifier.dispose();
    _ttsCoordinator
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
        _webViewBannerRefreshTimer?.cancel();
        _autoTtsNextArticleTimer?.cancel();
        _autoTtsAdvanceInFlight = false;
        break;
      case AppLifecycleState.resumed:
        if (_isReaderModeActiveSafely()) {
          unawaited(_pauseWebViewBackgroundWork());
        } else {
          _ctrl?.resumeTimers();
          _startWebViewBannerRefreshTimer();
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _startWebViewBannerRefreshTimer() {
    _webViewBannerRefreshTimer?.cancel();
    _webViewBannerRefreshTimer = Timer.periodic(_webViewBannerRefreshInterval, (
      _,
    ) {
      if (!mounted || !_isActiveState) {
        return;
      }
      if (_isReaderModeActiveSafely()) {
        return;
      }
      if (!ref.read(shouldShowAdsProvider)) {
        return;
      }
      setState(() => _webViewBannerRefreshTick++);
    });
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
    final currentUrl = _activeMainFrameUrl ?? _currentArticle.url;
    return _resolveVisiblePageTitle(
      rawUrl: currentUrl,
      fallbackTitle: fallback,
    );
  }

  Future<String> _resolveVisiblePageTitle({
    required String rawUrl,
    required String fallbackTitle,
  }) async {
    if (_ctrl == null) return fallbackTitle;
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
      if (decoded is! Map) return fallbackTitle;
      final payload = Map<String, dynamic>.from(decoded);
      return _pickReaderTitleHint(
        rawUrl: rawUrl,
        fallbackTitle: fallbackTitle,
        payload: payload,
      );
    } catch (_) {
      return fallbackTitle;
    }
  }

  String get _currentPageUrl =>
      _activeMainFrameUrl ?? _lastPolicyUri?.toString() ?? _currentArticle.url;

  void _cancelVisualReadyTimer() {
    _visualReadyTimer?.cancel();
    _visualReadyTimer = null;
  }

  void _markMainFrameReady({required String reason}) {
    _cancelVisualReadyTimer();
    _mainFrameLoading = false;
    _lastMainFrameLoadStopAt = DateTime.now();
    _lastObservedProgress = 1.0;
    _progressNotifier.value = 1.0;
    _completePendingPageLoad();
    _runtimeLogger.info('WebView main frame ready', <String, dynamic>{
      'reason': reason,
      'url': _currentPageUrl,
    });
  }

  void _maybePromoteMainFrameToVisuallyReady() {
    if (!_isActiveState) return;
    if (!shouldPromoteWebViewToVisuallyReady(
      mainFrameLoading: _mainFrameLoading,
      progress: _lastObservedProgress,
      loadStartedAt: _mainFrameLoadStartedAt,
      lastProgressChangedAt: _lastProgressChangedAt,
      plateauDelay: _visualReadyPlateauDelay,
      minLoadTime: _visualReadyMinLoadTime,
      now: DateTime.now(),
    )) {
      return;
    }
    _markMainFrameReady(reason: 'progress_plateau');
  }

  void _scheduleVisualReadyCheck() {
    _cancelVisualReadyTimer();
    if (!_isActiveState ||
        !_mainFrameLoading ||
        _mainFrameLoadStartedAt == null ||
        _lastProgressChangedAt == null ||
        _lastObservedProgress < 0.95) {
      return;
    }

    final now = DateTime.now();
    final plateauRemaining =
        _visualReadyPlateauDelay - now.difference(_lastProgressChangedAt!);
    final minLoadRemaining =
        _visualReadyMinLoadTime - now.difference(_mainFrameLoadStartedAt!);
    var delay = plateauRemaining > minLoadRemaining
        ? plateauRemaining
        : minLoadRemaining;
    if (delay < Duration.zero) {
      delay = Duration.zero;
    }

    _visualReadyTimer = Timer(delay, _maybePromoteMainFrameToVisuallyReady);
  }

  void _handleMainFrameLoadStart(Uri? uri) {
    _cancelVisualReadyTimer();
    _mainFrameLoading = true;
    _mainFrameLoadStartedAt = DateTime.now();
    _lastMainFrameLoadStopAt = null;
    _lastProgressChangedAt = _mainFrameLoadStartedAt;
    _lastObservedProgress = 0.0;

    final nextUrl = uri?.toString().trim();
    if (nextUrl == null || nextUrl.isEmpty) return;
    _activeMainFrameUrl = nextUrl;

    if (!_allowPublisherReaderFallback ||
        widget.articles != null ||
        _isReaderModeActiveSafely()) {
      return;
    }

    final currentCanonical = UrlIdentity.canonicalize(_currentArticle.url);
    final nextCanonical = UrlIdentity.canonicalize(nextUrl);
    if (currentCanonical == nextCanonical) return;

    ref.read(readerControllerProvider.notifier).invalidateForPageChange();
    setState(() {
      _currentArticle = _currentArticle.copyWith(url: nextUrl, fullContent: '');
    });
  }

  Future<void> _syncCurrentArticleWithLoadedPage(Uri? uri) async {
    if (!_allowPublisherReaderFallback ||
        widget.articles != null ||
        uri == null) {
      return;
    }

    final rawUrl = uri.toString();
    final resolvedTitle = await _resolveVisiblePageTitle(
      rawUrl: rawUrl,
      fallbackTitle: _currentArticle.title.trim().isEmpty
          ? widget.title
          : _currentArticle.title,
    );
    if (!_isActiveState) return;

    final currentCanonical = UrlIdentity.canonicalize(_currentArticle.url);
    final nextCanonical = UrlIdentity.canonicalize(rawUrl);
    if (currentCanonical == nextCanonical &&
        resolvedTitle == _currentArticle.title) {
      return;
    }

    setState(() {
      _currentArticle = _currentArticle.copyWith(
        url: rawUrl,
        title: resolvedTitle,
        fullContent: '',
      );
    });
  }

  Future<bool> _ensureReaderSourceReady({required bool showFeedback}) async {
    if (_ctrl == null) {
      if (showFeedback) {
        _snack(
          'Page is still loading. Please wait a moment and try Reader mode again.',
        );
      }
      return false;
    }

    if (_hasReusableArticleSnapshot) {
      return true;
    }

    try {
      if (_pendingPageLoadCompleter != null &&
          !(_pendingPageLoadCompleter?.isCompleted ?? true)) {
        await _waitForPendingPageLoad(
          timeout: _pendingPageLoadTimeout(rawUrl: _currentPageUrl),
        );
      }
    } on TimeoutException {
      if (showFeedback) {
        _snack(
          'This article is still loading. Please wait a moment and try Reader mode again.',
        );
      }
      return false;
    } catch (_) {
      if (showFeedback) {
        _snack(
          'Page is still loading. Please wait a moment and try Reader mode again.',
        );
      }
      return false;
    }

    final readyAfterSettle = isReaderSourceReadyForToggle(
      hasController: _ctrl != null,
      mainFrameLoading: _mainFrameLoading,
      lastLoadStopAt: _lastMainFrameLoadStopAt,
      settleDelay: _readerDomSettleDelay,
      now: DateTime.now(),
    );
    if (!readyAfterSettle &&
        (_mainFrameLoading || _lastMainFrameLoadStopAt == null)) {
      if (showFeedback) {
        _snack(
          'Page is still loading. Please wait a moment and try Reader mode again.',
        );
      }
      return false;
    }

    if (!readyAfterSettle) {
      final remainingSettle =
          _readerDomSettleDelay -
          DateTime.now().difference(_lastMainFrameLoadStopAt!);
      if (remainingSettle > Duration.zero) {
        await Future<void>.delayed(remainingSettle);
      }
    }

    if (!_isActiveState || _ctrl == null || _mainFrameLoading) {
      return false;
    }
    return true;
  }

  bool get _isSavedArticleOrigin =>
      widget.args.origin == WebViewOrigin.savedArticle;

  bool get _allowPublisherReaderFallback =>
      widget.origin == WebViewOrigin.publisher;

  bool get _hasReusableArticleSnapshot =>
      _currentArticle.fullContent.trim().isNotEmpty;

  bool _shouldUseCachedArticleSnapshot() {
    if (_allowPublisherReaderFallback || !_hasReusableArticleSnapshot) {
      return false;
    }
    if (_isSavedArticleOrigin) return true;

    final network = ref.read(appNetworkServiceProvider);
    final dataSaver = ref.read(dataSaverProvider);
    return dataSaver ||
        !network.isConnected ||
        network.currentQuality == NetworkQuality.poor;
  }

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

  InAppWebViewInitialData? _initialCachedArticleData() {
    if (!_shouldUseCachedArticleSnapshot()) return null;
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

  Future<bool> _loadCachedArticleSnapshotIfAvailable() async {
    if (_ctrl == null || !_shouldUseCachedArticleSnapshot()) return false;
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
      _runtimeLogger.warning('Failed to load offline snapshot', e, s);
      return false;
    }
  }

  bool _matchesCurrentArticleUrl(Uri? uri) {
    if (uri == null) return false;
    return UrlIdentity.canonicalize(uri.toString()) ==
        UrlIdentity.canonicalize(_currentArticle.url);
  }

  Future<void> _cacheCurrentArticleSnapshotIfNeeded(
    InAppWebViewController controller,
    Uri? uri,
  ) async {
    if (!_matchesCurrentArticleUrl(uri)) {
      return;
    }
    if (_cachedSnapshotUrls.contains(_currentArticle.url) ||
        _currentArticle.fullContent.trim().isNotEmpty) {
      return;
    }

    try {
      final dynamic raw = await controller
          .evaluateJavascript(
            source: '''
(function() {
  const normalize = (value) => String(value || '').replace(/\\u00a0/g, ' ').replace(/\\s+/g, ' ').trim();
  const selectors = [
    'article',
    'main article',
    '[itemprop*="articleBody"]',
    '[role="main"] article',
    '.article-body',
    '.article-content',
    '.post-content',
    '.entry-content',
    '.story-body',
    '.story-content',
    '.news-content',
    '.details',
    'main',
    '[role="main"]',
    'body'
  ];

  const cleanup = (root) => {
    if (!root || !root.querySelectorAll) return root;
    root.querySelectorAll(
      'script,style,nav,footer,aside,header,form,button,noscript,svg,canvas,iframe,' +
      '.related,.related-news,.recommended,.trending,.comments,.comment-section,' +
      '.share,.share-tools,.social-share,.newsletter,.subscribe,.ads,.ad,.advertisement,' +
      '.cookie,.cookie-banner,.consent,.popup,.overlay'
    ).forEach((node) => node.remove());
    return root;
  };

  const scoreCandidate = (node) => {
    const text = normalize(node?.innerText || node?.textContent || '');
    if (text.length < 200) return -1e9;
    const paragraphs = node.querySelectorAll ? node.querySelectorAll('p').length : 0;
    const anchors = node.querySelectorAll ? Array.from(node.querySelectorAll('a')) : [];
    const shortAnchors = anchors.filter((a) => normalize(a.innerText || a.textContent || '').split(/\\s+/).filter(Boolean).length <= 8).length;
    const anchorTextLen = anchors.reduce((sum, a) => sum + normalize(a.innerText || a.textContent || '').length, 0);
    const linkDensity = anchorTextLen / Math.max(text.length, 1);
    const listItems = node.querySelectorAll ? node.querySelectorAll('li').length : 0;
    return text.length + (paragraphs * 145) - Math.round(linkDensity * 1180) - (shortAnchors * 42) - (listItems * 16);
  };

  let best = null;
  let bestScore = -1e9;
  for (const selector of selectors) {
    const candidates = Array.from(document.querySelectorAll(selector));
    for (const candidate of candidates) {
      const clone = cleanup(candidate.cloneNode(true));
      const score = scoreCandidate(clone);
      if (score > bestScore) {
        best = clone;
        bestScore = score;
      }
    }
  }

  if (!best) return '';

  const bestText = normalize(best.innerText || best.textContent || '');
  const bestAnchors = Array.from(best.querySelectorAll ? best.querySelectorAll('a') : []);
  const bestAnchorTextLen = bestAnchors.reduce((sum, a) => sum + normalize(a.innerText || a.textContent || '').length, 0);
  const bestLinkDensity = bestAnchorTextLen / Math.max(bestText.length, 1);
  const bestParagraphs = best.querySelectorAll ? best.querySelectorAll('p').length : 0;

  if (bestText.length < 380 || bestParagraphs < 3 || bestLinkDensity > 0.46) {
    return '';
  }

  return (best.outerHTML || best.innerHTML || '').trim();
})();
''',
          )
          .timeout(const Duration(milliseconds: 1500));
      final snapshot = _normalizeSnapshotPayload(raw?.toString() ?? '').trim();
      if (snapshot.length < 800 || snapshot.length > 250000) {
        return;
      }

      final db = ref.read(appDatabaseProvider);
      final articleId = UrlIdentity.idFromUrl(_currentArticle.url);
      await (db.update(db.articles)..where((t) => t.id.equals(articleId)))
          .write(ArticlesCompanion(content: Value(snapshot)));

      _currentArticle = _currentArticle.copyWith(fullContent: snapshot);
      _cachedSnapshotUrls.add(_currentArticle.url);
    } catch (e, s) {
      _runtimeLogger.warning('Failed to cache article snapshot', e, s);
    }
  }

  bool _shouldUseConservativePolicy(Uri? uri) {
    return isConservativeWebViewHost(uri);
  }

  bool _shouldUseRuntimeHybridFallback(Uri? uri) {
    final hostKey = webViewHostCacheKey(uri);
    return hostKey.isNotEmpty &&
        _runtimeHybridCompositionHosts.contains(hostKey);
  }

  void _rememberRuntimeHybridFallback(Uri? uri) {
    final hostKey = webViewHostCacheKey(uri);
    if (hostKey.isEmpty) return;
    _runtimeHybridCompositionHosts.add(hostKey);
  }

  void _primeTransientRetryBudget(Uri? uri, {bool force = false}) {
    final trackedUrl = UrlIdentity.canonicalize(
      uri?.toString().isNotEmpty == true ? uri.toString() : _currentArticle.url,
    );
    if (force || _transientRetryBudgetUrl != trackedUrl) {
      _transientRetryBudgetUrl = trackedUrl;
      _transientRetryCount = 0;
    }
  }

  bool _consumeTransientRetryBudget(Uri? uri) {
    _primeTransientRetryBudget(uri);
    if (_transientRetryCount >= 1) return false;
    _transientRetryCount += 1;
    return true;
  }

  Future<bool> _maybeRetryTransientPublisherLoad(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) async {
    final requestUri = _safeUri(request.url.toString());
    final hasRetryBudget =
        UrlIdentity.canonicalize(
              requestUri?.toString().isNotEmpty == true
                  ? requestUri.toString()
                  : _currentArticle.url,
            ) !=
            _transientRetryBudgetUrl ||
        _transientRetryCount < 1;

    if (!shouldRetryTransientPublisherLoad(
      isPublisherMode: _allowPublisherReaderFallback,
      isMainFrame: request.isForMainFrame ?? false,
      hasRetryBudget: hasRetryBudget,
      error: error,
    )) {
      return false;
    }

    if (!_consumeTransientRetryBudget(requestUri)) {
      return false;
    }

    _runtimeLogger.info('WebView transient load retry', <String, dynamic>{
      'host': requestUri?.host ?? '',
      'errorType': error.type.toString(),
      'description': error.description,
      'retryCount': _transientRetryCount,
    });

    await _safeEndRefreshing();
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!_isActiveState) return;
      unawaited(controller.reload());
    });
    return true;
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
        const consentContainerSelectors = [
          '[id*="cookie"]', '[class*="cookie"]',
          '[id*="consent"]', '[class*="consent"]',
          '[id*="gdpr"]', '[class*="gdpr"]',
          '[id*="privacy"]', '[class*="privacy"]',
          '[id*="cmp"]', '[class*="cmp"]',
          '[id*="onetrust"]', '[class*="onetrust"]',
          '[id*="didomi"]', '[class*="didomi"]',
          '[id*="sp_message_container"]', '[class*="sp_message"]',
          '[aria-label*="cookie"]', '[aria-label*="consent"]', '[aria-label*="privacy"]',
          '[role="dialog"]'
        ];

        const consentActionSelectors = [
          'button',
          '[role="button"]',
          'input[type="button"]',
          'input[type="submit"]',
          'a'
        ];

        const consentHints = [
          'cookie', 'cookies', 'consent', 'gdpr', 'privacy', 'policy',
          'preferences', 'preference', 'choices', 'choice', 'onetrust',
          'didomi', 'sourcepoint', 'sp_message', 'cmp', 'trustarc',
          'cookiebot', 'tracking', 'data use'
        ];

        const safeDismissWords = [
          'reject', 'reject all', 'decline', 'decline all', 'deny', 'disagree',
          'close', 'dismiss', 'not now', 'skip',
          'essential only', 'necessary only', 'use necessary cookies only',
          'continue without accepting', 'continue without agreement',
          'only required', 'only essential',
          'না', 'প্রত্যাখ্যান', 'বন্ধ', 'এখন না'
        ];

        const riskyOverlayWords = [
          'subscribe', 'subscription', 'sign in', 'login', 'log in',
          'register', 'purchase', 'checkout', 'trial', 'upgrade',
          'membership', 'paywall', 'join now'
        ];

        const removableSelectors = [
          '.cookie-banner', '.cookie-consent', '.consent', '.gdpr',
          '.social-share', '.share-tools', '.related', '.recommended',
          '.trending', '.most-popular', '.comments', '.comment-section',
          '.ad', '.ads', '.advertisement', '.sponsored', '.promo', '.ad-slot',
          '.ad-banner', '.ad-container', '.ad-wrapper', '.outbrain', '.taboola',
          '.teads', '.mgid',
          '[role="complementary"]', '[aria-label*="cookie"]',
          '[aria-label*="consent"]', '[aria-label*="privacy"]',
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

        const clickSafely = (el) => {
          if (!el) return false;
          try {
            el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
          } catch (_) {}
          try {
            el.click();
            return true;
          } catch (_) {
            return false;
          }
        };

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

        const unlockRootLayout = () => {
          [document.documentElement, document.body].forEach((node) => {
            if (!node || !node.style) return;
            try {
              node.style.setProperty('overflow', 'auto', 'important');
              node.style.setProperty('position', 'static', 'important');
              node.style.setProperty('inset', 'auto', 'important');
              node.style.setProperty('height', 'auto', 'important');
              node.style.setProperty('max-height', 'none', 'important');
              node.style.setProperty('padding-right', '0', 'important');
              node.style.setProperty('touch-action', 'auto', 'important');
            } catch (_) {}
            try { node.removeAttribute('inert'); } catch (_) {}
            try { node.removeAttribute('aria-hidden'); } catch (_) {}
            try {
              Array.from(node.classList || []).forEach((className) => {
                if (/(modal|popup|overlay|cookie|consent|privacy|locked|noscroll|no-scroll|sp_message|onetrust)/i.test(className)) {
                  node.classList.remove(className);
                }
              });
            } catch (_) {}
          });
          document.querySelectorAll('main,article,[role="main"]').forEach((node) => {
            try { node.removeAttribute('inert'); } catch (_) {}
            try { node.removeAttribute('aria-hidden'); } catch (_) {}
          });
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

        const shouldProtectOverlay = (node) => {
          if (!node) return false;
          const text = normalize(
            node.innerText ||
            node.textContent ||
            node.getAttribute('aria-label') ||
            node.getAttribute('title') ||
            node.getAttribute('id') ||
            node.className
          );
          return text.length > 0 && hasAny(text, riskyOverlayWords);
        };

        const isConsentContainer = (node) => {
          if (!node || shouldProtectOverlay(node)) return false;
          const text = normalize(
            node.innerText ||
            node.textContent ||
            node.getAttribute('aria-label') ||
            node.getAttribute('title') ||
            node.getAttribute('id') ||
            node.className
          );
          return text.length > 0 && hasAny(text, consentHints);
        };

        const collectConsentContainers = () => {
          const results = new Set();
          consentContainerSelectors.forEach((selector) => {
            document.querySelectorAll(selector).forEach((node) => {
              if (isConsentContainer(node)) {
                results.add(node);
              }
            });
          });
          document.querySelectorAll(
            '[role="dialog"],[aria-modal="true"],[class*="modal"],[class*="overlay"],[id*="overlay"],[class*="banner"],[id*="banner"],[class*="backdrop"],[id*="backdrop"]'
          ).forEach((node) => {
            if (isConsentContainer(node)) {
              results.add(node);
            }
          });
          return Array.from(results);
        };

        const dismissConsentOverlays = () => {
          let acted = false;
          collectConsentContainers().forEach((container) => {
            const candidates = [];
            consentActionSelectors.forEach((actionSel) => {
              container.querySelectorAll(actionSel).forEach((candidate) => {
                const text = normalize(
                  candidate.innerText ||
                  candidate.textContent ||
                  candidate.value ||
                  candidate.getAttribute('aria-label') ||
                  candidate.getAttribute('title')
                );
                if (!text || hasAny(text, riskyOverlayWords)) return;
                if (hasAny(text, safeDismissWords) || text === '×' || text === 'x') {
                  candidates.push(candidate);
                }
              });
            });

            if (candidates.length > 0) {
              acted = clickSafely(candidates[0]) || acted;
            }

            hideElement(container);
            collapseEmptyParents(container);
            container.querySelectorAll('[class*="backdrop"],[id*="backdrop"],[class*="overlay"],[id*="overlay"]').forEach((node) => {
              if (!shouldProtectOverlay(node)) {
                hideElement(node);
              }
            });
            acted = true;
          });

          if (acted) {
            unlockRootLayout();
          }
          return acted;
        };

        const hideNoise = () => {
          let hidConsent = false;
          removableSelectors.forEach((selector) => {
            document.querySelectorAll(selector).forEach((el) => {
              if (shouldProtectOverlay(el)) return;
              if (isConsentContainer(el)) {
                hidConsent = true;
              }
              hideElement(el);
              collapseEmptyParents(el);
            });
          });

          document.querySelectorAll(
            '[id*="cookie"],[class*="cookie"],[id*="consent"],[class*="consent"],[id*="privacy"],[class*="privacy"],[id*="onetrust"],[class*="onetrust"],[id*="didomi"],[class*="didomi"],[id*="sp_message"],[class*="sp_message"]'
          ).forEach((el) => {
            if (shouldProtectOverlay(el)) return;
            hidConsent = hidConsent || isConsentContainer(el);
            hideElement(el);
            collapseEmptyParents(el);
          });

          if (hidConsent) {
            unlockRootLayout();
          }
        };

        const runSitePolicy = () => {
          dismissConsentOverlays();
          hideNoise();
        };

        window.__bdSitePolicyRun = runSitePolicy;
        runSitePolicy();

        const startObserver = () => {
          if (!document.body) return false;
          if (window.__bdSitePolicyObserver) return true;
          let mutations = 0;
          const maxMutations = 260;
          const observer = new MutationObserver((records) => {
            mutations += records.length;
            window.__bdSitePolicyRun && window.__bdSitePolicyRun();
            if (mutations >= maxMutations) {
              observer.disconnect();
              window.__bdSitePolicyObserver = null;
            }
          });
          window.__bdSitePolicyObserver = observer;
          observer.observe(document.body, { childList: true, subtree: true });
          setTimeout(() => {
            if (window.__bdSitePolicyObserver === observer) {
              observer.disconnect();
              window.__bdSitePolicyObserver = null;
            }
          }, 12000);
          return true;
        };

        if (!startObserver()) {
          window.addEventListener('DOMContentLoaded', () => {
            startObserver();
            window.__bdSitePolicyRun && window.__bdSitePolicyRun();
          }, { once: true });
        }

        setTimeout(() => {
          startObserver();
          window.__bdSitePolicyRun && window.__bdSitePolicyRun();
        }, 450);
        setTimeout(() => {
          startObserver();
          window.__bdSitePolicyRun && window.__bdSitePolicyRun();
        }, 1400);
      })();
    ''';
  }

  String _buildPublisherCompatibilityScript(Uri? uri) {
    if (!_allowPublisherReaderFallback) return '';
    final host = (uri?.host ?? '').toLowerCase();
    return '''
      (function() {
        const host = ${jsonEncode(host)};
        const norm = (value) => String(value || '').toLowerCase().replace(/\\s+/g, ' ').trim();
        const includesAny = (text, hints) => hints.some((hint) => text.includes(hint));

        const consentContainerHints = [
          'cookie', 'consent', 'gdpr', 'privacy', 'terms', 'policy',
          'onetrust', 'didomi', 'sourcepoint', 'sp_message', 'cmp',
          'cookies', 'tracking', 'data use', 'agree to continue'
        ];
        const consentDismissHints = [
          'reject', 'reject all', 'decline', 'decline all', 'deny', 'disagree',
          'close', 'dismiss', 'not now', 'skip',
          'essential only', 'necessary only', 'use necessary cookies only',
          'continue without accepting', 'continue without agreement',
          'না', 'প্রত্যাখ্যান', 'বন্ধ', 'এখন না'
        ];
        const riskyActionHints = [
          'subscribe', 'sign in', 'login', 'log in', 'register', 'purchase',
          'buy', 'trial', 'upgrade', 'pay', 'checkout'
        ];

        const hideNode = (node) => {
          if (!node || !node.style) return;
          try {
            node.style.setProperty('display', 'none', 'important');
            node.style.setProperty('height', '0', 'important');
            node.style.setProperty('min-height', '0', 'important');
            node.style.setProperty('max-height', '0', 'important');
            node.style.setProperty('overflow', 'hidden', 'important');
            node.style.setProperty('margin', '0', 'important');
            node.style.setProperty('padding', '0', 'important');
            node.style.setProperty('border', '0', 'important');
            node.style.setProperty('opacity', '0', 'important');
          } catch (_) {}
        };

        const unlockRootLayout = () => {
          [document.documentElement, document.body].forEach((node) => {
            if (!node || !node.style) return;
            try {
              node.style.setProperty('overflow', 'auto', 'important');
              node.style.setProperty('position', 'static', 'important');
              node.style.setProperty('inset', 'auto', 'important');
              node.style.setProperty('height', 'auto', 'important');
              node.style.setProperty('max-height', 'none', 'important');
              node.style.setProperty('padding-right', '0', 'important');
            } catch (_) {}
            try { node.removeAttribute('inert'); } catch (_) {}
            try { node.removeAttribute('aria-hidden'); } catch (_) {}
          });
        };

        const shouldTreatAsConsentContainer = (el) => {
          if (!el) return false;
          const text = norm(
            el.innerText ||
            el.textContent ||
            el.getAttribute('aria-label') ||
            el.getAttribute('id') ||
            el.className
          );
          if (!text) return false;
          return includesAny(text, consentContainerHints);
        };

        const tryDismissConsent = () => {
          const containers = document.querySelectorAll(
            '[id*="cookie"],[class*="cookie"],[id*="consent"],[class*="consent"],[id*="gdpr"],[class*="gdpr"],[id*="privacy"],[class*="privacy"],[id*="terms"],[class*="terms"],[id*="onetrust"],[class*="onetrust"],[id*="didomi"],[class*="didomi"],[id*="sp_message"],[class*="sp_message"],[role="dialog"],[aria-modal="true"]'
          );
          let acted = false;
          containers.forEach((container) => {
            if (!shouldTreatAsConsentContainer(container)) return;
            const actions = container.querySelectorAll('button,[role="button"],a,input[type="button"],input[type="submit"]');
            actions.forEach((action) => {
              if (acted) return;
              const text = norm(
                action.innerText ||
                action.textContent ||
                action.value ||
                action.getAttribute('aria-label') ||
                action.getAttribute('title')
              );
              if (!text) return;
              if (includesAny(text, riskyActionHints)) return;
              if (!includesAny(text, consentDismissHints) && text != '×' && text != 'x') return;
              try {
                action.click();
                acted = true;
              } catch (_) {}
            });
            hideNode(container);
          });
          if (acted) {
            unlockRootLayout();
          }
          return acted;
        };

        const cleanupSelectors = [
          '.ad', '.ads', '.advertisement', '.ad-slot', '.ad-wrapper', '.sponsored',
          '.promo', '.outbrain', '.taboola', '.teads', '.mgid',
          '.related', '.recommended', '.most-read', '.most-popular', '.trending',
          '.you-may-like', '.read-more', '.story-list',
          '[class*="related"]', '[id*="related"]', '[class*="recommend"]', '[id*="recommend"]',
          '[class*="trending"]', '[id*="trending"]',
          '[id*="ad-"]', '[id^="ad_"]', '[class*=" ad-"]', '[class^="ad_"]',
          'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]',
          'iframe[src*="taboola"]', 'iframe[src*="outbrain"]', 'iframe[src*="ads"]'
        ];

        const hideNoise = () => {
          let hidConsent = false;
          cleanupSelectors.forEach((selector) => {
            document.querySelectorAll(selector).forEach((node) => {
              const text = norm(
                node.innerText ||
                node.textContent ||
                node.getAttribute('aria-label') ||
                node.getAttribute('title') ||
                node.getAttribute('id') ||
                node.className
              );
              if (text && includesAny(text, riskyActionHints)) return;
              hidConsent = hidConsent || shouldTreatAsConsentContainer(node);
              hideNode(node);
            });
          });
          if (hidConsent) {
            unlockRootLayout();
          }
        };

        const runPublisherCompat = () => {
          tryDismissConsent();
          hideNoise();
        };

        window.__bdPublisherCompatRun = runPublisherCompat;
        runPublisherCompat();

        const startObserver = () => {
          if (!document.body) return false;
          if (window.__bdPublisherCompatObserver) return true;
          let mutationCounter = 0;
          const maxMutations = 320;
          const observer = new MutationObserver((mutations) => {
            mutationCounter += mutations.length;
            window.__bdPublisherCompatRun && window.__bdPublisherCompatRun();
            if (mutationCounter >= maxMutations) {
              observer.disconnect();
              window.__bdPublisherCompatObserver = null;
            }
          });
          window.__bdPublisherCompatObserver = observer;
          observer.observe(document.body, { childList: true, subtree: true });
          setTimeout(() => {
            if (window.__bdPublisherCompatObserver === observer) {
              observer.disconnect();
              window.__bdPublisherCompatObserver = null;
            }
          }, 15000);
          return true;
        };

        if (!startObserver()) {
          window.addEventListener('DOMContentLoaded', () => {
            startObserver();
            window.__bdPublisherCompatRun && window.__bdPublisherCompatRun();
          }, { once: true });
        }

        // Late-mount consent overlays are common on publisher pages.
        setTimeout(() => {
          startObserver();
          window.__bdPublisherCompatRun && window.__bdPublisherCompatRun();
        }, 800);
      })();
    ''';
  }

  String _buildWebViewPolicyKey({required bool adBlockingEnabled, Uri? uri}) {
    final host = (uri?.host ?? '').toLowerCase();
    final conservative = _shouldUseConservativePolicy(uri);
    return 'adBlocking=$adBlockingEnabled|host=$host|conservative=$conservative|publisher=$_allowPublisherReaderFallback';
  }

  String _buildPublisherMobileRescueScript(Uri? uri) {
    if (!_allowPublisherReaderFallback) return '';
    final host = (uri?.host ?? '').toLowerCase();
    return '''
      (function() {
        const host = ${jsonEncode(host)};
        const samePublisherHost = (candidate) => {
          if (!candidate || !host) return false;
          return candidate === host ||
            candidate.endsWith('.' + host) ||
            host.endsWith('.' + candidate);
        };

        const ensureViewport = () => {
          const parent = document.head || document.documentElement || document.body;
          if (!parent) return;
          let viewport = document.querySelector('meta[name="viewport"]');
          if (!viewport) {
            viewport = document.createElement('meta');
            viewport.setAttribute('name', 'viewport');
            parent.appendChild(viewport);
          }
          viewport.setAttribute(
            'content',
            'width=device-width,initial-scale=1,maximum-scale=5,viewport-fit=cover'
          );
        };

        const ensureStyle = () => {
          const parent = document.head || document.documentElement || document.body;
          if (!parent || document.getElementById('bd-mobile-rescue-style')) return;
          const style = document.createElement('style');
          style.id = 'bd-mobile-rescue-style';
          style.textContent = `
            html, body {
              max-width: 100% !important;
              width: 100% !important;
              overflow-x: hidden !important;
              -webkit-text-size-adjust: 100% !important;
              text-size-adjust: 100% !important;
            }
            body {
              margin-left: auto !important;
              margin-right: auto !important;
            }
            article, main, section, figure, picture, img, video, iframe,
            embed, object, table, pre, code, blockquote,
            [role="main"], [class*="article"], [class*="story"], [class*="content"] {
              max-width: 100% !important;
              box-sizing: border-box !important;
            }
            img, video, iframe, embed, object {
              width: auto !important;
              height: auto !important;
            }
            table {
              display: block !important;
              overflow-x: auto !important;
              white-space: normal !important;
            }
            pre, code {
              white-space: pre-wrap !important;
              word-break: break-word !important;
              overflow-wrap: anywhere !important;
            }
            [class*="container"], [class*="wrapper"], [class*="layout"],
            [class*="desktop"], [class*="content"], [class*="story"],
            [id*="container"], [id*="wrapper"], [id*="content"] {
              max-width: 100% !important;
              width: auto !important;
              min-width: 0 !important;
              margin-left: auto !important;
              margin-right: auto !important;
            }
          `;
          parent.appendChild(style);
        };

        const retargetBlankAnchors = () => {
          document.querySelectorAll('a[target="_blank"]').forEach((anchor) => {
            const href = anchor.getAttribute('href');
            if (!href) return;
            try {
              const target = new URL(href, location.href);
              if (
                samePublisherHost(target.hostname.toLowerCase()) ||
                target.origin === location.origin
              ) {
                anchor.setAttribute('target', '_self');
                anchor.removeAttribute('rel');
              }
            } catch (_) {}
          });
        };

        const normalizeWideNodes = () => {
          const viewportWidth = Math.max(window.innerWidth || 0, 320);
          document.querySelectorAll('body *').forEach((node) => {
            if (!node || !node.style || !node.getBoundingClientRect) return;
            let rect;
            try {
              rect = node.getBoundingClientRect();
            } catch (_) {
              rect = null;
            }
            if (!rect || rect.width <= viewportWidth * 1.12) return;
            try {
              node.style.setProperty('max-width', '100%', 'important');
              node.style.setProperty('width', 'auto', 'important');
              node.style.setProperty('min-width', '0', 'important');
              node.style.setProperty('overflow-x', 'auto', 'important');
            } catch (_) {}
          });
        };

        const hideIntrusiveFixedChrome = () => {
          document.querySelectorAll('body *').forEach((node) => {
            if (!node || !node.style || !window.getComputedStyle) return;
            const text = String(
              node.innerText ||
              node.textContent ||
              node.getAttribute('aria-label') ||
              node.id ||
              node.className ||
              ''
            ).toLowerCase();
            if (!/(cookie|consent|privacy|popup|overlay|modal|newsletter|subscribe)/i.test(text)) {
              return;
            }
            let computed;
            try {
              computed = window.getComputedStyle(node);
            } catch (_) {
              computed = null;
            }
            const position = String(computed?.position || '').toLowerCase();
            const zIndex = parseInt(String(computed?.zIndex || '0'), 10) || 0;
            if ((position === 'fixed' || position === 'sticky' || zIndex >= 20)) {
              try {
                node.style.setProperty('display', 'none', 'important');
                node.style.setProperty('pointer-events', 'none', 'important');
                node.style.setProperty('opacity', '0', 'important');
              } catch (_) {}
            }
          });
        };

        const run = () => {
          ensureViewport();
          ensureStyle();
          retargetBlankAnchors();
          normalizeWideNodes();
          hideIntrusiveFixedChrome();
        };

        window.__bdPublisherMobileRescueRun = run;
        run();

        const startObserver = () => {
          if (!document.body || window.__bdPublisherMobileRescueObserver) return false;
          let mutations = 0;
          const observer = new MutationObserver((records) => {
            mutations += records.length;
            run();
            if (mutations >= 220) {
              observer.disconnect();
              window.__bdPublisherMobileRescueObserver = null;
            }
          });
          observer.observe(document.body, { childList: true, subtree: true });
          window.__bdPublisherMobileRescueObserver = observer;
          setTimeout(() => {
            if (window.__bdPublisherMobileRescueObserver === observer) {
              observer.disconnect();
              window.__bdPublisherMobileRescueObserver = null;
            }
          }, 12000);
          return true;
        };

        if (!startObserver()) {
          window.addEventListener('DOMContentLoaded', () => {
            startObserver();
            run();
          }, { once: true });
        }
        window.addEventListener('load', run, { once: true });
        setTimeout(run, 400);
        setTimeout(run, 1400);
      })();
    ''';
  }

  List<UserScript> _buildInitialUserScripts() {
    if (!_allowPublisherReaderFallback) {
      return const <UserScript>[];
    }
    const earlyPublisherScript = '''
      (function() {
        if (window.__bdEarlyPublisherScriptApplied) return;
        window.__bdEarlyPublisherScriptApplied = true;

        try { window.open = () => null; } catch (_) {}

        const run = () => {
          const parent = document.head || document.documentElement || document.body;
          if (!parent) return;
          let viewport = document.querySelector('meta[name="viewport"]');
          if (!viewport) {
            viewport = document.createElement('meta');
            viewport.setAttribute('name', 'viewport');
            parent.appendChild(viewport);
          }
          viewport.setAttribute(
            'content',
            'width=device-width,initial-scale=1,maximum-scale=5,viewport-fit=cover'
          );

          if (!document.getElementById('bd-early-publisher-style')) {
            const style = document.createElement('style');
            style.id = 'bd-early-publisher-style';
            style.textContent = `
              html, body, main, #main, #content, [role="main"] {
                max-width: 100% !important;
                overflow-x: hidden !important;
                background-color: transparent !important;
                background: transparent !important;
              }
              img, video, iframe, embed, object, table, pre {
                max-width: 100% !important;
                box-sizing: border-box !important;
              }
              table {
                display: block !important;
                overflow-x: auto !important;
              }
            `;
            parent.appendChild(style);
          }
        };

        run();
        window.addEventListener('DOMContentLoaded', run, { once: true });
        window.addEventListener('load', run, { once: true });
      })();
    ''';

    return <UserScript>[
      UserScript(
        source: earlyPublisherScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    ];
  }

  String _resolvePolicyScript({
    required bool adBlockingEnabled,
    required bool dataSaver,
    Uri? uri,
  }) {
    final cacheKey =
        '${_buildWebViewPolicyKey(adBlockingEnabled: adBlockingEnabled, uri: uri)}|ds=$dataSaver';
    final cachedScript = _policyScriptCache[cacheKey];
    if (cachedScript != null) {
      return cachedScript;
    }
    final baseScript =
        _cachedBaseContentScript ?? _buildBaseContentScript(null);
    final adBlockingScript =
        _cachedAdBlockingContentScript ?? _buildAdBlockingContentScript(null);

    // CSS-based ad-blocking style (safe for all hosts).
    final adBlockingCssStyle = adBlockingEnabled
        ? '''
(function() {
  const target = document.head || document.documentElement || document.body;
  if (!target) return;
  const existing = document.getElementById('bd-webview-ad-style');
  const adStyle = existing || document.createElement('style');
  adStyle.id = 'bd-webview-ad-style';
  adStyle.textContent = `$kWebViewAdCssSelectors {
    display:none!important;height:0!important;pointer-events:none!important;
  }`;
  if (!existing) target.appendChild(adStyle);
})();
'''
        : '';

    // Ad blocking mode always uses the stronger cleanup script.
    String script = adBlockingEnabled ? adBlockingScript : baseScript;

    // Always append CSS blocking when publisher ad blocking is enabled.
    script += adBlockingCssStyle;
    script += _buildSiteSpecificScript(uri);
    script += _buildPublisherMobileRescueScript(uri);
    script += _buildPublisherCompatibilityScript(uri);

    if (_policyScriptCache.length >= 24) {
      _policyScriptCache.clear();
    }
    _policyScriptCache[cacheKey] = script;

    return script;
  }

  // ─────────────────────────────────────────────
  // READING SESSION
  // ─────────────────────────────────────────────
  void _recordReadingSession() {
    if (_startTime == null) return;
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    if (duration < 5) return;
    _learningEngine.trackReadDuration(_currentArticle, duration);
    // Fire-and-forget; no awaiting in dispose.
    unawaited(_persistReadingHistory(duration));
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
    if (_isDisposing) return;
    _scheduledScrollSaveUrl = articleUrl;
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(WT.scrollSaveDebounce, () {
      if (_isDisposing) return;
      _saveScrollPositionSync(articleUrl: _scheduledScrollSaveUrl);
    });
  }

  void _scheduleScrollSave() {
    _scheduleScrollSaveFor(_currentArticle.url);
  }

  void _saveScrollPositionSync({String? articleUrl}) {
    if (_isDisposing) return;
    final targetUrl = articleUrl ?? _currentArticle.url;
    final controller = _ctrl;
    if (controller == null) return;
    unawaited(() async {
      try {
        final y = await controller.getScrollY();
        if (_isDisposing || y == null || y <= 0) return;
        final prefs = await SharedPreferences.getInstance();
        if (_isDisposing) return;
        await prefs.setInt('scroll_$targetUrl', y);
      } on MissingPluginException {
        // WebView may be torn down while a deferred save runs.
      } on PlatformException {
        // Best-effort only.
      } catch (e, s) {
        _runtimeLogger.warning('Scroll position save failed', e, s);
      }
    }());
  }

  void _syncTtsFeedNavigationHooks() {
    _ttsCoordinator.configureFeedNavigation(
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

  void _handleTtsSessionUpdate(TtsSession? session) {
    if (!_isActiveState || session == null) return;
    if (session.state != TtsSessionState.completed) {
      if (_autoTtsAdvanceInFlight &&
          (session.state == TtsSessionState.playing ||
              session.state == TtsSessionState.paused ||
              session.state == TtsSessionState.preparing ||
              session.state == TtsSessionState.buffering)) {
        _autoTtsNextArticleTimer?.cancel();
        _autoTtsAdvanceInFlight = false;
      }
      return;
    }
    if (_lastAutoTtsCompletedSessionId == session.sessionId) return;
    _lastAutoTtsCompletedSessionId = session.sessionId;
    unawaited(_scheduleAutoTtsNextArticle(session));
  }

  Future<bool> _isReaderTtsAutoPlayEnabled() async {
    if (_allowPublisherReaderFallback) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(TtsPreferenceKeys.autoPlayNextArticle) ?? false;
  }

  String _autoTtsIntroFor(NewsArticle article) {
    final language = article.language.toLowerCase();
    final title = article.title;
    final looksBangla =
        language.startsWith('bn') || RegExp(r'[\u0980-\u09FF]').hasMatch(title);
    return looksBangla
        ? 'পরবর্তী সংবাদ শুরু হচ্ছে।'
        : 'Next article starts now.';
  }

  String _autoTtsSnackFor(NewsArticle article) {
    final title = article.title.trim();
    if (title.isEmpty) {
      return 'Next article starts in ${_autoTtsNextArticleDelay.inSeconds} seconds.';
    }
    return 'Next article starts in ${_autoTtsNextArticleDelay.inSeconds} seconds: $title';
  }

  Future<void> _scheduleAutoTtsNextArticle(TtsSession session) async {
    if (_autoTtsAdvanceInFlight) return;

    final articles = widget.articles;
    final hasNextArticle =
        articles != null && _currentIndex < (articles.length - 1);
    final autoPlayEnabled = await _isReaderTtsAutoPlayEnabled();
    final isReaderMode = _isReaderModeActiveSafely();

    if (!shouldAutoAdvanceReaderTts(
      autoPlayEnabled: autoPlayEnabled,
      isPublisherOrigin: _allowPublisherReaderFallback,
      isReaderMode: isReaderMode,
      hasNextArticle: hasNextArticle,
      navigationInFlight: _navInFlight,
      unlockPromptInFlight: _rewardedUnlockFlowInFlight,
    )) {
      return;
    }

    final nextArticle = articles![_currentIndex + 1];
    _autoTtsAdvanceInFlight = true;
    _autoTtsNextArticleTimer?.cancel();
    _snack(_autoTtsSnackFor(nextArticle));
    final completedIndex = _currentIndex;
    final completedUrl = _currentArticle.url;
    _autoTtsNextArticleTimer = Timer(_autoTtsNextArticleDelay, () {
      unawaited(
        _runAutoTtsNextArticle(
          completedSession: session,
          expectedIndex: completedIndex,
          expectedUrl: completedUrl,
        ),
      );
    });
  }

  Future<void> _runAutoTtsNextArticle({
    required TtsSession completedSession,
    required int expectedIndex,
    required String expectedUrl,
  }) async {
    try {
      if (!_isActiveState ||
          _allowPublisherReaderFallback ||
          !_isReaderModeActiveSafely()) {
        return;
      }
      if (!await _isReaderTtsAutoPlayEnabled()) {
        return;
      }
      if (_currentIndex != expectedIndex ||
          _currentArticle.url != expectedUrl) {
        return;
      }

      final articles = widget.articles;
      if (articles == null || expectedIndex >= articles.length - 1) {
        return;
      }

      await _goToNext(fromTtsControls: true);
      if (!_isActiveState ||
          !_isReaderModeActiveSafely() ||
          _currentIndex != expectedIndex + 1) {
        return;
      }

      final readerState = ref.read(readerControllerProvider);
      if (readerState.chunks.isEmpty) {
        _snack('Reader content is not ready for auto TTS.');
        return;
      }

      await _startReaderTtsForCurrentArticle(
        introAnnouncement: _autoTtsIntroFor(_currentArticle),
        allowRewardedUnlock: false,
      );
    } catch (e, s) {
      _runtimeLogger.warning(
        'Auto TTS next article failed after ${completedSession.sessionId}',
        e,
        s,
      );
      if (_isActiveState) {
        _snack('Auto TTS could not start the next article.');
      }
    } finally {
      _autoTtsAdvanceInFlight = false;
    }
  }

  Future<void> _restoreScrollPosition({String? articleUrl}) async {
    final targetUrl = articleUrl ?? _currentArticle.url;
    final prefs = await SharedPreferences.getInstance();
    final y = prefs.getInt('scroll_$targetUrl');
    if (y != null && y > 0) {
      // Schedule after layout so WebView has finished painting.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _ctrl?.scrollTo(x: 0, y: y);
      });
    }
  }

  void _scheduleSnapshotCaching(InAppWebViewController controller, Uri? uri) {
    _snapshotCacheTimer?.cancel();
    final targetUrl = _currentArticle.url;
    final cacheDelay = _allowPublisherReaderFallback
        ? const Duration(milliseconds: 420)
        : const Duration(milliseconds: 900);
    _snapshotCacheTimer = Timer(cacheDelay, () {
      if (!_isActiveState || targetUrl != _currentArticle.url) return;
      unawaited(_cacheCurrentArticleSnapshotIfNeeded(controller, uri));
    });
  }

  Future<void> _syncWebViewAdPolicy(
    bool adBlockingEnabled,
    bool dataSaver, {
    bool force = false,
    Uri? policyUri,
    bool injectScript = true,
    NetworkQuality? networkQuality,
  }) async {
    final controller = _ctrl;
    if (controller == null) return;
    final effectiveUri =
        policyUri ??
        _lastPolicyUri ??
        _safeUri(_currentArticle.url) ??
        _safeUri(widget.url);
    final policyKey =
        '${_buildWebViewPolicyKey(adBlockingEnabled: adBlockingEnabled, uri: effectiveUri)}|ds=$dataSaver';
    final shouldUpdateSettings =
        force || _lastAppliedWebViewPolicyKey != policyKey;
    final shouldInjectScript =
        injectScript && (force || _lastInjectedWebViewPolicyKey != policyKey);
    if (!shouldUpdateSettings && !shouldInjectScript) return;

    _lastKnownAdBlockingState = adBlockingEnabled;
    _lastKnownDataSaver = dataSaver;
    final effectiveNetworkQuality =
        networkQuality ?? ref.read(appNetworkServiceProvider).currentQuality;
    _lastKnownNetworkQuality = effectiveNetworkQuality;
    _lastPolicyUri = effectiveUri;
    final conservativePolicy = _shouldUseConservativePolicy(effectiveUri);
    final perf = _isActiveState ? PerformanceConfig.of(context) : null;
    final lightweightMode = _computeLightweightWebViewMode(
      dataSaver: dataSaver,
      networkQuality: effectiveNetworkQuality,
      perf: perf,
    );
    final blockers = buildWebViewContentBlockers(
      enableAdBlocking: adBlockingEnabled,
      conservative: conservativePolicy,
      dataSaver: dataSaver,
      lightweightMode: lightweightMode,
    );
    if (kDebugMode) {
      _runtimeLogger.info('WebView ad policy synced', <String, dynamic>{
        'adBlockingEnabled': adBlockingEnabled,
        'host': effectiveUri?.host ?? '',
        'conservative': conservativePolicy,
        'dataSaver': dataSaver,
        'networkQuality': effectiveNetworkQuality.name,
        'lightweightMode': lightweightMode,
        'blockerCount': blockers.length,
      });
    }
    try {
      if (shouldUpdateSettings) {
        await controller.setSettings(
          settings: InAppWebViewSettings(
            useShouldInterceptRequest: blockers.isNotEmpty || lightweightMode,
            contentBlockers: blockers,
            thirdPartyCookiesEnabled: !(adBlockingEnabled || lightweightMode),
            // blockNetworkImages: dataSaver, // Removed - unsupported parameter
          ),
        );
        _lastAppliedWebViewPolicyKey = policyKey;
      }

      if (shouldInjectScript) {
        final script = _resolvePolicyScript(
          adBlockingEnabled: adBlockingEnabled,
          dataSaver: dataSaver,
          uri: effectiveUri,
        );
        await controller.evaluateJavascript(source: script);
        _lastInjectedWebViewPolicyKey = policyKey;
      }
    } catch (e, s) {
      _runtimeLogger.warning('Failed to sync WebView ad policy', e, s);
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
      _runtimeLogger.warning('TTS highlight failed', e, s);
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
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            onPressed: _findNext,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: _closeFind,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────
  void _shareUrl() {
    _learningEngine.trackShare(_currentArticle);
    Share.share(_currentArticle.url, subject: _currentArticle.title);
  }

  void _toggleFavorite() {
    ref.read(favoritesProvider.notifier).toggleArticle(_currentArticle);
    _learningEngine.trackBookmark(_currentArticle);
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleOfflineSave() async {
    final isPremium = ref.read(isPremiumStateProvider);
    final notifier = ref.read(savedArticlesProvider.notifier);
    final isSaved = notifier.isSaved(_currentArticle.url);
    final loc = AppLocalizations.of(context);

    if (!isPremium && !isSaved) {
      _showPremiumUpsell(
        'Offline saving is a Pro feature. Free accounts can read everything, but saving articles offline requires Pro.',
      );
      return;
    }

    if (isSaved) {
      final ok = await notifier.removeArticle(_currentArticle.url);
      _snack(ok ? loc.removedFromOffline : loc.failedToRemove);
    } else {
      _snack(loc.savingForOffline, duration: const Duration(seconds: 1));
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
        _snack(ok ? loc.articleSavedOffline : loc.failedToSaveArticle);
      }
    }
  }

  void _snack(
    String msg, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }

  void _showPremiumUpsell(String message) {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: loc.goPremium,
          onPressed: () {
            NavigationHelper.openSubscriptionManagement<void>(context);
          },
        ),
      ),
    );
  }

  String _rewardedTtsUnlockKeyForCurrentArticle() {
    return UrlIdentity.canonicalize(_currentArticle.url);
  }

  bool _hasRewardedTtsUnlockForCurrentArticle() {
    return _rewardedTtsUnlocks.contains(
      _rewardedTtsUnlockKeyForCurrentArticle(),
    );
  }

  Future<bool> _promptRewardedTtsUnlock() async {
    if (!mounted || _rewardedUnlockFlowInFlight) {
      return false;
    }

    final rewarded = ref.read(rewardedAdServiceProvider);
    if (!rewarded.isAdReady) {
      await rewarded.loadAdManually();
    }

    if (!mounted) {
      return false;
    }

    final action = await showModalBottomSheet<_ReaderTtsUnlockAction>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final ready = rewarded.isAdReady;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reader TTS limit reached',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Free accounts can listen to 5 unique articles per week. You can watch a short ad to unlock narration for this article once, or go Pro for unlimited Reader TTS.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: ready
                      ? () {
                          Navigator.of(
                            context,
                          ).pop(_ReaderTtsUnlockAction.watchAd);
                        }
                      : null,
                  icon: const Icon(Icons.ondemand_video_rounded),
                  label: Text(
                    ready
                        ? 'Watch ad to unlock this article'
                        : 'Bonus ad unavailable right now',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(_ReaderTtsUnlockAction.goPremium);
                  },
                  icon: const Icon(Icons.star_rounded),
                  label: Text(AppLocalizations.of(context).goPremium),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return false;
    }

    if (action == _ReaderTtsUnlockAction.goPremium) {
      NavigationHelper.openSubscriptionManagement<void>(context);
      return false;
    }

    _rewardedUnlockFlowInFlight = true;
    try {
      final earnedReward = await rewarded.showAd(
        reason: 'Reader TTS free-limit unlock',
        onUserEarnedReward: (_) {},
      );
      if (!mounted) {
        return false;
      }

      if (!earnedReward) {
        _snack(
          'The bonus ad did not complete, so this article is still locked.',
        );
        return false;
      }

      final unlockKey = _rewardedTtsUnlockKeyForCurrentArticle();
      setState(() {
        _rewardedTtsUnlocks.add(unlockKey);
      });
      _snack('Bonus unlocked for this article. Enjoy the narration.');
      return true;
    } finally {
      _rewardedUnlockFlowInFlight = false;
    }
  }

  String _ttsQuotaMessage(TtsQuotaStatus status) {
    if (status.isPremium) {
      return 'Pro unlocked: unlimited reader TTS.';
    }
    if (status.remainingMonthlyArticles <= 0) {
      return 'Free reader TTS monthly limit reached.';
    }
    if (status.remainingDailyArticles <= 0) {
      return 'Free reader TTS daily limit reached.';
    }
    final noun = status.remainingDailyArticles == 1 ? 'article' : 'articles';
    return 'Free reader TTS: ${status.remainingDailyArticles} $noun left today.';
  }

  Future<void> _safeEndRefreshing() async {
    if (_isDisposing || _pullToRefreshDisposed) return;
    try {
      await _ptrCtrl.endRefreshing();
    } catch (e, s) {
      // Plugin controller can already be disposed while callbacks are still in-flight.
      _safeLogger.warning('Pull-to-refresh endRefreshing skipped', e, s);
      _pullToRefreshDisposed = true;
    }
  }

  bool _isReaderModeActiveSafely() {
    if (!_isActiveState) return false;
    try {
      return ref.read(readerControllerProvider).isReaderMode;
    } catch (e, s) {
      _safeLogger.warning('Reader mode lookup skipped after dispose', e, s);
      return false;
    }
  }

  void _bindReaderControllerSafely(InAppWebViewController controller) {
    if (!_isActiveState) return;
    try {
      ref
          .read(readerControllerProvider.notifier)
          .setWebViewController(controller);
    } catch (e, s) {
      _safeLogger.warning('Reader controller bind skipped after dispose', e, s);
    }
  }

  Future<void> _showTranslateSheet() async {
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
      _snack('Translate failed: $e');
    }
  }

  bool _hasActiveWebViewTtsSession() {
    final session = _ttsCoordinator.currentSession;
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

    final session = _ttsCoordinator.currentSession;
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
    final isReaderMode = ref.read(readerControllerProvider).isReaderMode;
    if (!isReaderMode) {
      _snack('TTS settings are available only in Reader mode.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReaderTtsSettingsSheet(
        showAutoPlayControls: !_allowPublisherReaderFallback,
      ),
    );
  }

  TtsQuotaStatus _localPremiumReaderTtsQuotaStatus() {
    return const TtsQuotaStatus(
      dayKey: 'premium_local_day',
      monthKey: 'premium_local_month',
      usedDailyUniqueArticles: 0,
      usedMonthlyUniqueArticles: 0,
      dailyLimit: EntitlementPolicy.freeTtsDailyArticleLimit,
      monthlyLimit: EntitlementPolicy.freeTtsMonthlyArticleLimit,
      isPremium: true,
      articleAlreadyCounted: true,
    );
  }

  Future<TtsQuotaStatus?> _loadReaderTtsQuotaStatus({
    required bool allowPremiumFallback,
  }) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final quotaResult = await repository.getTtsQuotaStatus(
      articleUrl: _currentArticle.url,
    );
    return quotaResult.fold<TtsQuotaStatus?>((failure) {
      if (allowPremiumFallback) {
        _runtimeLogger.warning(
          'Reader TTS quota lookup failed; using local premium entitlement fallback',
          failure,
          failure.stackTrace,
        );
        return _localPremiumReaderTtsQuotaStatus();
      }
      _snack(failure.userMessage);
      return null;
    }, (status) => status);
  }

  Future<TtsQuotaStatus?> _resolveReaderTtsQuotaStatus({
    required bool entitlementResolvedOnTap,
    required bool premiumOnTap,
  }) async {
    if (premiumOnTap) {
      return _localPremiumReaderTtsQuotaStatus();
    }

    final quota = await _loadReaderTtsQuotaStatus(allowPremiumFallback: false);
    if (quota != null || entitlementResolvedOnTap) {
      return quota;
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    final latestEntitlement = ref.read(entitlementSnapshotProvider);
    if (latestEntitlement.isPremium) {
      return _localPremiumReaderTtsQuotaStatus();
    }

    return _loadReaderTtsQuotaStatus(allowPremiumFallback: false);
  }

  bool _shouldRetryReaderTtsQuota({
    required TtsQuotaStatus quota,
    required bool entitlementResolvedOnTap,
    required bool premiumOnTap,
  }) {
    if (quota.isPremium || quota.canStartTts) {
      return false;
    }

    final user = ref.read(authServiceProvider).currentUser;
    final isSignedIn = user != null && !user.isAnonymous;
    if (!isSignedIn) {
      return false;
    }

    final latestEntitlement = ref.read(entitlementSnapshotProvider);
    if (latestEntitlement.isPremium) {
      return true;
    }

    return !entitlementResolvedOnTap ||
        premiumOnTap != latestEntitlement.isPremium;
  }

  Future<bool> _startReaderTtsForCurrentArticle({
    String? introAnnouncement,
    bool allowRewardedUnlock = true,
  }) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final reader = ref.read(readerControllerProvider.notifier);
    final readerState = ref.read(readerControllerProvider);

    if (readerState.chunks.isEmpty) {
      _snack('Reader content is still loading for TTS.');
      return false;
    }

    final entitlementAtTap = ref.read(entitlementSnapshotProvider);
    var quota = await _resolveReaderTtsQuotaStatus(
      entitlementResolvedOnTap: entitlementAtTap.resolved,
      premiumOnTap: entitlementAtTap.isPremium,
    );
    if (quota == null) {
      return false;
    }
    if (_shouldRetryReaderTtsQuota(
      quota: quota,
      entitlementResolvedOnTap: entitlementAtTap.resolved,
      premiumOnTap: entitlementAtTap.isPremium,
    )) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final retriedQuota = await _resolveReaderTtsQuotaStatus(
        entitlementResolvedOnTap: true,
        premiumOnTap: ref.read(entitlementSnapshotProvider).isPremium,
      );
      if (retriedQuota != null) {
        quota = retriedQuota;
      }
    }

    final quotaStatus = quota;
    var rewardUnlocked = _hasRewardedTtsUnlockForCurrentArticle();
    if (!quotaStatus.canStartTts && !rewardUnlocked) {
      if (!allowRewardedUnlock) {
        _snack(_ttsQuotaMessage(quotaStatus));
        return false;
      }
      rewardUnlocked = await _promptRewardedTtsUnlock();
      if (!rewardUnlocked) {
        return false;
      }
    }

    await reader.playFullArticle(
      category: _currentArticle.category,
      language: _currentArticle.language,
      introAnnouncement: introAnnouncement,
    );

    if (rewardUnlocked) {
      _snack('Bonus unlock active for this article.');
    } else if (!quotaStatus.isPremium) {
      if (quotaStatus.articleAlreadyCounted) {
        _snack(_ttsQuotaMessage(quotaStatus));
      } else {
        final recordResult = await repository.recordTtsArticleUsage(
          _currentArticle.url,
        );
        recordResult.fold((failure) => _snack(failure.userMessage), (_) {
          final remaining = TtsQuotaStatus(
            dayKey: quotaStatus.dayKey,
            monthKey: quotaStatus.monthKey,
            usedDailyUniqueArticles: quotaStatus.usedDailyUniqueArticles + 1,
            usedMonthlyUniqueArticles:
                quotaStatus.usedMonthlyUniqueArticles + 1,
            dailyLimit: quotaStatus.dailyLimit,
            monthlyLimit: quotaStatus.monthlyLimit,
            isPremium: false,
            articleAlreadyCounted: true,
          );
          _snack(_ttsQuotaMessage(remaining));
        });
      }
    }
    return true;
  }

  Future<void> _toggleTtsIntegration({required bool isReaderMode}) async {
    if (!isReaderMode) {
      _snack('TTS is available only in Reader mode.');
      return;
    }

    final reader = ref.read(readerControllerProvider.notifier);
    final readerTtsState = ref.read(ttsControllerProvider);
    if (readerTtsState.status == TtsStatus.playing ||
        readerTtsState.status == TtsStatus.buffering ||
        readerTtsState.status == TtsStatus.loading) {
      reader.pauseTts();
    } else if (readerTtsState.status == TtsStatus.paused) {
      reader.resumeTts();
    } else {
      await _startReaderTtsForCurrentArticle();
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleReaderToggle() async {
    final readerState = ref.read(readerControllerProvider);
    final enteringReaderMode = !readerState.isReaderMode;
    if (enteringReaderMode) {
      final ready = await _ensureReaderSourceReady(showFeedback: true);
      if (!ready) return;
      if (_hasActiveWebViewTtsSession()) {
        await _ttsCoordinator.stop();
      }
    }
    final titleHint = await _resolveReaderTitleHint();
    await ref
        .read(readerControllerProvider.notifier)
        .toggleReaderMode(
          urlHint: _currentArticle.url,
          titleHint: titleHint,
          allowPublisherFallback: _allowPublisherReaderFallback,
          rawHtmlHint: _currentReaderHtmlHint(),
        );
    final updatedReader = ref.read(readerControllerProvider);
    if (enteringReaderMode &&
        !updatedReader.isReaderMode &&
        updatedReader.errorCode == 'reader_unsupported_page_type') {
      _snack(
        updatedReader.errorMessage ??
            'Reader mode is unavailable for this page type.',
      );
    }
    if (enteringReaderMode && updatedReader.isReaderMode) {
      await _pauseWebViewBackgroundWork();
    } else if (!enteringReaderMode) {
      await _resumeWebViewBackgroundWork();
    }
    if (mounted) setState(() {});
  }

  Future<void> _pauseWebViewBackgroundWork() async {
    final controller = _ctrl;
    _webViewBannerRefreshTimer?.cancel();
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
    if (_isActiveState && !_isReaderModeActiveSafely()) {
      _startWebViewBannerRefreshTimer();
    }
  }

  _FeedNavTtsCarryState _captureFeedNavTtsCarryState({
    required bool isReaderMode,
  }) {
    if (isReaderMode) {
      final ttsState = ref.read(ttsControllerProvider);
      if (ttsState.status == TtsStatus.playing ||
          ttsState.status == TtsStatus.loading ||
          ttsState.status == TtsStatus.buffering) {
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

    final session = _ttsCoordinator.currentSession;
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
      // Keep reader highlight cursor in sync immediately, then await
      // concrete TTS stop so article navigation does not race with playback.
      ref.read(readerControllerProvider.notifier).stopTts();
      try {
        await ref.read(ttsControllerProvider.notifier).stop();
      } catch (e, s) {
        _runtimeLogger.warning(
          'Reader TTS stop before article navigation failed',
          e,
          s,
        );
      }
    }

    // WebView TTS can still be alive in non-reader mode; stop is best-effort.
    if (!isReaderMode || _hasActiveWebViewTtsSession()) {
      try {
        await _ttsCoordinator.stop();
      } catch (e, s) {
        _runtimeLogger.warning(
          'WebView TTS stop before article navigation failed',
          e,
          s,
        );
      }
    }
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
      final ready = await _ensureReaderSourceReady(showFeedback: false);
      if (!ready) {
        if (failIfNoArticle) {
          _markReaderRefreshFailure(
            'Reader mode is waiting for the article to finish loading. Tap Retry Reader.',
          );
        }
        return false;
      }
      final reader = ref.read(readerControllerProvider.notifier);
      final titleHint = await _resolveReaderTitleHint();
      await reader.extractContent(
        urlHint: _currentArticle.url,
        titleHint: titleHint,
        allowPublisherFallback: _allowPublisherReaderFallback,
        rawHtmlHint: _currentReaderHtmlHint(),
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
        await _startReaderTtsForCurrentArticle();
      }
      _resetPendingReaderNavigationState();
      _runtimeLogger.info(
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
      final ready = await _ensureReaderSourceReady(showFeedback: false);
      if (!ready) return;
      final titleHint = await _resolveReaderTitleHint();
      await reader.extractContent(
        urlHint: previousArticle.url,
        titleHint: titleHint,
        allowPublisherFallback: _allowPublisherReaderFallback,
        rawHtmlHint: previousArticle.fullContent.trim().length >= 800
            ? previousArticle.fullContent
            : null,
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
        _snack('This article cannot be loaded inside the app.');
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
          );
          return;
        }
      }

      _learningEngine.trackOpen(targetArticle);
      _diagMarkNavigation(targetArticle.url);
    } on TimeoutException {
      await _rollbackFailedFeedNavigation(
        previousIndex: previousIndex,
        previousArticle: previousArticle,
        wasReaderMode: isReaderMode,
      );
      _snack('This article is loading too slowly. Please retry or refresh.');
    } catch (e, s) {
      _runtimeLogger.warning(
        'Feed article navigation failed ($directionLabel)',
        e,
        s,
      );
      await _rollbackFailedFeedNavigation(
        previousIndex: previousIndex,
        previousArticle: previousArticle,
        wasReaderMode: isReaderMode,
      );
      _snack(
        direction == _FeedNavDirection.next
            ? 'Failed to load the next article.'
            : 'Failed to load the previous article.',
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
    bool allowCachedSnapshot = true,
  }) async {
    if (allowCachedSnapshot && await _loadCachedArticleSnapshotIfAvailable()) {
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
        _snack('Blocked unsafe link');
        return false;
    }
  }

  Future<void> _refreshCurrentPage() async {
    final targetUri =
        _lastPolicyUri ?? _safeUri(_currentArticle.url) ?? _safeUri(widget.url);
    if (targetUri == null) {
      await _ctrl?.reload();
      return;
    }

    try {
      await _loadUrlWithPolicy(
        targetUri.toString(),
        waitForLoadStop: true,
        allowCachedSnapshot: false,
      );
    } catch (e, s) {
      _runtimeLogger.warning('WebView refresh failed', e, s);
      await _ctrl?.reload();
    }
  }

  Future<NavigationActionPolicy> _handleNavigation(
    NavigationAction action,
  ) async {
    final uri = action.request.url == null
        ? null
        : Uri.tryParse(action.request.url.toString());
    if (uri == null) {
      return NavigationActionPolicy.CANCEL;
    }

    final articleUri =
        _lastPolicyUri ?? _safeUri(_currentArticle.url) ?? _safeUri(widget.url);
    final likelyAutomaticNavigation =
        action.isRedirect == true || action.hasGesture == false;
    if (action.isForMainFrame &&
        likelyAutomaticNavigation &&
        isConsentManagementDetour(targetUri: uri, articleUri: articleUri)) {
      if (kDebugMode) {
        _runtimeLogger
            .info('Blocked consent detour navigation', <String, dynamic>{
              'targetHost': uri.host,
              'targetPath': uri.path,
              'currentHost': articleUri?.host ?? '',
              'isRedirect': action.isRedirect,
              'hasGesture': action.hasGesture,
            });
      }
      await _ctrl?.stopLoading();
      await _syncWebViewAdPolicy(
        _lastKnownAdBlockingState ??
            ref.read(publisherAdBlockingEnabledProvider),
        _lastKnownDataSaver ?? ref.read(dataSaverProvider),
        force: true,
        policyUri: articleUri,
      );
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
        _snack('Blocked unsafe link');
        return NavigationActionPolicy.CANCEL;
    }
  }

  String? _currentReaderHtmlHint() {
    final html = _currentArticle.fullContent.trim();
    if (html.length < 800) return null;
    return html;
  }

  bool _isNoisyPublisherDialogMessage(String? message) {
    final text = (message ?? '').toLowerCase().trim();
    if (text.isEmpty) return false;
    const noisyHints = <String>[
      'cookie',
      'consent',
      'privacy',
      'notification',
      'subscribe',
      'newsletter',
      'popup',
      'overlay',
      'allow',
    ];
    return noisyHints.any(text.contains);
  }

  Future<bool?> _handleCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final urlValue = action.request.url?.toString();
    final uri = _safeUri(urlValue);
    final articleUri =
        _lastPolicyUri ?? _safeUri(_currentArticle.url) ?? _safeUri(widget.url);

    if (uri == null) {
      _runtimeLogger.info('Blocked popup window without URL', <String, dynamic>{
        'hasGesture': action.hasGesture,
        'isDialog': action.isDialog,
      });
      return false;
    }

    final samePublisher = isLikelySamePublisherHost(articleUri, uri);
    final userInitiated = action.hasGesture == true;
    final decision = UrlSafetyPolicy.evaluateUri(uri);

    if (decision.disposition == UrlSafetyDisposition.reject) {
      _snack('Blocked unsafe popup');
      return false;
    }

    if (_allowPublisherReaderFallback && (samePublisher || userInitiated)) {
      await controller.loadUrl(urlRequest: action.request);
      return false;
    }

    if (decision.disposition == UrlSafetyDisposition.openExternal &&
        userInitiated) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // Extracted _buildReaderLoadFallback to WebViewReaderFallback

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
    final networkQuality = ref.watch(
      appNetworkServiceProvider.select((state) => state.currentQuality),
    );
    final isReader = readerState.isReaderMode;
    final isLoading = readerState.isLoading;
    final webViewAdBlockingEnabled = ref.watch(
      publisherAdBlockingEnabledProvider,
    );
    final initialSavedData = _initialCachedArticleData();
    final initialUserScripts = _buildInitialUserScripts();

    final dataSaver = ref.watch(dataSaverProvider);
    _recreatePullToRefreshControllerIfNeeded();

    // If ad-blocking or data saver flips, we may need to reconsider settings.
    if (_lastKnownAdBlockingState != webViewAdBlockingEnabled ||
        _lastKnownDataSaver != dataSaver ||
        _lastKnownNetworkQuality != networkQuality) {
      _lastKnownAdBlockingState = webViewAdBlockingEnabled;
      _lastKnownDataSaver = dataSaver;
      _lastKnownNetworkQuality = networkQuality;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncWebViewAdPolicy(
          webViewAdBlockingEnabled,
          dataSaver,
          networkQuality: networkQuality,
          force: true,
        );
      });
    }

    ref.listen(readerControllerProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        _snack(next.errorMessage!);
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
              duration: const Duration(milliseconds: 1500),
            );
            return;
          }
          await _safeExitScreen();
        },
        child: Scaffold(
          backgroundColor: cs.surface,
          floatingActionButton: !isReader && _showScrollToTop
              ? FloatingActionButton.small(
                  heroTag: 'webview_scroll_fab',
                  elevation: 0,
                  hoverElevation: 0,
                  focusElevation: 0,
                  highlightElevation: 0,
                  backgroundColor: cs.primaryContainer.withOpacity(0.9),
                  onPressed: _scrollToTop,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: cs.onPrimaryContainer,
                  ),
                )
              : null,
          // ── Premium bottom toolbar ─────────────────────
          // Hidden in reader mode: NativeReaderView owns its own nav.
          bottomNavigationBar: isReader
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BannerAdWidget(
                      key: ValueKey<String>(
                        'webview_banner_${_webViewBannerRefreshTick}_${_currentArticle.url}',
                      ),
                      framed: true,
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      framePadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    RepaintBoundary(
                      child: WebBottomToolbar(
                        article: _currentArticle,
                        reduceEffects:
                            perf.reduceEffects ||
                            perf.lowPowerMode ||
                            perf.performanceTier !=
                                DevicePerformanceTier.flagship,
                        cs: cs,
                        onBack: () async {
                          if (isReader) {
                            if (widget.articles != null && _currentIndex > 0) {
                              await _goToPrev();
                              return;
                            }
                            _snack('No previous article');
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
                          _snack('No previous page');
                        },
                        onForward: () async {
                          if (isReader) {
                            if (widget.articles != null &&
                                _currentIndex < (widget.articles!.length - 1)) {
                              await _goToNext();
                              return;
                            }
                            _snack('No next article');
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
                          _snack('No next page');
                        },
                        onFavorite: _toggleFavorite,
                        onOfflineSave: _toggleOfflineSave,
                        onRefresh: () {
                          if (_ctrl == null) {
                            _snack('Page is still loading');
                            return;
                          }
                          unawaited(_refreshCurrentPage());
                        },
                        onFind: () {
                          if (_ctrl == null) {
                            _snack('Search is unavailable until page loads');
                            return;
                          }
                          _showFindInPage();
                        },
                      ),
                    ),
                  ],
                ),
          body: Column(
            children: [
              // ── Premium header ─────────────────────────
              RepaintBoundary(
                child: WebHeader(
                  article: _currentArticle,
                  progressNotifier: _progressNotifier,
                  reduceEffects:
                      perf.reduceEffects ||
                      perf.lowPowerMode ||
                      perf.performanceTier != DevicePerformanceTier.flagship,
                  cs: cs,
                  isReader: isReader,
                  onBack: () => unawaited(_safeExitScreen()),
                  onReaderToggle: () => unawaited(_handleReaderToggle()),
                  onTtsToggle: () =>
                      unawaited(_toggleTtsIntegration(isReaderMode: isReader)),
                  ttsIcon: _resolveHeaderTtsIcon(
                    isReaderMode: isReader,
                    readerTtsStatus: readerTtsStatus,
                  ),
                  showTtsButton: isReader,
                  onTtsSettings: isReader
                      ? () => unawaited(_showTtsSettingsSheet())
                      : null,
                  onTranslate: isReader ? null : _showTranslateSheet,
                  onShare: _shareUrl,
                ),
              ),

              _buildFindInPageBar(cs),

              // ── Web content ──────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    Offstage(
                      offstage: isReader,
                      child: InAppWebView(
                        initialData: initialSavedData,
                        initialUrlRequest: initialSavedData == null
                            ? URLRequest(url: WebUri(widget.url))
                            : null,
                        initialUserScripts: UnmodifiableListView<UserScript>(
                          initialUserScripts,
                        ),
                        pullToRefreshController: _ptrCtrl,
                        initialSettings: _buildWebViewSettings(
                          adBlockingEnabled: webViewAdBlockingEnabled,
                          perf: perf,
                          dataSaver: dataSaver,
                          networkQuality: networkQuality,
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
                          _recreatePullToRefreshControllerIfNeeded();
                          _ctrl = c;
                          _diagRegisterWebView(_currentArticle.url);
                          unawaited(
                            _syncWebViewAdPolicy(
                              webViewAdBlockingEnabled,
                              dataSaver,
                              networkQuality: networkQuality,
                              force: true,
                              policyUri: _safeUri(_currentArticle.url),
                              injectScript: false,
                            ),
                          );
                        },
                        onLoadStart: (_, uri) {
                          if (!_isActiveState) return;
                          _snapshotCacheTimer?.cancel();
                          _startTime = DateTime.now();
                          _progressNotifier.value = 0;
                          final currentUri = _safeUri(uri?.toString());
                          _handleMainFrameLoadStart(currentUri);
                          _primeTransientRetryBudget(currentUri);
                          _lastPolicyUri = currentUri;
                          _diagMarkNavigation(uri?.toString());
                          unawaited(
                            _syncWebViewAdPolicy(
                              webViewAdBlockingEnabled,
                              dataSaver,
                              networkQuality: networkQuality,
                              policyUri: currentUri,
                              injectScript: false,
                            ),
                          );
                        },
                        onProgressChanged: (_, p) {
                          if (!_isActiveState) return;
                          final now = DateTime.now();
                          final nextProgress = (p / 100).clamp(0.0, 1.0);
                          if ((nextProgress - _lastObservedProgress).abs() >
                              0.0005) {
                            _lastObservedProgress = nextProgress;
                            _lastProgressChangedAt = now;
                          }
                          _scheduleVisualReadyCheck();
                          final nowMs = now.millisecondsSinceEpoch;
                          if (nowMs - _lastProgressUpdateMs >=
                              WT.progressThrottleMs) {
                            _lastProgressUpdateMs = nowMs;
                            _progressNotifier.value = _mainFrameLoading
                                ? nextProgress
                                : 1.0;
                          }
                        },
                        onLoadStop: (controller, uri) async {
                          if (!_isActiveState) return;
                          await _safeEndRefreshing();
                          _markMainFrameReady(reason: 'load_stop');

                          final currentUri = _safeUri(uri?.toString());
                          _primeTransientRetryBudget(currentUri, force: true);
                          _activeMainFrameUrl = currentUri?.toString();
                          _lastPolicyUri = currentUri;
                          unawaited(
                            _syncWebViewAdPolicy(
                              webViewAdBlockingEnabled,
                              dataSaver,
                              networkQuality: networkQuality,
                              policyUri: currentUri,
                            ),
                          );
                          if (_isReaderModeActiveSafely()) {
                            unawaited(_pauseWebViewBackgroundWork());
                          }

                          if (!_isActiveState) return;
                          _bindReaderControllerSafely(controller);
                          await _syncCurrentArticleWithLoadedPage(currentUri);
                          unawaited(
                            _restoreScrollPosition(articleUrl: uri?.toString()),
                          );
                          _scheduleSnapshotCaching(controller, currentUri);

                          if (!_isActiveState) return;
                          _diagMarkNavigation(uri?.toString());
                        },
                        onRenderProcessGone: (_, detail) {
                          if (!_isActiveState) return;
                          _cancelVisualReadyTimer();
                          _mainFrameLoading = false;
                          _lastMainFrameLoadStopAt = null;
                          _rememberRuntimeHybridFallback(
                            _lastPolicyUri ?? _safeUri(_currentArticle.url),
                          );
                          _failPendingPageLoad(
                            StateError('WebView render process restarted'),
                          );
                          _safeLogger.warn(
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
                                  shouldUseHybridCompositionForWebView(
                                    isEmulator: perf.isEmulator,
                                    isLowEndDevice: perf.isLowEndDevice,
                                    lowPowerMode: perf.lowPowerMode,
                                    preferRuntimeHybridComposition:
                                        _shouldUseRuntimeHybridFallback(
                                          _lastPolicyUri ??
                                              _safeUri(_currentArticle.url),
                                        ),
                                  ),
                            },
                          );
                          _snack('WebView restarted for stability');
                          final webCtrl = _ctrl;
                          if (webCtrl != null) {
                            unawaited(webCtrl.reload());
                          }
                        },
                        onReceivedError: (controller, request, error) async {
                          if (!_isActiveState) return;
                          if (await _maybeRetryTransientPublisherLoad(
                            controller,
                            request,
                            error,
                          )) {
                            return;
                          }
                          final isMainFrame = request.isForMainFrame ?? false;
                          if (isMainFrame) {
                            _cancelVisualReadyTimer();
                            _mainFrameLoading = false;
                            _lastMainFrameLoadStopAt = null;
                          }
                          final description = error.description.toUpperCase();
                          final isCleartextSubresourceError =
                              !isMainFrame &&
                              description.contains(
                                'ERR_CLEARTEXT_NOT_PERMITTED',
                              );
                          if (isCleartextSubresourceError) {
                            final host = request.url.host.toLowerCase();
                            if (_cleartextHostsWarned.add(host)) {
                              _runtimeLogger.info(
                                'Blocked cleartext subresource',
                                <String, dynamic>{
                                  'host': host,
                                  'mainFrameHost':
                                      (_lastPolicyUri?.host ??
                                              _safeUri(
                                                _activeMainFrameUrl,
                                              )?.host ??
                                              '')
                                          .toLowerCase(),
                                },
                              );
                            }
                            return;
                          }
                          _safeLogger
                              .warn('WebView resource error', <String, dynamic>{
                                'errorType': error.type.toString(),
                                'error': error.description,
                                'host': request.url.host,
                                'isEmulator': perf.isEmulator,
                                'mainFrame': isMainFrame,
                              });
                          if (!isMainFrame) {
                            return;
                          }
                          _failPendingPageLoad(
                            StateError('WebView load error: ${error.type}'),
                          );
                          _markReaderRefreshFailure(
                            'Reader mode failed to load this page. Tap Retry Reader.',
                          );
                          _snack('Failed to load page');
                        },
                        onReceivedHttpError: (controller, request, errorResponse) {
                          if (!_isActiveState) return;
                          if (!(request.isForMainFrame ?? false)) {
                            _safeLogger.warn(
                              'WebView subresource http error',
                              <String, dynamic>{
                                'statusCode': errorResponse.statusCode,
                                'host': request.url.host,
                              },
                            );
                            return;
                          }
                          _cancelVisualReadyTimer();
                          _mainFrameLoading = false;
                          _lastMainFrameLoadStopAt = null;
                          _failPendingPageLoad(
                            StateError(
                              'WebView http error: ${errorResponse.statusCode}',
                            ),
                          );
                        },
                        shouldInterceptRequest: (_, request) async {
                          final lightweightMode =
                              _computeLightweightWebViewMode(
                                dataSaver: dataSaver,
                                networkQuality: networkQuality,
                                perf: perf,
                              );
                          if (!_shouldBlockSubresourceRequest(
                            request,
                            adBlockingEnabled: webViewAdBlockingEnabled,
                            dataSaver: dataSaver,
                            lightweightMode: lightweightMode,
                            pageUri:
                                _lastPolicyUri ??
                                _safeUri(_activeMainFrameUrl) ??
                                _safeUri(_currentArticle.url),
                          )) {
                            return null;
                          }
                          return WebResourceResponse(
                            contentType: 'text/plain',
                            data: Uint8List(0),
                            statusCode: 204,
                            reasonPhrase: 'No Content',
                            headers: const <String, String>{
                              'cache-control': 'no-store',
                            },
                          );
                        },
                        shouldOverrideUrlLoading: (_, action) async {
                          return _handleNavigation(action);
                        },
                        onCreateWindow: _handleCreateWindow,
                        onPermissionRequest: (_, request) async {
                          return PermissionResponse(
                            resources: request.resources,
                          );
                        },
                        onJsAlert: (_, request) async {
                          if (_allowPublisherReaderFallback &&
                              _isNoisyPublisherDialogMessage(request.message)) {
                            return JsAlertResponse(handledByClient: true);
                          }
                          return null;
                        },
                        onJsConfirm: (_, request) async {
                          if (_allowPublisherReaderFallback &&
                              _isNoisyPublisherDialogMessage(request.message)) {
                            return JsConfirmResponse(handledByClient: true);
                          }
                          return null;
                        },
                        onJsPrompt: (_, request) async {
                          if (_allowPublisherReaderFallback &&
                              _isNoisyPublisherDialogMessage(request.message)) {
                            return JsPromptResponse(handledByClient: true);
                          }
                          return null;
                        },
                        onScrollChanged: (controller, x, y) {
                          if (!_isActiveState) return;
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
                                  onTtsPressed: () {
                                    unawaited(
                                      _toggleTtsIntegration(isReaderMode: true),
                                    );
                                  },
                                  canGoPreviousArticle: _currentIndex > 0,
                                  canGoNextArticle:
                                      widget.articles != null &&
                                      _currentIndex <
                                          (widget.articles!.length - 1),
                                  showAutoTtsControls:
                                      !_allowPublisherReaderFallback,
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
                              : WebViewReaderFallback(
                                  readerState: readerState,
                                  currentArticle: _currentArticle,
                                  onShowWebPage: _handleReaderToggle,
                                  onRetryReader: () async {
                                    final ready = await _ensureReaderSourceReady(showFeedback: true);
                                    if (!ready) return;
                                    final titleHint = await _resolveReaderTitleHint();
                                    await ref.read(readerControllerProvider.notifier).extractContent(
                                      urlHint: _currentArticle.url,
                                      titleHint: titleHint,
                                      allowPublisherFallback: _allowPublisherReaderFallback,
                                      rawHtmlHint: _currentReaderHtmlHint(),
                                    );
                                  },
                                ),
                        ),
                      ),

                    // Loading dimmer – rendered only when truly needed.
                    if (shouldShowReaderLoadingOverlay(
                      isReader: isReader,
                      isLoading: isLoading,
                    ))
                      ColoredBox(
                        color: cs.surface.withValues(alpha: 0.35),
                        child: const Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
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
