import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, WidgetRef;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../di/providers.dart';
import 'bootstrap_task.dart';

class DeviceTrustBootstrapper implements BootstrapTask {

  DeviceTrustBootstrapper.withContainer(this.container) : ref = null;
  DeviceTrustBootstrapper(this.ref) : container = null;

  final WidgetRef? ref;
  final ProviderContainer? container;

  @override
  String get name => 'Device Trust';

  @override
  Future<void> initialize() async {
    if (ref != null) {
      await ref!.read(deviceTrustControllerProvider.notifier).initialize();
    } else if (container != null) {
      await container!.read(deviceTrustControllerProvider.notifier).initialize();
    }
  }
}
