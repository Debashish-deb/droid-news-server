import 'package:bdnewsreader/presentation/features/reader/controllers/reader_controller.dart';
import 'package:flutter_test/flutter_test.dart';

String _normalizeComparable(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0980-\u09ff]+'), '');

void main() {
  group('Reader content sanitization', () {
    const noiseTokens = <String>[
      'related',
      'recommended',
      'trending',
      'আরও পড়ুন',
      'সম্পর্কিত',
    ];
    const noisyPrefixes = <String>[
      'read more',
      'also read',
      'আরও পড়ুন',
      'related news',
    ];

    test('strict pass removes related headline blocks', () {
      const html = '''
      <article>
        <h1>Main Policy Shift Announced</h1>
        <div class="related">
          <a href="#">Related headline one</a>
          <a href="#">Related headline two</a>
          <a href="#">Related headline three</a>
        </div>
        <p>Main paragraph one with enough detail. It explains the policy in depth.</p>
        <p>Second paragraph contains article body and context for readers.</p>
      </article>
      ''';

      final output = processReaderHtmlForTtsIsolate(
        const ReaderHtmlProcessInput(
          content: html,
          articleTitle: 'Main Policy Shift Announced',
          noiseTokens: noiseTokens,
          noisyPrefixes: noisyPrefixes,
        ),
      );

      final combined = output.chunks
          .map((chunk) => chunk.text.toLowerCase())
          .join(' ');

      expect(combined.contains('related headline'), isFalse);
      expect(combined.contains('main paragraph one'), isTrue);
      expect(output.removedElements, greaterThan(0));
    });

    test('duplicate title echoes are removed from chunk stream', () {
      const html = '''
      <article>
        <h1>Economic Outlook 2026</h1>
        <p>Economic Outlook 2026</p>
        <p>The first real paragraph starts here and includes enough sentence content to keep.</p>
        <p>Another paragraph explains the details for the reader mode body.</p>
      </article>
      ''';

      final output = processReaderHtmlForTtsIsolate(
        const ReaderHtmlProcessInput(
          content: html,
          articleTitle: 'Economic Outlook 2026',
          noiseTokens: noiseTokens,
          noisyPrefixes: noisyPrefixes,
        ),
      );

      final normalizedTitle = _normalizeComparable('Economic Outlook 2026');
      final titleMentions = output.chunks.where((chunk) {
        final normalizedChunk = _normalizeComparable(chunk.text);
        return normalizedChunk.contains(normalizedTitle);
      }).length;

      expect(titleMentions, 0);
      expect(output.chunks.isNotEmpty, isTrue);
    });

    test('soft pass is selected when strict quality gate fails', () {
      const strictOutput = ReaderHtmlProcessOutput(
        html: '<p>too short</p>',
        chunks: [],
        removedElements: 0,
        linkHeavyRemoved: 0,
        headlineListRemoved: 0,
        contaminationScore: 0.90,
        contentLength: 90,
      );

      const softOutput = ReaderHtmlProcessOutput(
        html: '<p>valid body text</p>',
        chunks: [],
        removedElements: 4,
        linkHeavyRemoved: 1,
        headlineListRemoved: 1,
        contaminationScore: 0.22,
        contentLength: 540,
      );

      final pass = chooseReaderExtractionPass(
        strictOutput: strictOutput,
        softOutput: softOutput,
      );

      expect(pass, 'soft');
    });

    test('mixed Bangla and English noise is removed while body remains', () {
      const html = '''
      <div class="content-wrap">
        <h1>বাংলাদেশ অর্থনীতি আপডেট</h1>
        <p>আরও পড়ুন: সম্পর্কিত খবর</p>
        <ul class="recommended">
          <li><a href="#">Related News One</a></li>
          <li><a href="#">Related News Two</a></li>
          <li><a href="#">Related News Three</a></li>
        </ul>
        <p>বাংলাদেশের অর্থনীতিতে নতুন প্রবৃদ্ধির তথ্য প্রকাশিত হয়েছে।</p>
        <p>The report says exports increased in the last quarter with sustained growth.</p>
      </div>
      ''';

      final output = processReaderHtmlForTtsIsolate(
        const ReaderHtmlProcessInput(
          content: html,
          articleTitle: 'বাংলাদেশ অর্থনীতি আপডেট',
          noiseTokens: noiseTokens,
          noisyPrefixes: noisyPrefixes,
        ),
      );

      final combined = output.chunks.map((chunk) => chunk.text).join(' ');

      expect(combined.contains('আরও পড়ুন'), isFalse);
      expect(combined.toLowerCase().contains('related news'), isFalse);
      expect(
        combined.contains('বাংলাদেশের অর্থনীতিতে নতুন প্রবৃদ্ধির তথ্য'),
        isTrue,
      );
      expect(combined.toLowerCase().contains('exports increased'), isTrue);
    });

    test('headline-dump extraction fails soft quality gate', () {
      const html = '''
      <article>
        <h1>Market Update</h1>
        <div class="related-news">
          <a href="#">Breaking: Market Snapshot</a>
          <a href="#">Top Stories You Should Read</a>
          <a href="#">Analyst View On Market Movement</a>
          <a href="#">Weekly Picks For Investors</a>
          <a href="#">Editor's Choice</a>
          <a href="#">Top Reads</a>
        </div>
      </article>
      ''';

      final output = processReaderHtmlForTtsIsolate(
        const ReaderHtmlProcessInput(
          content: html,
          articleTitle: 'Market Update',
          noiseTokens: noiseTokens,
          noisyPrefixes: noisyPrefixes,
          strictMode: false,
        ),
      );

      final passesSoft = passesReaderQualityGate(
        contentLength: output.contentLength,
        contaminationScore: output.contaminationScore,
        strict: false,
      );

      expect(output.contaminationScore, greaterThan(0.55));
      expect(passesSoft, isFalse);
    });

    test('fallback gate accepts short but coherent article text', () {
      final accepted = passesReaderFallbackQualityGate(
        contentLength: 78,
        chunkCount: 1,
        qualityScore: 0.82,
      );

      expect(accepted, isTrue);
    });

    test(
      'fallback gate blocks feed-like classification for weak short body',
      () {
        final accepted = passesReaderFallbackQualityGate(
          contentLength: 128,
          chunkCount: 2,
          qualityScore: 0.61,
          classifiedPageType: ReaderPageType.listing,
        );

        expect(accepted, isFalse);
      },
    );

    test('readable-body recovery allows low-score short article fallback', () {
      const body = '''
      ঢাকার বাজারে চাল, ডাল ও তেলের দাম নতুন করে বেড়েছে এবং ভোক্তারা চাপের মুখে পড়েছেন।
      খুচরা ব্যবসায়ীরা বলছেন, পাইকারি বাজারে সরবরাহ কমে যাওয়ায় গত তিন দিনে দাম দ্রুত বেড়েছে।
      ''';

      expect(looksLikeReaderBodyText(body), isTrue);
      final accepted = passesReaderFallbackQualityGate(
        contentLength: 142,
        chunkCount: 1,
        qualityScore: 0.34,
        likelyReadableBody: true,
      );

      expect(accepted, isTrue);
    });
  });
}
