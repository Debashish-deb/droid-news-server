import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'log_sanitizer.dart';

/// Logger that outputs logs in a structured format using the logger package.
/// Compatible with ELK stack, Datadog, etc.
@lazySingleton
class StructuredLogger {

  StructuredLogger();
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      printTime: true,
    ),
  );

  void log(String message, {Level level = Level.info, Map<String, dynamic>? context}) {
    if (kDebugMode) {
      final safeMessage = LogSanitizer.sanitize(message);
      final safeContext = LogSanitizer.sanitizeContext(context);
      final logMessage = safeContext != null
          ? '$safeMessage | Context: ${jsonEncode(safeContext)}'
          : safeMessage;
      _logger.log(level, logMessage);
    }
  }

  void info(String message, [Map<String, dynamic>? context]) => 
      log(message, context: context);

  void warn(String message, [Map<String, dynamic>? context]) => 
      log(message, level: Level.warning, context: context);

  void warning(String message, [dynamic error, StackTrace? stack]) {
    if (kDebugMode) {
      _logger.w(LogSanitizer.sanitize(message), error: error, stackTrace: stack);
    }
  }

  void error(String message, [dynamic error, StackTrace? stack]) {
    if (kDebugMode) {
      _logger.e(LogSanitizer.sanitize(message), error: error, stackTrace: stack);
    }
  }
}
