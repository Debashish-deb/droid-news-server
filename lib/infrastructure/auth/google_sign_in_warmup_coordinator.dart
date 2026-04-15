import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInWarmupCoordinator {
  GoogleSignInWarmupCoordinator(this._googleSignIn);

  final GoogleSignIn _googleSignIn;
  Future<GoogleSignInAccount?>? _warmupFuture;

  Future<GoogleSignInAccount?> prewarm({
    Duration timeout = const Duration(seconds: 10),
  }) {
    final current = _googleSignIn.currentUser;
    if (current != null) {
      return Future<GoogleSignInAccount?>.value(current);
    }

    final inFlight = _warmupFuture;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<GoogleSignInAccount?> future;
    future = _googleSignIn
        .signInSilently()
        .timeout(timeout, onTimeout: () => _googleSignIn.currentUser)
        .catchError((_) => _googleSignIn.currentUser)
        .whenComplete(() {
          if (identical(_warmupFuture, future)) {
            _warmupFuture = null;
          }
        });

    _warmupFuture = future;
    return future;
  }

  Future<GoogleSignInAccount?> takePrewarmedUser({
    Duration waitLimit = const Duration(milliseconds: 120),
  }) async {
    final current = _googleSignIn.currentUser;
    if (current != null) {
      return current;
    }

    final inFlight = _warmupFuture;
    if (inFlight == null) {
      return null;
    }

    try {
      return await inFlight.timeout(
        waitLimit,
        onTimeout: () => _googleSignIn.currentUser,
      );
    } catch (_) {
      return _googleSignIn.currentUser;
    }
  }

  void clear() {
    _warmupFuture = null;
  }
}
