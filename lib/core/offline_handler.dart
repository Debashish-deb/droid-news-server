import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

class OfflineHandler {
  factory OfflineHandler() => _instance;
  OfflineHandler._internal() {
    _initListener();
  }
  static final OfflineHandler _instance = OfflineHandler._internal();

  bool _isOffline = false;
  bool get isDeviceOffline => _isOffline;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void _initListener() {
    _subscription = Connectivity().onConnectivityChanged
        .debounceTime(const Duration(milliseconds: 300))
        .listen((List<ConnectivityResult> results) {
          final bool offline = results.contains(ConnectivityResult.none);

          if (_isOffline != offline) {
            _isOffline = offline;
            _controller.add(offline);
          }
        });

    Connectivity().checkConnectivity().then((List<ConnectivityResult> results) {
      _isOffline = results.contains(ConnectivityResult.none);
    });
  }

  /// Static Accessor for manual checks
  static Future<bool> isOffline() async {
    return _instance._isOffline;
  }

  /// Force refresh status
  static Future<void> checkNow() async {
    final List<ConnectivityResult> results =
        await Connectivity().checkConnectivity();
    _instance._isOffline = results.contains(ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
