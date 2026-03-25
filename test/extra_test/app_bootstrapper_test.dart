import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bdnewsreader/core/bootstrap/app_bootstrapper.dart';
import 'package:bdnewsreader/core/bootstrap/bootstrap_task.dart';

class MockBootstrapTask extends Mock implements BootstrapTask {}

void main() {
  group('Parallel Bootstrap Tests', () {
    test('should complete initialization within 3 seconds', () async {
      final stopwatch = Stopwatch()..start();
      final task = MockBootstrapTask();
      when(() => task.name).thenReturn('TestTask');
      when(() => task.initialize()).thenAnswer((_) async {});

      await AppBootstrapper.initialize([task]);

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });

    test('should not block on single task failure', () async {
      final failTask = MockBootstrapTask();
      final successTask = MockBootstrapTask();
      
      when(() => failTask.name).thenReturn('FailTask');
      when(() => failTask.initialize()).thenThrow(Exception('Timeout'));
      
      when(() => successTask.name).thenReturn('SuccessTask');
      when(() => successTask.initialize()).thenAnswer((_) async {});

      // Should complete without throwing
      await expectLater(
        AppBootstrapper.initialize([failTask, successTask]), 
        completes,
      );
    });

    test('should respect minimum splash duration', () async {
      final start = DateTime.now();

      await AppBootstrapper.initialize(
        [],
        minDuration: const Duration(seconds: 2),
      );

      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inSeconds, greaterThanOrEqualTo(2));
    });
  });
}
