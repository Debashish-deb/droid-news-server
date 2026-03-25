import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/presentation/features/tts/core/text_cleaner.dart';

void main() {
  group('TextCleaner Tests', () {
    test('Should strip HTML tags', () {
      const input = '<p>Hello <b>World</b></p><br/>';
      final output = TextCleaner.clean(
        input,
      ); // Assuming static method or instance
      expect(output, 'Hello World');
      // behavior depends on specific implementation details (newlines etc)
    });

    test('Should decode HTML entities', () {
      const input = 'Fish &amp; Chips';
      final output = TextCleaner.clean(input);
      expect(output, 'Fish & Chips');
    });

    test('Should remove ads', () {
      const input = 'News content. [Ad] Buy this. [Sponsored] Click here.';
      final output = TextCleaner.clean(input);
      expect(output, contains('News content.'));
      expect(output, isNot(contains('[Ad]')));
      expect(output, isNot(contains('[Sponsored]')));
    });

    test('Should normalize whitespace', () {
      const input = 'Hello    World. \n\n New Line.';
      final output = TextCleaner.clean(input);
      expect(output, 'Hello World.\n\nNew Line.');
    });

    test('Should convert common emojis (optional)', () {
      // Only if feature enabled
      const input = 'Good job 👍';
      final output = TextCleaner.clean(input);
      // Check if it mapped to text or removed.
      // Based on code "24 common emojis -> text"
      expect(output, contains('thumbs up'));
    });

    test('Should normalize teleprompter pause markers and numbers', () {
      const input = '[LEAD] Breaking news [PAUSE 1.0s] Growth rose 23%.';
      final output = TextCleaner.clean(input);
      expect(output, isNot(contains('[PAUSE')));
      expect(output, contains('twenty three percent'));
      expect(output, contains('\n\n'));
    });
  });
}
