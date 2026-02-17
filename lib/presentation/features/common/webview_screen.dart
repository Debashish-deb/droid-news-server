import 'dart:convert';
import '../../../core/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart' show structuredLoggerProvider;
import '../../../l10n/generated/app_localizations.dart';

import '../../../domain/entities/news_article.dart';
import '../../providers/premium_providers.dart' show isPremiumStateProvider;
import '../../providers/favorites_providers.dart' show favoritesProvider, isFavoriteArticleProvider;
import '../../providers/saved_articles_provider.dart' show savedArticlesProvider;
import '../../providers/feature_providers.dart' show ttsManagerProvider, userInterestProvider;
import '../../../application/ai/ranking/user_interest_service.dart';
import '../settings/widgets/settings_3d_widgets.dart';
import '../tts/domain/models/speech_chunk.dart';
import '../../../core/webview_blocking.dart';

import '../reader/controllers/reader_controller.dart';
import '../reader/ui/native_reader_view.dart';

enum _TranslateEngine { google, bing, deepl }

extension on _TranslateEngine {

}

class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({
    required this.url,
    super.key,
    this.title = '',
    this.articles,
    this.initialIndex,
  });

  final String url;
  final String title;
  final List<NewsArticle>? articles;
  final int? initialIndex;

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  InAppWebViewController? _ctrl;
  late final PullToRefreshController _ptrCtrl;
  double _progress = 0.0;

  DateTime? _startTime;
  DateTime? _lastBackPressed;
  

  late int _currentIndex;
  late NewsArticle _currentArticle;

  static const String _contentEnhancementScript = '''
    (function() {
      // 1. Typography & Reading Experience
      const typeStyle = document.createElement('style');
      typeStyle.textContent = `
        body {
          -webkit-font-smoothing: antialiased;
          -moz-osx-font-smoothing: grayscale;
        }
        p, article, .article-body, .story-body {
          text-align: justify !important;
          line-height: 1.6 !important;
          font-size: 110% !important; /* Slightly larger default text */
          max-width: 100vw;
          overflow-wrap: break-word;
        }
        /* Make headings pop */
        h1, h2, h3 {
          line-height: 1.3 !important;
          margin-top: 1.5em !important;
          margin-bottom: 0.5em !important;
        }
      `;
      document.head.appendChild(typeStyle);

      // 2. CSS Ad Blocking (Fallback for elements that slip through network blocks)
      const style = document.createElement('style');
      style.textContent = `
        /* Hide common ad elements */
        .ad, .ads, .advertisement, .advert, .ad-container, .ad-wrapper,
        .google-ads, .adsense, [id*="google_ads"], [class*="google-ad"],
        [id*="advertisement"], [class*="advertisement"],
        iframe[src*="doubleclick"], iframe[src*="googlesyndication"],
        iframe[src*="googletagmanager"], div[id*="taboola"], div[id*="outbrain"],
        .sponsored, .sponsor, [class*="dfp-ad"], .ad-slot, .ad-banner,
        [class*="popup"], [class*="overlay"] {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
          height: 0 !important;
          width: 0 !important;
          overflow: hidden !important;
          pointer-events: none !important;
        }
      `;
      document.head.appendChild(style);

      // 2. Pop-up Blocker
      const originalOpen = window.open;
      window.open = function(url, target, features) {
        console.log('[WebView] Blocked pop-up attempt:', url);
        return null; 
      };

      // 3. Dynamic Ad Removal (Observer)
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === 1) {
              const isAd = node.textContent.toLowerCase().includes('ad') ||
                           node.className.toLowerCase().includes('ad') ||
                           node.id.toLowerCase().includes('ad');
              if (isAd) {
                node.style.display = 'none';
              }
            }
          });
        });
      });
      observer.observe(document.body, { childList: true, subtree: true });

      setTimeout(() => {
        console.log('[WebView] Clean Mode Active: Ads blocked.');
      }, 500);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    debugPrint('🌐 WebView Loading URL: ${widget.url}');
    
    _currentIndex = widget.initialIndex ?? -1;
    _currentArticle = widget.articles != null && _currentIndex >= 0
        ? widget.articles![_currentIndex]
        : NewsArticle(
            title: widget.title.isNotEmpty ? widget.title : AppLocalizations.of(context).webView,
            url: widget.url,
            source: '',
            publishedAt: DateTime.now(),
          );

    _ptrCtrl = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.blue),
      onRefresh: () async {
        if (_ctrl != null) {
          await _ctrl!.reload();
        }
      },
    );


    ref.read(ttsManagerProvider).currentChunk.listen((SpeechChunk? chunk) {
      if (chunk != null && mounted && _ctrl != null) {
        _highlightText(chunk.text);
      }
    });
  }

  Future<void> _highlightText(String text) async {
    if (_ctrl == null) return;
    
    final sanitizedText = text
        .replaceAll("\\", "\\\\")
        .replaceAll("'", "\\'")
        .replaceAll("\n", " ")
        .trim();
    
    final matchText = sanitizedText.length > 60 
        ? sanitizedText.substring(0, 60) 
        : sanitizedText;

    final js = '''
      (function() {
        const previous = document.querySelector('.tts-playing-highlight');
        if (previous) {
          previous.classList.remove('tts-playing-highlight');
          previous.style.backgroundColor = 'transparent';
        }

        const snippet = '$matchText';
        const walkers = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
        let node;
        while(node = walkers.nextNode()) {
          if (node.textContent.includes(snippet)) {
            const parent = node.parentElement;
            if (parent && parent.tagName !== 'SCRIPT' && parent.tagName !== 'STYLE') {
              parent.classList.add('tts-playing-highlight');
              parent.style.backgroundColor = 'rgba(255, 235, 59, 0.4)'; // Light yellow glow
              parent.style.transition = 'background-color 0.5s ease';
              parent.scrollIntoView({ behavior: 'smooth', block: 'center' });
              break;
            }
          }
        }
      })();
    ''';
    
    try {
      await _ctrl!.evaluateJavascript(source: js);
    } catch (e, stack) {
      ref.read(structuredLoggerProvider).warning('JS text highlighting failed', e, stack);  
    }
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _recordReadingSession();

    ref.read(ttsManagerProvider).stop();
    super.dispose();
  }

  void _recordReadingSession() async {
    if (_startTime == null) return;
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    if (duration < 5) return; 

    // Record AI Interaction
    ref.read(userInterestProvider).recordInteraction(
      article: _currentArticle,
      type: InteractionType.view,
    );

    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('reading_history') ?? [];

    final entry = {
      'url': _currentArticle.url,
      'title': _currentArticle.title,
      'timestamp': DateTime.now().toIso8601String(),
      'duration': duration,
    };

    history.insert(0, json.encode(entry));
    if (history.length > 50) history.removeLast();
    await prefs.setStringList('reading_history', history);
  }

  Future<void> _saveScrollPosition() async {
    if (_ctrl == null) return;
    final scrollY = await _ctrl!.getScrollY();
    if (scrollY == null || scrollY <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scroll_${_currentArticle.url}', scrollY);
  }

  Future<void> _restoreScrollPosition() async {
    if (_ctrl == null) return;
    final prefs = await SharedPreferences.getInstance();
    final scrollY = prefs.getInt('scroll_${_currentArticle.url}');
    if (scrollY != null && scrollY > 0) {
      await _ctrl!.scrollTo(x: 0, y: scrollY, animated: true);
    }
  }

  Future<void> _showErrorSnackbar(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _shareUrl() {
    Share.share(_currentArticle.url, subject: _currentArticle.title);
  }

  void _toggleFavorite() {
    ref.read(favoritesProvider.notifier).toggleArticle(_currentArticle);
    
    // Record AI Interaction
    ref.read(userInterestProvider).recordInteraction(
      article: _currentArticle,
      type: InteractionType.bookmark,
    );
  }

  Future<void> _toggleOfflineSave() async {
    final notifier = ref.read(savedArticlesProvider.notifier);
    final isSaved = notifier.isSaved(_currentArticle.url);

    if (!mounted) return;

    if (isSaved) {
      final success = await notifier.removeArticle(_currentArticle.url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? AppLocalizations.of(context).removedFromOffline : AppLocalizations.of(context).failedToRemove),
            duration: const Duration(seconds: 2),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
      }
    } else {
 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).savingForOffline),
          duration: const Duration(seconds: 1),
        ),
      );

      String? webContent;
      try {
        if (_ctrl != null) {
          webContent = await _ctrl!.evaluateJavascript(source: "document.body.innerHTML");
        }
      } catch (e) {
        debugPrint('⚠️ WebView Content Capture Error: $e');
      }

      final toSave = _currentArticle.copyWith(
        fullContent: webContent ?? _currentArticle.fullContent,
      );
      
      final success = await notifier.saveArticle(toSave);
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? AppLocalizations.of(context).articleSavedOffline : AppLocalizations.of(context).failedToSaveArticle),
            duration: const Duration(seconds: 2),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _translate(_TranslateEngine engine) async {
    final bool isPremium = ref.read(isPremiumStateProvider);
    if (!isPremium) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).premiumFeatInfo),
          action: SnackBarAction(
            label: AppLocalizations.of(context).upgrade,
            onPressed: () => context.push('/subscription'),
          ),
        ),
      );
      return;
    }

    if (_ctrl == null) return;
    final currentUrl = _currentArticle.url;

    String translateUrl;
    switch (engine) {
      case _TranslateEngine.google:
        translateUrl = 'https://translate.google.com/translate?sl=auto&tl=bn&u=$currentUrl';
        break;
      case _TranslateEngine.bing:
        translateUrl = 'https://www.microsofttranslator.com/bv.aspx?from=auto&to=bn&a=$currentUrl';
        break;
      case _TranslateEngine.deepl:
        translateUrl = 'https://www.deepl.com/translator#auto/bn/$currentUrl';
        break;
    }

    try {
      await _ctrl!.loadUrl(urlRequest: URLRequest(url: WebUri(translateUrl)));
    } catch (e) {
      await _showErrorSnackbar('Translate failed: $e');
    }
  }

  void _goToNextArticle() {
    if (widget.articles == null || _currentIndex >= widget.articles!.length - 1) return;
    
    _saveScrollPosition();
    _recordReadingSession();
    
    setState(() {
      _currentIndex++;
      _currentArticle = widget.articles![_currentIndex];
      _progress = 0;
    });
    
    _ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_currentArticle.url)));
  }

  void _goToPreviousArticle() {
    if (widget.articles == null || _currentIndex <= 0) return;
    
    _saveScrollPosition();
    _recordReadingSession();
    
    setState(() {
      _currentIndex--;
      _currentArticle = widget.articles![_currentIndex];
      _progress = 0;
    });
    
    _ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(_currentArticle.url)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressed == null || 
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).swipeAgainToExit),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }


        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      body: Column(
        children: [
          // Custom Compact Header (since standard AppBar is too bulky)
          Container(
            height: 64 + MediaQuery.of(context).padding.top, // Adjusted height to include status bar
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 8),
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.95),
              border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Settings3DButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                  width: 44,
                  height: 44,
                  iconSize: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentArticle.source.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12, // Matched AppBarTitle typography
                          fontWeight: FontWeight.w900, // Matched AppBarTitle typography
                          color: scheme.primary, // Matched AppBarTitle typography
                          letterSpacing: 1.2, // Matched AppBarTitle typography
                          fontFamily: AppTypography.fontFamily,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentArticle.title,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13, 
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Actions in Header (Compact)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                       Settings3DButton(
                        icon: Icons.article_rounded, // Material Reader Mode Icon
                        isSelected: ref.watch(readerControllerProvider).isReaderMode,
                        onTap: () async {
                           await ref.read(readerControllerProvider.notifier).toggleReaderMode();
                        },
                        width: 56,
                      ),
                      const SizedBox(width: 8),
                      if (!ref.watch(readerControllerProvider).isReaderMode) ...[
                        Settings3DButton(
                          icon: Icons.translate_rounded,
                          onTap: () => _translate(_TranslateEngine.google),
                          width: 56,
                        ),
                        const SizedBox(width: 8),
                      ],
                    const SizedBox(width: 8),
                    Settings3DButton(
                      icon: Icons.share_rounded,
                      onTap: _shareUrl,
                      width: 56,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
          
          if (_progress < 1.0)
             LinearProgressIndicator(value: _progress, minHeight: 2, color: scheme.primary, backgroundColor: Colors.transparent),

          Expanded(
            child: Stack(
              children: [
                // 1. WebView (Always loaded to keep state, hidden/offstage when in reader mode if desired, 
                // but keeping it in stack allows seamless switching)
                Offstage(
                  offstage: ref.watch(readerControllerProvider).isReaderMode,
                  child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_currentArticle.url)),
              pullToRefreshController: _ptrCtrl,
              initialSettings: InAppWebViewSettings( // MOBILE OPTIMIZED SETTINGS
                preferredContentMode: UserPreferredContentMode.MOBILE, // Force Mobile Site on iOS
                userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", // Force Mobile UA
                contentBlockers: [
                    // Robust Network-Level Ad Blocking
                    ContentBlocker(
                      trigger: ContentBlockerTrigger(
                        urlFilter: kAdUrlFilterPattern,
                      ),
                      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
                    ),
                ],
              ),
            onWebViewCreated: (controller) => _ctrl = controller,
            onLoadStart: (controller, url) {
              _startTime = DateTime.now();
              setState(() => _progress = 0);
            },
            onProgressChanged: (controller, progress) {
              if (mounted) setState(() => _progress = progress / 100);
            },
            onLoadStop: (controller, url) async {
              _ptrCtrl.endRefreshing();
              // Inject clean ad-blocker script
              await controller.evaluateJavascript(source: _contentEnhancementScript);
              
              // Register controller with ReaderController
              ref.read(readerControllerProvider.notifier).setWebViewController(controller);
              
              await _restoreScrollPosition();

              try {
                 await controller.evaluateJavascript(source: "document.body.innerText");
              } catch (e, stack) {
                 ref.read(structuredLoggerProvider).warning('Text extraction failed', e, stack);
              }
            },
            onLoadError: (_, __, ___, ____) => _showErrorSnackbar('Load error'),
          ),
        ),

        // 2. Native Reader View Overlay
        if (ref.watch(readerControllerProvider).isReaderMode) ...[
          Container(
            color: scheme.surface,
            child: ref.watch(readerControllerProvider).article != null
                ? NativeReaderView(article: ref.watch(readerControllerProvider).article!)
                : const Center(child: CircularProgressIndicator()),
          ),
        ],

        // 3. Loading Overlay for Extraction
        if (ref.watch(readerControllerProvider).isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),

      ],
    ),
  ), 
          // Note: MiniPlayer moved to overlay or bottom bar if needed, 
          // removing Stack from here simplifies layout.
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface.withOpacity(0.9),
          border: Border(top: BorderSide(color: scheme.outlineVariant.withOpacity(0.3))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
             
                Settings3DButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () async {
                    if (await _ctrl?.canGoBack() ?? false) {
                      _ctrl?.goBack();
                    } else {
                      _goToPreviousArticle();
                    }
                  },
                  width: 56,
                ),
                
          
                Consumer(
                  builder: (context, ref, _) {
                    final isFav = ref.watch(isFavoriteArticleProvider(_currentArticle));
                    return Settings3DButton(
                      icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      isDestructive: isFav, // Use destructive style for red heart
                      onTap: _toggleFavorite,
                      width: 56,
                    );
                  },
                ),

             
                Consumer(
                  builder: (context, ref, _) {
                    final savedArticles = ref.watch(savedArticlesProvider).articles;
                    final isSaved = savedArticles.any((a) => a.url == _currentArticle.url);
                    
                    return Settings3DButton(
                      icon: isSaved ? Icons.download_done_rounded : Icons.download_for_offline_rounded,
                      isSelected: isSaved,
                      onTap: _toggleOfflineSave,
                      width: 56,
                    );
                  },
                ),

   
                Settings3DButton(
                  icon: Icons.arrow_forward_rounded,
                  onTap: () async {
                    if (await _ctrl?.canGoForward() ?? false) {
                      _ctrl?.goForward();
                    } else {
                      _goToNextArticle();
                    }
                  },
                  width: 56,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}
