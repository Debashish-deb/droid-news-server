import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:bdnewsreader/application/lifecycle/app_state_machine.dart';

// Mock OfflineHandler if needed, or rely on default

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLifecycleNotifier', () {
    test('Initial state is coldStart', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(appLifecycleProvider);
      expect(state, AppState.coldStart);
    });

    test('paused lifecycle moves app state to background', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appLifecycleProvider.notifier);

      expect(
        () => notifier.didChangeAppLifecycleState(AppLifecycleState.paused),
        returnsNormally,
      );
      expect(container.read(appLifecycleProvider), AppState.background);
    });

    // Note: detailed testing of async timer/connectivity requires mocking OfflineHandler methods
    // For this demonstration, we verify the enum setup and basic initial state
  });
}
