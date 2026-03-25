import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:bdnewsreader/presentation/providers/language_providers.dart';
import 'package:bdnewsreader/application/sync/sync_orchestrator.dart';
import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';

import '../core/language_provider_test.mocks.dart';

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {
  @override
  void registerLanguageNotifier(LanguageNotifier? notifier) => super
      .noSuchMethod(Invocation.method(#registerLanguageNotifier, [notifier]));

  @override
  Future<void> pushSettings({bool immediate = false}) => super.noSuchMethod(
    Invocation.method(#pushSettings, [], {#immediate: immediate}),
    returnValue: Future<void>.value(),
    returnValueForMissingStub: Future<void>.value(),
  );
}

void main() {
  provideDummy<Either<AppFailure, String>>(const Right('en'));
  provideDummy<Either<AppFailure, void>>(const Right(null));

  group('Language Provider Tests', () {
    late MockSettingsRepository mockRepo;
    late _MockSyncOrchestrator mockSync;
    late LanguageNotifier languageNotifier;

    setUp(() {
      mockRepo = MockSettingsRepository();
      mockSync = _MockSyncOrchestrator();

      when(mockRepo.getLanguageCodeSync()).thenReturn('en');
      languageNotifier = LanguageNotifier(mockRepo, mockSync);
    });

    group('initialization', () {
      test('default language loads when no prefs', () async {
        // Arrange
        when(
          mockRepo.getLanguageCode(),
        ).thenAnswer((_) async => const Right('en'));

        // Act
        await languageNotifier.initialize();

        // Assert
        expect(languageNotifier.current.languageCode, 'en');
        verify(mockRepo.getLanguageCode()).called(1);
      });

      test('loads stored language', () async {
        // Arrange
        when(
          mockRepo.getLanguageCode(),
        ).thenAnswer((_) async => const Right('bn'));

        // Act
        await languageNotifier.initialize();

        // Assert
        expect(languageNotifier.current.languageCode, 'bn');
        verify(mockRepo.getLanguageCode()).called(1);
      });
    });

    group('language switching', () {
      test('setLanguage updates locale and persists', () async {
        // Arrange
        when(
          mockRepo.setLanguageCode('bn'),
        ).thenAnswer((_) async => const Right(null));

        // Act
        await languageNotifier.setLanguage('bn');

        // Assert
        expect(languageNotifier.current.languageCode, 'bn');
        verify(mockRepo.setLanguageCode('bn')).called(1);
        verify(mockSync.pushSettings(immediate: true)).called(1);
      });

      test('toggleLanguage switches between en/bn', () async {
        // Arrange
        when(
          mockRepo.setLanguageCode('bn'),
        ).thenAnswer((_) async => const Right(null));

        // Act
        await languageNotifier.toggleLanguage();

        // Assert
        expect(languageNotifier.current.languageCode, 'bn');
        verify(mockRepo.setLanguageCode('bn')).called(1);
      });

      test('toggleLanguage from bn to en', () async {
        // Arrange
        // Initial state is 'en', toggle to 'bn', then toggle back to 'en'
        when(
          mockRepo.setLanguageCode('bn'),
        ).thenAnswer((_) async => const Right(null));
        when(
          mockRepo.setLanguageCode('en'),
        ).thenAnswer((_) async => const Right(null));

        await languageNotifier.setLanguage('bn');
        await languageNotifier.toggleLanguage();

        // Assert
        expect(languageNotifier.current.languageCode, 'en');
      });
    });

    group('language normalization', () {
      test('normalizes Bengali correctly', () async {
        // Arrange
        when(
          mockRepo.setLanguageCode('bn'),
        ).thenAnswer((_) async => const Right(null));

        // Act
        await languageNotifier.setLanguage('BN');

        // Assert
        expect(languageNotifier.current.languageCode, 'bn');
      });

      test('handles invalid locale gracefully (defaults to en)', () async {
        // Act
        await languageNotifier.setLanguage('invalid');

        // Assert
        expect(languageNotifier.current.languageCode, 'en');
      });
    });
  });
}
