class SecurityException implements Exception {

  const SecurityException([
    this.message = 'Security verification failed. Access denied.',
    this.code,
  ]);
  final String message;
  final String? code;

  @override
  String toString() => 'SecurityException: $message ${code != null ? '($code)' : ''}';
}
