import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows ONLY the live DSE share-price scroll with full error/loading handling.
class StockExchangeWidget extends StatefulWidget {
  /// Height of the widget; default to 150.
  final double height;

  const StockExchangeWidget({Key? key, this.height = 150}) : super(key: key);

  @override
  State<StockExchangeWidget> createState() => _StockExchangeWidgetState();
}

class _StockExchangeWidgetState extends State<StockExchangeWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  static const _url = 'https://www.dsebd.org/latest_share_price_scroll_l.php';

  @override
  void initState() {
    super.initState();

    // Initialize controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          setState(() {
            _isLoading = true;
            _hasError = false;
          });
        },
        onPageFinished: (_) async {
          // Keep only the first <table>
          await _controller.runJavaScript('''
            (function(){
              const table = document.querySelector('table');
              if (!table) return;
              document.body.innerHTML = '';
              document.body.appendChild(table);
            })();
          ''');
          setState(() {
            _isLoading = false;
          });
        },
        onWebResourceError: (_) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        },
      ))
      ..loadRequest(Uri.parse(_url));
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _controller.reload();
  }

  Future<void> _openInBrowser() => launchUrl(
        Uri.parse(_url),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // WebView content
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: WebViewWidget(controller: _controller),
            ),
          ),

          // Loading spinner
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          // Error UI
          if (_hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load DSE data'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: _reload,
                  ),
                ],
              ),
            ),

          // Controls (refresh + browser)
          if (!_isLoading && !_hasError)
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reload',
                    onPressed: _reload,
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: 'Open in browser',
                    onPressed: _openInBrowser,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
