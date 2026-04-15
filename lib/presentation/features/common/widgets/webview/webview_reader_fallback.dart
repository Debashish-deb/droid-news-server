import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../domain/entities/news_article.dart' show NewsArticle;
import '../../../reader/controllers/reader_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WebViewReaderFallback extends ConsumerWidget {
  const WebViewReaderFallback({
    Key? key,
    required this.readerState,
    required this.currentArticle,
    required this.onRetryReader,
    required this.onShowWebPage,
  }) : super(key: key);

  final ReaderState readerState;
  final NewsArticle currentArticle;
  final Future<void> Function() onRetryReader;
  final Future<void> Function() onShowWebPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
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
              onPressed: () => unawaited(onRetryReader()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Reader'),
            ),
            TextButton(
              onPressed: () => unawaited(onShowWebPage()),
              child: const Text('Show Web Page'),
            ),
          ],
        ),
      ),
    );
  }
}
