import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Production-grade SSL Certificate Pinner
/// 
/// Prevents MITM attacks by verifying server certificate fingerprints.
/// Debug mode bypass requires explicit environment variable.
class CertificatePinner {
  /// The expected SHA-256 fingerprint of the server's certificate.
  /// In production, this should be injected via --dart-define or a vault.
  static const String _expectedFingerprint = String.fromEnvironment(
    'SSL_CERT_FINGERPRINT',
    defaultValue: 'PLACEHOLDER_INJECT_FINGERPRINT_FOR_PRODUCTION',
  );
  
  /// Verifies the SSL certificate fingerprint
  /// 
  /// Returns true if:
  /// - Certificate matches expected fingerprint (production)
  /// - Debug mode AND ALLOW_INSECURE_CERT env var is set (development only)
  /// 
  /// Logs security violations to Firebase Crashlytics
  static bool verifyFingerprint(X509Certificate cert) {
    try {
      final derBytes = cert.der;
      final digest = sha256.convert(derBytes);
      final fingerprint = base64.encode(digest.bytes);
      
      if (kDebugMode) {
        const allowInsecure = bool.fromEnvironment(
          'ALLOW_INSECURE_CERT',
        );
        
        if (allowInsecure) {
          debugPrint('⚠️ SSL PINNING BYPASSED IN DEBUG MODE');
          debugPrint('   Expected: $_expectedFingerprint');
          debugPrint('   Received: $fingerprint');
          return true;
        }
      }
      
      final isValid = fingerprint == _expectedFingerprint;
      
      if (!isValid) {
        final error = SecurityException(
          'SSL Certificate Fingerprint Mismatch\n'
          'Expected: $_expectedFingerprint\n'
          'Received: $fingerprint\n'
          'Subject: ${cert.subject}\n'
          'Issuer: ${cert.issuer}',
        );
        
        FirebaseCrashlytics.instance.recordError(
          error,
          StackTrace.current,
          reason: 'Potential MITM Attack Detected',
        );
        
        debugPrint('🚨 SECURITY ALERT: SSL Certificate Mismatch');
        debugPrint('   This could indicate a Man-in-the-Middle attack!');
      }
      
      return isValid;
      
    } catch (e, stack) {
      debugPrint('❌ SSL Verification Error: $e');
      
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'SSL Certificate Verification Failed',
      );
      
      return false;
    }
  }
  
  /// Get certificate information for debugging
  static String getCertificateInfo(X509Certificate cert) {
    final derBytes = cert.der;
    final digest = sha256.convert(derBytes);
    final fingerprint = base64.encode(digest.bytes);
    
    return '''
Certificate Information:
  Subject: ${cert.subject}
  Issuer: ${cert.issuer}
  Start Date: ${cert.startValidity}
  End Date: ${cert.endValidity}
  SHA-256 Fingerprint: $fingerprint
''';
  }
}

class SecurityException implements Exception {
  
  SecurityException(this.message);
  final String message;
  
  @override
  String toString() => 'SecurityException: $message';
}
