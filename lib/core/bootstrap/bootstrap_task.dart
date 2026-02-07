abstract class BootstrapTask {
  String get name;
  Future<void> initialize();
}
