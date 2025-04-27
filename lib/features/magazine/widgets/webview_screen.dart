// lib/features/common/webview_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../news/widgets/animated_background.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    required this.url,
    required this.title,
    super.key,
  });

  final String url;
  final String title;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();

    // Initialize the WebView controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            // Enforce HTTPS
            if (uri == null || uri.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onProgress: (progress) => setState(() {
            _progress = progress;
          }),
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) async {
            setState(() => _isLoading = false);
            // Inject viewport meta and custom CSS for magazine layout
            const css = '''
              body { margin: 0; padding: 16px; font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; }
              img { max-width: 100% !important; height: auto !important; display: block; margin: 8px auto; }
              header, footer, nav, .sidebar, .ads { display: none !important; }
              article { max-width: 600px; margin: auto; }
            ''';
            final script = '''
              (function() {
                if (!document.querySelector('meta[name="viewport"]')) {
                  var meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1.0';
                  document.head.appendChild(meta);
                }
                var style = document.createElement('style');
                style.textContent = ${css.replaceAll("'", "\\'")};
                document.head.appendChild(style);
              })();
            ''';
            await _controller.runJavaScript(script);
          },
          onWebResourceError: (error) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load: \${error.description}')),
          ),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _refresh() async {
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.95),
        centerTitle: true,
        title: Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: _isLoading
              ? LinearProgressIndicator(
                  value: _progress / 100.0,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: AnimatedBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: WebViewWidget(controller: _controller),
          ),
        ),
      ),
    );
  }
}
