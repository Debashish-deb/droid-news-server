import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/presentation/features/reader/controllers/reader_controller.dart';

void main() {
  group('Reader HTML processing', () {
    test('removes metadata and noisy sections while keeping article body', () {
      const input = ReaderHtmlProcessInput(
        content: '''
<div class="breadcrumb">Home > World</div>
<h1>নতুন মোড় নিচ্ছে যুদ্ধ</h1>
<p>প্রকাশ: ০৭ মার্চ, ২০২৬ ০০:০০</p>
<div class="share-tools">Share this article</div>
<p>ইসরায়েলে ক্লাস্টার ব্যালিস্টিক হামলার নতুন তথ্য এসেছে।</p>
<div class="related">Read more: related story</div>
<p>যুদ্ধ নতুন ধাপে প্রবেশ করেছে।</p>
''',
        articleTitle: 'নতুন মোড় নিচ্ছে যুদ্ধ',
        noiseTokens: <String>['related', 'share', 'breadcrumb', 'read-more'],
        noisyPrefixes: <String>[
          'read more',
          'আরও পড়ুন',
          'published',
          'প্রকাশ',
        ],
      );

      final processed = processReaderHtmlForTtsIsolate(input);

      expect(processed.html.contains('breadcrumb'), isFalse);
      expect(processed.html.contains('share-tools'), isFalse);
      expect(processed.html.contains('প্রকাশ:'), isFalse);
      expect(
        processed.html.contains('ইসরায়েলে ক্লাস্টার ব্যালিস্টিক'),
        isTrue,
      );
      expect(processed.html.contains('যুদ্ধ নতুন ধাপে প্রবেশ করেছে'), isTrue);
      expect(processed.chunks, isNotEmpty);
    });

    test('generates tappable sentence anchors with stable chunk ordering', () {
      const input = ReaderHtmlProcessInput(
        content: '<p>First sentence. Second sentence! Third sentence?</p>',
        articleTitle: 'Sample',
        noiseTokens: <String>[],
        noisyPrefixes: <String>[],
      );

      final processed = processReaderHtmlForTtsIsolate(input);

      expect(processed.chunks.length, 3);
      expect(processed.chunks[0].index, 0);
      expect(processed.chunks[1].index, 1);
      expect(processed.chunks[2].index, 2);
      expect(processed.html.contains('href="reader://chunk/0"'), isTrue);
      expect(processed.html.contains('href="reader://chunk/1"'), isTrue);
      expect(processed.html.contains('href="reader://chunk/2"'), isTrue);
    });

    test('forces category-like labels to static positioning', () {
      const input = ReaderHtmlProcessInput(
        content:
            '<div class="headline-label" style="position:fixed;top:0;">Top Story</div>'
            '<p>Paragraph body text for extraction.</p>',
        articleTitle: 'Sample',
        noiseTokens: <String>[],
        noisyPrefixes: <String>[],
      );

      final processed = processReaderHtmlForTtsIsolate(input);

      expect(processed.html.contains('headline-label'), isTrue);
      expect(processed.html.contains('position:static;'), isTrue);
    });
  });
}
