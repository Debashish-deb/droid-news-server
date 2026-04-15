import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import 'certificate_pinner.dart';

class SSLPinning {
  SSLPinning._();

  static SecurityContext? _strictContext;
  static HttpClient? _defaultHttpClient;
  static HttpClient? _strictHttpClient;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    _ensureInitialized();
  }

  static http.Client createHttpClient() {
    _ensureInitialized();
    return _PinnedAwareHttpClient();
  }

  static HttpClient getHttpClientFor(Uri uri) {
    _ensureInitialized();
    if (_shouldPin(uri)) {
      return _strictHttpClient ??= _buildStrictHttpClient();
    }
    return _defaultHttpClient ??= _buildDefaultHttpClient();
  }

  static HttpClient getSecureHttpClient() {
    _ensureInitialized();
    return _strictHttpClient ??= _buildStrictHttpClient();
  }

  @visibleForTesting
  static bool get debugUsesDefaultTrustedRoots =>
      identical(_strictContext, SecurityContext.defaultContext);

  @visibleForTesting
  static void debugReset() {
    _defaultHttpClient?.close(force: true);
    _strictHttpClient?.close(force: true);
    _defaultHttpClient = null;
    _strictHttpClient = null;
    _strictContext = null;
    _isInitialized = false;
  }

  static void configureDio(Dio dio) {
    _ensureInitialized();
    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () => getSecureHttpClient();
    }
  }

  static bool verifyCertificateFingerprint(
    X509Certificate cert,
    String expectedFingerprint,
  ) {
    if (CertificatePinner.allowInsecureCertificatesForDevelopment) {
      return true;
    }

    final actualBase64 = base64
        .encode(sha256.convert(cert.der).bytes)
        .toLowerCase();
    final actualHex = sha256.convert(cert.der).toString().toLowerCase();
    final normalizedExpected = expectedFingerprint
        .trim()
        .replaceFirst(RegExp(r'^sha256/', caseSensitive: false), '')
        .replaceAll(':', '')
        .toLowerCase();
    return normalizedExpected == actualBase64 ||
        normalizedExpected == actualHex;
  }

  static HttpClient _buildDefaultHttpClient() => HttpClient();

  static HttpClient _buildStrictHttpClient() {
    _ensureInitialized();
    final strictContext = _strictContext!;

    final client = HttpClient(context: strictContext);
    client.badCertificateCallback = (cert, host, port) {
      return CertificatePinner.verifyFingerprintForHost(cert, host);
    };
    return client;
  }

  static bool _shouldPin(Uri uri) =>
      uri.scheme == 'https' && CertificatePinner.isPinnedHost(uri.host);

  static void _ensureInitialized() {
    if (_isInitialized) {
      return;
    }

    // Keep the trust store empty so pinned hosts must pass fingerprint checks.
    _strictContext = SecurityContext();
    _isInitialized = true;
    if (kDebugMode) debugPrint('🔐 SSL pinning initialized');
  }
}

class _PinnedAwareHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpClient = SSLPinning.getHttpClientFor(request.url);
    final ioRequest = await httpClient.openUrl(request.method, request.url);
    ioRequest
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;

    request.headers.forEach((name, value) {
      ioRequest.headers.set(name, value);
    });
    await ioRequest.addStream(request.finalize());

    final response = await ioRequest.close();
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });

    return http.StreamedResponse(
      response.cast<List<int>>(),
      response.statusCode,
      contentLength: response.contentLength < 0 ? null : response.contentLength,
      request: request,
      headers: headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {}
}
