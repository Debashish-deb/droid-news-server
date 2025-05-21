import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/io_client.dart';

/// A utility for creating HTTP clients with certificate pinning.
///
/// Bundle your trusted server certificates under assets/certs/, for example:
///   - assets/certs/newsapi.pem
///   - assets/certs/openweathermap.pem
///
/// Then declare them in pubspec.yaml under flutter/assets.

class PinnedHttpClient {
  /// Creates an [IOClient] that trusts only the certificate at [assetPath].
  ///
  /// [assetPath] is the path to a PEM file in your assets, e.g. 'assets/certs/newsapi.pem'.
  static Future<IOClient> create(String assetPath) async {
    // Load the certificate bytes from assets
    final certData = await rootBundle.load(assetPath);

    // Create a new SecurityContext that does NOT include the platform's default CAs
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(certData.buffer.asUint8List());

    // Optionally verify the server DNS/IP matches
    final httpClient = HttpClient(context: context)
      // Reject certificates not matching the pinned one
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => false;

    return IOClient(httpClient);
  }
}
