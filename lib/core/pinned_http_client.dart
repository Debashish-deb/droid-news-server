import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'security/certificate_pinner.dart';

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
    final ByteData certData = await rootBundle.load(assetPath);

    // Create a new SecurityContext that does NOT include the platform's default CAs
    final SecurityContext context =
        SecurityContext()
          ..setTrustedCertificatesBytes(certData.buffer.asUint8List());

    // ✅ FIXED: Use CertificatePinner for fingerprint verification
    final HttpClient httpClient = HttpClient(context: context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
          CertificatePinner.verifyFingerprint(cert);

    return IOClient(httpClient);
  }

  /// Creates an [IOClient] with security headers wrapper.
  static Future<http.Client> createWithHeaders(String assetPath) async {
    final ioClient = await create(assetPath);
    return _HeaderHttpClient(ioClient);
  }
}

class _HeaderHttpClient extends http.BaseClient {
  final http.Client _inner;
  _HeaderHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = 'BDNewsReader/1.0 (Android; Secure)';
    request.headers['X-Content-Type-Options'] = 'nosniff';
    request.headers['X-Frame-Options'] = 'DENY';
    return _inner.send(request);
  }
}
