// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'bootstrap_task.dart';

class AppBootstrapper {
  static Future<void> initialize(
    List<BootstrapTask> tasks, {
    Duration minDuration = Duration.zero,
  }) async {
    final stopwatch = Stopwatch()..start();

    debugPrint('🚀 Starting parallel bootstrap with ${tasks.length} tasks');

    try {
      await Future.wait([
        ...tasks.map((task) async {
          final taskStopwatch = Stopwatch()..start();
          try {
            await task.initialize();
            debugPrint(
              '✅ Task "${task.name}" completed in ${taskStopwatch.elapsedMilliseconds}ms',
            );
          } catch (e) {
            debugPrint('❌ Task "${task.name}" failed: $e');
            rethrow;
          }
        }),
        Future.delayed(minDuration),
      ]);

      debugPrint(
        '🏁 Parallel bootstrap completed in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      debugPrint('🚨 Critical error during bootstrap: $e');
    }
  }
}
