// path: features/webview/web_view_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.url, this.title = 'Web View'});

  final String url;
  final String title;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;
  late PullToRefreshController pullToRefreshController;
  final ScrollController _scrollController = ScrollController();
  double progress = 0;
  double _opacity = 0.4; // Frost opacity

  @override
  void initState() {
    super.initState();
    pullToRefreshController = PullToRefreshController(
      onRefresh: () async {
        if (webViewController != null) {
          webViewController!.reload();
        }
      },
    );
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    double offset = _scrollController.offset;
    setState(() {
      _opacity = (0.4 - (offset / 300)).clamp(0.2, 0.4);
    });
  }

  Future<void> _shareCurrentUrl() async {
    final url = await webViewController?.getUrl();
    if (url != null) {
      Share.share(url.toString());
    }
  }

  Future<void> _saveCurrentUrl() async {
    final url = await webViewController?.getUrl();
    if (url != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_webview_url', url.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL saved successfully!')),
      );
    }
  }

  Future<void> _translateToBengali() async {
    final url = await webViewController?.getUrl();
    if (url != null) {
      final translateUrl = 'https://translate.google.com/translate?hl=bn&sl=auto&tl=bn&u=${Uri.encodeComponent(url.toString())}';
      await webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(translateUrl)));
    }
  }

  Color _getGlassColor(bool isHeader) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return Colors.black.withOpacity(isHeader ? 0.4 : 0.3);
    } else {
      return isHeader ? Colors.blue.withOpacity(0.2) : Colors.lightBlue.withOpacity(0.2);
    }
  }

  Color _getFontColor() {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _getGlassColor(true).withOpacity(_opacity),
            ),
          ),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: _getFontColor(),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actionsIconTheme: IconThemeData(
          color: _getFontColor(),
          size: 26,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate),
            onPressed: _translateToBengali,
            tooltip: 'Translate to Bengali',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareCurrentUrl,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: _saveCurrentUrl,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: progress < 1.0
              ? LinearProgressIndicator(value: progress)
              : const SizedBox(height: 3),
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        pullToRefreshController: pullToRefreshController,
        onWebViewCreated: (controller) => webViewController = controller,
        onLoadStop: (controller, url) async {
          pullToRefreshController.endRefreshing();
        },
        onProgressChanged: (controller, prog) {
          setState(() {
            progress = prog / 100;
          });
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: _getGlassColor(false),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () async {
                await webViewController?.loadUrl(
                  urlRequest: URLRequest(url: WebUri(widget.url)),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await webViewController?.canGoBack() ?? false) {
                  await webViewController?.goBack();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () async {
                if (await webViewController?.canGoForward() ?? false) {
                  await webViewController?.goForward();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await webViewController?.reload();
              },
            ),
          ],
        ),
      ),
    );
  }
}
