// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../errors/security_exception.dart';

class PinnedHostPolicy {
  const PinnedHostPolicy({
    required this.host,
    required this.pinDefineName,
    required this.pinValue,
    this.certificateAssetPath,
  });

  final String host;
  final String pinDefineName;
  final String pinValue;
  final String? certificateAssetPath;

  List<String> get pins {
    final rawPinValue =
        pinValue.toUpperCase().contains('PLACEHOLDER') &&
            host == 'newsapi.org' &&
            CertificatePinner._legacyNewsApiPin.isNotEmpty
        ? CertificatePinner._legacyNewsApiPin
        : pinValue;
    return rawPinValue
        .split(',')
        .map((pin) => pin.trim())
        .where((pin) => pin.isNotEmpty)
        .toList(growable: false);
  }
}

class CertificatePinner {
  static const String _legacyNewsApiPin = String.fromEnvironment(
    'SSL_CERT_FINGERPRINT',
  );

  // SECURITY: Hard kill-switch — never allow insecure certs in release, even
  // if someone accidentally passes --dart-define=ALLOW_INSECURE_CERTS=true.
  static bool get allowInsecureCertificatesForDevelopment {
    if (kReleaseMode) return false; // ABSOLUTE — cannot be overridden
    return const bool.fromEnvironment(
      'ALLOW_INSECURE_CERTS',
    );
  }

  static const List<PinnedHostPolicy> _policies = <PinnedHostPolicy>[
    PinnedHostPolicy(
      host: 'newsdata.io',
      pinDefineName: 'PIN_NEWSDATA_SHA256',
      pinValue: String.fromEnvironment(
        'PIN_NEWSDATA_SHA256',
        defaultValue: 'cBECzPI6CrrWoz67IM9ZhY7Hp6N+qogy8/StAqlJxpU=',
      ),
    ),
    PinnedHostPolicy(
      host: 'gnews.io',
      pinDefineName: 'PIN_GNEWS_SHA256',
      pinValue: String.fromEnvironment(
        'PIN_GNEWS_SHA256',
        defaultValue: 'QRsUcDdIVK/+3oAE5MRrNA0tkzNlr6kcflx+IkIdPlY=',
      ),
    ),
    PinnedHostPolicy(
      host: 'newsapi.org',
      pinDefineName: 'PIN_NEWSAPI_SHA256',
      pinValue: String.fromEnvironment(
        'PIN_NEWSAPI_SHA256',
        defaultValue: 'P01nq8IxR+Lxo2oRrz7jT6QiWPjRKlSGxSQS0MX4/eo=',
      ),
      certificateAssetPath: 'assets/certs/newsapi.pem',
    ),
    PinnedHostPolicy(
      host: 'api.openweathermap.org',
      pinDefineName: 'PIN_OPENWEATHER_SHA256',
      pinValue: String.fromEnvironment(
        'PIN_OPENWEATHER_SHA256',
        defaultValue: 'w10Xco6eAYtD8tEog3DQsCqKrXB2e7GJb+jP10EbLPQ=',
      ),
      certificateAssetPath: 'assets/certs/openweathermap.pem',
    ),
  ];

  static Iterable<PinnedHostPolicy> get policies => _policies;

  static bool isPinnedHost(String host) => policyForHost(host) != null;

  static PinnedHostPolicy? policyForHost(String host) {
    final normalizedHost = host.trim().toLowerCase();
    for (final policy in _policies) {
      if (normalizedHost == policy.host ||
          normalizedHost.endsWith('.${policy.host}')) {
        return policy;
      }
    }
    return null;
  }

  static void validateConfiguration({bool enforceRelease = false}) {
    if (!(enforceRelease || kReleaseMode)) {
      return;
    }

    for (final policy in _policies) {
      final pins = policy.pins;
      final hasValidPin = pins.isNotEmpty && pins.every(_isConfiguredPin);
      if (!hasValidPin) {
        final error = SecurityException(
          'Missing certificate pin for ${policy.host}. '
              'Build with --dart-define=${policy.pinDefineName}=<sha256 pin>',
          'missing_certificate_pin',
        );
        _recordSecurityError(
          error,
          reason: 'Pinned host misconfiguration: ${policy.host}',
          fatal: true,
        );
        throw error;
      }
    }
  }

  static bool verifyFingerprintForHost(X509Certificate cert, String host) {

    final policy = policyForHost(host);
    if (policy == null) {
      return false;
    }

    final actualBase64 = base64.encode(sha256.convert(cert.der).bytes);
    final actualHex = sha256.convert(cert.der).toString().toLowerCase();
    final isMatch = policy.pins.any(
      (expectedPin) => _matchesPin(
        expectedPin,
        actualBase64: actualBase64,
        actualHex: actualHex,
      ),
    );

    if (!isMatch) {
      final error = SecurityException(
        'Fingerprint mismatch for ${policy.host}',
        'certificate_pin_mismatch',
      );
      _recordSecurityError(error, reason: 'Potential MITM for ${policy.host}');
      // SECURITY: Only log pin mismatches in debug — prevents pin value leakage
      if (kDebugMode) {
        debugPrint(
          '🚨 SSL pin mismatch for ${policy.host}: '
          'received=$actualBase64 subject=${cert.subject}',
        );
      }
    }

    return isMatch;
  }

  static String getCertificateInfo(X509Certificate cert) {
    final digest = sha256.convert(cert.der);
    final base64Pin = base64.encode(digest.bytes);
    return '''
Certificate Information:
  Subject: ${cert.subject}
  Issuer: ${cert.issuer}
  Start Date: ${cert.startValidity}
  End Date: ${cert.endValidity}
  SHA-256 Pin: $base64Pin
''';
  }

  static bool _isConfiguredPin(String pin) {
    final normalized = pin.trim();
    return normalized.isNotEmpty &&
        !normalized.toUpperCase().contains('PLACEHOLDER');
  }

  static bool _matchesPin(
    String expectedPin, {
    required String actualBase64,
    required String actualHex,
  }) {
    final normalized = expectedPin
        .trim()
        .replaceFirst(RegExp(r'^sha256/', caseSensitive: false), '')
        .replaceAll(':', '')
        .toLowerCase();
    return normalized == actualBase64.toLowerCase() || normalized == actualHex;
  }

  static Future<void> _recordSecurityError(
    Object error, {
    required String reason,
    bool fatal = false,
  }) async {
    if (Firebase.apps.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ Crashlytics unavailable for security error: $reason');
      }
      return;
    }

    await FirebaseCrashlytics.instance.recordError(
      error,
      StackTrace.current,
      reason: reason,
      fatal: fatal,
    );
  }
}
