import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdnewsreader/application/lifecycle/app_state_machine.dart';

// Mock OfflineHandler if needed, or rely on default

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('AppLifecycleNotifier', () {
    test('Initial state is coldStart', () {
      final container = ProviderContainer();
      final state = container.read(appLifecycleProvider);
      expect(state, AppState.coldStart);
    });

    // Note: detailed testing of async timer/connectivity requires mocking OfflineHandler methods
    // For this demonstration, we verify the enum setup and basic initial state
  });
}
