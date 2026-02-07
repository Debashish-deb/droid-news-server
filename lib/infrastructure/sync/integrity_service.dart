// lib/infrastructure/sync/integrity_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/security/security_service.dart';

/// Service to handle data integrity and signing of sync payloads.
class IntegrityService {

  IntegrityService({SecurityService? security})
      : _security = security ?? SecurityService();
  final SecurityService _security;
  static const String _kSecretKeyPrefix = 'integrity_v1_';

  /// Generates a signature for a JSON payload.
  Future<String> signPayload(Map<String, dynamic> payload, String userId) async {
    final String secret = await _getSecret(userId);
    final String dataToSign = jsonEncode(_sortMap(payload));
    
    final List<int> key = utf8.encode(secret);
    final List<int> bytes = utf8.encode(dataToSign);
    final Hmac hmac = Hmac(sha256, key);
    final Digest digest = hmac.convert(bytes);
    
    return digest.toString();
  }

  /// Verifies a payload against a signature.
  Future<bool> verifyPayload(Map<String, dynamic> payload, String signature, String userId) async {
    final String computedSignature = await signPayload(payload, userId);
    return computedSignature == signature;
  }

  /// Recovers or generates a per-user secret key stored in Secure Storage.
  Future<String> _getSecret(String userId) async {
    final String key = '$_kSecretKeyPrefix$userId';
    String? secret = await _security.secureRead(key);
    
    if (secret == null) {
    
      secret = _security.hashString('${DateTime.now().microsecondsSinceEpoch}_$userId');
      await _security.secureWrite(key, secret);
    }
    
    return secret;
  }

  /// Deterministically sort map keys for consistent hashing.
  Map<String, dynamic> _sortMap(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();
    return {
      for (var k in sortedKeys) 
        k: map[k] is Map<String, dynamic> ? _sortMap(map[k]) : map[k]
    };
  }
}
