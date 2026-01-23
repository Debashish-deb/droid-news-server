import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme_provider.dart' show AppThemeMode;
import '../../data/models/news_article.dart';
import '../../widgets/app_drawer.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../presentation/providers/saved_articles_provider.dart';
// For AppThemeMode

class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({required this.news, super.key});
  final NewsArticle news;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  InAppWebViewController? webViewController;
  double progress = 0;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
  }

  void _shareNews() {
    Share.share(widget.news.url, subject: widget.news.title);
  }

  // Content enhancement for live webpages
  Future<void> _injectContentEnhancements(InAppWebViewController controller, bool isDark) async {
    final script = '''
      (function() {
        const style = document.createElement('style');
        style.textContent = \`
          /* Text justification for better readability */
          article, p, div.article-content, div.story-body, div.post-content,
          div.entry-content, div.content, main, div.article-text {
            text-align: justify !important;
            text-justify: inter-word !important;
            hyphens: auto !important;
            -webkit-hyphens: auto !important;
            line-height: 1.7 !important;
            font-size: 17px !important;
          }
          
          /* Better typography */
          body {
            font-size: 17px !important;
            line-height: 1.7 !important;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif !important;
          }
          
          /* Hide ads */
          .ad, .ads, .advertisement, .google-ads, iframe[src*="doubleclick"],
          iframe[src*="googlesyndication"], [id*="taboola"], [id*="outbrain"] {
            display: none !important;
          }
        \`;
        document.head.appendChild(style);
      })();
    ''';
    
    try {
      await controller.evaluateJavascript(source: script);
    } catch (e) {
      print('Failed to inject content enhancements: \$e');
    }
  }

  // HTML Template for offline reading with enhanced readability
  String _wrapHtml(String content, bool isDark) {
    final bgColor = isDark ? '#1C1C1E' : '#FFFFFF';
    final textColor = isDark ? '#E0E0E0' : '#1C1C1E';
    final linkColor = isDark ? '#0A84FF' : '#007AFF'; // iOS blue

    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          * { box-sizing: border-box; }
          
          body { 
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            font-size: 17px;
            line-height: 1.7;
            padding: 20px 16px;
            background-color: $bgColor;
            color: $textColor;
            max-width: 720px;
            margin: 0 auto;
            -webkit-font-smoothing: antialiased;            -moz-osx-font-smoothing: grayscale;
          }
          
          /* Enhanced text justification */
          p, article, div {
            text-align: justify;
            text-justify: inter-word;
            hyphens: auto;
            -webkit-hyphens: auto;
            margin-bottom: 18px;
          }
          
          h1 { 
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 12px;
            line-height: 1.25;
            letter-spacing: -0.5px;
            text-align: left;
          }
          
          .metadata { 
            font-size: 14px;
            color: ${isDark ? '#8E8E93' : '#6E6E73'};
            margin-bottom: 24px;
            font-weight: 500;
          }
          
          img { 
            max-width: 100%;
            height: auto;
            border-radius: 12px;
            margin: 16px 0;
            display: block;
          }
          
          a { 
            color: $linkColor;
            text-decoration: none;
          }
          
          blockquote { 
            border-left: 4px solid $linkColor;
            padding-left: 16px;
            margin: 20px 0;
            color: ${isDark ? '#8E8E93' : '#6E6E73'};
            font-style: italic;
            line-height: 1.6;
          }
        </style>
      </head>
      <body>
        <h1>${widget.news.title}</h1>
        <div class="metadata">
          ${widget.news.source} • ${widget.news.publishedAt.toString().substring(0, 16)}
        </div>
        $content
      </body>
      </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final bool isDark = themeMode == AppThemeMode.dark;

    // Check saved status
    final savedState = ref.watch(savedArticlesProvider);
    final isSaved = savedState.articles.any((a) => a.url == widget.news.url);
    final savedArticle =
        isSaved
            ? savedState.articles.firstWhere((a) => a.url == widget.news.url)
            : null;

    final bool hasOfflineContent = savedArticle?.fullContent.isNotEmpty == true;

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(widget.news.source),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareNews),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => launchUrl(Uri.parse(widget.news.url)),
          ),
        ],
      ),

      body: Stack(
        children: [
          // Skip WebView in tests to avoid platform view crashes
          Platform.environment.containsKey('FLUTTER_TEST')
              ? const Center(child: Text('WebView Placeholder'))
              : InAppWebView(
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                  // Enhanced readability
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  textZoom: 110, // Slightly larger for better reading
javaScriptCanOpenWindowsAutomatically: false, // Block pop-ups
                  supportZoom: true,
                  builtInZoomControls: true,
                  displayZoomControls: false,
                  // Content blocking
                  contentBlockers: [
                    ContentBlocker(
                      trigger: ContentBlockerTrigger(
                        urlFilter: ".*",
                        resourceType: [ContentBlockerTriggerResourceType.IMAGE],
                        ifDomain: ["*doubleclick.net", "*googlesyndication.com"],
                      ),
                      action: ContentBlockerAction(
                        type: ContentBlockerActionType.BLOCK,
                      ),
                    ),
                  ],
                ),
                onWebViewCreated: (controller) {
                  webViewController = controller;

                  if (hasOfflineContent) {
                    // 📄 HYBRID: Load offline HTML
                    print('📱 Loading OFFLINE content');
                    _isOfflineMode = true;
                    controller.loadData(
                      data: _wrapHtml(savedArticle!.fullContent, isDark),
                      encoding: 'utf-8',
                    );
                  } else {
                    // 🌐 HYBRID: Load live URL
                    print('🌐 Loading LIVE url');
                    _isOfflineMode = false;
                    controller.loadUrl(
                      urlRequest: URLRequest(url: WebUri(widget.news.url)),
                    );
                  }
                },
                onProgressChanged: (controller, p) {
                  setState(() {
                    progress = p / 100;
                  });
                  
                  // Inject content enhancements when page is loading
                  if (p > 50 && p < 70 && !_isOfflineMode) {
                    _injectContentEnhancements(controller, isDark);
                  }
                },
                onLoadStop: (controller, url) async {
                  // Apply final enhancements after page loads
                  if (!_isOfflineMode) {
                    await _injectContentEnhancements(controller, isDark);
                  }
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  // Open external links in browser
                  return NavigationActionPolicy.ALLOW;
                },
                // Block unwanted new windows/pop-ups
                onCreateWindow: (controller, createWindowAction) async {
                  return false; // Block all new windows
                },
              ),

          if (progress < 1.0)
            LinearProgressIndicator(value: progress, color: Colors.green),

        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final notifier = ref.read(savedArticlesProvider.notifier);
  
          if (isSaved) {
                await notifier.removeArticle(widget.news.url);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Article removed from downloads')),
                );
                // Reload live URL if we just removed the offline copy
                if (_isOfflineMode) {
                  webViewController?.loadUrl(
                    urlRequest: URLRequest(url: WebUri(widget.news.url)),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading article...')),
                );
  
                final success = await notifier.saveArticle(widget.news);
  
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Article saved for offline reading'
                          : 'Failed to save article',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
        icon: Icon(isSaved ? Icons.download_done : Icons.download),
        label: Text(isSaved ? 'Saved' : 'Save Offline'),
        backgroundColor: isSaved ? Colors.green : null,
        foregroundColor: isSaved ? Colors.white : null,
      ),
    );
  }
}
