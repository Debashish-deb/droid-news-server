import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/performance_config.dart';
import 'app_settings_providers.dart';

/// Provider for the native performance configuration.
/// This uses the auto-detection logic which may include native Android calls.
final performanceConfigProvider = FutureProvider<PerformanceConfig>((ref) async {
  final dataSaver = ref.watch(dataSaverProvider);
  
  // We use defaults for child as this is just used for data retrieval
  // The actual InheritedWidget will be rebuilt in the main app builder.
  return PerformanceConfig.autoDetect(
    child: const SizedBox.shrink(),
    dataSaver: dataSaver,
    // Note: reduceMotion and reduceEffects are handled in the build method 
    // using MediaQuery, but we pass they can be influenced by dataSaver too.
    reduceMotion: dataSaver,
    reduceEffects: dataSaver,
  );
});

/// A simpler provider that returns the current performance tier or defaults
final performanceTierProvider = Provider<DevicePerformanceTier>((ref) {
  final configAsync = ref.watch(performanceConfigProvider);
  return configAsync.maybeWhen(
    data: (config) => config.performanceTier,
    orElse: () => DevicePerformanceTier.midRange,
  );
});
