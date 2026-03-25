import 'dart:async';
import 'package:bdnewsreader/core/tts/domain/repositories/tts_repository.dart';
import 'package:bdnewsreader/core/tts/domain/entities/tts_chunk.dart';
import 'package:bdnewsreader/core/tts/presentation/providers/tts_controller.dart'
    show TtsController;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mocktail/mocktail.dart' show registerFallbackValue;

class MockTtsRepository extends Mock implements TtsRepository {
  @override
  Stream<int> get currentChunkIndex => Stream.value(-1);
  @override
  Stream<double> get progress => Stream.value(0.0);

  @override
  Future<void> play(List<TtsChunk>? chunks, int? startIndex) =>
      super.noSuchMethod(
        Invocation.method(#play, [chunks, startIndex]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      );

  @override
  Future<void> stop() => super.noSuchMethod(
    Invocation.method(#stop, []),
    returnValue: Future<void>.value(),
    returnValueForMissingStub: Future<void>.value(),
  );

  @override
  Future<void> pause() => super.noSuchMethod(
    Invocation.method(#pause, []),
    returnValue: Future<void>.value(),
    returnValueForMissingStub: Future<void>.value(),
  );

  @override
  Future<void> resume() => super.noSuchMethod(
    Invocation.method(#resume, []),
    returnValue: Future<void>.value(),
    returnValueForMissingStub: Future<void>.value(),
  );
}

class AudioFocusException implements Exception {
  final String message;
  AudioFocusException(this.message);
  @override
  String toString() => 'AudioFocusException: $message';
}

void main() {
  setUpAll(() {
    registerFallbackValue(<TtsChunk>[]);
  });

  group('TTS Controller Tests', () {
    late MockTtsRepository mockTtsRepository;
    late TtsController ttsController;

    setUp(() {
      mockTtsRepository = MockTtsRepository();
      ttsController = TtsController(mockTtsRepository);
    });

    tearDown(() {
      ttsController.dispose();
    });

    group('TTS speech control', () {
      test('TTS starts speaking text', () async {
        // Arrange
        const testText = 'Hello world';
        when(mockTtsRepository.play(any, any)).thenAnswer((_) async {});

        // Act
        await ttsController.playFromText(testText);

        // Assert
        verify(mockTtsRepository.play(any, 0)).called(1);
      });

      test('TTS pauses speech', () async {
        // Arrange
        when(mockTtsRepository.play(any, any)).thenAnswer((_) async {});
        await ttsController.playFromText('Test');

        when(mockTtsRepository.pause()).thenAnswer((_) async {});

        // Act
        await ttsController.pause();

        // Assert
        verify(mockTtsRepository.pause()).called(1);
      });

      test('TTS resumes speech', () async {
        // Arrange
        when(mockTtsRepository.play(any, any)).thenAnswer((_) async {});
        await ttsController.playFromText('Test');

        when(mockTtsRepository.pause()).thenAnswer((_) async {});
        await ttsController.pause();

        when(mockTtsRepository.resume()).thenAnswer((_) async {});

        // Act
        await ttsController.resume();

        // Assert
        verify(mockTtsRepository.resume()).called(1);
      });

      test('TTS stops speech', () async {
        // Arrange
        when(mockTtsRepository.stop()).thenAnswer((_) async {});

        // Act
        await ttsController.stop();

        // Assert
        verify(mockTtsRepository.stop()).called(1);
      });

      test('TTS handles long text', () async {
        // Arrange
        const longText =
            'This is a very long text that should be handled properly by the TTS system without causing any issues or crashes during the speech synthesis process.';
        when(mockTtsRepository.play(any, any)).thenAnswer((_) async {});

        // Act
        await ttsController.playFromText(longText);

        // Assert
        verify(mockTtsRepository.play(any, 0)).called(1);
      });

      test('TTS handles empty text', () async {
        // Act
        await ttsController.playFromText('');

        // Assert
        verifyNever(mockTtsRepository.play(any, any));
      });
    });

    group('TTS state management', () {
      test('TTS stops on dispose', () async {
        // Arrange
        final localController = TtsController(mockTtsRepository);
        when(mockTtsRepository.stop()).thenAnswer((_) async {});

        // Act
        localController.dispose();

        // Assert
        verify(mockTtsRepository.stop()).called(1);
      });

      test('multiple play calls handled correctly', () async {
        // Arrange
        when(mockTtsRepository.play(any, any)).thenAnswer((_) async {});

        // Act
        await ttsController.playFromText('First');
        await ttsController.playFromText('Second');

        // Assert
        verify(mockTtsRepository.play(any, 0)).called(2);
      });

      test('TTS handles rapid play/pause', () async {
        // Arrange
        when(mockTtsRepository.play(any, any)).thenAnswer((_) async {});
        when(mockTtsRepository.pause()).thenAnswer((_) async {});
        when(mockTtsRepository.resume()).thenAnswer((_) async {});

        // Act
        await ttsController.playFromText('Test');
        await ttsController.pause();
        await ttsController.resume();

        // Assert
        verify(mockTtsRepository.play(any, 0)).called(1);
        verify(mockTtsRepository.pause()).called(1);
        verify(mockTtsRepository.resume()).called(1);
      });

      test('TTS handles audio focus changes', () async {
        // Arrange
        when(
          mockTtsRepository.play(any, any),
        ).thenThrow(AudioFocusException('Audio focus lost'));

        // Act
        await ttsController.playFromText('Test');

        // Assert
        verify(mockTtsRepository.play(any, 0)).called(1);
      });
    });

    group('TTS error handling', () {
      test('TTS handles engine errors gracefully', () async {
        // Arrange
        when(
          mockTtsRepository.play(any, any),
        ).thenThrow(Exception('TTS engine error'));

        // Act
        await ttsController.playFromText('Test');

        // Assert - Should not crash
        verify(mockTtsRepository.play(any, 0)).called(1);
      });
    });
  });
}
