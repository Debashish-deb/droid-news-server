import 'package:bdnewsreader/presentation/features/reader/controllers/reader_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reader title resolution', () {
    test('prefers extracted headline when hint is publisher branding', () {
      final title = resolvePreferredReaderTitle(
        extractedTitle: 'আরও ৫ সিটি করপোরেশনে নতুন প্রশাসক, সবাই বিএনপির নেতা',
        titleHint: 'Prothom Alo',
        siteName: 'Prothom Alo',
        sourceUrl: 'https://www.prothomalo.com/bangladesh/example',
      );

      expect(title, 'আরও ৫ সিটি করপোরেশনে নতুন প্রশাসক, সবাই বিএনপির নেতা');
    });

    test('uses hint when extracted title is only publisher name', () {
      final title = resolvePreferredReaderTitle(
        extractedTitle: 'Prothom Alo',
        titleHint: 'আরও ৫ সিটি করপোরেশনে নতুন প্রশাসক, সবাই বিএনপির নেতা',
        siteName: 'Prothom Alo',
        sourceUrl: 'https://www.prothomalo.com/bangladesh/example',
      );

      expect(title, 'আরও ৫ সিটি করপোরেশনে নতুন প্রশাসক, সবাই বিএনপির নেতা');
    });

    test('falls back to generic label when both titles are empty', () {
      final title = resolvePreferredReaderTitle(
        extractedTitle: '',
        titleHint: '',
        siteName: '',
        sourceUrl: '',
      );

      expect(title, 'Reader mode');
    });
  });
}
