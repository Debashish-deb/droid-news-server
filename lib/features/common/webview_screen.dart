import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/favorites_manager.dart';
import '../../data/models/news_article.dart';
import '/l10n/app_localizations.dart';
import '../../core/theme_provider.dart';

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
  final String url;
  final String title;

  const WebViewScreen({
    Key? key,
    required this.url,
    this.title = 'Web View',
  }) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _ctrl;
  late final PullToRefreshController _ptrCtrl;
  double _progress = 0.0;
  bool _readerMode = false;

  int _scrollY = 0;
  DateTime? _startTime;

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
    await prefs.setStringList('read_stats', list.take(50).toList()); // cap to 50 entries
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        description: '',
        imageUrl: null,
        language: 'en',
        snippet: '',
        fullContent: '',
        isLive: false,
      );
      FavoritesManager.instance.toggleArticle(article);
      await _showErrorSnackbar(AppLocalizations.of(context)!.bookmarkSuccess);
    } catch (e) {
      await _showErrorSnackbar('Bookmark failed: $e');
    }
  }

  Future<void> _toggleReaderMode() async {
    if (_ctrl == null) return;
    _readerMode = !_readerMode;
    final js = _readerMode
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
        _TranslateEngine.google => 'https://translate.google.com/translate?u=$encoded',
        _TranslateEngine.bing => 'https://www.bing.com/translator?text=$encoded',
        _TranslateEngine.deepl => 'https://www.deepl.com/translator#auto/en/$encoded',
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
          IconButton(icon: const Icon(Icons.translate), onPressed: () => _translate(_TranslateEngine.google)),
          IconButton(icon: const Icon(Icons.share), onPressed: _shareUrl),
          IconButton(icon: const Icon(Icons.bookmark_add), onPressed: _bookmarkUrl),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == '_toggleReader') _toggleReaderMode();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: '_toggleReader',
                checked: _readerMode,
                child: Text(loc.readerMode),
              ),
            ],
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        pullToRefreshController: _ptrCtrl,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          useWideViewPort: true,
          loadWithOverviewMode: true,
          builtInZoomControls: true,
          supportZoom: true,
          displayZoomControls: false,
          cacheEnabled: true,
        ),
        onWebViewCreated: (controller) => _ctrl = controller,
        onLoadStart: (_, __) {
          _startTime = DateTime.now();
          setState(() => _progress = 0);
        },
        onProgressChanged: (_, p) => setState(() => _progress = p / 100),
        onLoadStop: (_, __) async {
          _ptrCtrl.endRefreshing();
          await _restoreScrollPosition();
        },
        onLoadError: (_, __, ___, ____) => _showErrorSnackbar(loc.loadError),
        onLoadHttpError: (_, __, ___, ____) => _showErrorSnackbar(loc.loadError),
      ),
      bottomNavigationBar: BottomAppBar(
        color: scheme.surface.withOpacity(0.08),
        elevation: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _ctrl?.goBack()),
            IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _ctrl?.goForward()),
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => _ctrl?.reload()),
            IconButton(icon: const Icon(Icons.home), onPressed: () {
              _ctrl?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
            }),
          ],
        ),
      ),
    );
  }
}
