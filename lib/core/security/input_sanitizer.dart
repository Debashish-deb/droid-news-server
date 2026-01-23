// lib/core/security/input_sanitizer.dart
// ========================================
// INPUT SANITIZATION UTILITY
// Prevents XSS, injection attacks
// ========================================

/// Utility class for sanitizing user inputs
class InputSanitizer {
  InputSanitizer._();

  /// Sanitize HTML - remove script tags and dangerous attributes
  static String sanitizeHtml(String input) {
    if (input.isEmpty) return input;

    return input
        // Remove script tags
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '')
        // Remove onclick and other event handlers
        .replaceAll(RegExp(r'on\w+\s*=\s*"[^"]*"', caseSensitive: false), '')
        .replaceAll(RegExp(r"on\w+\s*=\s*'[^']*'", caseSensitive: false), '')
        // Remove javascript: URLs
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        // Remove data: URLs
        .replaceAll(RegExp(r'data:', caseSensitive: false), '');
  }

  /// Sanitize for SQL-like injection (paranoid mode)
  static String sanitizeSqlLike(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAll("'", "''")
        .replaceAll('"', '""')
        .replaceAll(';', '')
        .replaceAll('--', '')
        .replaceAll('/*', '')
        .replaceAll('*/', '');
  }

  /// Sanitize URL - validate and clean
  static String? sanitizeUrl(String input) {
    if (input.isEmpty) return null;

    final trimmed = input.trim();
    
    // Only allow http/https URLs
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }

    // Try parsing to validate
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }

    // Block dangerous schemes
    if (uri.scheme == 'javascript' || uri.scheme == 'data') {
      return null;
    }

    return uri.toString();
  }

  /// Sanitize text - remove control characters
  static String sanitizeText(String input) {
    if (input.isEmpty) return input;

    return input
        // Remove control characters except newlines and tabs
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Sanitize email
  static String? sanitizeEmail(String input) {
    if (input.isEmpty) return null;

    final trimmed = input.trim().toLowerCase();
    
    // Basic email validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return null;
    }

    return trimmed;
  }

  /// Check if input contains potential XSS
  static bool containsXss(String input) {
    final xssPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+=', caseSensitive: false),
      RegExp(r'<iframe', caseSensitive: false),
      RegExp(r'<object', caseSensitive: false),
      RegExp(r'<embed', caseSensitive: false),
    ];

    for (final pattern in xssPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  /// Validate and sanitize URL for external linking
  static bool isValidExternalUrl(String url) {
    final sanitized = sanitizeUrl(url);
    if (sanitized == null) return false;

    final uri = Uri.parse(sanitized);
    
    // Block localhost and internal IPs
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || 
        host == '127.0.0.1' || 
        host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.')) {
      return false;
    }

    return true;
  }
}
