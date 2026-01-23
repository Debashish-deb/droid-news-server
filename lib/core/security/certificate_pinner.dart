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
  // TODO: Replace with your actual server's certificate SHA-256 fingerprint
  // To get fingerprint: openssl s_client -connect yourdomain.com:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
  static const String _expectedFingerprint = 'YOUR_CERT_SHA256_FINGERPRINT_HERE';
  
  /// Verifies the SSL certificate fingerprint
  /// 
  /// Returns true if:
  /// - Certificate matches expected fingerprint (production)
  /// - Debug mode AND ALLOW_INSECURE_CERT env var is set (development only)
  /// 
  /// Logs security violations to Firebase Crashlytics
  static bool verifyFingerprint(X509Certificate cert) {
    try {
      // Calculate certificate fingerprint
      final derBytes = cert.der;
      final digest = sha256.convert(derBytes);
      final fingerprint = base64.encode(digest.bytes);
      
      // Debug mode bypass (ONLY with explicit environment variable)
      if (kDebugMode) {
        const allowInsecure = bool.fromEnvironment(
          'ALLOW_INSECURE_CERT',
          defaultValue: false,
        );
        
        if (allowInsecure) {
          debugPrint('⚠️ SSL PINNING BYPASSED IN DEBUG MODE');
          debugPrint('   Expected: $_expectedFingerprint');
          debugPrint('   Received: $fingerprint');
          return true;
        }
      }
      
      // Verify fingerprint match
      final isValid = fingerprint == _expectedFingerprint;
      
      if (!isValid) {
        // Log security violation
        final error = SecurityException(
          'SSL Certificate Fingerprint Mismatch\n'
          'Expected: $_expectedFingerprint\n'
          'Received: $fingerprint\n'
          'Subject: ${cert.subject}\n'
          'Issuer: ${cert.issuer}',
        );
        
        // Report to Firebase Crashlytics (non-fatal but critical)
        FirebaseCrashlytics.instance.recordError(
          error,
          StackTrace.current,
          reason: 'Potential MITM Attack Detected',
          fatal: false,
        );
        
        debugPrint('🚨 SECURITY ALERT: SSL Certificate Mismatch');
        debugPrint('   This could indicate a Man-in-the-Middle attack!');
      }
      
      return isValid;
      
    } catch (e, stack) {
      // Error during verification - fail closed (reject certificate)
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
  final String message;
  
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}
