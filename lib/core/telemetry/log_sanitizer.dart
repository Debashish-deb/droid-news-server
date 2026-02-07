import 'dart:convert';

/// Redacts sensitive values from log messages and contexts.
class LogSanitizer {
  LogSanitizer._();

  static final RegExp _jwtPattern = RegExp(
    r'eyJ[a-zA-Z0-9_\-]+(?:\.[a-zA-Z0-9_\-]+){1,2}',
  );
  static final RegExp _googleApiKeyPattern = RegExp(r'AIzaSy[0-9A-Za-z_\-]{10,}');
  static final RegExp _supabaseUrlPattern = RegExp(r'https?:\/\/[A-Za-z0-9\-]+\.supabase\.co');
  static final RegExp _keyValuePattern = RegExp(
    r'\b(password|pwd|token|api[_-]?key|secret|key)\b\s*[:=]\s*([^\s]+)',
    caseSensitive: false,
  );

  static String sanitize(String input) {
    var output = input;

    output = output.replaceAllMapped(_keyValuePattern, (match) {
      final key = match.group(1) ?? 'secret';
      return '$key: [REDACTED]';
    });

    output = output.replaceAllMapped(_jwtPattern, (_) => '[REDACTED]');
    output = output.replaceAllMapped(_googleApiKeyPattern, (_) => '[REDACTED]');
    output = output.replaceAllMapped(_supabaseUrlPattern, (_) => '[REDACTED_URL]');

    return output;
  }

  static Map<String, dynamic>? sanitizeContext(Map<String, dynamic>? context) {
    if (context == null) return null;
    final sanitized = <String, dynamic>{};
    context.forEach((key, value) {
      sanitized[key] = _sanitizeValue(value);
    });
    return sanitized;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value is String) {
      return sanitize(value);
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _sanitizeValue(val)));
    }
    if (value is Iterable) {
      return value.map(_sanitizeValue).toList();
    }
    return value;
  }

  static String? sanitizeNullable(String? input) {
    if (input == null) return null;
    return sanitize(input);
  }

  static String sanitizeJson(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is Map<String, dynamic>) {
        return jsonEncode(sanitizeContext(decoded));
      }
      if (decoded is List) {
        return jsonEncode(decoded.map(_sanitizeValue).toList());
      }
    } catch (_) {
      // If it's not JSON, just return the sanitized string.
    }
    return sanitize(input);
  }
}
