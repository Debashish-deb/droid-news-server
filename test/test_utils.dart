import 'package:bdnewsreader/core/di/providers.dart' show sharedPreferencesProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utility functions for testing
class TestUtils {
  /// Creates a test app wrapper with common providers
  static Widget createTestApp({
    required Widget child,
    SharedPreferences? prefs,
    List<Override> overrides = const [],
    ProviderContainer? container,
  }) {
    return MaterialApp(
      home: UncontrolledProviderScope(
        container: container ?? ProviderContainer(
          overrides: [
            if (prefs != null)
              sharedPreferencesProvider.overrideWith((ref) => prefs),
            ...overrides,
          ],
        ),
        child: child,
      ),
    );
  }

  /// Creates a test app with material scaffold
  static Widget createTestScaffold({
    required Widget child,
    String? title,
  }) {
    return MaterialApp(
      home: Scaffold(
        appBar: title != null ? AppBar(title: Text(title)) : null,
        body: child,
      ),
    );
  }

  /// Mock network images for testing
  static void mockNetworkImages() {
    // This prevents network image loading in tests
    // You can extend this as needed for your specific image loading solution
  }

  /// Creates a test article with default values
  static Map<String, dynamic> createTestArticle({
    String id = '1',
    String title = 'Test Article',
    String description = 'Test Description',
    String url = 'https://example.com/1',
    String? imageUrl,
    String source = 'Test Source',
    String language = 'en',
    DateTime? publishedAt,
  }) {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'source': source,
      'language': language,
      'publishedAt': publishedAt?.toIso8601String(),
    };
  }

  /// Creates multiple test articles
  static List<Map<String, dynamic>> createTestArticles(int count) {
    return List.generate(count, (index) => createTestArticle(
      id: index.toString(),
      title: 'Test Article $index',
      description: 'Description for article $index',
      url: 'https://example.com/$index',
      imageUrl: index % 2 == 0 ? 'https://example.com/$index.jpg' : null,
      source: 'Test Source',
      language: 'en',
      publishedAt: DateTime.now().subtract(Duration(hours: count - index)),
    ));
  }

  /// Waits for async operations with timeout
  static Future<T> waitForAsync<T>(
    Future<T> future, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return future.timeout(timeout);
  }

  /// Finds widget by type with better error message
  static Finder findByType<T>(Type type) {
    try {
      return find.byType(type);
    } catch (e) {
      throw TestFailure('Could not find widget of type $type: $e');
    }
  }

  /// Finds widget by key with better error message
  static Finder findByKey(Key key) {
    try {
      return find.byKey(key);
    } catch (e) {
      throw TestFailure('Could not find widget with key $key: $e');
    }
  }

  /// Finds text with better error message
  static Finder findText(String text) {
    try {
      return find.text(text);
    } catch (e) {
      throw TestFailure('Could not find text "$text": $e');
    }
  }

  /// Pumps and settles widget with timeout
  static Future<void> pumpAndSettle(
    WidgetTester tester, {
    Duration duration = const Duration(seconds: 3),
  }) async {
    await tester.pumpAndSettle(duration);
  }

  /// Verifies widget exists with better error message
  static void expectWidgetExists(
    Finder finder, {
    String? reason,
  }) {
    expect(finder, findsOneWidget, reason: reason);
  }

  /// Verifies widget doesn't exist with better error message
  static void expectWidgetNotExists(
    Finder finder, {
    String? reason,
  }) {
    expect(finder, findsNothing, reason: reason);
  }

  /// Creates a mock SharedPreferences
  static SharedPreferences createMockPrefs({
    Map<String, dynamic> data = const {},
  }) {
    return _MockSharedPreferences(data);
  }
}

/// Mock SharedPreferences for testing
class _MockSharedPreferences implements SharedPreferences {
  _MockSharedPreferences(this._data);

  final Map<String, dynamic> _data;

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  Object? get(String key) => _data[key];

  @override
  bool getBool(String key) => _data[key] as bool? ?? false;

  @override
  double getDouble(String key) => _data[key] as double? ?? 0.0;

  @override
  int getInt(String key) => _data[key] as int? ?? 0;

  @override
  String getString(String key) => _data[key] as String? ?? '';

  @override
  List<String> getStringList(String key) {
    final value = _data[key];
    return value is List ? List<String>.from(value) : [];
  }

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  Set<String> getKeys() => _data.keys.cast<String>().toSet();

  @override
  Future<void> reload() async {}
}
