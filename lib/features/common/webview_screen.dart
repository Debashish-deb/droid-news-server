import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/news_article.dart';
import '/l10n/app_localizations.dart';
import '../tts/ui/mini_player_widget.dart';
import '../tts/ui/app_bar_audio_action.dart';

enum _TranslateEngine { google, bing, deepl }

extension on _TranslateEngine {
  String get label {
    switch (this) {
      case _TranslateEngine.google:
        return 'Google Translate';
      case _TranslateEngine.bing:
        return 'Bing Translator';
      case _TranslateEngine.deepl:
        return 'DeepL';
    }
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({required this.url, super.key, this.title = 'Web View'});
  final String url;
  final String title;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _ctrl;
  late final PullToRefreshController _ptrCtrl;
  double _progress = 0.0;
  bool _readerMode = false;
  String _pageContent = ''; // Content for TTS

  int _scrollY = 0;
  DateTime? _startTime;

  // Content enhancement script - injected on page load
  static const String _contentEnhancementScript = '''
    (function() {
      // 1. TEXT JUSTIFICATION - Make all text justified for better readability
      const style = document.createElement('style');
      style.textContent = \`
        article, p, div.article-content, div.story-body, div.post-content, 
        div.entry-content, div.content, main, div.article-text {
          text-align: justify !important;
          text-justify: inter-word !important;
          hyphens: auto !important;
          -webkit-hyphens: auto !important;
          line-height: 1.6 !important;
        }
        
        /* Better mobile reading */
        body {
          font-size: 16px !important;
          line-height: 1.6 !important;
        }
        
        /* Hide common ad elements */
        .ad, .ads, .advertisement, .advert, .ad-container, .ad-wrapper,
        .google-ads, .adsense, [id*="google_ads"], [class*="google-ad"],
        [id*="advertisement"], [class*="advertisement"],
        iframe[src*="doubleclick"], iframe[src*="googlesyndication"],
        iframe[src*="googletagmanager"], div[id*="taboola"], div[id*="outbrain"],
        .sponsored, .sponsor, [class*="dfp-ad"], .ad-slot, .ad-banner {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
          height: 0 !important;
          width: 0 !important;
          overflow: hidden !important;
        }
      \`;
      document.head.appendChild(style);

      // 2. BLOCK POP-UPS - Override window.open unless from publisher
      const originalOpen = window.open;
      window.open = function(url, target, features) {
        // Allow only if called from same domain (publisher's own pop-ups)
        const currentDomain = window.location.hostname;
        const targetUrl = url ? new URL(url, window.location.href) : null;
        
        if (!targetUrl || targetUrl.hostname !== currentDomain) {
          console.log('[WebView] Blocked external pop-up:', url);
          return null; // Block external pop-ups
        }
        
        return originalOpen.call(window, url, target, features);
      };

      // 3. PREVENT INTRUSIVE OVERLAYS
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === 1) { // Element node
              // Remove common overlay/modal ad containers
              if (node.matches && node.matches('.modal, .overlay, .popup, [class*="popup"], [class*="modal"], [class*="overlay"]')) {
                const isAd = node.textContent.toLowerCase().includes('ad') ||
                             node.className.toLowerCase().includes('ad') ||
                             node.id.toLowerCase().includes('ad');
                if (isAd) {
                  node.remove();
                  console.log('[WebView] Removed intrusive overlay');
                }
              }
            }
          });
        });
      });
      
      observer.observe(document.body, { childList: true, subtree: true });

      // 4. REMOVE EXISTING ADS ON LOAD
      setTimeout(() => {
        document.querySelectorAll('.ad, .ads, iframe[src*="doubleclick"]').forEach(el => {
          el.remove();
        });
        console.log('[WebView] Content enhanced: text justified, ads minimized, pop-ups blocked');
      }, 500);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _ptrCtrl = PullToRefreshController(
      options: PullToRefreshOptions(color: Colors.blueAccent),
      onRefresh: () => _ctrl?.reload(),
    );
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _recordReadingSession();
    _ctrl?.stopLoading();
    super.dispose();
  }

  Future<void> _recordReadingSession() async {
    if (_startTime == null) return;

    final duration = DateTime.now().difference(_startTime!).inSeconds;
    if (duration < 10) return; // skip very short sessions

    final prefs = await SharedPreferences.getInstance();
    final stat = {
      'url': widget.url,
      'title': widget.title,
      'readAt': DateTime.now().toIso8601String(),
      'durationSec': duration,
    };

    final list = prefs.getStringList('read_stats') ?? [];
    list.add(jsonEncode(stat));
    await prefs.setStringList(
      'read_stats',
      list.take(50).toList(),
    ); // cap to 50 entries
  }

  Future<void> _saveScrollPosition() async {
    if (_ctrl == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scrollY = await _ctrl!.getScrollY();
    await prefs.setInt('scroll_${widget.url}', scrollY ?? 0);
  }

  Future<void> _restoreScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    _scrollY = prefs.getInt('scroll_${widget.url}') ?? 0;
    Future.delayed(const Duration(milliseconds: 400), () {
      _ctrl?.scrollTo(x: 0, y: _scrollY);
    });
  }

  Future<void> _showErrorSnackbar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareUrl() async {
    try {
      final uri = await _ctrl?.getUrl();
      if (uri == null) throw Exception('URL not available');
      await Share.share(uri.toString());
    } catch (e) {
      await _showErrorSnackbar('Could not share URL: $e');
    }
  }

  Future<void> _bookmarkUrl() async {
    try {
      final uri = await _ctrl?.getUrl();
      final title = await _ctrl?.getTitle();
      if (uri == null || title == null) throw Exception('Missing URL or title');
      final article = NewsArticle(
        title: title,
        url: uri.toString(),
        publishedAt: DateTime.now(),
        source: Uri.parse(uri.toString()).host,
      );
      // TODO: Re-enable when FavoritesManager is available
      // FavoritesManager.instance.toggleArticle(article);
      await _showErrorSnackbar(AppLocalizations.of(context)!.bookmarkSuccess);
    } catch (e) {
      await _showErrorSnackbar('Bookmark failed: $e');
    }
  }

  Future<void> _toggleReaderMode() async {
    if (_ctrl == null) return;
    _readerMode = !_readerMode;
    final js =
        _readerMode
            ? "document.querySelectorAll('header, footer, nav, aside, .ads, .popup').forEach(e => e.remove()); document.body.style.padding='16px';"
            : "location.reload();";
    try {
      await _ctrl!.evaluateJavascript(source: js);
      setState(() {});
    } catch (e) {
      await _showErrorSnackbar('Reader mode failed: $e');
    }
  }

  Future<void> _translate(_TranslateEngine engine) async {
    try {
      final uri = await _ctrl?.getUrl();
      if (uri == null) throw Exception('URL not available');
      final encoded = Uri.encodeComponent(uri.toString());
      final translateUrl = switch (engine) {
        _TranslateEngine.google =>
          'https://translate.google.com/translate?u=$encoded',
        _TranslateEngine.bing =>
          'https://www.bing.com/translator?text=$encoded',
        _TranslateEngine.deepl =>
          'https://www.deepl.com/translator#auto/en/$encoded',
      };
      await _ctrl!.loadUrl(urlRequest: URLRequest(url: WebUri(translateUrl)));
    } catch (e) {
      await _showErrorSnackbar('Translate failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: theme.textTheme.titleMedium),
        centerTitle: true,
        backgroundColor: scheme.surface.withOpacity(0.7),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _progress < 1 ? _progress : 0,
            backgroundColor: Colors.transparent,
            color: scheme.secondary,
          ),
        ),
        actions: [
          AppBarAudioAction(
            articleId: widget.url,
            title: widget.title,
            content: _pageContent.isNotEmpty ? _pageContent : widget.title, 
          ),
          IconButton(
            icon: const Icon(Icons.translate),
            onPressed: () => _translate(_TranslateEngine.google),
          ),
          IconButton(icon: const Icon(Icons.share), onPressed: _shareUrl),
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: _bookmarkUrl,
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            pullToRefreshController: _ptrCtrl,
            initialSettings: InAppWebViewSettings(
              // Enhanced content blocking
              contentBlockers: [
                ContentBlocker(
                  trigger: ContentBlockerTrigger(
                    urlFilter: ".*",
                    resourceType: [
                      ContentBlockerTriggerResourceType.IMAGE,
                    ],
                    ifDomain: ["*doubleclick.net", "*googlesyndication.com", "*googleadservices.com"],
                  ),
                  action: ContentBlockerAction(
                    type: ContentBlockerActionType.BLOCK,
                  ),
                ),
              ],
              javaScriptEnabled: true,
              domStorageEnabled: true,
              // Block third-party content
              blockNetworkImage: false,
              // Text scaling for better readability
              textZoom: 100,
              // Disable pop-ups by default (our script allows publisher pop-ups)
              javaScriptCanOpenWindowsAutomatically: false,
              // Better UX
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              
              // Mobile Responsiveness
              useWideViewPort: true, 
              loadWithOverviewMode: true,
            ),
            onWebViewCreated: (controller) => _ctrl = controller,
            onLoadStart: (controller, url) {
              _startTime = DateTime.now();
              setState(() => _progress = 0);
            },
            onProgressChanged: (controller, progress) {
              setState(() => _progress = progress / 100);
              
              // Inject content enhancement script when page is loading
              if (progress > 50 && progress < 70) {
                controller.evaluateJavascript(source: _contentEnhancementScript);
              }
            },
            onLoadStop: (controller, url) async {
              _ptrCtrl.endRefreshing();
              
              // Apply final enhancements after page fully loads
              await controller.evaluateJavascript(source: _contentEnhancementScript);
              await _restoreScrollPosition();

              // ENHANCEMENT: Extract text for TTS
              try {
                 // Get clean text after our ad-blocking script has run
                 final text = await controller.evaluateJavascript(source: "document.body.innerText");
                 if (text != null && text is String && text.isNotEmpty) {
                   setState(() {
                     _pageContent = text; 
                   });
                 }
              } catch (e) {
                 debugPrint("Failed to extract page content: $e");
              }
            },
            onLoadError: (_, __, ___, ____) => _showErrorSnackbar('Load error'),
            onLoadHttpError: (_, __, ___, ____) => _showErrorSnackbar('Load error'),
            // Block unwanted new windows/pop-ups
            onCreateWindow: (controller, createWindowAction) async {
              // Only allow if from same domain
              return false; // Block all new windows by default
            },
            // Handle JavaScript dialogs (alerts/confirms from ads)
            onJsAlert: (controller, jsAlertRequest) async {
              // Allow alerts from publisher, block suspicious ones
              final message = jsAlertRequest.message?.toLowerCase() ?? '';
              if (message.contains('ad') || message.contains('subscribe') || 
                  message.contains('newsletter')) {
                return JsAlertResponse(
                  handledByClient: true,
                  action: JsAlertResponseAction.CONFIRM,
                );
              }
              return null; // Show genuine publisher alerts
            },
          ),
          
          // Mini Player overlay (bottom)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerWidget(),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: scheme.surface.withOpacity(0.08),
        elevation: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _ctrl?.goBack(),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _ctrl?.goForward(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _ctrl?.reload(),
            ),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                _ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
              },
            ),
          ],
        ),
      ),
    );
  }
}
