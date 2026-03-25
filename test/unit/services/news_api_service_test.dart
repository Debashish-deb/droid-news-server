import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:bdnewsreader/infrastructure/services/news/news_api_service.dart';
import 'package:bdnewsreader/core/telemetry/structured_logger.dart';

@GenerateMocks([http.Client, StructuredLogger])
import 'news_api_service_test.mocks.dart';

void main() {
  group('News API Service Tests', () {
    late MockStructuredLogger mockLogger;
    late NewsApiService newsApiService;

    setUp(() {
      mockLogger = MockStructuredLogger();
      newsApiService = NewsApiService(mockLogger);
    });

    group('fetchFromNewsData', () {
      test('returns empty list as API is currently stubbed', () async {
        // Act
        final articles = await newsApiService.fetchFromNewsData(
          category: 'latest',
        );

        // Assert
        expect(articles.isEmpty, true);
        verify(
          mockLogger.info('API Stub: fetchFromNewsData skipped'),
        ).called(1);
      });
    });

    group('fetchFromGNews', () {
      test('returns empty list as GNews is currently stubbed', () async {
        // Act
        final articles = await newsApiService.fetchFromGNews(
          category: 'international',
        );

        // Assert
        expect(articles.isEmpty, true);
        verify(mockLogger.info('API Stub: fetchFromGNews skipped')).called(1);
      });
    });
  });
}
