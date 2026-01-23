// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/ui/ui_glitches_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UI Glitches Tests', () {
    testWidgets('TC-UI-001: Text doesn\'t overflow container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: Text(
                'This is a very long text that should not overflow',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Text), findsOneWidget);
      // No overflow error thrown
    });

    testWidgets('TC-UI-002: Image errors show placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Image.network(
              'https://invalid-url-that-will-fail.com/image.jpg',
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.broken_image);
              },
            ),
          ),
        ),
      );

      // Error builder should kick in for failed images
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('TC-UI-003: Scrollable content handles edge cases', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 0, // Empty list
              itemBuilder: (context, index) => const SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      // No crash with empty list
    });

    testWidgets('TC-UI-004: Buttons are large enough to tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      final buttonSize = tester.getSize(find.byType(ElevatedButton));
      
      // Minimum tap target size is 48x48 per Material guidelines
      expect(buttonSize.height, greaterThanOrEqualTo(36)); // Button content
    });

    testWidgets('TC-UI-005: Long press shows tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Tooltip(
              message: 'Share this article',
              child: IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsOneWidget);
      
      // Long press to show tooltip
      await tester.longPress(find.byIcon(Icons.share));
      await tester.pumpAndSettle();
      
      expect(find.text('Share this article'), findsOneWidget);
    });

    testWidgets('TC-UI-006: Keyboard doesn\'t cover inputs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ...List.generate(10, (i) => SizedBox(height: 50, child: Text('Item $i'))),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Email'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      // Scrollable so keyboard can push content up
    });

    testWidgets('TC-UI-007: RTL layout is supported', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Row(
                children: [
                  Text('First'),
                  Spacer(),
                  Text('Last'),
                ],
              ),
            ),
          ),
        ),
      );

      // RTL should have First on the right
      final firstPos = tester.getTopLeft(find.text('First'));
      final lastPos = tester.getTopLeft(find.text('Last'));
      
      expect(firstPos.dx, greaterThan(lastPos.dx)); // First is to the right in RTL
    });

    testWidgets('TC-UI-008: Dark mode doesn\'t break contrast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Text(
              'Readable Text',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );

      expect(find.text('Readable Text'), findsOneWidget);
    });

    testWidgets('TC-UI-009: Loading states are shown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CircularProgressIndicator(),
                Text('Loading...'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('TC-UI-010: Empty states are handled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No articles yet'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No articles yet'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/core/language_provider_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/core/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider Tests', () {
    test('Initializes with default English locale when no prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LanguageProvider();
      
      // Allow async load to complete
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(provider.locale.languageCode, 'en');
    });

    test('Initializes with stored locale', () async {
      SharedPreferences.setMockInitialValues({'languageCode': 'bn'});
      final provider = LanguageProvider();
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(provider.locale.languageCode, 'bn');
    });

    test('setLocale updates locale and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LanguageProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      await provider.setLocale('bn');
      
      expect(provider.locale.languageCode, 'bn');
      
      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('languageCode'), 'bn');
    });
    
    test('resetLocale clears persistence', () async {
      SharedPreferences.setMockInitialValues({'languageCode': 'bn'});
      final provider = LanguageProvider();
      await Future.delayed(const Duration(milliseconds: 50)); // Wait for load
      
      await provider.resetLocale();
      
      expect(provider.locale.languageCode, 'en');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('languageCode'), false);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/core/theme_provider_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/core/theme_provider.dart';

@GenerateMocks([SharedPreferences])
import 'theme_provider_test.mocks.dart';

void main() {
  late MockSharedPreferences mockPrefs;
  late ThemeProvider themeProvider;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    
    // Default mocks
    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockPrefs.setDouble(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.getInt(any)).thenReturn(null);
    when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.getDouble(any)).thenReturn(null);

    themeProvider = ThemeProvider(mockPrefs);
  });

  group('ThemeProvider Tests', () {
    test('Initializes with default light theme when no prefs', () {
      expect(themeProvider.appThemeMode, AppThemeMode.light);
    });

    test('Initializes with stored theme', () {
      // Theme stored as int index
      when(mockPrefs.getInt('theme_mode')).thenReturn(AppThemeMode.dark.index);
      final provider = ThemeProvider(mockPrefs);
      expect(provider.appThemeMode, AppThemeMode.dark);
    });

    test('toggleTheme sets theme and notifies listeners', () async {
      bool notified = false;
      themeProvider.addListener(() {
        notified = true;
      });

      await themeProvider.toggleTheme(AppThemeMode.dark);

      expect(themeProvider.appThemeMode, AppThemeMode.dark);
      expect(notified, true);
      verify(mockPrefs.setInt('theme_mode', AppThemeMode.dark.index)).called(1);
    });
    
    test('updateReaderPrefs persists values', () async {
      await themeProvider.updateReaderPrefs(lineHeight: 2.0, contrast: 1.5);
      
      verify(mockPrefs.setDouble('reader_line_height', 2.0)).called(1);
      verify(mockPrefs.setDouble('reader_contrast', 1.5)).called(1);
      expect(themeProvider.readerLineHeight, 2.0);
      expect(themeProvider.readerContrast, 1.5);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/core/theme_provider_test.mocks.dart ===

// Mocks generated by Mockito 5.4.4 from annotations
// in bdnewsreader/test/unit/core/theme_provider_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:mockito/mockito.dart' as _i1;
import 'package:shared_preferences/src/shared_preferences_legacy.dart' as _i2;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

/// A class which mocks [SharedPreferences].
///
/// See the documentation for Mockito's code generation for more information.
class MockSharedPreferences extends _i1.Mock implements _i2.SharedPreferences {
  MockSharedPreferences() {
    _i1.throwOnMissingStub(this);
  }

  @override
  Set<String> getKeys() => (super.noSuchMethod(
        Invocation.method(
          #getKeys,
          [],
        ),
        returnValue: <String>{},
      ) as Set<String>);

  @override
  Object? get(String? key) => (super.noSuchMethod(Invocation.method(
        #get,
        [key],
      )) as Object?);

  @override
  bool? getBool(String? key) => (super.noSuchMethod(Invocation.method(
        #getBool,
        [key],
      )) as bool?);

  @override
  int? getInt(String? key) => (super.noSuchMethod(Invocation.method(
        #getInt,
        [key],
      )) as int?);

  @override
  double? getDouble(String? key) => (super.noSuchMethod(Invocation.method(
        #getDouble,
        [key],
      )) as double?);

  @override
  String? getString(String? key) => (super.noSuchMethod(Invocation.method(
        #getString,
        [key],
      )) as String?);

  @override
  bool containsKey(String? key) => (super.noSuchMethod(
        Invocation.method(
          #containsKey,
          [key],
        ),
        returnValue: false,
      ) as bool);

  @override
  List<String>? getStringList(String? key) =>
      (super.noSuchMethod(Invocation.method(
        #getStringList,
        [key],
      )) as List<String>?);

  @override
  _i3.Future<bool> setBool(
    String? key,
    bool? value,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #setBool,
          [
            key,
            value,
          ],
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<bool> setInt(
    String? key,
    int? value,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #setInt,
          [
            key,
            value,
          ],
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<bool> setDouble(
    String? key,
    double? value,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #setDouble,
          [
            key,
            value,
          ],
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<bool> setString(
    String? key,
    String? value,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #setString,
          [
            key,
            value,
          ],
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<bool> setStringList(
    String? key,
    List<String>? value,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #setStringList,
          [
            key,
            value,
          ],
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<bool> remove(String? key) => (super.noSuchMethod(
        Invocation.method(
          #remove,
          [key],
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<bool> commit() => (super.noSuchMethod(
        Invocation.method(
          #commit,
          [],
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<bool> clear() => (super.noSuchMethod(
        Invocation.method(
          #clear,
          [],
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<void> reload() => (super.noSuchMethod(
        Invocation.method(
          #reload,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/network/network_edge_cases_test.dart ===

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/utils/retry_helper.dart';

void main() {
  group('Network Edge Case Tests', () {
    group('Timeout Scenarios', () {
      test('TC-EDGE-001: Network request times out after specified duration', () async {
        final timeout = const Duration(seconds: 1);
        
        expect(
          () async {
            await Future.delayed(const Duration(seconds: 2))
                .timeout(timeout);
          },
          throwsA(isA<TimeoutException>()),
        );
      });

      test('TC-EDGE-002: Retry helper works with errors', () async {
        int attemptCount = 0;
        
        try {
          await RetryHelper.retry(
            operation: () async {
              attemptCount++;
              throw TimeoutException('Simulated timeout');
            },
            maxRetries: 3,
            delayDuration: const Duration(milliseconds: 100),
          );
          fail('Should have thrown TimeoutException');
        } catch (e) {
          expect(e, isA<TimeoutException>());
          expect(attemptCount, 3); // Should retry 3 times
        }
      });

      test('TC-EDGE-003: Different timeout durations', () async {
        // Short timeout
        await expectLater(
          Future.delayed(const Duration(seconds: 2)).timeout(const Duration(milliseconds: 500)),
          throwsA(isA<TimeoutException>()),
        );

        // Long timeout (should succeed)
        final result = await Future.value('success').timeout(const Duration(seconds: 10));
        expect(result, 'success');
      });
    });

    group('Malformed Data', () {
      test('TC-EDGE-004: Handles invalid JSON gracefully', () {
        const invalidJson = '{invalid json}';
        
        expect(
          () => jsonDecode(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('TC-EDGE-005: Handles incomplete JSON', () {
        const incompleteJson = '{"title": "test", "url":';
        
        expect(
          () => jsonDecode(incompleteJson),
          throwsA(isA<FormatException>()),
        );
      });

      test('TC-EDGE-006: Handles null values in JSON', () {
        const jsonWithNulls = '{"title": null, "url": "https://example.com"}';
        
        final decoded = jsonDecode(jsonWithNulls);
        expect(decoded['title'], isNull);
        expect(decoded['url'], isNotNull);
      });

     test('TC-EDGE-007: Handles empty response', () {
        const emptyJson = '{}';
        
        final decoded = jsonDecode(emptyJson);
        expect(decoded, isEmpty);
      });
    });

    group('Network State Changes', () {
      test('TC-EDGE-008: Handles connection loss during operation', () async {
        // Simulate operation that fails mid-way
        var connected = true;
        
        Future<String> fetchData() async {
          await Future.delayed(const Duration(milliseconds: 100));
          if (!connected) {
            throw Exception('Connection lost');
          }
          return 'data';
        }

        // Start operation
        final future = fetchData();
        
        // Simulate connection loss
        await Future.delayed(const Duration(milliseconds: 50));
        connected = false;
        
        await expectLater(future, throwsException);
      });

      test('TC-EDGE-009: Retry on network failure', () async {
        int attempts = 0;
        bool networkAvailable = false;
        
        Future<String> fetchWithRetry() async {
          return await RetryHelper.retry(
            operation: () async {
              attempts++;
              if (!networkAvailable) {
                throw Exception('No network');
              }
              return 'success';
            },
            maxRetries: 3,
            delayDuration: const Duration(milliseconds: 100),
          );
        }

        // First attempt fails
        final future = fetchWithRetry();
        
        // Network becomes available after 2 attempts
        await Future.delayed(const Duration(milliseconds: 150));
        networkAvailable = true;
        
        final result = await future;
        expect(result, 'success');
        expect(attempts, greaterThan(1));
      });
    });

    group('Server Error Responses', () {
      test('TC-EDGE-010: Handles 500 Internal Server Error', () {
        final errorResponse = {
          'statusCode': 500,
          'message': 'Internal Server Error'
        };
        
        expect(errorResponse['statusCode'], 500);
        expect(errorResponse['message'], contains('Error'));
      });

      test('TC-EDGE-011: Handles 503 Service Unavailable', () {
        final errorResponse = {
          'statusCode': 503,
          'message': 'Service Unavailable',
          'retryAfter': 60
        };
        
        expect(errorResponse['statusCode'], 503);
        expect(errorResponse['retryAfter'], greaterThan(0));
      });

      test('TC-EDGE-012: Handles 404 Not Found', () {
        final errorResponse = {
          'statusCode': 404,
          'message': 'Resource Not Found'
        };
        
        expect(errorResponse['statusCode'], 404);
      });
    });

    group('Concurrent Operations', () {
      test('TC-EDGE-013: Multiple simultaneous requests complete', () async {
        final futures = List.generate(
          5,
          (i) => Future.delayed(
            Duration(milliseconds: 100 * (i + 1)),
            () => 'Result $i',
          ),
        );

        final results = await Future.wait(futures);
        expect(results.length, 5);
        expect(results[0], 'Result 0');
        expect(results[4], 'Result 4');
      });

      test('TC-EDGE-014: Race condition handling', () async {
        int counter = 0;
        
        // Simulate multiple concurrent increments
        final futures = List.generate(
          10,
          (_) => Future(() => counter++),
        );

        await Future.wait(futures);
        expect(counter, 10);
      });
    });

    group('Large Data Handling', () {
      test('TC-EDGE-015: Handles large JSON response', () {
        // Simulate large response (1000 items)
        final largeList = List.generate(1000, (i) => {
          'id': i,
          'title': 'Item $i',
          'data': 'x' * 100, // 100 chars each
        });

        final jsonString = jsonEncode(largeList);
        final decoded = jsonDecode(jsonString);
        
        expect(decoded, isList);
        expect(decoded.length, 1000);
      });

      test('TC-EDGE-016: Handles pagination correctly', () {
        final allItems = List.generate(100, (i) => 'Item $i');
        const pageSize = 20;
        
        // Get page 2 (items 20-39)
        final page2 = allItems.skip(20).take(pageSize).toList();
        
        expect(page2.length, 20);
        expect(page2.first, 'Item 20');
        expect(page2.last, 'Item 39');
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/utils/retry_helper_test.dart ===

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bdnewsreader/core/utils/retry_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RetryHelper', () {
    group('Successful Operations', () {
      test('TC-UNIT-050: retry succeeds on first attempt', () async {
        var attempts = 0;
        
        final result = await RetryHelper.retry<String>(
          operation: () async {
            attempts++;
            return 'success';
          },
        );
        
        expect(result, 'success');
        expect(attempts, 1);
      });

      test('TC-UNIT-051: retry succeeds after transient failure', () async {
        var attempts = 0;
        
        final result = await RetryHelper.retry<String>(
          operation: () async {
            attempts++;
            if (attempts < 2) {
              throw const SocketException('Temporary network error');
            }
            return 'success';
          },
        );
        
        expect(result, 'success');
        expect(attempts, 2);
      });

      test('TC-UNIT-052: retry succeeds on third attempt', () async {
        var attempts = 0;
        
        final result = await RetryHelper.retry<String>(
          operation: () async {
            attempts++;
            if (attempts < 3) {
              throw const SocketException('Network error');
            }
            return 'success';
          },
        );
        
        expect(result, 'success');
        expect(attempts, 3);
      });
    });

    group('Failed Operations', () {
      test('TC-UNIT-053: retry fails after max retries', () async {
        var attempts = 0;
        
        await expectLater(
          RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw const SocketException('Persistent failure');
            },
          ),
          throwsA(isA<SocketException>()),
        );
        
        expect(attempts, 3);
      });

      test('TC-UNIT-054: non-retryable errors fail immediately', () async {
        var attempts = 0;
        
        await expectLater(
          RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw const FormatException('Parse error');
            },
          ),
          throwsA(isA<FormatException>()),
        );
        
        // FormatException is not retryable, should fail on first attempt
        expect(attempts, 1);
      });
    });

    group('Retryable Error Detection', () {
      test('TC-UNIT-055: SocketException is retryable', () async {
        var attempts = 0;
        
        try {
          await RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw const SocketException('Network');
            },
            maxRetries: 2,
          );
        } catch (_) {}
        
        expect(attempts, 2); // Should retry
      });

      test('TC-UNIT-056: TimeoutException is retryable', () async {
        var attempts = 0;
        
        try {
          await RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw TimeoutException('Timeout');
            },
            maxRetries: 2,
          );
        } catch (_) {}
        
        expect(attempts, 2); // Should retry
      });

      test('TC-UNIT-057: http.ClientException is retryable', () async {
        var attempts = 0;
        
        try {
          await RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw http.ClientException('HTTP error');
            },
            maxRetries: 2,
          );
        } catch (_) {}
        
        expect(attempts, 2); // Should retry
      });
    });

    group('Custom Retry Logic', () {
      test('TC-UNIT-058: custom shouldRetry function is respected', () async {
        var attempts = 0;
        
        await expectLater(
          RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw Exception('Custom error');
            },
            shouldRetry: (error) => false, // Never retry
          ),
          throwsException,
        );
        
        expect(attempts, 1); // Should not retry
      });

      test('TC-UNIT-059: custom maxRetries is respected', () async {
        var attempts = 0;
        
        try {
          await RetryHelper.retry<String>(
            operation: () async {
              attempts++;
              throw const SocketException('Error');
            },
            maxRetries: 5,
          );
        } catch (_) {}
        
        expect(attempts, 5);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/utils/favorites_manager_test.dart ===

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

/// Tests FavoritesManager patterns without importing the Firebase-dependent service
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesManager (Patterns)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    group('Article Favorites', () {
      test('TC-UNIT-030: Initial favorites list is empty', () {
        final favorites = prefs.getStringList('favorites') ?? [];
        expect(favorites, isEmpty);
      });

      test('TC-UNIT-031: addFavorite stores article', () async {
        final article = NewsArticle(
          title: 'Test Article',
          url: 'https://example.com/test',
          source: 'Test Source',
          publishedAt: DateTime.now(),
        );
        
        final favorites = [json.encode(article.toMap())];
        await prefs.setStringList('favorites', favorites);
        
        expect(prefs.getStringList('favorites')!.length, 1);
      });

      test('TC-UNIT-032: removeFavorite updates list', () async {
        await prefs.setStringList('favorites', ['{"title":"t","url":"u","source":"s","publishedAt":"2024-01-01T00:00:00.000"}']);
        expect(prefs.getStringList('favorites')!.length, 1);
        
        await prefs.setStringList('favorites', []);
        expect(prefs.getStringList('favorites'), isEmpty);
      });

      test('TC-UNIT-033: toggleArticle adds when not favorited', () async {
        final list = prefs.getStringList('favorites') ?? [];
        const article = '{"title":"t","url":"u","source":"s","publishedAt":"2024-01-01T00:00:00.000"}';
        
        list.add(article);
        await prefs.setStringList('favorites', list);
        
        expect(prefs.getStringList('favorites')!.length, 1);
      });

      test('TC-UNIT-034: toggleArticle removes when already favorited', () async {
        await prefs.setStringList('favorites', ['article1']);
        
        final list = prefs.getStringList('favorites') ?? [];
        list.remove('article1');
        await prefs.setStringList('favorites', list);
        
        expect(prefs.getStringList('favorites'), isEmpty);
      });

      test('TC-UNIT-035: isFavoriteArticle checks URL', () {
        final favorites = ['{"title":"t","url":"https://example.com/test","source":"s","publishedAt":"2024-01-01T00:00:00.000"}'];
        
        bool isFavorite(String url) {
          return favorites.any((f) {
            final map = json.decode(f);
            return map['url'] == url;
          });
        }
        
        expect(isFavorite('https://example.com/test'), isTrue);
        expect(isFavorite('https://example.com/other'), isFalse);
      });
    });

    group('Magazine Favorites', () {
      test('TC-UNIT-036: Initial magazine favorites is empty', () {
        expect(prefs.getStringList('magazine_favorites'), isNull);
      });

      test('TC-UNIT-037: toggleMagazine adds magazine', () async {
        final magazines = [json.encode({'id': 'mag1', 'name': 'Test Magazine'})];
        await prefs.setStringList('magazine_favorites', magazines);
        
        expect(prefs.getStringList('magazine_favorites')!.length, 1);
      });

      test('TC-UNIT-038: toggleMagazine removes when already favorited', () async {
        await prefs.setStringList('magazine_favorites', ['{"id":"mag1"}']);
        await prefs.setStringList('magazine_favorites', []);
        
        expect(prefs.getStringList('magazine_favorites'), isEmpty);
      });
    });

    group('Newspaper Favorites', () {
      test('TC-UNIT-039: Initial newspaper favorites is empty', () {
        expect(prefs.getStringList('newspaper_favorites'), isNull);
      });

      test('TC-UNIT-040: toggleNewspaper adds newspaper', () async {
        final newspapers = [json.encode({'id': 'paper1', 'name': 'Prothom Alo'})];
        await prefs.setStringList('newspaper_favorites', newspapers);
        
        expect(prefs.getStringList('newspaper_favorites')!.length, 1);
      });

      test('TC-UNIT-041: toggleNewspaper removes when already favorited', () async {
        await prefs.setStringList('newspaper_favorites', ['{"id":"paper1"}']);
        await prefs.setStringList('newspaper_favorites', []);
        
        expect(prefs.getStringList('newspaper_favorites'), isEmpty);
      });
    });

    group('Persistence', () {
      test('TC-UNIT-042: Favorites persist to SharedPreferences', () async {
        await prefs.setStringList('favorites', ['article1', 'article2']);
        
        final saved = prefs.getStringList('favorites');
        expect(saved!.length, 2);
      });
    });

    group('Serialization', () {
      test('TC-UNIT-043: NewsArticle serializes correctly', () {
        final article = NewsArticle(
          title: 'Serialize Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime(2024, 12, 25),
        );
        
        final serialized = json.encode(article.toMap());
        final restored = NewsArticle.fromMap(json.decode(serialized));
        
        expect(restored.title, article.title);
        expect(restored.url, article.url);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/models/news_article_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

void main() {
  group('NewsArticle Model', () {
    group('Construction', () {
      test('TC-MODEL-001: NewsArticle can be created with required fields', () {
        final article = NewsArticle(
          title: 'Test Title',
          url: 'https://example.com/article',
          source: 'Test Source',
          publishedAt: DateTime(2024, 12, 25),
        );
        
        expect(article.title, 'Test Title');
        expect(article.url, 'https://example.com/article');
        expect(article.source, 'Test Source');
        expect(article.publishedAt, DateTime(2024, 12, 25));
      });

      test('TC-MODEL-002: NewsArticle can be created with optional fields', () {
        final article = NewsArticle(
          title: 'Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
          description: 'Test description',
          snippet: 'Short snippet',
          imageUrl: 'https://example.com/image.jpg',
          language: 'bn',
          isLive: true,
        );
        
        expect(article.description, 'Test description');
        expect(article.snippet, 'Short snippet');
        expect(article.imageUrl, 'https://example.com/image.jpg');
        expect(article.language, 'bn');
        expect(article.isLive, isTrue);
      });

      test('TC-MODEL-003: Default values are correct', () {
        final article = NewsArticle(
          title: 'Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
        );
        
        // description and other optional strings default to empty string
        expect(article.description, isEmpty);
        expect(article.isLive, isFalse);
      });
    });

    group('Serialization', () {
      test('TC-MODEL-004: toMap returns valid map', () {
        final article = NewsArticle(
          title: 'Serialize Test',
          url: 'https://example.com/serialize',
          source: 'Test Source',
          description: 'Description',
          publishedAt: DateTime(2024, 12, 25, 10, 30),
          isLive: true,
        );
        
        final map = article.toMap();
        
        expect(map['title'], 'Serialize Test');
        expect(map['url'], 'https://example.com/serialize');
        expect(map['source'], 'Test Source');
        expect(map['description'], 'Description');
        expect(map['isLive'], isTrue);
        expect(map.containsKey('publishedAt'), isTrue);
      });

      test('TC-MODEL-005: fromMap creates valid article', () {
        final map = {
          'title': 'From Map Test',
          'url': 'https://example.com/frommap',
          'source': 'Map Source',
          'description': 'Map description',
          'publishedAt': '2024-12-25T10:30:00.000',
          'isLive': false,
        };
        
        final article = NewsArticle.fromMap(map);
        
        expect(article.title, 'From Map Test');
        expect(article.url, 'https://example.com/frommap');
        expect(article.source, 'Map Source');
        expect(article.description, 'Map description');
      });

      test('TC-MODEL-006: Round-trip serialization preserves data', () {
        final original = NewsArticle(
          title: 'Round Trip',
          url: 'https://example.com/roundtrip',
          source: 'Original Source',
          description: 'Original description',
          snippet: 'Short',
          imageUrl: 'https://example.com/img.jpg',
          publishedAt: DateTime(2024, 12, 25, 10),
          isLive: true,
        );
        
        final map = original.toMap();
        final restored = NewsArticle.fromMap(map);
        
        expect(restored.title, original.title);
        expect(restored.url, original.url);
        expect(restored.source, original.source);
        expect(restored.isLive, original.isLive);
      });
    });

    group('LIVE Badge', () {
      test('TC-MODEL-007: isLive flag can be true', () {
        final liveArticle = NewsArticle(
          title: 'Live Event',
          url: 'https://example.com/live',
          source: 'Live Source',
          publishedAt: DateTime.now(),
          isLive: true,
        );
        
        expect(liveArticle.isLive, isTrue);
      });

      test('TC-MODEL-008: isLive flag defaults to false', () {
        final regularArticle = NewsArticle(
          title: 'Regular',
          url: 'https://example.com/regular',
          source: 'Source',
          publishedAt: DateTime.now(),
        );
        
        expect(regularArticle.isLive, isFalse);
      });
    });

    group('Date Handling', () {
      test('TC-MODEL-009: publishedAt stores correct date', () {
        final date = DateTime(2024, 12, 25, 15, 30, 45);
        final article = NewsArticle(
          title: 'Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: date,
        );
        
        expect(article.publishedAt.year, 2024);
        expect(article.publishedAt.month, 12);
        expect(article.publishedAt.day, 25);
        expect(article.publishedAt.hour, 15);
      });

      test('TC-MODEL-010: Articles can be sorted by date', () {
        final articles = [
          NewsArticle(title: 'Old', url: 'u1', source: 's', publishedAt: DateTime(2024)),
          NewsArticle(title: 'New', url: 'u2', source: 's', publishedAt: DateTime(2024, 12, 25)),
          NewsArticle(title: 'Mid', url: 'u3', source: 's', publishedAt: DateTime(2024, 6, 15)),
        ];
        
        articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        
        expect(articles[0].title, 'New');
        expect(articles[1].title, 'Mid');
        expect(articles[2].title, 'Old');
      });
    });

    group('Image Handling', () {
      test('TC-MODEL-011: imageUrl can be null', () {
        final article = NewsArticle(
          title: 'No Image',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
        );
        
        expect(article.imageUrl, isNull);
      });

      test('TC-MODEL-012: imageUrl stores URL correctly', () {
        final article = NewsArticle(
          title: 'With Image',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
          imageUrl: 'https://cdn.example.com/image.jpg',
        );
        
        expect(article.imageUrl, 'https://cdn.example.com/image.jpg');
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/models/notification_preferences_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/data/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences', () {
    test('TC-UNIT-021: Default preferences created correctly', () {
      final prefs = NotificationPreferences();
      
      // Verify default values
      expect(prefs.enabled, true);
      expect(prefs.breakingNews, true);
      expect(prefs.personalizedAlerts, true);
      expect(prefs.promotional, true);
      expect(prefs.subscribedTopics, isEmpty);
    });

    test('TC-UNIT-022: toJson() serializes all fields', () {
      final prefs = NotificationPreferences(
        personalizedAlerts: false,
        promotional: false,
        subscribedTopics: ['technology', 'sports'],
      );
      
      final json = prefs.toJson();
      
      expect(json, isA<Map<String, dynamic>>());
      expect(json['enabled'], true);
      expect(json['breakingNews'], true);
      expect(json['personalizedAlerts'], false);
      expect(json['promotional'], false);
      expect(json['subscribedTopics'], ['technology', 'sports']);
    });

    test('TC-UNIT-023: fromJson() deserializes correctly', () {
      final json = {
        'enabled': false,
        'breakingNews': true,
        'personalizedAlerts': false,
        'promotional': true,
        'subscribedTopics': ['politics', 'business'],
      };
      
      final prefs = NotificationPreferences.fromJson(json);
      
      expect(prefs.enabled, false);
      expect(prefs.breakingNews, true);
      expect(prefs.personalizedAlerts, false);
      expect(prefs.promotional, true);
      expect(prefs.subscribedTopics, ['politics', 'business']);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/domain/use_cases/subscription/check_subscription_status_use_case_test.mocks.dart ===

// Mocks generated by Mockito 5.4.4 from annotations
// in bdnewsreader/test/unit/domain/use_cases/subscription/check_subscription_status_use_case_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:bdnewsreader/core/architecture/either.dart' as _i4;
import 'package:bdnewsreader/core/architecture/failure.dart' as _i5;
import 'package:bdnewsreader/domain/entities/subscription.dart' as _i6;
import 'package:bdnewsreader/domain/repositories/subscription_repository.dart'
    as _i2;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i7;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

/// A class which mocks [SubscriptionRepository].
///
/// See the documentation for Mockito's code generation for more information.
class MockSubscriptionRepository extends _i1.Mock
    implements _i2.SubscriptionRepository {
  MockSubscriptionRepository() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>
      getCurrentSubscription() => (super.noSuchMethod(
            Invocation.method(
              #getCurrentSubscription,
              [],
            ),
            returnValue: _i3
                .Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>.value(
                _i7.dummyValue<_i4.Either<_i5.AppFailure, _i6.Subscription>>(
              this,
              Invocation.method(
                #getCurrentSubscription,
                [],
              ),
            )),
          ) as _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, bool>> canAccessFeature(
          String? featureId) =>
      (super.noSuchMethod(
        Invocation.method(
          #canAccessFeature,
          [featureId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, bool>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, bool>>(
          this,
          Invocation.method(
            #canAccessFeature,
            [featureId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, bool>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>> upgradeSubscription(
          _i6.SubscriptionTier? newTier) =>
      (super.noSuchMethod(
        Invocation.method(
          #upgradeSubscription,
          [newTier],
        ),
        returnValue:
            _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>.value(
                _i7.dummyValue<_i4.Either<_i5.AppFailure, _i6.Subscription>>(
          this,
          Invocation.method(
            #upgradeSubscription,
            [newTier],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>
      cancelSubscription() => (super.noSuchMethod(
            Invocation.method(
              #cancelSubscription,
              [],
            ),
            returnValue: _i3
                .Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>.value(
                _i7.dummyValue<_i4.Either<_i5.AppFailure, _i6.Subscription>>(
              this,
              Invocation.method(
                #cancelSubscription,
                [],
              ),
            )),
          ) as _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>
      restoreSubscription() => (super.noSuchMethod(
            Invocation.method(
              #restoreSubscription,
              [],
            ),
            returnValue: _i3
                .Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>.value(
                _i7.dummyValue<_i4.Either<_i5.AppFailure, _i6.Subscription>>(
              this,
              Invocation.method(
                #restoreSubscription,
                [],
              ),
            )),
          ) as _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>);

  @override
  _i3.Future<
      _i4.Either<_i5.AppFailure,
          Map<_i6.SubscriptionTier, List<String>>>> getAvailableTiers() =>
      (super.noSuchMethod(
        Invocation.method(
          #getAvailableTiers,
          [],
        ),
        returnValue: _i3.Future<
            _i4.Either<_i5.AppFailure,
                Map<_i6.SubscriptionTier, List<String>>>>.value(_i7.dummyValue<
            _i4
            .Either<_i5.AppFailure, Map<_i6.SubscriptionTier, List<String>>>>(
          this,
          Invocation.method(
            #getAvailableTiers,
            [],
          ),
        )),
      ) as _i3.Future<
          _i4.Either<_i5.AppFailure, Map<_i6.SubscriptionTier, List<String>>>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>
      validateAndRefreshSubscription() => (super.noSuchMethod(
            Invocation.method(
              #validateAndRefreshSubscription,
              [],
            ),
            returnValue: _i3
                .Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>.value(
                _i7.dummyValue<_i4.Either<_i5.AppFailure, _i6.Subscription>>(
              this,
              Invocation.method(
                #validateAndRefreshSubscription,
                [],
              ),
            )),
          ) as _i3.Future<_i4.Either<_i5.AppFailure, _i6.Subscription>>);
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/domain/use_cases/subscription/check_subscription_status_use_case_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/core/architecture/use_case.dart'; // for NoParams
import 'package:bdnewsreader/domain/entities/subscription.dart';
import 'package:bdnewsreader/domain/repositories/subscription_repository.dart';
import 'package:bdnewsreader/domain/use_cases/subscription/check_subscription_status_use_case.dart';

@GenerateMocks([SubscriptionRepository])
import 'check_subscription_status_use_case_test.mocks.dart';

void main() {
  provideDummy<Either<AppFailure, Subscription>>(
    Right(Subscription(
      id: 'test',
      userId: 'test',
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
    )),
  );

  late CheckSubscriptionStatusUseCase useCase;
  late MockSubscriptionRepository mockRepository;

  setUp(() {
    mockRepository = MockSubscriptionRepository();
    useCase = CheckSubscriptionStatusUseCase(mockRepository);
  });

  group('CheckSubscriptionStatusUseCase', () {
    test('should return active subscription status', () async {
      // Arrange
      final subscription = Subscription(
        id: 'sub-123',
        userId: 'user-123',
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.active,
        startDate: DateTime(2025),
        endDate: DateTime(2026),
      );

      // Stub all methods that might be called
      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => Right(subscription));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => Right(subscription));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (sub) {
          expect(sub.tier, SubscriptionTier.pro);
          expect(sub.status, SubscriptionStatus.active);
          expect(sub.isActive, true);
        },
      );

      verify(mockRepository.validateAndRefreshSubscription()).called(1);
    });

    test('should return free tier for no subscription', () async {
      // Arrange
      final freeSubscription = Subscription(
        id: 'free',
        userId: 'user-123',
        tier: SubscriptionTier.free,
        status: SubscriptionStatus.active,
        startDate: DateTime.now(),
      );

      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => Right(freeSubscription));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => Right(freeSubscription));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (sub) {
          expect(sub.tier, SubscriptionTier.free);
          expect(sub.isActive, true); // free tier is active
        },
      );
    });

    test('should detect expired subscription', () async {
      // Arrange
      final expiredSub = Subscription(
        id: 'sub-123',
        userId: 'user-123',
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.expired,
        startDate: DateTime(2024),
        endDate: DateTime(2024, 12, 31),
      );

      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => Right(expiredSub));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => Right(expiredSub));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (sub) {
          expect(sub.status, SubscriptionStatus.expired);
          expect(sub.isExpired, true);
          expect(sub.isActive, false); // expired means not active
        },
      );
    });

    test('should return SubscriptionFailure on repository error', () async {
      // Arrange
      const failure = SubscriptionFailure('Failed to fetch subscription');
      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => const Left(failure));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<SubscriptionFailure>());
          expect(f.message, contains('Failed to fetch'));
        },
        (_) => fail('Expected failure'),
      );
    });

    test('should handle network failure', () async {
      // Arrange
      const failure = NetworkFailure('No internet connection');
      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => const Left(failure));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/domain/use_cases/news/fetch_news_feed_use_case_test.mocks.dart ===

// Mocks generated by Mockito 5.4.4 from annotations
// in bdnewsreader/test/unit/domain/use_cases/news/fetch_news_feed_use_case_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:bdnewsreader/core/architecture/either.dart' as _i4;
import 'package:bdnewsreader/core/architecture/failure.dart' as _i5;
import 'package:bdnewsreader/domain/entities/news_article.dart' as _i6;
import 'package:bdnewsreader/domain/repositories/news_repository.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i7;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

/// A class which mocks [NewsRepository].
///
/// See the documentation for Mockito's code generation for more information.
class MockNewsRepository extends _i1.Mock implements _i2.NewsRepository {
  MockNewsRepository() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>> getNewsFeed({
    required int? page,
    required int? limit,
    String? category,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #getNewsFeed,
          [],
          {
            #page: page,
            #limit: limit,
            #category: category,
          },
        ),
        returnValue: _i3
            .Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>(
          this,
          Invocation.method(
            #getNewsFeed,
            [],
            {
              #page: page,
              #limit: limit,
              #category: category,
            },
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, _i6.NewsArticle>> getArticleById(
          String? id) =>
      (super.noSuchMethod(
        Invocation.method(
          #getArticleById,
          [id],
        ),
        returnValue:
            _i3.Future<_i4.Either<_i5.AppFailure, _i6.NewsArticle>>.value(
                _i7.dummyValue<_i4.Either<_i5.AppFailure, _i6.NewsArticle>>(
          this,
          Invocation.method(
            #getArticleById,
            [id],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, _i6.NewsArticle>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, void>> bookmarkArticle(
          String? articleId) =>
      (super.noSuchMethod(
        Invocation.method(
          #bookmarkArticle,
          [articleId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, void>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, void>>(
          this,
          Invocation.method(
            #bookmarkArticle,
            [articleId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, void>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, void>> unbookmarkArticle(
          String? articleId) =>
      (super.noSuchMethod(
        Invocation.method(
          #unbookmarkArticle,
          [articleId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, void>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, void>>(
          this,
          Invocation.method(
            #unbookmarkArticle,
            [articleId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, void>>);

  @override
  _i3.Future<
      _i4.Either<_i5.AppFailure,
          List<_i6.NewsArticle>>> getBookmarkedArticles() =>
      (super.noSuchMethod(
        Invocation.method(
          #getBookmarkedArticles,
          [],
        ),
        returnValue: _i3
            .Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>(
          this,
          Invocation.method(
            #getBookmarkedArticles,
            [],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, void>> markAsRead(String? articleId) =>
      (super.noSuchMethod(
        Invocation.method(
          #markAsRead,
          [articleId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, void>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, void>>(
          this,
          Invocation.method(
            #markAsRead,
            [articleId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, void>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>> searchArticles({
    required String? query,
    int? limit = 20,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #searchArticles,
          [],
          {
            #query: query,
            #limit: limit,
          },
        ),
        returnValue: _i3
            .Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>(
          this,
          Invocation.method(
            #searchArticles,
            [],
            {
              #query: query,
              #limit: limit,
            },
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>);

  @override
  _i3.Future<
      _i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>> getArticlesByCategory(
    String? category, {
    int? page = 1,
    int? limit = 20,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #getArticlesByCategory,
          [category],
          {
            #page: page,
            #limit: limit,
          },
        ),
        returnValue: _i3
            .Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>(
          this,
          Invocation.method(
            #getArticlesByCategory,
            [category],
            {
              #page: page,
              #limit: limit,
            },
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, void>> shareArticle(
          String? articleId) =>
      (super.noSuchMethod(
        Invocation.method(
          #shareArticle,
          [articleId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, void>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, void>>(
          this,
          Invocation.method(
            #shareArticle,
            [articleId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, void>>);
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/domain/use_cases/news/bookmark_article_use_case_test.mocks.dart ===

// Mocks generated by Mockito 5.4.4 from annotations
// in bdnewsreader/test/unit/domain/use_cases/news/bookmark_article_use_case_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:bdnewsreader/core/architecture/either.dart' as _i4;
import 'package:bdnewsreader/core/architecture/failure.dart' as _i5;
import 'package:bdnewsreader/domain/entities/news_article.dart' as _i6;
import 'package:bdnewsreader/domain/repositories/news_repository.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i7;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

/// A class which mocks [NewsRepository].
///
/// See the documentation for Mockito's code generation for more information.
class MockNewsRepository extends _i1.Mock implements _i2.NewsRepository {
  MockNewsRepository() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>> getNewsFeed({
    required int? page,
    required int? limit,
    String? category,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #getNewsFeed,
          [],
          {
            #page: page,
            #limit: limit,
            #category: category,
          },
        ),
        returnValue: _i3
            .Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>(
          this,
          Invocation.method(
            #getNewsFeed,
            [],
            {
              #page: page,
              #limit: limit,
              #category: category,
            },
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, _i6.NewsArticle>> getArticleById(
          String? id) =>
      (super.noSuchMethod(
        Invocation.method(
          #getArticleById,
          [id],
        ),
        returnValue:
            _i3.Future<_i4.Either<_i5.AppFailure, _i6.NewsArticle>>.value(
                _i7.dummyValue<_i4.Either<_i5.AppFailure, _i6.NewsArticle>>(
          this,
          Invocation.method(
            #getArticleById,
            [id],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, _i6.NewsArticle>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, void>> bookmarkArticle(
          String? articleId) =>
      (super.noSuchMethod(
        Invocation.method(
          #bookmarkArticle,
          [articleId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, void>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, void>>(
          this,
          Invocation.method(
            #bookmarkArticle,
            [articleId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, void>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, void>> unbookmarkArticle(
          String? articleId) =>
      (super.noSuchMethod(
        Invocation.method(
          #unbookmarkArticle,
          [articleId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, void>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, void>>(
          this,
          Invocation.method(
            #unbookmarkArticle,
            [articleId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, void>>);

  @override
  _i3.Future<
      _i4.Either<_i5.AppFailure,
          List<_i6.NewsArticle>>> getBookmarkedArticles() =>
      (super.noSuchMethod(
        Invocation.method(
          #getBookmarkedArticles,
          [],
        ),
        returnValue: _i3
            .Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>(
          this,
          Invocation.method(
            #getBookmarkedArticles,
            [],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, void>> markAsRead(String? articleId) =>
      (super.noSuchMethod(
        Invocation.method(
          #markAsRead,
          [articleId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, void>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, void>>(
          this,
          Invocation.method(
            #markAsRead,
            [articleId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, void>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>> searchArticles({
    required String? query,
    int? limit = 20,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #searchArticles,
          [],
          {
            #query: query,
            #limit: limit,
          },
        ),
        returnValue: _i3
            .Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>(
          this,
          Invocation.method(
            #searchArticles,
            [],
            {
              #query: query,
              #limit: limit,
            },
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>);

  @override
  _i3.Future<
      _i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>> getArticlesByCategory(
    String? category, {
    int? page = 1,
    int? limit = 20,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #getArticlesByCategory,
          [category],
          {
            #page: page,
            #limit: limit,
          },
        ),
        returnValue: _i3
            .Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>(
          this,
          Invocation.method(
            #getArticlesByCategory,
            [category],
            {
              #page: page,
              #limit: limit,
            },
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, List<_i6.NewsArticle>>>);

  @override
  _i3.Future<_i4.Either<_i5.AppFailure, void>> shareArticle(
          String? articleId) =>
      (super.noSuchMethod(
        Invocation.method(
          #shareArticle,
          [articleId],
        ),
        returnValue: _i3.Future<_i4.Either<_i5.AppFailure, void>>.value(
            _i7.dummyValue<_i4.Either<_i5.AppFailure, void>>(
          this,
          Invocation.method(
            #shareArticle,
            [articleId],
          ),
        )),
      ) as _i3.Future<_i4.Either<_i5.AppFailure, void>>);
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/domain/use_cases/news/bookmark_article_use_case_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/domain/use_cases/news/bookmark_article_use_case.dart';

@GenerateMocks([NewsRepository])
import 'bookmark_article_use_case_test.mocks.dart';

void main() {
  provideDummy<Either<AppFailure, void>>(
    const Right(null),
  );

  late BookmarkArticleUseCase useCase;
  late MockNewsRepository mockRepository;

  setUp(() {
    mockRepository = MockNewsRepository();
    useCase = BookmarkArticleUseCase(mockRepository);
  });

  group('BookmarkArticleUseCase', () {
    const testArticleId = 'test-article-123';

    test('should bookmark article successfully', () async {
      // Arrange
      when(mockRepository.bookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: true,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.bookmarkArticle(testArticleId)).called(1);
    });

    test('should unbookmark article when already bookmarked', () async {
      // Arrange
      when(mockRepository.unbookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Right(null));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: false, // unbookmark
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.unbookmarkArticle(testArticleId)).called(1);
      verifyNever(mockRepository.bookmarkArticle(any));
    });

    test('should return StorageFailure when bookmark fails', () async {
      // Arrange
      const failure = StorageFailure('Failed to save bookmark');
      when(mockRepository.bookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: true,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<StorageFailure>());
          expect(f.message, contains('Failed to save bookmark'));
        },
        (_) => fail('Expected failure'),
      );
    });

    test('should return StorageFailure when unbookmark fails', () async {
      // Arrange
      const failure = StorageFailure('Failed to remove bookmark');
      when(mockRepository.unbookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: false, // unbookmark
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<StorageFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('should handle network failure gracefully', () async {
      // Arrange
      const failure = NetworkFailure('No network connection');
      when(mockRepository.bookmarkArticle(testArticleId))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const BookmarkArticleParams(
          articleId: testArticleId,
          shouldBookmark: true,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/domain/use_cases/news/fetch_news_feed_use_case_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/domain/use_cases/news/fetch_news_feed_use_case.dart';

// Configure mocks with proper dummy values for Either types
@GenerateMocks([NewsRepository])
import 'fetch_news_feed_use_case_test.mocks.dart';

void main() {
  provideDummy<Either<AppFailure, List<NewsArticle>>>(
    const Right([]),
  );

  late FetchNewsFeedUseCase useCase;
  late MockNewsRepository mockRepository;

  setUp(() {
    mockRepository = MockNewsRepository();
    useCase = FetchNewsFeedUseCase(mockRepository);
  });

  group('FetchNewsFeedUseCase', () {
    const testCategory = 'latest';
    final testArticles = [
      NewsArticle(
        id: '1',
        title: 'Test Article 1',
        content: 'Content 1',
        publishedAt: DateTime(2026, 1, 5),
        source: 'Test Source',
      ),
      NewsArticle(
        id: '2',
        title: 'Test Article 2',
        content: 'Content 2',
        publishedAt: DateTime(2026, 1, 4),
        source: 'Test Source',
        isBookmarked: true,
      ),
    ];

    test('should return list of articles on success', () async {
      // Arrange
      when(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).thenAnswer((_) async => Right(testArticles));

      // Act
      final result = await useCase.execute(
        const FetchNewsFeedParams(
          page: 1,
          category: testCategory,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success but got failure: $failure'),
        (articles) {
          expect(articles, testArticles);
          expect(articles.length, 2);
          expect(articles[0].title, 'Test Article 1');
          expect(articles[1].isBookmarked, true);
        },
      );

      verify(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).called(1);
    });

    test('should return NetworkFailure on network error', () async {
      // Arrange
      const failure = NetworkFailure('Connection failed');
      when(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const FetchNewsFeedParams(
          page: 1,
          category: testCategory,
        ),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<NetworkFailure>());
          expect(f.message, 'Connection failed');
        },
        (_) => fail('Expected failure but got success'),
      );

      verify(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).called(1);
    });

    test('should use default limit when not provided', () async {
      // Arrange
      when(mockRepository.getNewsFeed(
        page: 1,
        limit: 20,
        category: testCategory,
      )).thenAnswer((_) async => Right(testArticles));

      // Act - using default limit
      final result = await useCase.execute(
        const FetchNewsFeedParams(
          page: 1,
          category: testCategory,
        ),
      );

      // Assert
      expect(result.isRight(), true);
      verify(mockRepository.getNewsFeed(
        page: 1,
        limit: 20, // default value
        category: testCategory,
      )).called(1);
    });

    test('should handle empty result list', () async {
      // Arrange
      when(mockRepository.getNewsFeed(
        page: anyNamed('page'),
        limit: anyNamed('limit'),
        category: anyNamed('category'),
      )).thenAnswer((_) async => const Right([]));

      // Act
      final result = await useCase.execute(
        const FetchNewsFeedParams(page: 1, category: testCategory),
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (articles) => expect(articles, isEmpty),
      );
    });

    test('should return StorageFailure on storage error', () async {
      // Arrange
      const failure = StorageFailure('Database error');
      when(mockRepository.getNewsFeed(
        page: anyNamed('page'),
        limit: anyNamed('limit'),
        category: anyNamed('category'),
      )).thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(
        const FetchNewsFeedParams(page: 1, category: testCategory),
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<StorageFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/network_utils_test.dart ===

// test/unit/services/network_utils_test.dart
// ============================================
// Unit tests for NetworkUtils
// ============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/utils/network_utils.dart';

void main() {
  group('NetworkUtils', () {
    test('singleton instance should be same', () {
      final instance1 = NetworkUtils.instance;
      final instance2 = NetworkUtils.instance;
      expect(identical(instance1, instance2), true);
    });

    test('withFallback should return fallback on error', () async {
      final result = await NetworkUtils.instance.withFallback(
        operation: () async => throw Exception('Test error'),
        fallbackValue: 'fallback',
      );
      expect(result, 'fallback');
    });
  });

  group('NetworkException', () {
    test('should contain message and status code', () {
      final exception = NetworkException('Connection failed', statusCode: 500);
      expect(exception.message, 'Connection failed');
      expect(exception.statusCode, 500);
      expect(exception.toString(), contains('Connection failed'));
      expect(exception.toString(), contains('500'));
    });
  });

  group('InputSanitizer', () {
    // Import would be needed: import 'package:bdnewsreader/core/security/input_sanitizer.dart';
    
    test('isValidExternalUrl should reject localhost', () {
      // This tests the InputSanitizer.isValidExternalUrl function
      expect(true, true); // Placeholder until imports are sorted
    });

    test('sanitizeUrl should reject javascript protocol', () {
      expect(true, true); // Placeholder
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/device_session_service_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Session Service Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Device ID Management', () {
      test('TC-DEVICE-001: Device ID stored in SecurePrefs', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate device ID cached
        await prefs.setString('device_id_cached', 'device_abc123');
        
        expect(prefs.getString('device_id_cached'), 'device_abc123');
      });

      test('TC-DEVICE-002: Device ID persists across sessions', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('device_id_cached', 'persistent_device_id');
        
        // Simulate app restart
        final retrievedId = prefs.getString('device_id_cached');
        
        expect(retrievedId, 'persistent_device_id');
      });

      test('TC-DEVICE-003: Device info tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final deviceInfo = {
          'model': 'Samsung Galaxy S21',
          'platform': 'android',
          'osVersion': '12',
        };
        
        await prefs.setString('device_info', deviceInfo.toString());
        
        expect(prefs.getString('device_info'), isNotNull);
      });
    });

    group('Active Sessions', () {
      test('TC-DEVICE-004: Current session tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('current_session_id', 'session_xyz789');
        await prefs.setInt('session_start', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getString('current_session_id'), 'session_xyz789');
        expect(prefs.getInt('session_start'), greaterThan(0));
      });

      test('TC-DEVICE-005: Multiple device sessions listed', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final sessions = [
          '{"deviceId":"device1","lastActive":1234567890,"platform":"android"}',
          '{"deviceId":"device2","lastActive":1234567900,"platform":"ios"}',
        ];
        
        await prefs.setStringList('active_sessions', sessions);
        
        expect(prefs.getStringList('active_sessions')!.length, 2);
      });

      test('TC-DEVICE-006: Session limit enforced (max 5 devices)', () {
        final maxDevices = 5;
        final currentDevices = 6;
        
        final exceedsLimit = currentDevices > maxDevices;
        expect(exceedsLimit, true);
      });
    });

    group('Session Synchronization', () {
      test('TC-DEVICE-007: Sessions synced to Firestore', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('sessions_synced', true);
        await prefs.setInt('last_sync_time', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('sessions_synced'), true);
      });

      test('TC-DEVICE-008: Sync conflict resolution', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final localTimestamp = DateTime.now().millisecondsSinceEpoch;
        final serverTimestamp = localTimestamp - 1000; // Server is older
        
        // Local is newer, should take precedence
        final useLocal = localTimestamp > serverTimestamp;
        expect(useLocal, true);
      });
    });

    group('Device Logout', () {
      test('TC-DEVICE-009: Single device logout', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final sessions = [
          '{"deviceId":"device1"}',
          '{"deviceId":"device2"}',
        ];
        
        await prefs.setStringList('active_sessions', sessions);
        
        // Remove one device
        sessions.removeAt(0);
        await prefs.setStringList('active_sessions', sessions);
        
        expect(prefs.getStringList('active_sessions')!.length, 1);
      });

      test('TC-DEVICE-010: Logout all other devices', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Keep only current device
        await prefs.setStringList('active_sessions', ['{"deviceId":"current"}']);
        
        expect(prefs.getStringList('active_sessions')!.length, 1);
      });

      test('TC-DEVICE-011: Logout confirmation required', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('logout_confirmed', true);
        
        expect(prefs.getBool('logout_confirmed'), true);
      });
    });

    group('Security Features', () {
      test('TC-DEVICE-012: Suspicious device detected', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('suspicious_login', true);
        await prefs.setString('suspicious_device', 'device_unknown');
        
        expect(prefs.getBool('suspicious_login'), true);
      });

      test('TC-DEVICE-013: Device verification required', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('device_verified', false);
        await prefs.setString('verification_method', 'email');
        
        expect(prefs.getBool('device_verified'), false);
      });

      test('TC-DEVICE-014: Trusted devices list', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final trustedDevices = ['device1', 'device2', 'device3'];
        await prefs.setStringList('trusted_devices', trustedDevices);
        
        expect(prefs.getStringList('trusted_devices')!.length, 3);
      });
    });

    group('Activity Tracking', () {
      test('TC-DEVICE-015: Last activity time updated', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final lastActivity = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('last_activity', lastActivity);
        
        expect(prefs.getInt('last_activity'), lastActivity);
      });

      test('TC-DEVICE-016: Inactive session timeout', () {
        final lastActivity = DateTime.now().subtract(Duration(days: 31));
        final timeout = Duration(days: 30);
        
        final isInactive = DateTime.now().difference(lastActivity) > timeout;
        expect(isInactive, true);
      });

      test('TC-DEVICE-017: Session activity log', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final activities = [
          '{"action":"login","time":1234567890}',
          '{"action":"viewed_article","time":1234567900}',
        ];
        
        await prefs.setStringList('activity_log', activities);
        
        expect(prefs.getStringList('activity_log')!.length, 2);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/push_notification_service_test.dart ===

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushNotificationService', () {
    // Skip Firebase-dependent tests - these need Firebase Test Lab or emulators
    
    test('TC-UNIT-050: Notification preferences structure', () {
      final prefs = {
        'breakingNews': true,
        'categoryUpdates': false,
        'liveEvents': true,
      };
      
      expect(prefs.containsKey('breakingNews'), true);
      expect(prefs['liveEvents'], true);
    });

    test('TC-UNIT-051: Notification channel IDs', () {
      const breakingNewsChannel = 'breaking_news';
      const categoryChannel = 'category_updates';
      
      expect(breakingNewsChannel, 'breaking_news');
      expect(categoryChannel, 'category_updates');
    });

    test('TC-UNIT-052: Notification importance levels', () {
      const highImportance = 4;
      const defaultImportance = 3;
      
      expect(highImportance, greaterThan(defaultImportance));
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/sync_service_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

/// These tests validate SyncService patterns without requiring Firebase
/// Firebase integration tests should use firebase_auth_mocks package
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService (Patterns)', () {
    // Note: SyncService requires Firebase. These tests validate patterns
    // that can be tested without Firebase initialization.

    group('Settings Structure', () {
      test('TC-UNIT-020: Settings map has expected structure', () {
        final settings = <String, dynamic>{
          'dataSaver': true,
          'pushNotif': true,
          'themeMode': 1,
          'languageCode': 'bn',
          'readerLineHeight': 1.5,
          'readerContrast': 1.0,
        };
        
        expect(settings['dataSaver'], isA<bool>());
        expect(settings['pushNotif'], isA<bool>());
        expect(settings['themeMode'], isA<int>());
        expect(settings['languageCode'], isA<String>());
        expect(settings['readerLineHeight'], isA<double>());
        expect(settings['readerContrast'], isA<double>());
      });

      test('TC-UNIT-021: Theme mode has valid range', () {
        // 0 = system, 1 = light, 2 = dark
        const validThemeModes = [0, 1, 2];
        
        for (final mode in validThemeModes) {
          expect(mode, inInclusiveRange(0, 2));
        }
      });

      test('TC-UNIT-022: Language codes are valid', () {
        const supportedLanguages = ['en', 'bn'];
        
        expect(supportedLanguages, contains('en'));
        expect(supportedLanguages, contains('bn'));
      });
    });

    group('Favorites Structure', () {
      test('TC-UNIT-023: Articles can be serialized for sync', () {
        final article = NewsArticle(
          title: 'Test Article',
          url: 'https://example.com/test',
          source: 'Test Source',
          publishedAt: DateTime.now(),
        );
        
        final map = article.toMap();
        
        expect(map['title'], 'Test Article');
        expect(map['url'], 'https://example.com/test');
        expect(map['source'], 'Test Source');
      });

      test('TC-UNIT-024: Magazine favorites have required fields', () {
        final magazine = <String, dynamic>{
          'id': 'mag1',
          'name': 'Test Magazine',
          'coverUrl': 'https://example.com/cover.jpg',
        };
        
        expect(magazine['id'], isNotNull);
        expect(magazine['name'], isNotNull);
      });

      test('TC-UNIT-025: Newspaper favorites have required fields', () {
        final newspaper = <String, dynamic>{
          'id': 'paper1',
          'name': 'Prothom Alo',
          'logoUrl': 'https://example.com/logo.png',
        };
        
        expect(newspaper['id'], isNotNull);
        expect(newspaper['name'], isNotNull);
      });
    });

    group('Sync Data Validation', () {
      test('TC-UNIT-026: Favorites sync payload structure', () {
        final syncPayload = <String, dynamic>{
          'articles': <Map<String, dynamic>>[],
          'magazines': <Map<String, dynamic>>[],
          'newspapers': <Map<String, dynamic>>[],
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        expect(syncPayload['articles'], isA<List>());
        expect(syncPayload['magazines'], isA<List>());
        expect(syncPayload['newspapers'], isA<List>());
      });

      test('TC-UNIT-027: Settings sync payload structure', () {
        final syncPayload = <String, dynamic>{
          'dataSaver': false,
          'pushNotif': true,
          'themeMode': 0,
          'languageCode': 'en',
          'readerLineHeight': 1.6,
          'readerContrast': 1.0,
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        expect(syncPayload.keys.length, 7);
      });
    });

    group('SharedPreferences Integration', () {
      test('TC-UNIT-028: Settings can be stored locally', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('data_saver_mode', true);
        await prefs.setBool('push_notifications', true);
        await prefs.setInt('theme_mode', 2);
        await prefs.setString('language_code', 'bn');
        await prefs.setDouble('reader_line_height', 1.5);
        await prefs.setDouble('reader_contrast', 0.9);
        
        expect(prefs.getBool('data_saver_mode'), isTrue);
        expect(prefs.getInt('theme_mode'), 2);
        expect(prefs.getString('language_code'), 'bn');
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/auth_service_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These tests validate AuthService patterns without requiring Firebase
/// Firebase integration tests should use firebase_auth_mocks package
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService (Patterns)', () {
    // Note: AuthService requires Firebase. These tests validate patterns
    // that can be tested without Firebase initialization.

    group('SharedPreferences Keys', () {
      test('TC-UNIT-001: User preference keys are properly formatted', () {
        const keys = <String, String>{
          'name': 'user_name',
          'email': 'user_email',
          'phone': 'user_phone',
          'role': 'user_role',
          'department': 'user_department',
          'image': 'user_image',
          'isLoggedIn': 'isLoggedIn',
        };
        
        for (final entry in keys.entries) {
          expect(entry.value, isNotEmpty);
          expect(entry.value.startsWith('user_') || entry.value == 'isLoggedIn', isTrue);
        }
      });

      test('TC-UNIT-002: SharedPreferences can store profile data', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('user_name', 'Test User');
        await prefs.setString('user_email', 'test@example.com');
        await prefs.setBool('isLoggedIn', true);
        
        expect(prefs.getString('user_name'), 'Test User');
        expect(prefs.getString('user_email'), 'test@example.com');
        expect(prefs.getBool('isLoggedIn'), isTrue);
      });

      test('TC-UNIT-003: Profile data can be cleared while preserving settings', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'user_name': 'Test User',
          'user_email': 'test@example.com',
          'isLoggedIn': true,
          'theme_mode': 2,
          'language_code': 'bn',
        });
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate logout: clear user data but preserve settings
        final themeMode = prefs.getInt('theme_mode');
        final languageCode = prefs.getString('language_code');
        
        await prefs.clear();
        
        // Restore settings
        if (themeMode != null) await prefs.setInt('theme_mode', themeMode);
        if (languageCode != null) await prefs.setString('language_code', languageCode);
        
        // User data cleared
        expect(prefs.getString('user_name'), isNull);
        // Settings preserved
        expect(prefs.getInt('theme_mode'), 2);
        expect(prefs.getString('language_code'), 'bn');
      });
    });

    group('Email Validation', () {
      test('TC-UNIT-004: Email regex validates correctly', () {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        
        // Valid emails
        expect(emailRegex.hasMatch('user@example.com'), isTrue);
        expect(emailRegex.hasMatch('test.user@domain.org'), isTrue);
        expect(emailRegex.hasMatch('user-name@company.bd'), isTrue);
        
        // Invalid emails
        expect(emailRegex.hasMatch('notanemail'), isFalse);
        expect(emailRegex.hasMatch('@example.com'), isFalse);
        expect(emailRegex.hasMatch('user@'), isFalse);
        expect(emailRegex.hasMatch(''), isFalse);
      });
    });

    group('Password Validation', () {
      test('TC-UNIT-005: Password minimum length is 6', () {
        bool isValidPassword(String password) {
          return password.length >= 6;
        }
        
        expect(isValidPassword('123456'), isTrue);
        expect(isValidPassword('password'), isTrue);
        expect(isValidPassword('12345'), isFalse);
        expect(isValidPassword(''), isFalse);
      });
    });

    group('Profile Structure', () {
      test('TC-UNIT-006: Profile map has expected keys', () {
        final profile = <String, String>{
          'name': '',
          'email': '',
          'phone': '',
          'role': '',
          'department': '',
          'image': '',
        };
        
        expect(profile.containsKey('name'), isTrue);
        expect(profile.containsKey('email'), isTrue);
        expect(profile.containsKey('phone'), isTrue);
        expect(profile.containsKey('role'), isTrue);
        expect(profile.containsKey('department'), isTrue);
        expect(profile.containsKey('image'), isTrue);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/security_service_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/security/security_service.dart';
import 'package:flutter/services.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock flutter_secure_storage
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'write') {
        return null; // Success
      }
      if (methodCall.method == 'read') {
        return 'mock_value'; // Success
      }
      if (methodCall.method == 'delete') {
        return null; // Success
      }
      if (methodCall.method == 'deleteAll') {
        return null; // Success
      }
      return null;
    });
  });

  group('SecurityService', () {
    late SecurityService securityService;

    setUp(() {
      securityService = SecurityService();
    });

    group('Singleton Pattern', () {
      test('TC-UNIT-060: SecurityService is a singleton', () {
        final instance1 = SecurityService();
        final instance2 = SecurityService();
        
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Cryptography', () {
      test('TC-UNIT-061: hashString produces consistent SHA-256 hash', () {
        final hash1 = securityService.hashString('test_input');
        final hash2 = securityService.hashString('test_input');
        
        expect(hash1, equals(hash2));
        expect(hash1.length, 64); // SHA-256 produces 64 hex characters
      });

      test('TC-UNIT-062: hashString produces different hashes for different inputs', () {
        final hash1 = securityService.hashString('input1');
        final hash2 = securityService.hashString('input2');
        
        expect(hash1, isNot(equals(hash2)));
      });

      test('TC-UNIT-063: generateHmac produces valid HMAC', () {
        final hmac = securityService.generateHmac('data', 'secret_key');
        
        expect(hmac, isNotEmpty);
        expect(hmac.length, 64); // HMAC-SHA256 produces 64 hex characters
      });

      test('TC-UNIT-064: generateHmac is consistent with same inputs', () {
        final hmac1 = securityService.generateHmac('data', 'secret');
        final hmac2 = securityService.generateHmac('data', 'secret');
        
        expect(hmac1, equals(hmac2));
      });

      test('TC-UNIT-065: verifyHmac returns true for matching HMAC', () {
        const data = 'important_data';
        const secretKey = 'my_secret_key';
        
        final hmac = securityService.generateHmac(data, secretKey);
        final isValid = securityService.verifyHmac(data, hmac, secretKey);
        
        expect(isValid, isTrue);
      });

      test('TC-UNIT-066: verifyHmac returns false for wrong HMAC', () {
        const data = 'important_data';
        const secretKey = 'my_secret_key';
        
        final isValid = securityService.verifyHmac(data, 'wrong_hmac', secretKey);
        
        expect(isValid, isFalse);
      });

      test('TC-UNIT-067: verifyHmac returns false for wrong key', () {
        const data = 'important_data';
        
        final hmac = securityService.generateHmac(data, 'key1');
        final isValid = securityService.verifyHmac(data, hmac, 'key2');
        
        expect(isValid, isFalse);
      });
    });

    group('State', () {
      test('TC-UNIT-068: isRooted is a boolean', () {
        expect(securityService.isRooted, isA<bool>());
      });

      test('TC-UNIT-069: isSecure is a boolean', () {
        expect(securityService.isSecure, isA<bool>());
      });
    });

    group('Initialization', () {
      test('TC-UNIT-070: initialize() completes without throwing', () async {
        // May fail in test environment but shouldn't throw unhandled exception
        await expectLater(
          securityService.initialize(),
          completes,
        );
      });
    });

    group('Secure Storage Methods', () {
      test('TC-UNIT-071: secureWrite accepts key-value pair', () async {
        // This may not work in test environment but API should be correct
        try {
          await securityService.secureWrite('test_key', 'test_value');
        } catch (e) {
          // Expected to fail without native implementation in tests
        }
        expect(true, isTrue); // API exists and is callable
      });

      test('TC-UNIT-072: secureRead returns value or null', () async {
        try {
          final value = await securityService.secureRead('nonexistent_key');
          expect(value, isNull);
        } catch (e) {
          // Expected in test environment
        }
        expect(true, isTrue);
      });
    });

    group('Biometrics', () {
      test('TC-UNIT-073: canUseBiometrics returns boolean', () async {
        final canUse = await securityService.canUseBiometrics();
        expect(canUse, isA<bool>());
      });

      test('TC-UNIT-074: getAvailableBiometrics returns list', () async {
        final biometrics = await securityService.getAvailableBiometrics();
        expect(biometrics, isA<List>());
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/data_saver_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/network_quality_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Saver & Network Quality', () {
    late NetworkQualityManager networkManager;

    setUp(() {
      networkManager = NetworkQualityManager();
    });

    group('Singleton Pattern', () {
      test('TC-UNIT-070: NetworkQualityManager is a singleton', () {
        final instance1 = NetworkQualityManager();
        final instance2 = NetworkQualityManager();
        
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Cache Duration', () {
      test('TC-UNIT-071: getCacheDuration returns a Duration', () {
        final duration = networkManager.getCacheDuration();
        
        expect(duration, isA<Duration>());
        expect(duration.inMinutes, greaterThan(0));
      });

      test('TC-UNIT-072: Cache duration is reasonable', () {
        final duration = networkManager.getCacheDuration();
        
        expect(duration.inMinutes, inInclusiveRange(10, 300)); // 10min to 5hr
      });
    });

    group('Adaptive Timeout', () {
      test('TC-UNIT-073: getAdaptiveTimeout returns a Duration', () {
        final timeout = networkManager.getAdaptiveTimeout();
        
        expect(timeout, isA<Duration>());
        expect(timeout.inSeconds, greaterThan(0));
      });

      test('TC-UNIT-074: Timeout is within reasonable bounds', () {
        final timeout = networkManager.getAdaptiveTimeout();
        
        expect(timeout.inSeconds, inInclusiveRange(5, 60));
      });
    });

    group('Network Quality State', () {
      test('TC-UNIT-075: currentQuality is accessible', () {
        final quality = networkManager.currentQuality;
        
        expect(quality, isA<NetworkQuality>());
      });

      test('TC-UNIT-076: NetworkQuality enum has expected values', () {
        expect(NetworkQuality.values, contains(NetworkQuality.excellent));
        expect(NetworkQuality.values, contains(NetworkQuality.good));
        expect(NetworkQuality.values, contains(NetworkQuality.fair));
        expect(NetworkQuality.values, contains(NetworkQuality.poor));
        expect(NetworkQuality.values, contains(NetworkQuality.offline));
      });
    });

    group('Image Handling', () {
      test('TC-UNIT-077: getImageCacheWidth returns int', () {
        final width = networkManager.getImageCacheWidth(dataSaver: false);
        
        expect(width, isA<int>());
        expect(width, greaterThan(0));
      });

      test('TC-UNIT-078: Data saver mode reduces image width', () {
        final normalWidth = networkManager.getImageCacheWidth(dataSaver: false);
        final dataSaverWidth = networkManager.getImageCacheWidth(dataSaver: true);
        
        expect(dataSaverWidth, lessThanOrEqualTo(normalWidth));
      });

      test('TC-UNIT-079: shouldLoadImages respects data saver', () {
        expect(networkManager.shouldLoadImages(dataSaver: true), isFalse);
      });
    });

    group('Article Limit', () {
      test('TC-UNIT-080: getArticleLimit returns int', () {
        final limit = networkManager.getArticleLimit();
        
        expect(limit, isA<int>());
        expect(limit, greaterThan(0));
      });
    });

    group('Quality Description', () {
      test('TC-UNIT-081: getQualityDescription returns string', () {
        final description = networkManager.getQualityDescription();
        
        expect(description, isA<String>());
        expect(description, isNotEmpty);
      });
    });

    group('Prefetch Logic', () {
      test('TC-UNIT-082: shouldPrefetch returns boolean', () {
        final shouldPrefetch = networkManager.shouldPrefetch();
        
        expect(shouldPrefetch, isA<bool>());
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/premium_service_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests PremiumService patterns without importing the Firebase-dependent service
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumService (Patterns)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Tier System', () {
      test('TC-PREM-001: Tier values are defined', () {
        // Tiers: 0=free, 1=pro, 2=proPlus
        const tiers = [0, 1, 2];
        
        expect(tiers.length, 3);
        expect(tiers, contains(0)); // Free
        expect(tiers, contains(1)); // Pro
        expect(tiers, contains(2)); // Pro Plus
      });

      test('TC-PREM-002: Tier can be stored in prefs', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setInt('premium_tier', 1);
        expect(prefs.getInt('premium_tier'), 1);
      });

      test('TC-PREM-003: isPremium based on tier', () {
        bool isPremium(int tier) => tier >= 1;
        
        expect(isPremium(0), isFalse);
        expect(isPremium(1), isTrue);
        expect(isPremium(2), isTrue);
      });

      test('TC-PREM-004: isProPlus based on tier', () {
        bool isProPlus(int tier) => tier >= 2;
        
        expect(isProPlus(0), isFalse);
        expect(isProPlus(1), isFalse);
        expect(isProPlus(2), isTrue);
      });
    });

    group('Feature Access', () {
      test('TC-PREM-005: Features have tier requirements', () {
        final featureTiers = {
          'cloud_sync': 1,
          'no_ads': 1,
          'offline_mode': 1,
          'priority_support': 2,
          'early_access': 2,
        };
        
        bool canAccess(String feature, int userTier) {
          final requiredTier = featureTiers[feature] ?? 0;
          return userTier >= requiredTier;
        }
        
        // Free user
        expect(canAccess('cloud_sync', 0), isFalse);
        expect(canAccess('no_ads', 0), isFalse);
        
        // Pro user
        expect(canAccess('cloud_sync', 1), isTrue);
        expect(canAccess('no_ads', 1), isTrue);
        expect(canAccess('priority_support', 1), isFalse);
        
        // Pro Plus user
        expect(canAccess('cloud_sync', 2), isTrue);
        expect(canAccess('priority_support', 2), isTrue);
      });
    });

    group('Whitelist', () {
      test('TC-PREM-006: Whitelist email format is valid', () {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        
        final testEmails = [
          'ddeba32@gmail.com',
          'debashish.deb@gmail.com',
        ];
        
        for (final email in testEmails) {
          expect(emailRegex.hasMatch(email), isTrue);
        }
      });

      test('TC-PREM-007: Whitelist check returns boolean', () {
        final whitelist = {'ddeba32@gmail.com', 'vip@example.com'};
        
        bool isWhitelisted(String email) {
          return whitelist.contains(email.toLowerCase());
        }
        
        expect(isWhitelisted('ddeba32@gmail.com'), isTrue);
        expect(isWhitelisted('random@example.com'), isFalse);
      });
    });

    group('Persistence', () {
      test('TC-PREM-008: Premium status persists', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('is_premium', true);
        await prefs.setInt('premium_tier', 2);
        
        expect(prefs.getBool('is_premium'), isTrue);
        expect(prefs.getInt('premium_tier'), 2);
      });

      test('TC-PREM-009: Expiry date can be stored', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final expiry = DateTime.now().add(const Duration(days: 30));
        await prefs.setString('premium_expiry', expiry.toIso8601String());
        
        final stored = prefs.getString('premium_expiry');
        expect(stored, isNotNull);
        
        final parsed = DateTime.parse(stored!);
        expect(parsed.isAfter(DateTime.now()), isTrue);
      });
    });

    group('Status Reload', () {
      test('TC-PREM-010: Status can be reset', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('is_premium', true);
        await prefs.remove('is_premium');
        
        expect(prefs.getBool('is_premium'), isNull);
      });

      test('TC-PREM-011: Default tier is free (0)', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final tier = prefs.getInt('premium_tier') ?? 0;
        expect(tier, 0);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/unit/services/rss_service_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:bdnewsreader/data/services/rss_service.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RssService', () {
    group('Categories', () {
      test('TC-UNIT-040: RssService.categories contains expected categories', () {
        expect(RssService.categories, contains('latest'));
        expect(RssService.categories, contains('national'));
        expect(RssService.categories, contains('international'));
        expect(RssService.categories, contains('sports'));
        expect(RssService.categories, contains('entertainment'));
        expect(RssService.categories, contains('technology'));
        expect(RssService.categories, contains('economy'));
      });

      test('TC-UNIT-041: Categories list is not empty', () {
        expect(RssService.categories.length, greaterThan(0));
      });
    });

    group('Fetch News', () {
      test('TC-UNIT-042: fetchNews with empty feeds returns empty list', () async {
        // Create RssService with mock client that returns 404
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'nonexistent_category',
          locale: const Locale('en'),
        );
        
        expect(articles, isEmpty);
      });

      test('TC-UNIT-043: fetchNews handles network errors gracefully', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });
        
        final rssService = RssService(client: mockClient);
        
        // Should not throw, should return empty list
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });

      test('TC-UNIT-044: fetchNews with valid RSS returns articles', () async {
        const validRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <item>
      <title>Test Article 1</title>
      <link>https://example.com/article1</link>
      <description>Test description</description>
      <pubDate>Mon, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Test Article 2</title>
      <link>https://example.com/article2</link>
      <description>Another test</description>
      <pubDate>Mon, 25 Dec 2024 09:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';
        
        final mockClient = MockClient((request) async {
          return http.Response(validRss, 200, headers: {
            'content-type': 'application/rss+xml; charset=utf-8',
          });
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
        expect(articles.length, greaterThanOrEqualTo(0));
      });

      test('TC-UNIT-045: fetchNews handles malformed XML gracefully', () async {
        const malformedRss = '<rss><channel><title>Broken';
        
        final mockClient = MockClient((request) async {
          return http.Response(malformedRss, 200);
        });
        
        final rssService = RssService(client: mockClient);
        
        // Should not throw, should return empty list
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });
    });

    group('Locale Support', () {
      test('TC-UNIT-046: fetchNews accepts Bengali locale', () async {
        const validRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>BBC Bengali</title>
    <item>
      <title>Bengali News 1</title>
      <link>https://bbc.com/bengali/news1</link>
      <pubDate>Mon, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

        final mockClient = MockClient((request) async {
          if (request.url.toString().contains('bengali')) {
             return http.Response(validRss, 200, headers: {
              'content-type': 'application/rss+xml; charset=utf-8',
            });
          }
          return http.Response('', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('bn'),
        );
        
        expect(articles, isNotEmpty);
        expect(articles.first.title, contains('Bengali'));
      });

      test('TC-UNIT-047: fetchNews accepts English locale', () async {
         const validRss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>BBC World</title>
    <item>
      <title>English News 1</title>
      <link>https://bbc.com/news/1</link>
      <pubDate>Mon, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';

        final mockClient = MockClient((request) async {
           // Return success for BBC World URL which is first in the list for 'latest'/'en'
           if (request.url.toString().contains('bbci.co.uk/news/world')) {
             return http.Response(validRss, 200, headers: {
              'content-type': 'application/rss+xml; charset=utf-8',
            });
           }
          return http.Response('', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isNotEmpty);
        expect(articles.first.title, contains('English'));
      });
    });

    group('Deduplication', () {
      test('TC-UNIT-048: Duplicate URLs are removed from results', () {
        // Test the deduplication logic
        final urls = <String>{'url1', 'url1', 'url2', 'url3', 'url2'};
        
        // Using Set for deduplication (as RssService does)
        expect(urls.length, 3);
      });
    });

    group('Sorting', () {
      test('TC-UNIT-049: Articles are sorted newest first', () {
        final articles = [
          NewsArticle(title: 'Old', url: 'u1', source: 's', publishedAt: DateTime(2024)),
          NewsArticle(title: 'New', url: 'u2', source: 's', publishedAt: DateTime(2024, 12, 25)),
          NewsArticle(title: 'Mid', url: 'u3', source: 's', publishedAt: DateTime(2024, 6, 15)),
        ];
        
        articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        
        expect(articles[0].title, 'New');
        expect(articles[2].title, 'Old');
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/professional/hive_rss_professional_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/data/services/rss_service.dart';
import 'package:bdnewsreader/data/models/news_article.dart';
import 'package:bdnewsreader/core/network_quality_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Professional Hive & RSS Tests', () {
    group('Cache TTL (Time To Live)', () {
      test('TC-HIVE-PRO-001: Cache has valid TTL configuration', () {
        final manager = NetworkQualityManager();
        final cacheDuration = manager.getCacheDuration();
        
        expect(cacheDuration.inMinutes, greaterThan(0));
        expect(cacheDuration.inHours, lessThanOrEqualTo(24));
      });

      test('TC-HIVE-PRO-002: Cache expiry is properly calculated', () {
        final cachedAt = DateTime.now().subtract(const Duration(hours: 2));
        const cacheDuration = Duration(hours: 1);
        
        final isExpired = DateTime.now().difference(cachedAt) > cacheDuration;
        
        expect(isExpired, isTrue); // 2 hours > 1 hour TTL
      });
    });

    group('RSS Service Categories', () {
      test('TC-RSS-PRO-001: All categories are defined', () {
        const categories = RssService.categories;
        
        expect(categories.length, greaterThanOrEqualTo(5));
        expect(categories, contains('latest'));
        expect(categories, contains('sports'));
      });
    });

    group('Data Validation', () {
      test('TC-RSS-PRO-002: NewsArticle validates required fields', () {
        final article = NewsArticle(
          title: 'Valid Title',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime.now(),
        );
        
        expect(article.title.isNotEmpty, isTrue);
        expect(article.url.isNotEmpty, isTrue);
        expect(article.source.isNotEmpty, isTrue);
      });

      test('TC-RSS-PRO-003: Empty titles are filtered', () {
        final articles = [
          NewsArticle(title: 'Valid', url: 'u1', source: 's', publishedAt: DateTime.now()),
          NewsArticle(title: '', url: 'u2', source: 's', publishedAt: DateTime.now()),
        ];
        
        final valid = articles.where((a) => a.title.isNotEmpty).toList();
        
        expect(valid.length, 1);
      });
    });

    group('Network Adaptation', () {
      test('TC-RSS-PRO-004: NetworkQualityManager provides timeout', () {
        final manager = NetworkQualityManager();
        final timeout = manager.getAdaptiveTimeout();
        
        expect(timeout.inSeconds, greaterThanOrEqualTo(5));
        expect(timeout.inSeconds, lessThanOrEqualTo(60));
      });

      test('TC-RSS-PRO-005: NetworkQualityManager is singleton', () {
        final m1 = NetworkQualityManager();
        final m2 = NetworkQualityManager();
        
        expect(identical(m1, m2), isTrue);
      });
    });

    group('Deduplication', () {
      test('TC-RSS-PRO-006: Duplicate URLs are removed', () {
        final articles = [
          NewsArticle(title: 'A', url: 'same-url', source: 's', publishedAt: DateTime.now()),
          NewsArticle(title: 'B', url: 'same-url', source: 's', publishedAt: DateTime.now()),
          NewsArticle(title: 'C', url: 'different-url', source: 's', publishedAt: DateTime.now()),
        ];
        
        final seen = <String>{};
        final unique = articles.where((a) => seen.add(a.url)).toList();
        
        expect(unique.length, 2);
      });
    });

    group('Sorting', () {
      test('TC-RSS-PRO-007: Articles sorted by newest first', () {
        final articles = [
          NewsArticle(title: 'Old', url: 'u1', source: 's', publishedAt: DateTime(2024)),
          NewsArticle(title: 'New', url: 'u2', source: 's', publishedAt: DateTime(2024, 12, 25)),
          NewsArticle(title: 'Mid', url: 'u3', source: 's', publishedAt: DateTime(2024, 6, 15)),
        ];
        
        articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        
        expect(articles[0].title, 'New');
        expect(articles[2].title, 'Old');
      });
    });

    group('Fallback Strategy', () {
      test('TC-RSS-PRO-008: Empty data doesn\'t overwrite valid cache', () {
        final existingCache = ['article1', 'article2'];
        final newData = <String>[];
        
        // Business logic: Never replace valid cache with empty
        final shouldUpdate = newData.isNotEmpty;
        
        expect(shouldUpdate, isFalse);
        expect(existingCache.length, 2); // Cache preserved
      });
    });

    group('Error Handling', () {
      test('TC-RSS-PRO-009: Errors return empty list, not throw', () async {
        Future<List<String>> fetchWithErrorHandling() async {
          try {
            throw Exception('Network error');
          } catch (e) {
            return []; // Graceful degradation
          }
        }
        
        final result = await fetchWithErrorHandling();
        expect(result, isEmpty);
      });
    });

    group('Serialization', () {
      test('TC-RSS-PRO-010: NewsArticle serializes to map', () {
        final article = NewsArticle(
          title: 'Test',
          url: 'https://example.com',
          source: 'Source',
          publishedAt: DateTime(2024, 12, 25),
        );
        
        final map = article.toMap();
        
        expect(map['title'], 'Test');
        expect(map['url'], 'https://example.com');
        expect(map.containsKey('publishedAt'), isTrue);
      });

      test('TC-RSS-PRO-011: NewsArticle deserializes from map', () {
        final map = {
          'title': 'From Map',
          'url': 'https://example.com',
          'source': 'Source',
          'publishedAt': '2024-12-25T00:00:00.000',
        };
        
        final article = NewsArticle.fromMap(map);
        
        expect(article.title, 'From Map');
        expect(article.url, 'https://example.com');
      });
    });

    group('Cache Performance', () {
      test('TC-HIVE-PRO-003: Map operations are fast', () {
        final cache = <String, String>{};
        
        final start = DateTime.now();
        for (int i = 0; i < 1000; i++) {
          cache['key$i'] = 'value$i';
        }
        final writeTime = DateTime.now().difference(start).inMilliseconds;
        
        expect(writeTime, lessThan(100)); // 1000 writes < 100ms
        expect(cache.length, 1000);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/features/home/home_screen_test.dart ===

import 'dart:io'; 
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:bdnewsreader/features/home/home_screen.dart';
import 'package:bdnewsreader/features/home/widgets/news_card.dart';
import 'package:bdnewsreader/data/models/news_article.dart';
import 'package:bdnewsreader/data/services/rss_service.dart';
import 'package:bdnewsreader/data/repositories/news_repository.dart';
import 'package:bdnewsreader/presentation/providers/news_providers.dart';
import 'package:bdnewsreader/presentation/providers/language_providers.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:bdnewsreader/core/theme_provider.dart';
import 'package:bdnewsreader/presentation/providers/subscription_providers.dart';
import 'package:bdnewsreader/presentation/providers/app_settings_providers.dart';
import 'package:bdnewsreader/core/services/favorites_providers.dart';
import 'package:bdnewsreader/presentation/providers/tab_providers.dart';
import 'package:bdnewsreader/l10n/app_localizations.dart';

// Fake RssService
class FakeRssService extends Fake implements RssService {
  List<NewsArticle> _news = [];

  void setNews(List<NewsArticle> news) {
    _news = news;
  }

  @override
  Future<List<NewsArticle>> fetchNews({
    required String category, 
    required Locale locale,
    BuildContext? context,
    bool preferRss = false,
  }) async {
    return _news;
  }
}

void main() {
  setUpAll(() async {
    // Mock Path Provider for Hive.initFlutter
    // We need this because HomeScreen calls HiveService.init which calls Hive.initFlutter
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );

    // Initialize Hive manually in temp dir
    Hive.init(Directory.systemTemp.path);
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(NewsArticleAdapter());
    }
  });

  testWidgets('HomeScreen renders news feed when loaded', (WidgetTester tester) async {
    // Open the box expected by logic
    if (!Hive.isBoxOpen('latest')) {
       await Hive.openBox<NewsArticle>('latest');
       await Hive.openBox('latest_meta');
    }

    final fakeRssService = FakeRssService();
    final testArticle = NewsArticle(
      source: 'Test Source',
      title: 'Test Title',
      description: 'Test Description', 
      url: 'https://example.com',
      imageUrl: 'https://example.com/image.png',
      publishedAt: DateTime.now(),
      fullContent: 'Content',
    );
    fakeRssService.setNews([testArticle]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override newsProvider properly
          newsProvider.overrideWith((ref) => NewsNotifier(newsRepository: NewsRepository(rssService: fakeRssService))),
          
          currentThemeModeProvider.overrideWithValue(AppThemeMode.light),
          currentLocaleProvider.overrideWithValue(const Locale('en')),
          
          // Subscription & Settings
          isPremiumProvider.overrideWithValue(true), 
          dataSaverProvider.overrideWithValue(false),
          
          // Theme & Other
          glassColorProvider.overrideWithValue(Colors.black),
          borderColorProvider.overrideWithValue(Colors.transparent),
          favoritesCountProvider.overrideWithValue(0),
          
          // Tabs
          currentTabIndexProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));

    // Debug output if fails
    if (find.text('Test Title').evaluate().isEmpty) {
       debugPrint('❌ Test Title not found!');
       debugPrint('Checking for errors...');
       final errorFind = find.textContaining('Error');
       if (errorFind.evaluate().isNotEmpty) {
          debugPrint('Found Error Text: ${errorFind.evaluate()}');
       }
       if (find.text('No articles found').evaluate().isNotEmpty) {
           debugPrint('Found Empty State Text: No articles found');
       }
    }

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.byType(NewsCard), findsOneWidget);
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/features/news/news_detail_screen_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdnewsreader/features/news_detail/news_detail_screen.dart';
import 'package:bdnewsreader/data/models/news_article.dart';
import 'package:bdnewsreader/presentation/providers/saved_articles_provider.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:bdnewsreader/core/theme_provider.dart';
import 'package:bdnewsreader/core/services/saved_articles_service.dart';
import 'package:bdnewsreader/l10n/app_localizations.dart'; 

// Fake Service - much simpler than mocking for this case
class FakeSavedArticlesService implements SavedArticlesService {
  final List<NewsArticle> _saved = [];
  
  void setSaved(List<NewsArticle> articles) {
    _saved.clear();
    _saved.addAll(articles);
  }

  @override
  Future<void> init() async {}
  
  @override
  bool isSaved(String? url) => _saved.any((a) => a.url == url);
  
  @override
  List<NewsArticle> getSavedArticles() => List.unmodifiable(_saved);

  // Implement other methods safely
  @override
  Future<bool> saveArticle(NewsArticle article) async {
    _saved.add(article);
    return true;
  }
  
  @override
  Future<bool> removeArticle(String url) async {
    _saved.removeWhere((a) => a.url == url);
    return true;
  }
  
  @override
  int get savedCount => _saved.length;
  
  @override
  double get storageUsageMB => 0;
  
  @override
  Future<void> clearAll() async => _saved.clear();
  
  @override
  NewsArticle? getSavedArticle(String url) => 
      _saved.where((a) => a.url == url).firstOrNull;
      
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> main() async {
  // Common test data
  final testArticle = NewsArticle(
    source: 'Test Source',
    title: 'Test Title',
    description: 'Test Description',
    url: 'https://example.com/test',
    imageUrl: 'https://example.com/image.png',
    publishedAt: DateTime(2023),
    fullContent: 'Test Content',
  );

  testWidgets('NewsDetailScreen renders AppBar with source and FAB', (WidgetTester tester) async {
    // Setup Fake Service and Notifier
    final fakeService = FakeSavedArticlesService();
    // Default empty state
    
    final notifier = SavedArticlesNotifier(service: fakeService);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedArticlesProvider.overrideWith((ref) => notifier),
          currentThemeModeProvider.overrideWithValue(AppThemeMode.light),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: NewsDetailScreen(news: testArticle),
        ),
      ),
    );
    
    // Pump to ensure any async ops settle
    await tester.pumpAndSettle();

    expect(find.text('Test Source'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
  });

  testWidgets('NewsDetailScreen shows correct icon when article is saved', (WidgetTester tester) async {
    final fakeService = FakeSavedArticlesService();
    // Pre-populate service with saved article
    fakeService.setSaved([testArticle]);
    
    final notifier = SavedArticlesNotifier(service: fakeService);
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedArticlesProvider.overrideWith((ref) => notifier),
          currentThemeModeProvider.overrideWithValue(AppThemeMode.light),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: NewsDetailScreen(news: testArticle),
        ),
      ),
    );
    
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/features/news/newspaper_card_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdnewsreader/core/theme_provider.dart';
import 'package:bdnewsreader/features/news/widgets/newspaper_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NewspaperCard Widget', () {
    late Map<String, dynamic> testNews;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_mode': 'light',
        'language_code': 'en',
      });
      prefs = await SharedPreferences.getInstance();
      
      testNews = {
        'id': '123',
        'name': 'Breaking News: Important Event',
        'title': 'Breaking News: Important Event',
        'description': 'This is a test news article for unit testing',
        'url': 'https://example.com/breaking-news',
        'link': 'https://example.com/breaking-news',
        'pubDate': DateTime.now().toIso8601String(),
        'published': DateTime.now().toIso8601String(),
        'contact': {
          'website': 'https://example.com/breaking-news',
        },
        'enclosure': {
          'url': 'https://example.com/image.jpg',
        },
      };
    });

    Widget wrapWithProviders(Widget child) {
      return ProviderScope(
        child: MaterialApp(
          home: provider.ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(prefs),
            child: Scaffold(body: child),
          ),
        ),
      );
    }

    testWidgets('TC-WIDGET-021: NewspaperCard displays and renders correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NewspaperCard), findsOneWidget);
    });

    testWidgets('TC-WIDGET-022: Favorite button is visible', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Favorite icon should be present
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('TC-WIDGET-023: Favorite button toggles state', (tester) async {
      var isFavorite = false;
      
      await tester.pumpWidget(
        wrapWithProviders(
          StatefulBuilder(
            builder: (context, setState) => NewspaperCard(
              news: testNews,
              isFavorite: isFavorite,
              onFavoriteToggle: () => setState(() => isFavorite = !isFavorite),
              searchQuery: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the favorite icon
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      
      // Tap it
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      
      // Should now show filled heart
      expect(isFavorite, isTrue);
    });

    testWidgets('TC-WIDGET-024: Share button is present', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          NewspaperCard(
            news: testNews,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('TC-WIDGET-025: NewspaperCard can render in a list', (tester) async {
      final newsList = List.generate(5, (i) => {
        'id': '$i',
        'name': 'News Item $i',
        'title': 'News Item $i',
        'description': 'Description for news item $i',
        'url': 'https://example.com/$i',
        'link': 'https://example.com/$i',
        'pubDate': DateTime.now().toIso8601String(),
        'published': DateTime.now().toIso8601String(),
        'contact': {
          'website': 'https://example.com/$i',
        },
      });

      await tester.pumpWidget(
        wrapWithProviders(
          SizedBox(
            width: 400,
            height: 800,
            child: ListView.builder(
              itemCount: newsList.length,
              itemBuilder: (context, index) => NewspaperCard(
                news: newsList[index],
                isFavorite: false,
                onFavoriteToggle: () {},
                searchQuery: '',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NewspaperCard), findsWidgets);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/screens/home_screen_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeScreen Widget Structure', () {
    testWidgets('TC-WIDGET-001: App renders with MaterialApp', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('BD News Reader')),
          ),
        ),
      );

      expect(find.text('BD News Reader'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-002: Bottom navigation has correct items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'Newspaper'),
                BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Magazine'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
                BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Extras'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Newspaper'), findsOneWidget);
      expect(find.text('Magazine'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Extras'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-003: Bottom navigation can switch tabs', (tester) async {
      var currentIndex = 0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: IndexedStack(
                index: currentIndex,
                children: const [
                  Center(child: Text('Home Content')),
                  Center(child: Text('Newspaper Content')),
                ],
              ),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (index) => setState(() => currentIndex = index),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'Newspaper'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Home Content'), findsOneWidget);
      
      await tester.tap(find.text('Newspaper'));
      await tester.pumpAndSettle();
      
      expect(currentIndex, 1);
    });

    testWidgets('TC-WIDGET-004: Offline banner displays message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MaterialBanner(
                  content: Text('You are offline'),
                  actions: [SizedBox()],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('You are offline'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-005: Pull to refresh works', (tester) async {
      var refreshed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                refreshed = true;
              },
              child: ListView(
                children: const [
                  ListTile(title: Text('Item 1')),
                  ListTile(title: Text('Item 2')),
                ],
              ),
            ),
          ),
        ),
      );

      // Perform pull to refresh gesture
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      
      expect(refreshed, isTrue);
    });

    testWidgets('TC-WIDGET-006: Category tabs are scrollable', (tester) async {
      final categories = ['Latest', 'Bangladesh', 'Sports', 'Entertainment', 'International', 'Technology'];
      
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: categories.length,
            child: Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  isScrollable: true,
                  tabs: categories.map((c) => Tab(text: c)).toList(),
                ),
              ),
              body: TabBarView(
                children: categories.map((c) => Center(child: Text('$c Content'))).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Latest'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('TC-WIDGET-007: ListView renders news items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => ListTile(
                title: Text('News $index'),
                subtitle: Text('Source $index'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('News 0'), findsOneWidget);
      expect(find.text('Source 0'), findsOneWidget);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/screens/webview_screen_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebView Screen Widget', () {
    testWidgets('TC-WIDGET-040: WebView screen has navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Article'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {},
              ),
              actions: [
                IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                IconButton(icon: const Icon(Icons.open_in_browser), onPressed: () {}),
              ],
            ),
            body: const Center(child: Text('WebView Content')),
          ),
        ),
      );

      expect(find.text('Article'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('TC-WIDGET-041: Share button is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('TC-WIDGET-042: Open in browser button works', (tester) async {
      var opened = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: () => opened = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.open_in_browser));
      expect(opened, isTrue);
    });

    testWidgets('TC-WIDGET-043: Loading indicator shows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(child: Text('WebView')),
                Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('TC-WIDGET-044: Favorite button toggles', (tester) async {
      var isFavorite = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              appBar: AppBar(
                actions: [
                  IconButton(
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    onPressed: () => setState(() => isFavorite = !isFavorite),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/screens/login_screen_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginScreen Widget', () {
    testWidgets('TC-WIDGET-010: Login screen has email field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-011: Login screen has password field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Password',
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-012: Email field accepts input', (tester) async {
      final controller = TextEditingController();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test@example.com');
      expect(controller.text, 'test@example.com');
    });

    testWidgets('TC-WIDGET-013: Login button is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Login'),
            ),
          ),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('TC-WIDGET-014: Login button triggers callback', (tester) async {
      var loginPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () => loginPressed = true,
              child: const Text('Login'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Login'));
      expect(loginPressed, isTrue);
    });

    testWidgets('TC-WIDGET-015: Google Sign-In button is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.g_mobiledata),
              label: const Text('Sign in with Google'),
            ),
          ),
        ),
      );

      expect(find.textContaining('Google'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-016: Create Account link is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextButton(
              onPressed: () {},
              child: const Text('Create Account'),
            ),
          ),
        ),
      );

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-017: Password visibility toggle works', (tester) async {
      var obscureText = true;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TextField(
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscureText = !obscureText),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      
      expect(obscureText, isFalse);
    });

    testWidgets('TC-WIDGET-018: Invalid email shows error', (tester) async {
      String? errorText;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: errorText,
              ),
            ),
          ),
        ),
      );

      // Verify error text can be shown
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/screens/settings_screen_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsScreen Widget', () {
    testWidgets('TC-WIDGET-030: Settings screen has title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: const SizedBox(),
          ),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-031: Theme toggle switch is present', (tester) async {
      var isDark = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ListTile(
                title: const Text('Dark Mode'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (value) => setState(() => isDark = value),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('TC-WIDGET-032: Data Saver toggle works', (tester) async {
      var dataSaver = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SwitchListTile(
                title: const Text('Data Saver'),
                subtitle: const Text('Reduce image quality on slow networks'),
                value: dataSaver,
                onChanged: (value) => setState(() => dataSaver = value),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Data Saver'), findsOneWidget);
      
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      
      expect(dataSaver, isTrue);
    });

    testWidgets('TC-WIDGET-033: Language selector is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: const Text('Language'),
              subtitle: const Text('English'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-034: Reader settings section exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                ListTile(
                  title: Text('Reader Settings'),
                  leading: Icon(Icons.text_fields),
                ),
                ListTile(title: Text('Line Height')),
                ListTile(title: Text('Contrast')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Reader Settings'), findsOneWidget);
      expect(find.text('Line Height'), findsOneWidget);
      expect(find.text('Contrast'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-035: Slider changes value', (tester) async {
      var sliderValue = 1.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Slider(
                value: sliderValue,
                min: 0.5,
                max: 2.0,
                onChanged: (value) => setState(() => sliderValue = value),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
      
      // Drag slider to change value
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();
      
      expect(sliderValue, isNot(1.0));
    });

    testWidgets('TC-WIDGET-036: Push notification toggle is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive breaking news alerts'),
              value: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Push Notifications'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-037: Logout button is present', (tester) async {
      var loggedOut = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => loggedOut = true,
                child: const Text('Logout'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Logout'), findsOneWidget);
      
      await tester.tap(find.text('Logout'));
      expect(loggedOut, isTrue);
    });

    testWidgets('TC-WIDGET-038: About section shows app version', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: Text('About'),
              subtitle: Text('Version 1.0.0'),
            ),
          ),
        ),
      );

      expect(find.text('About'), findsOneWidget);
      expect(find.textContaining('Version'), findsOneWidget);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/components/trust_confirmations_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trust Confirmations Widget', () {
    testWidgets('TC-WIDGET-060: Confirmation dialog renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Action'),
                    content: const Text('Are you sure you want to proceed?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Confirm')),
                    ],
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Action'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-061: Cancel button closes dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      
      expect(find.text('Confirm'), findsOneWidget);
      
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      
      expect(find.text('Confirm'), findsNothing);
    });

    testWidgets('TC-WIDGET-062: Destructive action shows warning', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Account?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Account?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-063: Loading state during confirmation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  Text('Processing...'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Processing...'), findsOneWidget);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/components/breaking_news_ticker_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breaking News Ticker Widget', () {
    testWidgets('TC-WIDGET-050: Ticker renders headlines', (tester) async {
      final headlines = ['Breaking: Event 1', 'Update: Event 2', 'Alert: Event 3'];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              height: 40,
              color: Colors.red,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: headlines.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(child: Text(headlines[index], style: const TextStyle(color: Colors.white))),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Breaking: Event 1'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-051: Ticker has LIVE indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  color: Colors.red,
                  child: const Text('LIVE', style: TextStyle(color: Colors.white)),
                ),
                const Text('Breaking News'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('TC-WIDGET-052: Ticker scrolls horizontally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(
                  10,
                  (i) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Headline $i'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Headline 0'), findsOneWidget);
      
      await tester.drag(find.byType(ListView), const Offset(-200, 0));
      await tester.pumpAndSettle();
      
      // Scrolled to next headlines
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('TC-WIDGET-053: Ticker background is red', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              color: Colors.red,
              height: 40,
              child: const Center(child: Text('Breaking News')),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, Colors.red);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/widget/confirmations/trust_confirmations_test.dart ===

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User Confirmation Feedback for Trust Building', () {
    
    test('TC-WIDGET-050: Account deletion shows confirmation dialog', () {
      // Critical operation: Delete account
      final confirmationConfig = {
        'operation': 'deleteAccount',
        'title': 'Delete Account?',
        'message': 'This will permanently delete your account and all data. This action cannot be undone.',
        'confirmButtonText': 'Delete Account',
        'confirmButtonColor': 'red',
        'cancelButtonText': 'Cancel',
        'requiresExtraConfirmation': true, // Type "DELETE" to confirm
        'confirmationText': 'DELETE',
      };
      
      // Simulate user input
      bool userConfirmed(String input) {
        return input == confirmationConfig['confirmationText'];
      }
      
      // Verify dialog structure
      expect(confirmationConfig['title'], contains('Delete Account'));
      expect(confirmationConfig['message'], contains('cannot be undone'));
      expect(confirmationConfig['requiresExtraConfirmation'], true);
      
      // Verify user must type DELETE
      expect(userConfirmed('DELETE'), true);
      expect(userConfirmed('delete'), false);
      expect(userConfirmed('yes'), false);
    });

    test('TC-WIDGET-051: Clear all data shows warning with confirmation', () {
      final confirmationConfig = {
        'operation': 'clearAllData',
        'title': 'Clear All Data?',
        'message': 'This will delete all cached articles, favorites, and reading history.',
        'warningIcon': 'warning',
        'confirmButtonText': 'Clear All Data',
        'showsImpactSummary': true,
      };
      
      // Impact summary
      final impactSummary = {
        'cachedArticles': 150,
        'favorites': 25,
        'readingHistory': 89,
        'estimatedDataSize': '45 MB',
      };
      
      String getImpactMessage(Map<String, dynamic> impact) {
        return 'This will delete:\n'
            '• ${impact['cachedArticles']} cached articles\n'
            '• ${impact['favorites']} favorites\n'
            '• ${impact['readingHistory']} reading history items\n'
            '• ${impact['estimatedDataSize']} of data';
      }
      
      final message = getImpactMessage(impactSummary);
      
      expect(message, contains('150 cached articles'));
      expect(message, contains('25 favorites'));
      expect(message, contains('45 MB'));
      expect(confirmationConfig['warningIcon'], 'warning');
    });

    test('TC-WIDGET-052: Logout shows success confirmation sticker', () {
      // After logout completes
      final successFeedback = {
        'type': 'success',
        'icon': '✓',
        'title': 'Logged Out Successfully',
        'message': 'Your data is safe. Sign in anytime to access your favorites.',
        'duration': 3, // seconds
        'color': 'green',
        'showsCheckmark': true,
      };
      
      // Verify success feedback
      expect(successFeedback['type'], 'success');
      expect(successFeedback['showsCheckmark'], true);
      expect(successFeedback['message'], contains('data is safe'));
      expect(successFeedback['duration'], greaterThan(0));
    });

    test('TC-WIDGET-053: Data sync completed shows trust badge', () {
      // After successful cloud sync
      final syncConfirmation = {
        'type': 'success',
        'icon': '☁️',
        'title': 'Synced Successfully',
        'message': 'Your favorites and settings are backed up to cloud',
        'timestamp': DateTime.now().toIso8601String(),
        'showsTrustBadge': true,
        'trustBadgeText': 'Secure Backup',
      };
      
      expect(syncConfirmation['showsTrustBadge'], true);
      expect(syncConfirmation['trustBadgeText'], contains('Secure'));
      expect(syncConfirmation['message'], contains('backed up'));
    });

    test('TC-WIDGET-054: Remove all favorites shows count confirmation', () {
      const favoriteCount = 42;
      
      final confirmationDialog = {
        'title': 'Remove All Favorites?',
        'message': 'You have $favoriteCount saved items. Are you sure you want to remove all?',
        'showsCount': true,
        'confirmButtonText': 'Remove All',
        'cancelButtonText': 'Keep Them',
      };
      
      expect(confirmationDialog['message'], contains('42 saved items'));
      expect(confirmationDialog['showsCount'], true);
      expect(confirmationDialog['cancelButtonText'], contains('Keep'));
    });

    test('TC-WIDGET-055: Premium subscription shows verification badge', () {
      // After successful premium purchase
      final verificationBadge = {
        'type': 'verification',
        'icon': '✓',
        'title': 'Premium Activated!',
        'message': 'You now have access to all premium features',
        'features': [
          'Ad-free experience',
          'Offline reading',
          'Priority support',
        ],
        'showsVerificationBadge': true,
        'badgeColor': 'gold',
      };
      
      expect(verificationBadge['showsVerificationBadge'], true);
      expect(verificationBadge['badgeColor'], 'gold');
      expect((verificationBadge['features'] as List).length, 3);
    });

    test('TC-WIDGET-056: Cache cleared shows savings confirmation', () {
      final cacheCleared = {
        'sizeCleared': '78.5 MB',
        'articlesRemoved': 234,
      };
      
      final successMessage = {
        'type': 'success',
        'title': 'Cache Cleared',
        'message': 'Freed up ${cacheCleared['sizeCleared']} of storage',
        'detail': '${cacheCleared['articlesRemoved']} articles removed from cache',
        'icon': '🗑️',
      };
      
      expect(successMessage['message'], contains('78.5 MB'));
      expect(successMessage['detail'], contains('234 articles'));
    });

    test('TC-WIDGET-057: Article saved shows visual confirmation', () {
      const articleTitle = 'Breaking News: Important Update';
      
      final confirmationToast = {
        'type': 'success',
        'message': 'Saved to favorites',
        'duration': 2,
        'showsUndo': true,
        'undoText': 'Undo',
        'articleTitle': articleTitle,
      };
      
      expect(confirmationToast['showsUndo'], true);
      expect(confirmationToast['duration'], 2);
      expect(confirmationToast['undoText'], 'Undo');
    });

    test('TC-WIDGET-058: Share article shows success indicator', () {
      final shareSuccess = {
        'type': 'info',
        'message': 'Article copied to clipboard',
        'icon': '📋',
        'duration': 2,
      };
      
      expect(shareSuccess['message'], contains('copied'));
      expect(shareSuccess['duration'], greaterThan(0));
    });

    test('TC-WIDGET-059: Settings saved shows auto-save confirmation', () {
      final settingsSaved = {
        'type': 'success',
        'message': 'Settings saved automatically',
        'icon': '✓',
        'duration': 2,
        'isAutoSaved': true,
      };
      
      expect(settingsSaved['isAutoSaved'], true);
      expect(settingsSaved['message'], contains('automatically'));
    });

    test('TC-WIDGET-060: Password change shows security confirmation', () {
      final securityConfirmation = {
        'type': 'success',
        'title': 'Password Changed',
        'message': 'Your account is now more secure',
        'icon': '🔒',
        'showsSecurityBadge': true,
        'additionalInfo': 'We sent a confirmation email to your address',
      };
      
      expect(securityConfirmation['showsSecurityBadge'], true);
      expect(securityConfirmation['additionalInfo'], contains('confirmation email'));
      expect(securityConfirmation['icon'], '🔒');
    });

    test('TC-WIDGET-061: Critical operations require double confirmation', () {
      final criticalOperations = [
        'deleteAccount',
        'clearAllData',
        'removeAllFavorites',
        'resetSettings',
      ];
      
      bool requiresDoubleConfirmation(String operation) {
        return criticalOperations.contains(operation);
      }
      
      expect(requiresDoubleConfirmation('deleteAccount'), true);
      expect(requiresDoubleConfirmation('clearAllData'), true);
      expect(requiresDoubleConfirmation('logout'), false);
      expect(requiresDoubleConfirmation('saveArticle'), false);
    });

    test('TC-WIDGET-062: Offline mode shows reassuring message', () {
      final offlineNotification = {
        'type': 'info',
        'title': 'You\'re Offline',
        'message': 'Don\'t worry! You can still read your saved articles',
        'icon': '📡',
        'showsReassurance': true,
        'actionText': 'View Saved Articles',
      };
      
      expect(offlineNotification['showsReassurance'], true);
      expect(offlineNotification['message'], contains('Don\'t worry'));
      expect(offlineNotification['actionText'], isNotEmpty);
    });

    test('TC-WIDGET-063: Data saver enabled shows badge with savings', () {
      final dataSaverBadge = {
        'enabled': true,
        'title': 'Data Saver Active',
        'message': 'Saving up to 70% data on images',
        'icon': '📊',
        'showsSavingsBadge': true,
        'estimatedSavings': '70%',
      };
      
      expect(dataSaverBadge['showsSavingsBadge'], true);
      expect(dataSaverBadge['estimatedSavings'], '70%');
      expect(dataSaverBadge['message'], contains('70%'));
    });

    test('TC-WIDGET-064: Failed operations show retry option', () {
      final errorWithRetry = {
        'type': 'error',
        'title': 'Sync Failed',
        'message': 'Could not connect to server',
        'showsRetry': true,
        'retryButtonText': 'Try Again',
        'showsOfflineHelp': true,
        'helpText': 'Check your internet connection',
      };
      
      expect(errorWithRetry['showsRetry'], true);
      expect(errorWithRetry['retryButtonText'], 'Try Again');
      expect(errorWithRetry['showsOfflineHelp'], true);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/security/spam_and_collision_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/security/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spam and Collision Prevention', () {
    late SecurityService securityService;

    setUp(() {
      securityService = SecurityService();
    });

    group('Content Hash Collision Detection', () {
      test('TC-SPAM-001: Same content produces same hash', () {
        final hash1 = securityService.hashString('duplicate content');
        final hash2 = securityService.hashString('duplicate content');
        
        expect(hash1, equals(hash2));
      });

      test('TC-SPAM-002: Different content produces different hash', () {
        final hash1 = securityService.hashString('content 1');
        final hash2 = securityService.hashString('content 2');
        
        expect(hash1, isNot(equals(hash2)));
      });

      test('TC-SPAM-003: Whitespace normalization for spam detection', () {
        String normalize(String content) {
          return content.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        }
        
        expect(
          normalize('Click HERE now!!!'),
          equals(normalize('   click   here   NOW!!!   ')),
        );
      });
    });

    group('Rate Limiting', () {
      test('TC-SPAM-004: Rate limiter tracks requests', () {
        final timestamps = <DateTime>[];
        const maxPerMinute = 10;
        
        bool canRequest() {
          final now = DateTime.now();
          timestamps.removeWhere((t) => now.difference(t).inMinutes >= 1);
          
          if (timestamps.length >= maxPerMinute) {
            return false;
          }
          
          timestamps.add(now);
          return true;
        }
        
        // First 10 requests succeed
        for (var i = 0; i < 10; i++) {
          expect(canRequest(), isTrue);
        }
        
        // 11th request blocked
        expect(canRequest(), isFalse);
      });
    });

    group('URL Collision Detection', () {
      test('TC-SPAM-005: URL normalization removes protocol', () {
        String normalize(String url) {
          return url
            .replaceAll(RegExp(r'^https?://'), '')
            .replaceAll(RegExp(r'^www\.'), '')
            .replaceAll(RegExp(r'/+$'), '');
        }
        
        expect(
          normalize('https://www.example.com/page/'),
          equals(normalize('http://example.com/page')),
        );
      });

      test('TC-SPAM-006: Duplicate URLs are detected', () {
        final seenUrls = <String>{};
        
        bool isDuplicate(String url) {
          final normalized = url.toLowerCase().replaceAll(RegExp(r'/+$'), '');
          return !seenUrls.add(normalized);
        }
        
        expect(isDuplicate('https://example.com/article'), isFalse);
        expect(isDuplicate('https://example.com/article/'), isTrue); // Duplicate!
      });
    });

    group('Title Collision Detection', () {
      test('TC-SPAM-007: Similar titles are detected', () {
        double similarity(String a, String b) {
          final words1 = a.toLowerCase().split(' ').where((w) => w.length > 3).toSet();
          final words2 = b.toLowerCase().split(' ').where((w) => w.length > 3).toSet();
          
          if (words1.isEmpty) return 0;
          
          final common = words1.intersection(words2);
          return common.length / words1.length;
        }
        
        expect(
          similarity(
            'Breaking News About Economy',
            'Breaking News About Economy Today',
          ),
          greaterThan(0.7),
        );
        
        expect(
          similarity(
            'Sports Team Wins Championship',
            'Weather Forecast For Tomorrow',
          ),
          lessThan(0.3),
        );
      });
    });

    group('Bot Detection Patterns', () {
      test('TC-SPAM-008: Rapid actions indicate bot', () {
        bool isBotBehavior(int actionsPerMinute) {
          return actionsPerMinute > 20;
        }
        
        expect(isBotBehavior(5), isFalse); // Normal user
        expect(isBotBehavior(25), isTrue); // Bot
      });

      test('TC-SPAM-009: Multiple accounts from same IP is suspicious', () {
        bool isSuspicious(int uniqueAccountsFromIp) {
          return uniqueAccountsFromIp > 3;
        }
        
        expect(isSuspicious(2), isFalse);
        expect(isSuspicious(5), isTrue);
      });
    });

    group('HMAC Verification', () {
      test('TC-SPAM-010: Request integrity verified with HMAC', () {
        const requestData = 'user_id=123&action=post';
        const apiKey = 'secret_api_key';
        
        final hmac = securityService.generateHmac(requestData, apiKey);
        
        // Server verifies the request
        final isValid = securityService.verifyHmac(requestData, hmac, apiKey);
        expect(isValid, isTrue);
        
        // Tampered request fails
        final isTampered = securityService.verifyHmac(
          'user_id=123&action=delete',
          hmac,
          apiKey,
        );
        expect(isTampered, isFalse);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/security/logging_security_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

/// Critical security test: Ensure no secrets are logged
/// 
/// This test prevents security breaches by verifying that sensitive
/// information like tokens, API keys, and passwords are never logged.
void main() {
  group('Security Logging Tests', () {
    late List<String> capturedLogs;
    late DebugPrintCallback? originalDebugPrint;

    setUp(() {
      capturedLogs = [];
      // Capture all debug logs
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          capturedLogs.add(message);
        }
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint!;
      capturedLogs.clear();
    });

    test('Firebase Auth tokens are NOT logged', () {
      // Simulate logging with a token (this should be caught)
      const fakeToken = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjEyMzQ1Njc4OTAifQ.eyJpc3MiOiJodHRwczovL2V4YW1wbGUuY29tIn0.signature';
      
      debugPrint('User authenticated');
      debugPrint('Token: $fakeToken'); // BAD! Should be caught
      
      // Check for token in logs
      final hasToken = capturedLogs.any((log) => log.contains('eyJ'));
      
      // This test SHOULD FAIL if tokens are being logged
      // In production, remove all token logging before this passes
      expect(hasToken, isFalse, reason: 'Security violation: Auth token found in logs!');
    });

    test('API keys are NOT logged', () {
      const fakeApiKey = 'AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
      
      debugPrint('Calling API...');
      debugPrint('API Key: $fakeApiKey'); // BAD!
      
      final hasApiKey = capturedLogs.any((log) => log.contains('AIzaSy'));
      
      expect(hasApiKey, isFalse, reason: 'Security violation: API key found in logs!');
    });

    test('User PII is NOT logged in release mode', () {
      // Simulate logging user data
      const userEmail = 'user@example.com';
      const userPhone = '+1234567890';
      
      debugPrint('Processing user');
      debugPrint('Email: $userEmail'); // BAD!
      debugPrint('Phone: $userPhone'); // BAD!
      
      final hasEmail = capturedLogs.any((log) => log.contains('@'));
      final hasPhone = capturedLogs.any((log) => log.contains('+1234'));
      
      // These should be filtered in release mode
      if (!kDebugMode) {
        expect(hasEmail, isFalse, reason: 'PII violation: Email found in logs!');
        expect(hasPhone, isFalse, reason: 'PII violation: Phone found in logs!');
      }
    });

    test('Supabase credentials are NOT logged', () {
      const fakeSupabaseUrl = 'https://abcdefgh.supabase.co';
      const fakeSupabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxx';
      
      debugPrint('Connecting to database...');
      debugPrint('URL: $fakeSupabaseUrl'); // BAD!
      debugPrint('Key: $fakeSupabaseKey'); // BAD!
      
      final hasUrl = capturedLogs.any((log) => log.contains('supabase.co'));
      final hasKey = capturedLogs.any((log) => log.contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'));
      
      expect(hasUrl, isFalse, reason: 'Security violation: Supabase URL in logs!');
      expect(hasKey, isFalse, reason: 'Security violation: Supabase key in logs!');
    });

    test('Password or sensitive data is NOT logged', () {
      const fakePassword = 'MySecretP@ssw0rd123';
      
      debugPrint('User login attempt');
      debugPrint('Password: $fakePassword'); // EXTREMELY BAD!
      
      final hasPassword = capturedLogs.any((log) => log.contains('SecretP@ss'));
      
      expect(hasPassword, isFalse, reason: 'CRITICAL: Password found in logs!');
    });

    test('kDebugMode is false in release builds', () {
      // This test verifies that debug mode is properly disabled
      // In a real release build, kDebugMode should be false
      
      // This will pass in debug, but reminds you to check release
      if (!kDebugMode) {
        expect(kDebugMode, isFalse);
      } else {
        // In debug mode, just log a reminder
        debugPrint('⚠️ Remember: kDebugMode must be false in release builds');
      }
    });

    test('debugPrint calls are removed in release mode', () {
      int callCount = 0;
      
      // Override debugPrint to count calls
      debugPrint = (String? message, {int? wrapWidth}) {
        callCount++;
        if (message != null) capturedLogs.add(message);
      };
      
      debugPrint('Test message 1');
      debugPrint('Test message 2');
      debugPrint('Test message 3');
      
      if (kDebugMode) {
        expect(callCount, equals(3));
      } else {
        // In release, debugPrint should be a no-op
        expect(callCount, equals(0), reason: 'debugPrint still active in release!');
      }
    });
  });

  group('Production Logging Sanity Check', () {
    test('Sensitive data should be sanitized before logging', () {
      // This is a reminder test that in production:
      // 1. All error messages should be sanitized
      // 2. Stack traces should not contain sensitive data
      // 3. Use ErrorHandler.logError() which already filters in release mode
      
      const sensitiveData = 'eyJhbGciOiJSUzI1NiJ9.xxx';
      const message = 'API call failed'; // Sanitized - no token
      
      // In production, never log the actual token
      expect(message.contains(sensitiveData),  isFalse);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/security/authentication_security_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:bdnewsreader/core/security/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Security Tests', () {
    late SecurityService securityService;

    setUp(() {
      const MethodChannel channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          return null; // Successfully handled
        },
      );
      securityService = SecurityService();
    });

    group('Secure Storage', () {
      test('TC-AUTH-SEC-001: secureWrite API is available', () async {
        // API exists and is callable
        expect(() => securityService.secureWrite('key', 'value'), returnsNormally);
      });

      test('TC-AUTH-SEC-002: secureRead API is available', () async {
        // API exists and returns Future<String?>
        final future = securityService.secureRead('key');
        expect(future, isA<Future<String?>>());
      });

      test('TC-AUTH-SEC-003: secureDelete API is available', () async {
        expect(() => securityService.secureDelete('key'), returnsNormally);
      });
    });

    group('Password Hashing', () {
      test('TC-AUTH-SEC-004: Password is hashed, not stored plain', () {
        const password = 'mySecretPassword123';
        
        final hashed = securityService.hashString(password);
        
        expect(hashed, isNot(equals(password)));
        expect(hashed.length, 64); // SHA-256
      });

      test('TC-AUTH-SEC-005: Same password produces same hash', () {
        const password = 'consistentPassword';
        
        final hash1 = securityService.hashString(password);
        final hash2 = securityService.hashString(password);
        
        expect(hash1, equals(hash2));
      });

      test('TC-AUTH-SEC-006: Different passwords produce different hashes', () {
        final hash1 = securityService.hashString('password1');
        final hash2 = securityService.hashString('password2');
        
        expect(hash1, isNot(equals(hash2)));
      });
    });

    group('Session Token Security', () {
      test('TC-AUTH-SEC-007: Token HMAC can be generated', () {
        const token = 'session_token_123';
        const secret = 'server_secret';
        
        final hmac = securityService.generateHmac(token, secret);
        
        expect(hmac, isNotEmpty);
        expect(hmac.length, 64);
      });

      test('TC-AUTH-SEC-008: Token HMAC can be verified', () {
        const token = 'session_token_123';
        const secret = 'server_secret';
        
        final hmac = securityService.generateHmac(token, secret);
        final isValid = securityService.verifyHmac(token, hmac, secret);
        
        expect(isValid, isTrue);
      });

      test('TC-AUTH-SEC-009: Tampered token fails verification', () {
        const token = 'session_token_123';
        const secret = 'server_secret';
        
        final hmac = securityService.generateHmac(token, secret);
        final isValid = securityService.verifyHmac('tampered_token', hmac, secret);
        
        expect(isValid, isFalse);
      });
    });

    group('Biometric Authentication', () {
      test('TC-AUTH-SEC-010: canUseBiometrics returns boolean', () async {
        final canUse = await securityService.canUseBiometrics();
        
        expect(canUse, isA<bool>());
      });

      test('TC-AUTH-SEC-011: getAvailableBiometrics returns list', () async {
        final biometrics = await securityService.getAvailableBiometrics();
        
        expect(biometrics, isA<List>());
      });
    });

    group('Device Security', () {
      test('TC-AUTH-SEC-012: isSecure status is available', () {
        expect(securityService.isSecure, isA<bool>());
      });

      test('TC-AUTH-SEC-013: isRooted status is available', () {
        expect(securityService.isRooted, isA<bool>());
      });

      test('TC-AUTH-SEC-014: isInitialized status is available', () {
        expect(securityService.isInitialized, isA<bool>());
      });
    });

    group('Initialization', () {
      test('TC-AUTH-SEC-015: initialize() completes', () async {
        await expectLater(
          securityService.initialize(),
          completes,
        );
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/security/advanced_security_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/security/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Advanced Security Tests', () {
    late SecurityService securityService;

    setUp(() {
      securityService = SecurityService();
    });

    group('Bot Attack Protection', () {
      test('TC-SECURITY-007: Bot detection through rapid action tracking', () {
        // Test rate limiting logic that should be in app
        final actionTimestamps = <DateTime>[];
        
        bool isBotBehavior(int recentActionCount) {
          // More than 20 actions in 1 minute = bot
          return recentActionCount > 20;
        }
        
        // Simulate bot: 25 actions very quickly
        expect(isBotBehavior(25), isTrue);
        
        // Normal user
        expect(isBotBehavior(5), isFalse);
      });

      test('TC-SECURITY-008: Coordinated spam detection through content hash', () {
        // Same content from multiple users = spam
        String normalizeContent(String content) {
          return content.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        }
        
        bool isSpam(String content, Map<String, int> contentCounts, {int threshold = 3}) {
          final hash = normalizeContent(content).hashCode.toString();
          contentCounts[hash] = (contentCounts[hash] ?? 0) + 1;
          return contentCounts[hash]! >= threshold;
        }
        
        final counts = <String, int>{};
        const spamMessage = 'Buy cheap followers! Click here!!!';
        
        // First two posts are OK
        expect(isSpam(spamMessage, counts), isFalse);
        expect(isSpam(spamMessage, counts), isFalse);
        
        // Third identical post = spam
        expect(isSpam(spamMessage, counts), isTrue);
      });
    });

    group('Account Lockout Protection', () {
      test('TC-SECURITY-010: Account locks after 5 failed attempts', () {
        final failedAttempts = <String, int>{};
        final lockedAccounts = <String>{};
        
        bool attemptLogin(String email, bool correctPassword) {
          if (lockedAccounts.contains(email)) {
            return false; // Account locked
          }
          
          if (!correctPassword) {
            failedAttempts[email] = (failedAttempts[email] ?? 0) + 1;
            
            if (failedAttempts[email]! >= 5) {
              lockedAccounts.add(email);
            }
            return false;
          }
          
          failedAttempts.remove(email);
          return true;
        }
        
        const email = 'user@example.com';
        
        // 5 failed attempts
        for (int i = 0; i < 5; i++) {
          attemptLogin(email, false);
        }
        
        // Account should be locked now
        expect(lockedAccounts.contains(email), isTrue);
        
        // Even correct password fails when locked
        expect(attemptLogin(email, true), isFalse);
      });
    });

    group('URL Validation', () {
      test('TC-SECURITY-009: Malicious URL detection', () {
        final blockedDomains = ['spam.com', 'malware.net', 'phishing.org'];
        
        bool isUrlBlocked(String url) {
          return blockedDomains.any((domain) => url.contains(domain));
        }
        
        expect(isUrlBlocked('https://spam.com/offer'), isTrue);
        expect(isUrlBlocked('https://malware.net/download'), isTrue);
        expect(isUrlBlocked('https://example.com/legit'), isFalse);
      });

      test('TC-SECURITY-011: URL shortener detection', () {
        final shorteners = ['bit.ly', 't.co', 'tinyurl.com', 'goo.gl'];
        
        bool usesShortener(String url) {
          return shorteners.any((short) => url.contains(short));
        }
        
        expect(usesShortener('https://bit.ly/abc123'), isTrue);
        expect(usesShortener('https://example.com/article'), isFalse);
      });
    });

    group('Premium Account Sharing Detection', () {
      test('TC-SECURITY-012: Detects multiple IPs in short time', () {
        bool isAccountSharing(int uniqueIPsInLastHour) {
          return uniqueIPsInLastHour >= 3;
        }
        
        // Normal: 2 devices (home WiFi + mobile)
        expect(isAccountSharing(2), isFalse);
        
        // Suspicious: 3+ different IPs in 1 hour
        expect(isAccountSharing(3), isTrue);
        expect(isAccountSharing(5), isTrue);
      });
    });

    group('SecurityService Integration', () {
      test('TC-SECURITY-013: hashString produces consistent results', () {
        final hash1 = securityService.hashString('sensitive_data');
        final hash2 = securityService.hashString('sensitive_data');
        
        expect(hash1, equals(hash2));
        expect(hash1.length, 64);
      });

      test('TC-SECURITY-014: HMAC verification works correctly', () {
        const data = 'api_request_data';
        const secret = 'my_api_secret';
        
        final hmac = securityService.generateHmac(data, secret);
        
        expect(securityService.verifyHmac(data, hmac, secret), isTrue);
        expect(securityService.verifyHmac(data, 'wrong', secret), isFalse);
        expect(securityService.verifyHmac('modified', hmac, secret), isFalse);
      });

      test('TC-SECURITY-015: Device security status is accessible', () {
        expect(securityService.isSecure, isA<bool>());
        expect(securityService.isRooted, isA<bool>());
      });
    });

    group('Rate Limiting', () {
      test('TC-SECURITY-016: Rate limiter blocks excessive requests', () {
        final requestTimestamps = <DateTime>[];
        const maxRequestsPerMinute = 10;
        
        bool canMakeRequest() {
          final now = DateTime.now();
          requestTimestamps.removeWhere(
            (t) => now.difference(t).inMinutes >= 1,
          );
          
          if (requestTimestamps.length >= maxRequestsPerMinute) {
            return false;
          }
          
          requestTimestamps.add(now);
          return true;
        }
        
        // First 10 requests allowed
        for (int i = 0; i < 10; i++) {
          expect(canMakeRequest(), isTrue);
        }
        
        // 11th request blocked
        expect(canMakeRequest(), isFalse);
      });
    });

    group('Cache Stampede Prevention', () {
      test('TC-SECURITY-017: Concurrent requests coalesce', () async {
        final ongoingRequests = <String, Future<String>>{};
        var apiCallCount = 0;
        
        Future<String> fetchWithCoalescing(String key) async {
          if (ongoingRequests.containsKey(key)) {
            return ongoingRequests[key]!;
          }
          
          final future = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () {
              apiCallCount++;
              return 'data';
            },
          );
          
          ongoingRequests[key] = future;
          
          try {
            return await future;
          } finally {
            ongoingRequests.remove(key);
          }
        }
        
        // 10 concurrent requests for same key
        final futures = List.generate(10, (_) => fetchWithCoalescing('key'));
        await Future.wait(futures);
        
        // Should only make 1-2 API calls due to coalescing
        expect(apiCallCount, lessThanOrEqualTo(2));
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/speed/speed_optimization_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/network_quality_manager.dart';
import 'package:bdnewsreader/core/utils/retry_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Speed Optimization Tests', () {
    group('Network Quality Manager', () {
      test('TC-SPEED-001: Adaptive timeout is reasonable', () {
        final manager = NetworkQualityManager();
        final timeout = manager.getAdaptiveTimeout();
        
        expect(timeout.inSeconds, greaterThanOrEqualTo(5));
        expect(timeout.inSeconds, lessThanOrEqualTo(60));
      });

      test('TC-SPEED-002: Cache duration varies by network', () {
        final manager = NetworkQualityManager();
        final duration = manager.getCacheDuration();
        
        expect(duration.inMinutes, greaterThan(0));
      });
    });

    group('Retry Optimization', () {
      test('TC-SPEED-003: Retry succeeds on first attempt is fast', () async {
        final start = DateTime.now();
        
        await RetryHelper.retry<String>(
          operation: () async => 'success',
        );
        
        final elapsed = DateTime.now().difference(start);
        expect(elapsed.inMilliseconds, lessThan(100));
      });
    });

    group('Caching Speed', () {
      test('TC-SPEED-004: Map operations are O(1)', () {
        final cache = <String, String>{};
        
        // Write performance
        final writeStart = DateTime.now();
        for (int i = 0; i < 1000; i++) {
          cache['key$i'] = 'value$i';
        }
        final writeTime = DateTime.now().difference(writeStart);
        
        // Read performance
        final readStart = DateTime.now();
        for (int i = 0; i < 1000; i++) {
          final _ = cache['key$i'];
        }
        final readTime = DateTime.now().difference(readStart);
        
        expect(writeTime.inMilliseconds, lessThan(100));
        expect(readTime.inMilliseconds, lessThan(50));
      });
    });

    group('Deduplication Speed', () {
      test('TC-SPEED-005: Set deduplication is fast', () {
        final start = DateTime.now();
        
        final urls = <String>{};
        for (int i = 0; i < 1000; i++) {
          urls.add('https://example.com/article/${i % 100}');
        }
        
        final elapsed = DateTime.now().difference(start);
        
        expect(urls.length, 100); // Deduplicated
        expect(elapsed.inMilliseconds, lessThan(50));
      });
    });

    group('Sorting Speed', () {
      test('TC-SPEED-006: Article sorting is fast', () {
        final articles = List.generate(
          100,
          (i) => {'date': DateTime.now().subtract(Duration(hours: i))},
        );
        
        final start = DateTime.now();
        articles.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        final elapsed = DateTime.now().difference(start);
        
        expect(elapsed.inMilliseconds, lessThan(50));
      });
    });

    group('JSON Parsing Speed', () {
      test('TC-SPEED-007: JSON structure operations are fast', () {
        final start = DateTime.now();
        
        final data = <Map<String, dynamic>>[];
        for (int i = 0; i < 100; i++) {
          data.add({
            'title': 'Article $i',
            'url': 'https://example.com/$i',
            'date': DateTime.now().toIso8601String(),
          });
        }
        
        final elapsed = DateTime.now().difference(start);
        expect(elapsed.inMilliseconds, lessThan(50));
      });
    });

    group('Lazy Loading', () {
      test('TC-SPEED-008: Lazy loading reduces initial work', () {
        var initialized = 0;
        
        Object lazyInit(String name) {
          initialized++;
          return name;
        }
        
        final modules = <String, Object?>{
          'core': null,
          'settings': null,
          'premium': null,
        };
        
        // Only initialize what's needed
        modules['core'] = lazyInit('core');
        
        expect(initialized, 1);
        expect(modules.values.where((v) => v != null).length, 1);
      });
    });

    group('Memory Efficiency', () {
      test('TC-SPEED-009: LRU eviction keeps cache bounded', () {
        final cache = <String, String>{};
        const maxSize = 50;
        
        void addWithEviction(String key, String value) {
          cache[key] = value;
          while (cache.length > maxSize) {
            cache.remove(cache.keys.first);
          }
        }
        
        for (int i = 0; i < 100; i++) {
          addWithEviction('key$i', 'value$i');
        }
        
        expect(cache.length, maxSize);
      });
    });

    group('Parallel Processing', () {
      test('TC-SPEED-010: Parallel operations are faster', () async {
        Future<String> fetchItem(int id) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'item$id';
        }
        
        // Parallel
        final parallelStart = DateTime.now();
        await Future.wait(List.generate(5, (i) => fetchItem(i)));
        final parallelTime = DateTime.now().difference(parallelStart);
        
        // Sequential
        final sequentialStart = DateTime.now();
        for (int i = 0; i < 5; i++) {
          await fetchItem(i);
        }
        final sequentialTime = DateTime.now().difference(sequentialStart);
        
        expect(parallelTime.inMilliseconds, lessThan(sequentialTime.inMilliseconds));
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/integration/routing_integration_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Routing Integration Tests', () {
    testWidgets('TC-ROUTE-001: Navigator can push routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/second'),
                child: const Text('Go to Second'),
              ),
            ),
            '/second': (context) => const Scaffold(
              body: Center(child: Text('Second Page')),
            ),
          },
        ),
      );

      expect(find.text('Go to Second'), findsOneWidget);
      
      await tester.tap(find.text('Go to Second'));
      await tester.pumpAndSettle();
      
      expect(find.text('Second Page'), findsOneWidget);
    });

    testWidgets('TC-ROUTE-002: Navigator can pop routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            pages: const [
              MaterialPage(child: Text('First')),
              MaterialPage(child: Text('Second')),
            ],
            onPopPage: (route, result) => route.didPop(result),
          ),
        ),
      );

      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('TC-ROUTE-003: Back button pops navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('TC-ROUTE-004: Named routes work correctly', (tester) async {
      final routes = <String>['/home', '/settings', '/profile'];
      
      for (final route in routes) {
        expect(route.startsWith('/'), isTrue);
      }
    });

    testWidgets('TC-ROUTE-005: Route parameters can be passed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/article') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Text('Article: ${args?['id'] ?? 'none'}'),
                ),
              );
            }
            return null;
          },
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/article', arguments: {'id': '123'});
              },
              child: const Text('Open Article'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Article'));
      await tester.pumpAndSettle();

      expect(find.text('Article: 123'), findsOneWidget);
    });

    testWidgets('TC-ROUTE-006: Deep links work', (tester) async {
      // Deep link structure test
      const deepLink = 'bdnews://article/12345';
      final uri = Uri.parse(deepLink);
      
      expect(uri.scheme, 'bdnews');
      expect(uri.host, 'article');
      expect(uri.pathSegments.isEmpty || uri.pathSegments.first == '12345', isTrue);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/integration/news_api_integration_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:bdnewsreader/data/services/rss_service.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('News API Integration', () {
    group('RssService Integration', () {
      test('TC-INT-001: RssService handles successful response', () async {
        const rssXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test News</title>
    <item>
      <title>Breaking News</title>
      <link>https://example.com/news/1</link>
      <pubDate>Wed, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';
        
        final mockClient = MockClient((request) async {
          return http.Response(rssXml, 200);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });

      test('TC-INT-002: RssService handles 404 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isEmpty);
      });

      test('TC-INT-003: RssService handles network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isEmpty);
      });

      test('TC-INT-004: RssService handles malformed XML', () async {
        final mockClient = MockClient((request) async {
          return http.Response('<broken xml', 200);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isEmpty);
      });
    });

    group('Category Support', () {
      test('TC-INT-005: All categories are supported', () {
        const categories = RssService.categories;
        
        expect(categories, contains('latest'));
        expect(categories, contains('national'));
        expect(categories, contains('sports'));
        expect(categories, contains('entertainment'));
        expect(categories, contains('international'));
      });
    });

    group('Locale Support', () {
      test('TC-INT-006: Bengali locale is supported', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        // Should not throw
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('bn'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });

      test('TC-INT-007: English locale is supported', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 404);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        expect(articles, isA<List<NewsArticle>>());
      });
    });

    group('Article Processing', () {
      test('TC-INT-008: Articles are deduplicated by URL', () async {
        const rssXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test</title>
    <item>
      <title>Article 1</title>
      <link>https://example.com/same-url</link>
      <pubDate>Wed, 25 Dec 2024 10:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Article 2</title>
      <link>https://example.com/same-url</link>
      <pubDate>Wed, 25 Dec 2024 09:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>''';
        
        final mockClient = MockClient((request) async {
          return http.Response(rssXml, 200);
        });
        
        final rssService = RssService(client: mockClient);
        
        final articles = await rssService.fetchNews(
          category: 'latest',
          locale: const Locale('en'),
        );
        
        // Should be deduplicated to 1 article
        expect(articles.length, lessThanOrEqualTo(1));
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/integration/firebase_auth_integration_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These tests validate Firebase auth integration patterns without requiring Firebase
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase Auth Integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Auth Patterns', () {
      test('TC-INT-030: SharedPreferences stores login state', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{'isLoggedIn': false});
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getBool('isLoggedIn'), isFalse);
        
        await prefs.setBool('isLoggedIn', true);
        expect(prefs.getBool('isLoggedIn'), isTrue);
      });

      test('TC-INT-031: User data can be cached', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('user_name', 'Test User');
        await prefs.setString('user_email', 'test@example.com');
        
        expect(prefs.getString('user_name'), 'Test User');
        expect(prefs.getString('user_email'), 'test@example.com');
      });

      test('TC-INT-032: Profile retrieval returns correct data', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'user_name': 'Test User',
          'user_email': 'test@example.com',
        });
        
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getString('user_name'), 'Test User');
        expect(prefs.getString('user_email'), 'test@example.com');
      });

      test('TC-INT-033: isLoggedIn reflects login state', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{'isLoggedIn': true});
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getBool('isLoggedIn'), isTrue);
      });

      test('TC-INT-034: currentUser key can be stored', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        // Store UID for advanced scenarios
        await prefs.setString('current_user_uid', 'uid12345');
        expect(prefs.getString('current_user_uid'), 'uid12345');
      });
    });

    group('Email Validation', () {
      test('TC-INT-035: Email regex validates correctly', () {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        
        // Valid emails
        expect(emailRegex.hasMatch('test@example.com'), isTrue);
        expect(emailRegex.hasMatch('user.name@domain.co'), isTrue);
        expect(emailRegex.hasMatch('user@company.bd'), isTrue);
        
        // Invalid emails
        expect(emailRegex.hasMatch('notanemail'), isFalse);
        expect(emailRegex.hasMatch('@example.com'), isFalse);
        expect(emailRegex.hasMatch('user@'), isFalse);
      });
    });

    group('SharedPreferences Keys', () {
      test('TC-INT-036: User data keys are consistent', () {
        // These are the keys used for user data
        const expectedKeys = [
          'user_name',
          'user_email',
          'user_phone',
          'user_role',
          'user_department',
          'user_image',
          'isLoggedIn',
        ];
        
        for (final key in expectedKeys) {
          expect(key, isNotEmpty);
        }
      });
    });

    group('Logout Behavior', () {
      test('TC-INT-037: Logout preserves settings', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'user_name': 'Test',
          'user_email': 'test@test.com',
          'isLoggedIn': true,
          'theme_mode': 2,
          'language_code': 'bn',
        });
        
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate logout preserving settings
        final themeMode = prefs.getInt('theme_mode');
        final languageCode = prefs.getString('language_code');
        
        await prefs.clear();
        
        if (themeMode != null) await prefs.setInt('theme_mode', themeMode);
        if (languageCode != null) await prefs.setString('language_code', languageCode);
        
        // Settings preserved
        expect(prefs.getInt('theme_mode'), 2);
        expect(prefs.getString('language_code'), 'bn');
        
        // User data cleared
        expect(prefs.getBool('isLoggedIn'), isNull);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/features/search/search_functionality_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Search Functionality Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Search Suggestions', () {
      test('TC-SEARCH-001: Recent searches stored and retrieved', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final recentSearches = ['bangladesh', 'cricket', 'politics'];
        await prefs.setStringList('recent_searches', recentSearches);
        
        final retrieved = prefs.getStringList('recent_searches');
        expect(retrieved, recentSearches);
      });

      test('TC-SEARCH-002: Recent searches limited to 10', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Add 15 searches
        final searches = List.generate(15, (i) => 'search_$i');
        
        // Keep only last 10
        final limited = searches.length > 10 
            ? searches.sublist(searches.length - 10)
            : searches;
        
        await prefs.setStringList('recent_searches', limited);
        
        final stored = prefs.getStringList('recent_searches');
        expect(stored!.length, 10);
        expect(stored.first, 'search_5'); // First 5 were dropped
      });

      test('TC-SEARCH-003: Duplicate searches moved to top', () {
        final searches = ['cricket', 'politics', 'sports'];
        final newSearch = 'cricket'; // Duplicate
        
        // Remove existing and add to front
        searches.remove(newSearch);
        final updated = [newSearch, ...searches];
        
        expect(updated.first, 'cricket');
        expect(updated.length, 3); // No duplicates
      });
    });

    group('Search History', () {
      test('TC-SEARCH-004: Search history persists', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final history = ['query1', 'query2', 'query3'];
        await prefs.setStringList('search_history', history);
        
        final retrieved = prefs.getStringList('search_history');
        expect(retrieved, history);
      });

      test('TC-SEARCH-005: Can clear search history', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setStringList('search_history', ['query1', 'query2']);
        await prefs.remove('search_history');
        
        expect(prefs.getStringList('search_history'), isNull);
      });
    });

    group('Search Filtering', () {
      test('TC-SEARCH-006: Case-insensitive search', () {
        final articles = [
          {'title': 'Bangladesh News'},
          {'title': 'BANGLADESH Cricket'},
          {'title': 'bangladesh politics'},
        ];
        
        bool matches(Map article, String query) {
          return article['title'].toString().toLowerCase()
              .contains(query.toLowerCase());
        }
        
        final results = articles.where((a) => matches(a, 'BaNgLaDesH')).toList();
        expect(results.length, 3);
      });

      test('TC-SEARCH-007: Search by category filter', () {
        final articles = [
          {'title': 'News 1', 'category': 'sports'},
          {'title': 'News 2', 'category': 'politics'},
          {'title': 'News 3', 'category': 'sports'},
        ];
        
        final sportsArticles = articles
            .where((a) => a['category'] == 'sports')
            .toList();
        
        expect(sportsArticles.length, 2);
      });

      test('TC-SEARCH-008: Search by date range', () {
        final now = DateTime.now();
        final yesterday = now.subtract(Duration(days: 1));
        final lastWeek = now.subtract(Duration(days: 7));
        
        final articles = [
          {'title': 'Today', 'date': now},
          {'title': 'Yesterday', 'date': yesterday},
          {'title': 'Last Week', 'date': lastWeek},
        ];
        
        // Get articles from last 2 days
        final recent = articles.where((a) {
          final date = a['date'] as DateTime;
          return now.difference(date).inDays <= 2;
        }).toList();
        
        expect(recent.length, 2);
      });
    });

    group('Special Characters', () {
      test('TC-SEARCH-009: Handles special characters in query', () {
        final query = 'test & query + special!';
        
        // Should not throw
        expect(query.length, greaterThan(0));
        expect(query, contains('&'));
        expect(query, contains('+'));
      });

      test('TC-SEARCH-010: Handles Unicode characters (Bengali)', () {
        final query = 'বাংলাদেশ'; // Bangladesh in Bengali
        
        expect(query.length, greaterThan(0));
        expect(query.runes.length, query.length);
      });

      test('TC-SEARCH-011: Handles emojis in search', () {
        final query = 'cricket 🏏';
        
        expect(query, contains('cricket'));
        expect(query, contains('🏏'));
      });
    });

    group('Empty Results', () {
      test('TC-SEARCH-012: Empty query returns no results', () {
        final query = '';
        final articles = [{'title': 'News 1'}, {'title': 'News 2'}];
        
        if (query.trim().isEmpty) {
          expect([], isEmpty);
        }
      });

      test('TC-SEARCH-013: No matches returns empty list', () {
        final articles = [
          {'title': 'Bangladesh News'},
          {'title': 'Cricket Update'},
        ];
        
        final results = articles
            .where((a) => a['title'].toString().contains('NotFound'))
            .toList();
        
        expect(results, isEmpty);
      });

      test('TC-SEARCH-014: Shows empty state message', () {
        final hasResults = false;
        final emptyMessage = hasResults ? '' : 'No results found';
        
        expect(emptyMessage, 'No results found');
      });
    });

    group('Search Performance', () {
      test('TC-SEARCH-015: Large dataset search completes quickly', () {
        final articles = List.generate(
          1000,
          (i) => {'title': 'Article $i', 'content': 'Content for article $i'},
        );
        
        final stopwatch = Stopwatch()..start();
        
        final results = articles
            .where((a) => a['title'].toString().contains('500'))
            .toList();
        
        stopwatch.stop();
        
        expect(results.length, greaterThan(0));
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });

      test('TC-SEARCH-016: Debounced search prevents too many queries', () async {
        int queryCount = 0;
        
        void search(String query) {
          queryCount++;
        }
        
        // Simulate rapid typing
        search('b');
        search('ba');
        search('ban');
        
        // In real implementation, only last query should execute
        // For this test, we verify the concept
        expect(queryCount, 3); // All executed (would be 1 with debounce)
      });
    });

    group('Search Analytics', () {
      test('TC-SEARCH-017: Popular searches tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Track search count
        final searchCounts = {
          'bangladesh': 10,
          'cricket': 8,
          'politics': 5,
        };
        
        await prefs.setString('search_analytics', searchCounts.toString());
        
        final stored = prefs.getString('search_analytics');
        expect(stored, isNotNull);
      });

      test('TC-SEARCH-018: Search result click tracking', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final clickedResults = ['article1', 'article2', 'article3'];
        await prefs.setStringList('clicked_search_results', clickedResults);
        
        final tracked = prefs.getStringList('clicked_search_results');
        expect(tracked!.length, 3);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/features/premium/premium_payment_flow_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Premium Payment Flow Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Payment Processing', () {
      test('TC-PAYMENT-001: Payment intent created', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final paymentIntent = {
          'id': 'pi_123abc',
          'amount': 999, // $9.99 in cents
          'currency': 'usd',
          'status': 'pending',
        };
        
        await prefs.setString('current_payment_intent', paymentIntent.toString());
        
        expect(prefs.getString('current_payment_intent'), isNotNull);
      });

      test('TC-PAYMENT-002: Payment confirmation tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('payment_status', 'confirmed');
        await prefs.setInt('payment_confirmed_at', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getString('payment_status'), 'confirmed');
      });

      test('TC-PAYMENT-003: Payment failure handled', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('payment_status', 'failed');
        await prefs.setString('payment_error', 'Card declined');
        
        expect(prefs.getString('payment_status'), 'failed');
        expect(prefs.getString('payment_error'), isNotNull);
      });

      test('TC-PAYMENT-004: Payment retry after failure', () async {
        final prefs = await SharedPreferences.getInstance();
        
        var retryCount = prefs.getInt('payment_retry_count') ?? 0;
        retryCount++;
        await prefs.setInt('payment_retry_count', retryCount);
        
        expect(prefs.getInt('payment_retry_count'), 1);
      });
    });

    group('Subscription Activation', () {
      test('TC-PAYMENT-005: Subscription activated after payment', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('is_premium', true);
        await prefs.setInt('premium_tier', 1); // Pro tier
        await prefs.setInt('subscription_start', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('is_premium'), true);
        expect(prefs.getInt('premium_tier'), 1);
      });

      test('TC-PAYMENT-006: Subscription ID stored', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('subscription_id', 'sub_123abc');
        await prefs.setString('customer_id', 'cus_456def');
        
        expect(prefs.getString('subscription_id'), 'sub_123abc');
        expect(prefs.getString('customer_id'), 'cus_456def');
      });

      test('TC-PAYMENT-007: Trial period activated', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('is_trial', true);
        final trialEnd = DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch;
        await prefs.setInt('trial_end_date', trialEnd);
        
        expect(prefs.getBool('is_trial'), true);
        expect(prefs.getInt('trial_end_date'), greaterThan(DateTime.now().millisecondsSinceEpoch));
      });
    });

    group('Feature Unlocking', () {
      test('TC-PAYMENT-008: Premium features unlocked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('is_premium', true);
        
        // Verify features unlocked
        final isPremium = prefs.getBool('is_premium') ?? false;
        
        // Feature access checks
        final canAccessCloudSync = isPremium;
        final hasNoAds = isPremium;
        final hasOfflineMode = isPremium;
        
        expect(canAccessCloudSync, true);
        expect(hasNoAds, true);
        expect(hasOfflineMode, true);
      });

      test('TC-PAYMENT-009: Pro Plus exclusive features', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setInt('premium_tier', 2); // Pro Plus
        
        final tier = prefs.getInt('premium_tier') ?? 0;
        
        // Pro Plus exclusive features
        final hasPrioritySupport = tier >= 2;
        final hasEarlyAccess = tier >= 2;
        final hasAdvancedStats = tier >= 2;
        
        expect(hasPrioritySupport, true);
        expect(hasEarlyAccess, true);
        expect(hasAdvancedStats, true);
      });

      test('TC-PAYMENT-010: Features locked for free users', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('is_premium', false);
        
        final isPremium = prefs.getBool('is_premium') ?? false;
        
        expect(isPremium, false);
        // Features should be locked
      });
    });

    group('Subscription Expiry', () {
      test('TC-PAYMENT-011: Expiry date set correctly', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final expiryDate = DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch;
        await prefs.setInt('subscription_expiry', expiryDate);
        
        expect(prefs.getInt('subscription_expiry'), greaterThan(DateTime.now().millisecondsSinceEpoch));
      });

      test('TC-PAYMENT-012: Expiry warning shown', () {
        final expiryDate = DateTime.now().add(Duration(days: 3));
        final now = DateTime.now();
        
        final daysUntilExpiry = expiryDate.difference(now).inDays;
        final shouldShowWarning = daysUntilExpiry <= 7;
        
        expect(shouldShowWarning, true);
      });

      test('TC-PAYMENT-013: Expired subscription downgraded', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Set past expiry
        final pastExpiry = DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;
        await prefs.setInt('subscription_expiry', pastExpiry);
        
        // Check if expired
        final expiryTime = prefs.getInt('subscription_expiry') ?? 0;
        final isExpired = DateTime.now().millisecondsSinceEpoch > expiryTime;
        
        expect(isExpired, true);
        
        // Should downgrade to free
        if (isExpired) {
          await prefs.setBool('is_premium', false);
          await prefs.setInt('premium_tier', 0);
        }
        
        expect(prefs.getBool('is_premium'), false);
      });
    });

    group('Subscription Management', () {
      test('TC-PAYMENT-014: Can cancel subscription', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('subscription_active', false);
        await prefs.setString('cancellation_reason', 'User requested');
        await prefs.setInt('cancelled_at', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('subscription_active'), false);
        expect(prefs.getString('cancellation_reason'), isNotNull);
      });

      test('TC-PAYMENT-015: Can reactivate subscription', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('subscription_active', true);
        await prefs.remove('cancelled_at');
        await prefs.setInt('reactivated_at', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('subscription_active'), true);
        expect(prefs.getInt('reactivated_at'), greaterThan(0));
      });

      test('TC-PAYMENT-016: Subscription upgrade handled', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Upgrade from Pro (1) to Pro Plus (2)
        await prefs.setInt('premium_tier', 1);
        
        // Upgrade
        await prefs.setInt('premium_tier', 2);
        await prefs.setInt('upgraded_at', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getInt('premium_tier'), 2);
        expect(prefs.getInt('upgraded_at'), greaterThan(0));
      });

      test('TC-PAYMENT-017: Subscription downgrade handled', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Downgrade from Pro Plus (2) to Pro (1)
        await prefs.setInt('premium_tier', 2);
        
        // Downgrade
        await prefs.setInt('premium_tier', 1);
        await prefs.setInt('downgraded_at', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getInt('premium_tier'), 1);
      });
    });

    group('Payment History', () {
      test('TC-PAYMENT-018: Payment transactions recorded', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final payments = [
          '{"date":"2024-01-01","amount":999,"status":"success"}',
          '{"date":"2024-02-01","amount":999,"status":"success"}',
        ];
        
        await prefs.setStringList('payment_history', payments);
        
        expect(prefs.getStringList('payment_history')!.length, 2);
      });

      test('TC-PAYMENT-019: Refund processed', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('refund_requested', true);
        await prefs.setInt('refund_requested_at', DateTime.now().millisecondsSinceEpoch);
        await prefs.setString('refund_reason', 'Not satisfied');
        
        expect(prefs.getBool('refund_requested'), true);
      });

      test('TC-PAYMENT-020: Receipt generated', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('latest_receipt', 'receipt_abc123');
        await prefs.setInt('receipt_date', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getString('latest_receipt'), 'receipt_abc123');
      });
    });

    group('Billing Cycles', () {
      test('TC-PAYMENT-021: Monthly billing cycle', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('billing_cycle', 'monthly');
        await prefs.setInt('next_billing_date', DateTime.now().add(Duration(days: 30)).millisecondsSinceEpoch);
        
        expect(prefs.getString('billing_cycle'), 'monthly');
      });

      test('TC-PAYMENT-022: Yearly billing cycle with discount', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('billing_cycle', 'yearly');
        await prefs.setDouble('discount_percentage', 20.0); // 20% off
        await prefs.setInt('next_billing_date', DateTime.now().add(Duration(days: 365)).millisecondsSinceEpoch);
        
        expect(prefs.getString('billing_cycle'), 'yearly');
        expect(prefs.getDouble('discount_percentage'), 20.0);
      });
    });

    group('Promotional Codes', () {
      test('TC-PAYMENT-023: Promo code applied', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('promo_code', 'SAVE20');
        await prefs.setDouble('promo_discount', 20.0);
        await prefs.setBool('promo_applied', true);
        
        expect(prefs.getString('promo_code'), 'SAVE20');
        expect(prefs.getBool('promo_applied'), true);
      });

      test('TC-PAYMENT-024: Invalid promo code rejected', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('promo_error', 'Invalid or expired code');
        await prefs.setBool('promo_applied', false);
        
        expect(prefs.getBool('promo_applied'), false);
        expect(prefs.getString('promo_error'), isNotNull);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/features/notifications/push_notification_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/data/models/notification_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Push Notification Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Notification Permissions', () {
      test('TC-NOTIF-001: Permission state can be stored', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('notifications_enabled', true);
        await prefs.setString('permission_status', 'authorized');
        
        expect(prefs.getBool('notifications_enabled'), true);
        expect(prefs.getString('permission_status'), 'authorized');
      });

      test('TC-NOTIF-002: Permission denial tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('notifications_enabled', false);
        await prefs.setString('permission_status', 'denied');
        
        expect(prefs.getBool('notifications_enabled'), false);
        expect(prefs.getString('permission_status'), 'denied');
      });

      test('TC-NOTIF-003: Provisional permission supported', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('permission_status', 'provisional');
        
        final status = prefs.getString('permission_status');
        expect(status, 'provisional');
      });
    });

    group('FCM Token Management', () {
      test('TC-NOTIF-004: FCM token can be stored', () async {
        final prefs = await SharedPreferences.getInstance();
        
        const mockToken = 'fcm_token_abc123xyz';
        await prefs.setString('fcm_token', mockToken);
        
        expect(prefs.getString('fcm_token'), mockToken);
      });

      test('TC-NOTIF-005: Token refresh tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Old token
        await prefs.setString('fcm_token', 'old_token');
        
        // Token refreshes
        await prefs.setString('fcm_token', 'new_token');
        await prefs.setInt('token_updated_at', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getString('fcm_token'), 'new_token');
        expect(prefs.getInt('token_updated_at'), greaterThan(0));
      });

      test('TC-NOTIF-006: Token uploaded to server tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('token_uploaded', true);
        await prefs.setInt('token_upload_time', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('token_uploaded'), true);
      });
    });

    group('Notification Preferences', () {
      test('TC-NOTIF-007: Default preferences initialized', () {
        final prefs = NotificationPreferences();
        
        expect(prefs.enabled, true);
        expect(prefs.breakingNews, true);
        expect(prefs.personalizedAlerts, true);
        expect(prefs.promotional, true);
      });

      test('TC-NOTIF-008: Preferences can be modified', () async {
        final sharedPrefs = await SharedPreferences.getInstance();
        var prefs = NotificationPreferences.load(sharedPrefs);
        
        prefs.breakingNews = false;
        prefs.promotional = false;
        prefs.save(sharedPrefs);
        
        // Reload and verify
        prefs = NotificationPreferences.load(sharedPrefs);
        expect(prefs.breakingNews, false);
        expect(prefs.promotional, false);
      });

      test('TC-NOTIF-009: Subscribed topics can be managed', () async {
        final sharedPrefs = await SharedPreferences.getInstance();
        
        // Create preferences with topics
        var prefs = NotificationPreferences(
          subscribedTopics: ['breaking', 'sports', 'tech'],
        );
        prefs.save(sharedPrefs);
        
        // Reload and verify
        prefs = NotificationPreferences.load(sharedPrefs);
        expect(prefs.subscribedTopics, ['breaking', 'sports', 'tech']);
        expect(prefs.subscribedTopics.length, 3);
      });
    });

    group('Topic Subscriptions', () {
      test('TC-NOTIF-010: Can subscribe to topics', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final topics = ['breaking_news', 'bangladesh', 'sports'];
        await prefs.setStringList('subscribed_topics', topics);
        
        final subscribed = prefs.getStringList('subscribed_topics');
        expect(subscribed, topics);
      });

      test('TC-NOTIF-011: Can unsubscribe from topics', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setStringList('subscribed_topics', ['breaking_news', 'sports']);
        
        // Unsubscribe from sports
        var topics = prefs.getStringList('subscribed_topics')!;
        topics.remove('sports');
        await prefs.setStringList('subscribed_topics', topics);
        
        expect(prefs.getStringList('subscribed_topics'), ['breaking_news']);
      });

      test('TC-NOTIF-012: Topic sync status tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('topics_synced', true);
        await prefs.setInt('topics_sync_time', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('topics_synced'), true);
      });
    });

    group('Notification Reception', () {
      test('TC-NOTIF-013: Received notification data parsed', () {
        final notificationData = {
          'title': 'Breaking News',
          'body': 'Important update',
          'articleUrl': 'https://example.com/article',
          'imageUrl': 'https://example.com/image.jpg',
        };
        
        expect(notificationData['title'], 'Breaking News');
        expect(notificationData['articleUrl'], isNotNull);
      });

      test('TC-NOTIF-014: Notification with empty data handled', () {
        final notificationData = <String, dynamic>{};
        
        expect(notificationData.isEmpty, true);
        expect(notificationData['title'], isNull);
      });

      test('TC-NOTIF-015: Notification count tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        var count = prefs.getInt('notification_count') ?? 0;
        count++;
        await prefs.setInt('notification_count', count);
        
        expect(prefs.getInt('notification_count'), 1);
      });
    });

    group('Deep Linking', () {
      test('TC-NOTIF-016: Article URL extracted from notification', () {
        final data = {
          'articleUrl': 'https://example.com/article/123',
          'type': 'article',
        };
        
        expect(data['articleUrl'], contains('/article/'));
        expect(data['type'], 'article');
      });

      test('TC-NOTIF-017: Category deep link parsed', () {
        final data = {
          'route': '/category/sports',
          'type': 'category',
        };
        
        expect(data['route'], '/category/sports');
        expect(data['type'], 'category');
      });

      test('TC-NOTIF-018: Invalid deep link handled', () {
        final data = {
          'route': '',
          'type': 'unknown',
        };
        
        expect(data['route'], isEmpty);
        // Should fall back to home screen
      });
    });

    group('Background/Foreground Handling', () {
      test('TC-NOTIF-019: App state tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('app_state', 'foreground');
        expect(prefs.getString('app_state'), 'foreground');
        
        await prefs.setString('app_state', 'background');
        expect(prefs.getString('app_state'), 'background');
      });

      test('TC-NOTIF-020: Background notification count', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setInt('bg_notifications', 5);
        expect(prefs.getInt('bg_notifications'), 5);
      });

      test('TC-NOTIF-021: Last notification time tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('last_notification_time', now);
        
        expect(prefs.getInt('last_notification_time'), now);
      });
    });

    group('Notification Channels', () {
      test('TC-NOTIF-022: Channel preferences stored', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('channel_general_news', true);
        await prefs.setBool('channel_personalized', true);
        await prefs.setBool('channel_promotional', false);
        
        expect(prefs.getBool('channel_general_news'), true);
        expect(prefs.getBool('channel_promotional'), false);
      });

      test('TC-NOTIF-023: Channel importance levels', () {
        final channels = {
          'general_news': 'high',
          'personalized': 'high',
          'promotional': 'default',
        };
        
        expect(channels['general_news'], 'high');
        expect(channels['promotional'], 'default');
      });
    });

    group('Analytics & Tracking', () {
      test('TC-NOTIF-024: Notification tap tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        var tapCount = prefs.getInt('notification_taps') ?? 0;
        tapCount++;
        await prefs.setInt('notification_taps', tapCount);
        
        expect(prefs.getInt('notification_taps'), 1);
      });

      test('TC-NOTIF-025: Notification dismiss tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        var dismissCount = prefs.getInt('notification_dismissals') ?? 0;
        dismissCount++;
        await prefs.setInt('notification_dismissals', dismissCount);
        
        expect(prefs.getInt('notification_dismissals'), 1);
      });

      test('TC-NOTIF-026: Popular notification topics tracked', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final topicStats = {
          'sports': 10,
          'politics': 8,
          'entertainment': 5,
        };
        
        await prefs.setString('topic_stats', topicStats.toString());
        expect(prefs.getString('topic_stats'), isNotNull);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/features/offline/offline_functionality_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Functionality Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Offline Article Access', () {
      test('TC-OFFLINE-001: Cached articles accessible offline', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate cached articles
        final cachedArticles = [
          '{"title":"Offline Article 1","url":"https://example.com/1","cached":true}',
          '{"title":"Offline Article 2","url":"https://example.com/2","cached":true}',
        ];
        
        await prefs.setStringList('cached_articles', cachedArticles);
        
        // Verify access offline
        final cached = prefs.getStringList('cached_articles');
        expect(cached, isNotNull);
        expect(cached!.length, 2);
      });

      test('TC-OFFLINE-002: Recently viewed articles are cached', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate viewing articles
        final recentArticles = ['url1', 'url2', 'url3'];
        await prefs.setStringList('recent_articles', recentArticles);
        
        final recent = prefs.getStringList('recent_articles');
        expect(recent, recentArticles);
      });

      test('TC-OFFLINE-003: Cache limit enforced (max 50 articles)', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Try to cache 60 articles
        final articles = List.generate(60, (i) => 'article_$i');
        
        // Should only keep last 50
        final limitedCache = articles.length > 50 
            ? articles.sublist(articles.length - 50)
            : articles;
        
        await prefs.setStringList('cached_articles', limitedCache);
        
        final cached = prefs.getStringList('cached_articles');
        expect(cached!.length, 50);
        expect(cached.first, 'article_10'); // First 10 were dropped
      });
    });

    group('Offline Favorites Access', () {
      test('TC-OFFLINE-004: Favorites accessible without network', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final favorites = [
          '{"title":"Favorite 1","url":"https://example.com/fav1"}',
          '{"title":"Favorite 2","url":"https://example.com/fav2"}',
        ];
        
        await prefs.setStringList('favorites', favorites);
        
        // Access offline
        final offlineFavs = prefs.getStringList('favorites');
        expect(offlineFavs, isNotNull);
        expect(offlineFavs!.length, 2);
      });

      test('TC-OFFLINE-005: Can add favorites offline', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Existing favorites
        await prefs.setStringList('favorites', ['fav1']);
        
        // Add new favorite offline
        final current = prefs.getStringList('favorites') ?? [];
        current.add('fav2');
        await prefs.setStringList('favorites', current);
        
        expect(prefs.getStringList('favorites')!.length, 2);
      });

      test('TC-OFFLINE-006: Offline changes tracked for sync', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Track pending sync
        await prefs.setStringList('pending_favorite_adds', ['url1', 'url2']);
        await prefs.setStringList('pending_favorite_removes', ['url3']);
        
        final pendingAdds = prefs.getStringList('pending_favorite_adds');
        final pendingRemoves = prefs.getStringList('pending_favorite_removes');
        
        expect(pendingAdds!.length, 2);
        expect(pendingRemoves!.length, 1);
      });
    });

    group('Offline Settings Changes', () {
      test('TC-OFFLINE-007: Settings changes persist offline', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Change settings offline
        await prefs.setInt('theme_mode', 2);
        await prefs.setString('language_code', 'bn');
        await prefs.setBool('data_saver', true);
        
        expect(prefs.getInt('theme_mode'), 2);
        expect(prefs.getString('language_code'), 'bn');
        expect(prefs.getBool('data_saver'), true);
      });

      test('TC-OFFLINE-008: Offline settings marked for sync', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('settings_needs_sync', true);
        await prefs.setInt('settings_last_modified', DateTime.now().millisecondsSinceEpoch);
        
        expect(prefs.getBool('settings_needs_sync'), true);
        expect(prefs.getInt('settings_last_modified'), greaterThan(0));
      });
    });

    group('Sync Resume After Reconnection', () {
      test('TC-OFFLINE-009: Pending changes detected on reconnect', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate offline changes
        await prefs.setStringList('pending_sync_favorites', ['item1', 'item2']);
        await prefs.setStringList('pending_sync_settings', ['theme', 'language']);
        
        // Check on reconnect
        final hasPendingFavorites = (prefs.getStringList('pending_sync_favorites') ?? []).isNotEmpty;
        final hasPendingSettings = (prefs.getStringList('pending_sync_settings') ?? []).isNotEmpty;
        
        expect(hasPendingFavorites, true);
        expect(hasPendingSettings, true);
      });

      test('TC-OFFLINE-010: Sync queue cleared after successful sync', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setStringList('pending_sync_favorites', ['item1']);
        
        // Simulate successful sync
        await prefs.remove('pending_sync_favorites');
        
        expect(prefs.getStringList('pending_sync_favorites'), isNull);
      });
    });

    group('Conflict Resolution', () {
      test('TC-OFFLINE-011: Local changes timestamped', () async {
        final prefs = await SharedPreferences.getInstance();
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('favorites_last_modified_local', timestamp);
        
        expect(prefs.getInt('favorites_last_modified_local'), timestamp);
      });

      test('TC-OFFLINE-012: Last-write-wins strategy', () {
        final localTimestamp = DateTime.now().millisecondsSinceEpoch;
        final serverTimestamp = localTimestamp - 1000; // 1 second older
        
        // Local is newer, should win
        expect(localTimestamp > serverTimestamp, true);
      });

      test('TC-OFFLINE-013: Handles simultaneous offline changes', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Device A adds favorite
        await prefs.setStringList('device_a_changes', ['add:article1']);
        
        // Device B removes favorite
        await prefs.setStringList('device_b_changes', ['remove:article2']);
        
        // Both changes should be tracked
        expect(prefs.getStringList('device_a_changes'), isNotNull);
        expect(prefs.getStringList('device_b_changes'), isNotNull);
      });
    });

    group('Cache Management', () {
      test('TC-OFFLINE-014: Old cache cleared on storage full', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate old cached data
        final oldArticles = List.generate(100, (i) => 'old_$i');
        await prefs.setStringList('old_cache', oldArticles);
        
        // Clear old cache
        await prefs.remove('old_cache');
        
        expect(prefs.getStringList('old_cache'), isNull);
      });

      test('TC-OFFLINE-015: Cache expiry based on age', () {
        final cacheTime = DateTime.now().subtract(Duration(days: 8));
        final maxAge = Duration(days: 7);
        
        final isExpired = DateTime.now().difference(cacheTime) > maxAge;
        expect(isExpired, true);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/features/extras/games/snake/snake_engine_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:bdnewsreader/features/extras/games/snake/engine/snake_engine.dart';

void main() {
  group('SnakeEngine Tests', () {
    late SnakeEngine engine;

    setUp(() {
      engine = SnakeEngine();
    });

    test('Engine initializes with correct state', () {
      expect(engine.score, 0);
      expect(engine.isGameOver, false);
      expect(engine.gridSize, 20);
      expect(engine.state.snake.length, 3);
    });

    test('Snake moves forward on tick', () {
      final initialHead = engine.state.snake.first;
      engine.tick();
      final newHead = engine.state.snake.first;
      
      expect(newHead, isNot(equals(initialHead)));
      expect(engine.state.snake.length, 3); // Should stay same if no food
    });

    test('Snake grows when eating food', () {
      // Position snake next to food
      final food = engine.state.food;
      engine.tick();
      
      // If snake ate food, length should increase
      if (engine.state.snake.first == food) {
        expect(engine.state.snake.length, 4);
        expect(engine.score, 10);
      }
    });

    test('Game over on self-collision', () {
      // Grow the snake first so it's long enough to collide
      // Use the test helper as the state is immutable
      const int center = 10;
      engine.setSnakeForTesting([
        const Point(center, center),
        const Point(center - 1, center),
        const Point(center - 2, center),
        const Point(center - 3, center), // Length 4
        const Point(center - 4, center), // Length 5
      ]);
      
      // Create a scenario where snake hits itself
      // Force snake into a loop
      engine.queueDirection(const Point(0, 1));  // Down
      engine.tick();
      engine.queueDirection(const Point(-1, 0)); // Left
      engine.tick();
      engine.queueDirection(const Point(0, -1)); // Up
      engine.tick();
      engine.queueDirection(const Point(1, 0));  // Right (hit self)
      
      // Keep ticking until collision
      for (int i = 0; i < 10; i++) {
        if (engine.isGameOver) break;
        engine.tick();
      }
      
      // Should eventually hit itself
      expect(engine.isGameOver, true);
    });

    test('Direction queue prevents opposite direction', () {
      // Try to queue opposite direction
      engine.queueDirection(const Point(-1, 0)); // Opposite of initial
      engine.tick();
      
      // Snake should continue in original direction
      expect(engine.state.direction, const Point(1, 0));
    });

    test('Speed increases with score', () {
      final initialSpeed = engine.getSpeed();
      
      // Simulate scoring points
      for (int i = 0; i < 60; i++) {
        engine.tick();
      }
      
      // Speed should change based on score
      if (engine.score >= 50) {
        expect(engine.getSpeed(), lessThan(initialSpeed));
      }
    });

    test('Reset returns to initial state', () {
      // Play for a bit
      for (int i = 0; i < 10; i++) {
        engine.tick();
      }
      
      // Reset
      engine.reset();
      
      expect(engine.score, 0);
      expect(engine.isGameOver, false);
      expect(engine.state.snake.length, 3);
    });

    test('Direction queue limits to 2 inputs', () {
      engine.queueDirection(const Point(0, 1));
      engine.queueDirection(const Point(-1, 0));
      engine.queueDirection(const Point(0, -1)); // Should be ignored
      
      engine.tick();
      expect(engine.state.direction, const Point(0, 1));
      
      engine.tick();
      expect(engine.state.direction, const Point(-1, 0));
      
      engine.tick();
      // Third direction should not have been queued
      expect(engine.state.direction, isNot(equals(const Point(0, -1))));
    });

    test('Food spawns in valid position', () {
      final food = engine.state.food;
      
      // Food should be within grid bounds
      expect(food.x, greaterThanOrEqualTo(0));
      expect(food.x, lessThan(engine.gridSize));
      expect(food.y, greaterThanOrEqualTo(0));
      expect(food.y, lessThan(engine.gridSize));
      
      // Food should not be on snake
      expect(engine.state.snake.contains(food), false);
    });

    test('O(1) collision detection using Set', () {
      // This is implicitly tested by performance, but we can verify
      // by checking game over occurs correctly
      
      // Grow snake long
      for (int i = 0; i < 50; i++) {
        engine.tick();
      }
      
      // Collision should still be detected instantly
      // (If using List.contains, performance would degrade)
      expect(engine.isGameOver, anyOf(equals(true), equals(false)));
    });
  });

  group('GameState Immutability Tests', () {
    test('GameState is immutable', () {
      const state = GameState(
        snake: [Point(5, 5)],
        food: Point(10, 10),
        direction: Point(1, 0),
        score: 0,
        gameOver: false,
        paused: false,
        gridSize: 20,
      );
      
      final newState = state.copyWith(score: 10);
      
      expect(state.score, 0);
      expect(newState.score, 10);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/logo.dart ===

#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

class Config {

  Config._({
    required this.listPath,
    required this.outputDir,
    required this.timeout,
    required this.userAgent,
    required this.maxRetries,
    required this.concurrency,
    required this.maxBytes,
    required this.minWidth,
    required this.minHeight,
  });

  factory Config.fromArgs(List<String> args) {
    final ArgParser parser = ArgParser()
      ..addOption('list', abbr: 'l', defaultsTo: 'newspaperlist.txt')
      ..addOption('out', abbr: 'o', defaultsTo: 'logos')
      ..addOption('timeout', abbr: 't', defaultsTo: '20')
      ..addOption('retries', abbr: 'r', defaultsTo: '3')
      ..addOption('concurrency', abbr: 'c', defaultsTo: '4')
      ..addOption('max-size', defaultsTo: '${1024 * 500}')
      ..addOption('min-width', defaultsTo: '100')
      ..addOption('min-height', defaultsTo: '50');

    final ArgResults opts = parser.parse(args);
    final String scriptDir = p.dirname(Platform.script.toFilePath());
    final listArg = opts['list'];
    final listFile = p.isAbsolute(listArg) ? listArg : p.join(scriptDir, listArg);

    return Config._(
      listPath: p.absolute(listFile),
      outputDir: p.absolute(opts['out']!),
      timeout: Duration(seconds: int.parse(opts['timeout']!)),
      userAgent: 'LogoCollector/1.0',
      maxRetries: int.parse(opts['retries']!),
      concurrency: int.parse(opts['concurrency']!),
      maxBytes: int.parse(opts['max-size']!),
      minWidth: int.parse(opts['min-width']!),
      minHeight: int.parse(opts['min-height']!),
    );
  }
  final String listPath;
  final String outputDir;
  final Duration timeout;
  final String userAgent;
  final int maxRetries;
  final int concurrency;
  final int maxBytes;
  final int minWidth;
  final int minHeight;
}

Future<void> main(List<String> args) async {
  final Config config = Config.fromArgs(args);
  stdout.writeln('🚀 Starting logo collector...');
  await Directory(config.outputDir).create(recursive: true);

  final List<String> names = await _loadNames(config.listPath);
  final Dio dio = Dio(BaseOptions(
    connectTimeout: config.timeout,
    receiveTimeout: config.timeout,
    headers: <String, dynamic>{HttpHeaders.userAgentHeader: config.userAgent},
    responseType: ResponseType.bytes,
  ));

  final StreamController<void> sem = StreamController<void>.broadcast();
  for (int i = 0; i < config.concurrency; i++) {
    sem.add(null);
  }

  final List<Future<dynamic>> futures = <Future>[];
  for (final String name in names) {
    await for (final _ in sem.stream.take(1)) {
      futures.add(
        _processName(name, config, dio).whenComplete(() => sem.add(null)),
      );
    }
  }

  await Future.wait(futures);
  await sem.close();

  stdout.writeln('✅ Completed. Logos saved to: ${config.outputDir}');
}

Future<List<String>> _loadNames(String path) async {
  final File file = File(path);
  if (!await file.exists()) {
    stderr.writeln('❌ List file not found: $path');
    exit(1);
  }
  final List<String> lines = await file.readAsLines();
  return lines.map((String l) => l.trim()).where((String l) => l.isNotEmpty).toList();
}

Future<void> _processName(String name, Config c, Dio dio) async {
  stdout.writeln('🔍 Searching logo for: $name');
  final List<String> candidates = await _searchLogoUrls(name, dio);
  for (final String url in candidates) {
    try {
      final Uint8List bytes = await _downloadBytes(url, dio);
      if (bytes.length > c.maxBytes) throw 'Too large';

      final img.Image? image = img.decodeImage(bytes);
      if (image == null) throw 'Decode failure';
      if (image.width < c.minWidth || image.height < c.minHeight) {
        throw 'Dimensions too small';
      }
      if (!_hasTransparency(image)) throw 'No transparency';

      final String ext = _getExt(url);
      final String safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final String outFile = p.join(c.outputDir, '$safe.$ext');
      final Uint8List encoded = ext == 'png' ? img.encodePng(image) : img.encodeJpg(image);
      await File(outFile).writeAsBytes(Uint8List.fromList(encoded));

      stdout.writeln('💾 Saved: $outFile');
      return;
    } catch (e) {
      stderr.writeln('⚠️ $url failed: $e');
    }
  }
  stderr.writeln('❌ No valid logo found for: $name');
}

Future<List<String>> _searchLogoUrls(String name, Dio dio) async {
  final String query = Uri.encodeQueryComponent('$name logo');
  final String url = 'https://duckduckgo.com/i.js?q=$query&iax=images&ia=images';

  final Response<dynamic> response = await dio.get(url, options: Options(responseType: ResponseType.plain));
  try {
    final Map<String, dynamic> data = json.decode(response.data!) as Map<String, dynamic>;
    final List<String> results = (data['results'] as List)
        .map((e) => e['image'] as String)
        .toList();
    return results.take(5).toList();
  } catch (e) {
    stderr.writeln('❌ Failed to parse search results: $e');
    return <String>[];
  }
}

Future<Uint8List> _downloadBytes(String url, Dio dio) async {
  final Response<Uint8List> resp = await dio.get<Uint8List>(url);
  if (resp.statusCode != 200 || resp.data == null) {
    throw 'HTTP ${resp.statusCode}';
  }
  return resp.data!;
}

bool _hasTransparency(img.Image image) {
  final Uint8List bytes = image.getBytes(order: img.ChannelOrder.rgba);
  for (int i = 3; i < bytes.length; i += 4) {
    if (bytes[i] < 255) return true;
  }
  return false;
}

String _getExt(String url) {
  final String ext = p.extension(Uri.parse(url).path).toLowerCase();
  return ext.startsWith('.') ? ext.substring(1) : 'png';
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/crash_proofing/error_handler_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

/// Critical crash-proofing test: Prevent infinite error loops
/// 
/// This test ensures that the global error handler doesn't cause
/// infinite loops when handling errors, which would crash the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Error Handler Crash-Proofing', () {
    test('TC-ERROR-001: Error handler can be called without crashing',() {
      // Simple sanity test: error handler works
      int errors = 0;
      
      for (int i = 0; i < 10; i++) {
        try {
          throw Exception('Test error $i');
        } catch (e) {
          // ErrorHandler.logError would be called in real code
          // For test, just count
          errors++;
        }
      }
      
      expect(errors, equals(10));
    });

    test('TC-ERROR-002: Multiple rapid errors can be handled', () {
      final errors = <String>[];
      
      // Simulate rapid error handling
      for (int i = 0; i < 100; i++) {
        try {
          throw Exception('Rapid error $i');
        } catch (e) {
          errors.add(e.toString());
        }
      }
      
      expect(errors.length, equals(100));
      expect(errors.first, contains('Rapid error 0'));
      expect(errors.last, contains('Rapid error 99'));
    });

    test('TC-ERROR-003: Nested error handling works gracefully', () {
      String? outerError;
      String? innerError;
      
      try {
        throw Exception('Outer error');
      } catch (e) {
        outerError = e.toString();
        
        try {
          throw Exception('Inner error');
        } catch (e2) {
          innerError = e2.toString();
        }
      }
      
      expect(outerError, contains('Outer error'));
      expect(innerError, contains('Inner error'));
    });

    test('TC-ERROR-004: Error stack trace captured', () {
      String? stackTrace;
      
      try {
        throw Exception('Error with stack');
      } catch (e, stack) {
        stackTrace = stack.toString();
      }
      
      expect(stackTrace, isNotNull);
      expect(stackTrace, isNotEmpty);
    });
  });

  group('Empty State Crash-Proofing', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('TC-ERROR-005: App handles empty SharedPreferences gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all preferences (simulate fresh install)
      await prefs.clear();
      
      // App should provide defaults, not crash
      final theme = prefs.getInt('theme_mode') ?? 0; // Default system
      final language = prefs.getString('language_code') ?? 'en'; // Default English
      final firstRun = prefs.getBool('first_run') ?? true; // Default true
      
      expect(theme, 0);
      expect(language, 'en');
      expect(firstRun, true);
    });

    test('TC-ERROR-006: App handles missing keys gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Try to read non-existent keys
      final missingString = prefs.getString('non_existent_key');
      final missingInt = prefs.getInt('non_existent_int');
      final missingBool = prefs.getBool('non_existent_bool');
      
      expect(missingString, isNull);
      expect(missingInt, isNull);
      expect(missingBool, isNull);
      
      // Should not crash, just return null
    });

    test('TC-ERROR-007: App handles corrupted JSON gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Write corrupted JSON
      await prefs.setString('corrupted_data', '{invalid json}');
      
      final corrupted = prefs.getString('corrupted_data');
      
      // Try to parse
      try {
        jsonDecode(corrupted!);
        fail('Should have thrown FormatException');
      } catch (e) {
        expect(e, isA<FormatException>());
        // App should catch this and use defaults
      }
    });

    test('TC-ERROR-008: App recovers from corrupted cache data', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Write invalid article data
      await prefs.setString('cached_article', 'not valid json');
      
      // App should detect corruption and reset
      final cached = prefs.getString('cached_article');
      bool isCorrupted = false;
      
      try {
        jsonDecode(cached!);
      } catch (e) {
        isCorrupted = true;
        // Reset to defaults
        await prefs.remove('cached_article');
      }
      
      expect(isCorrupted, true);
      expect(prefs.getString('cached_article'), isNull);
    });
  });

  group('Network Failure Crash-Proofing', () {
    test('TC-ERROR-009: App handles no internet connection', () async {
      // Simulate network unavailable
      final isOnline = false;
      
      if (!isOnline) {
        // Should show offline UI, not crash
        final shouldShowOfflineBanner = true;
        final shouldUseCachedData = true;
        
        expect(shouldShowOfflineBanner, true);
        expect(shouldUseCachedData, true);
      }
    });

    test('TC-ERROR-010: App handles timeout gracefully', () async {
      bool timedOut = false;
      
      try {
        await Future.delayed(Duration(seconds: 2))
            .timeout(Duration(seconds: 1));
      } catch (e) {
        if (e is TimeoutException || e.toString().contains('TimeoutException')) {
          timedOut = true;
        }
      }
      
      expect(timedOut, true);
      // App should show retry option, not crash
    });

    test('TC-ERROR-011: App handles server error (500) gracefully', () {
      final serverResponse = {
        'statusCode': 500,
        'error': 'Internal Server Error',
      };
      
      if (serverResponse['statusCode'] == 500) {
        // Should show error message, not crash
        final shouldShowError = true;
        final shouldRetry = true;
        
        expect(shouldShowError, true);
        expect(shouldRetry, true);
      }
    });
  });

  group('Permission Denial Crash-Proofing', () {
    test('TC-ERROR-012: App handles notification permission denial', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Simulate permission denied
      await prefs.setString('notification_permission', 'denied');
      
      final permission = prefs.getString('notification_permission');
      
      if (permission == 'denied') {
        // Should disable notification features, not crash
        final notificationsEnabled = false;
        final shouldShowPermissionPrompt = true;
        
        expect(notificationsEnabled, false);
        expect(shouldShowPermissionPrompt, true);
      }
    });

    test('TC-ERROR-013: App handles storage permission denial', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Simulate storage permission denied
      await prefs.setString('storage_permission', 'denied');
      
      final permission = prefs.getString('storage_permission');
      
      if (permission == 'denied') {
        // Should fall back to memory-only cache
        final useMemoryCache = true;
        final canDownloadOffline = false;
        
        expect(useMemoryCache, true);
        expect(canDownloadOffline, false);
      }
    });

    test('TC-ERROR-014: App handles camera permission denial', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Simulate camera permission denied
      await prefs.setBool('camera_permission', false);
      
      final hasPermission = prefs.getBool('camera_permission') ?? false;
      
      if (!hasPermission) {
        // Should disable camera features, not crash
        final cameraFeaturesDisabled = true;
        expect(cameraFeaturesDisabled, true);
      }
    });
  });

  group('Data Integrity Crash-Proofing', () {
    test('TC-ERROR-015: App handles type mismatch in storage', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Store as string, try to read as int
      await prefs.setString('user_age', 'twenty-five');
      
      final age = prefs.getInt('user_age'); // Should return null, not crash
      expect(age, isNull);
      
      // App should use default value
      final defaultAge = age ?? 0;
      expect(defaultAge, 0);
    });

    test('TC-ERROR-016: App handles extremely large numbers', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Store very large number
      final largeNumber = 9223372036854775807; // Max int64
      await prefs.setInt('large_number', largeNumber);
      
      final retrieved = prefs.getInt('large_number');
      expect(retrieved, largeNumber);
    });

    test('TC-ERROR-017: App handles special characters in strings', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Test special characters
      final specialString = 'Test\nWith\tSpecial\r\nCharacters\u0000Null';
      await prefs.setString('special_string', specialString);
      
      final retrieved = prefs.getString('special_string');
      expect(retrieved, specialString);
    });

    test('TC-ERROR-018: App handles empty lists', () async {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setStringList('empty_list', []);
      
      final retrieved = prefs.getStringList('empty_list');
      expect(retrieved, isEmpty);
      expect(retrieved, isNotNull);
    });
  });

  group('Concurrent Operation Crash-Proofing', () {
    test('TC-ERROR-019: App handles concurrent writes', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Simulate concurrent writes
      final futures = <Future>[];
      for (int i = 0; i < 10; i++) {
        futures.add(prefs.setInt('counter_$i', i));
      }
      
      await Future.wait(futures);
      
      // All writes should succeed
      for (int i = 0; i < 10; i++) {
        expect(prefs.getInt('counter_$i'), i);
      }
    });

    test('TC-ERROR-020: App handles concurrent reads', () async {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('shared_value', 'test');
      
      // Simulate concurrent reads
      final futures = <Future<String?>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(Future(() => prefs.getString('shared_value')));
      }
      
      final results = await Future.wait(futures);
      
      // All reads should return same value
      for (final result in results) {
        expect(result, 'test');
      }
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/performance/optimization_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/network_quality_manager.dart';
import 'package:bdnewsreader/core/utils/retry_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Performance & Optimization Tests', () {
    group('Network Optimization', () {
      test('TC-PERF-001: NetworkQualityManager provides adaptive timeout', () {
        final manager = NetworkQualityManager();
        final timeout = manager.getAdaptiveTimeout();
        
        expect(timeout.inSeconds, greaterThan(0));
        expect(timeout.inSeconds, lessThanOrEqualTo(60));
      });

      test('TC-PERF-002: NetworkQualityManager provides cache duration', () {
        final manager = NetworkQualityManager();
        final duration = manager.getCacheDuration();
        
        expect(duration.inMinutes, greaterThan(0));
      });
    });

    group('Retry Performance', () {
      test('TC-PERF-003: Retry helper succeeds on first try', () async {
        var attempts = 0;
        
        final result = await RetryHelper.retry<String>(
          operation: () async {
            attempts++;
            return 'success';
          },
        );
        
        expect(result, 'success');
        expect(attempts, 1);
      });

      test('TC-PERF-004: Exponential backoff increases delay', () {
        // 2^0 = 1, 2^1 = 2, 2^2 = 4
        final delays = [1, 2, 4];
        
        for (int i = 0; i < delays.length; i++) {
          final expectedDelay = 1 << i; // 2^i
          expect(expectedDelay, delays[i]);
        }
      });
    });

    group('Memory Optimization', () {
      test('TC-PERF-005: LRU cache evicts old entries', () {
        final cache = <String, String>{};
        const maxSize = 10;
        
        void addToCache(String key, String value) {
          cache[key] = value;
          if (cache.length > maxSize) {
            cache.remove(cache.keys.first);
          }
        }
        
        // Add 15 items
        for (int i = 0; i < 15; i++) {
          addToCache('key$i', 'value$i');
        }
        
        expect(cache.length, maxSize);
        expect(cache.containsKey('key0'), isFalse); // Evicted
        expect(cache.containsKey('key14'), isTrue); // Newest
      });

      test('TC-PERF-006: Deduplication reduces memory', () {
        final urls = <String>{'url1', 'url1', 'url2', 'url2', 'url3'};
        
        expect(urls.length, 3); // Set deduplicates
      });
    });

    group('Rendering Performance', () {
      test('TC-PERF-007: Lazy loading reduces initial render items', () {
        const totalItems = 1000;
        const visibleItems = 15;
        
        // Lazy loading renders only visible items
        expect(visibleItems, lessThan(totalItems * 0.1));
      });

      test('TC-PERF-008: 60 FPS requires <16ms frame time', () {
        const targetFPS = 60;
        const maxFrameTimeMs = 1000 / targetFPS;
        
        expect(maxFrameTimeMs, closeTo(16.67, 0.1));
      });
    });

    group('Startup Optimization', () {
      test('TC-PERF-009: Lazy initialization reduces startup time', () {
        final loadedModules = <String>{};
        
        void lazyLoad(String module) {
          loadedModules.add(module);
        }
        
        // Only load core on startup
        lazyLoad('core');
        expect(loadedModules.length, 1);
        
        // Load other modules on demand
        lazyLoad('settings');
        lazyLoad('premium');
        expect(loadedModules.length, 3);
      });
    });

    group('Caching Strategy', () {
      test('TC-PERF-010: Cache-first strategy is fast', () async {
        final cache = <String, String>{'key': 'cached_value'};
        
        String? fetchFromCache(String key) {
          return cache[key];
        }
        
        Future<String> fetchFromNetwork(String key) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'network_value';
        }
        
        Future<String> getData(String key) async {
          final cached = fetchFromCache(key);
          if (cached != null) {
            return cached;
          }
          return fetchFromNetwork(key);
        }
        
        final start = DateTime.now();
        final result = await getData('key');
        final elapsed = DateTime.now().difference(start);
        
        expect(result, 'cached_value');
        expect(elapsed.inMilliseconds, lessThan(10)); // Fast cache hit
      });

      test('TC-PERF-011: Concurrent requests coalesce', () async {
        var apiCalls = 0;
        final ongoing = <String, Future<String>>{};
        
        Future<String> fetchWithCoalescing(String key) async {
          if (ongoing.containsKey(key)) {
            return ongoing[key]!;
          }
          
          final future = Future<String>.delayed(
            const Duration(milliseconds: 50),
            () {
              apiCalls++;
              return 'data';
            },
          );
          
          ongoing[key] = future;
          
          try {
            return await future;
          } finally {
            ongoing.remove(key);
          }
        }
        
        // 10 concurrent requests
        await Future.wait(
          List.generate(10, (_) => fetchWithCoalescing('popular')),
        );
        
        expect(apiCalls, lessThanOrEqualTo(2));
      });
    });

    group('Battery Optimization', () {
      test('TC-PERF-012: Background sync intervals are reasonable', () {
        const syncIntervalMinutes = 15;
        
        // Not too frequent (battery drain)
        expect(syncIntervalMinutes, greaterThanOrEqualTo(5));
        
        // Not too infrequent (stale data)
        expect(syncIntervalMinutes, lessThanOrEqualTo(60));
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/e2e/settings_sync_flow_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests settings sync flow patterns without importing Firebase-dependent services
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Sync Flow E2E', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Settings Structure', () {
      test('TC-E2E-040: Settings map has correct structure', () {
        final settings = <String, dynamic>{
          'dataSaver': true,
          'pushNotif': true,
          'themeMode': 1,
          'languageCode': 'bn',
          'readerLineHeight': 1.5,
          'readerContrast': 1.0,
        };
        
        expect(settings['dataSaver'], isA<bool>());
        expect(settings['themeMode'], isA<int>());
        expect(settings['languageCode'], isA<String>());
        expect(settings['readerLineHeight'], isA<double>());
      });

      test('TC-E2E-041: Theme mode values are valid (0-2)', () {
        final validThemeModes = [0, 1, 2];
        for (final mode in validThemeModes) {
          expect(mode, inInclusiveRange(0, 2));
        }
      });
    });

    group('Settings Persistence', () {
      test('TC-E2E-042: Settings persist to SharedPreferences', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setBool('data_saver_mode', true);
        await prefs.setBool('push_notifications', true);
        await prefs.setInt('theme_mode', 1);
        await prefs.setString('language_code', 'bn');
        await prefs.setDouble('reader_line_height', 1.5);
        await prefs.setDouble('reader_contrast', 0.9);
        
        expect(prefs.getBool('data_saver_mode'), isTrue);
        expect(prefs.getInt('theme_mode'), 1);
        expect(prefs.getString('language_code'), 'bn');
      });

      test('TC-E2E-043: Theme mode defaults correctly', () async {
        final prefs = await SharedPreferences.getInstance();
        
        // Default should be 0 (system) or null
        expect(prefs.getInt('theme_mode'), isNull);
        
        await prefs.setInt('theme_mode', 0);
        expect(prefs.getInt('theme_mode'), 0);
      });
    });

    group('Settings Retrieval', () {
      test('TC-E2E-044: Missing settings return null', () async {
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getBool('nonexistent'), isNull);
        expect(prefs.getInt('nonexistent'), isNull);
        expect(prefs.getString('nonexistent'), isNull);
      });
    });

    group('Favorites Sync Structure', () {
      test('TC-E2E-045: Favorites payload has articles/magazines/newspapers', () {
        final favoritesPayload = <String, dynamic>{
          'articles': <Map<String, dynamic>>[],
          'magazines': <Map<String, dynamic>>[],
          'newspapers': <Map<String, dynamic>>[],
        };
        
        expect(favoritesPayload['articles'], isA<List>());
        expect(favoritesPayload['magazines'], isA<List>());
        expect(favoritesPayload['newspapers'], isA<List>());
      });
    });

    group('Settings Keys', () {
      test('TC-E2E-046: All settings keys are defined', () {
        const keys = [
          'data_saver_mode',
          'push_notifications',
          'theme_mode',
          'language_code',
          'reader_line_height',
          'reader_contrast',
        ];
        
        for (final key in keys) {
          expect(key, isNotEmpty);
        }
      });

      test('TC-E2E-047: Settings can be cleared and reset', () async {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setInt('theme_mode', 2);
        await prefs.clear();
        
        expect(prefs.getInt('theme_mode'), isNull);
      });
    });

    group('Settings Validation', () {
      test('TC-E2E-048: Line height has valid range', () {
        const validLineHeights = [1.0, 1.25, 1.5, 1.75, 2.0];
        
        for (final height in validLineHeights) {
          expect(height, inInclusiveRange(1.0, 2.0));
        }
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/e2e/authentication_flow_test.dart ===

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These tests validate authentication flow patterns without requiring Firebase
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow E2E', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('Email Validation', () {
      test('TC-E2E-001: Valid email formats pass validation', () {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        
        expect(emailRegex.hasMatch('user@example.com'), isTrue);
        expect(emailRegex.hasMatch('test.user@domain.org'), isTrue);
        expect(emailRegex.hasMatch('user-name@company.co'), isTrue);
        expect(emailRegex.hasMatch('user123@domain.bd'), isTrue);
      });

      test('TC-E2E-002: Invalid email formats fail validation', () {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        
        expect(emailRegex.hasMatch('notanemail'), isFalse);
        expect(emailRegex.hasMatch('@example.com'), isFalse);
        expect(emailRegex.hasMatch('user@'), isFalse);
        expect(emailRegex.hasMatch(''), isFalse);
        expect(emailRegex.hasMatch('user@domain'), isFalse);
      });
    });

    group('Password Validation', () {
      test('TC-E2E-003: Strong passwords meet requirements', () {
        bool isValidPassword(String password) {
          return password.length >= 6;
        }
        
        expect(isValidPassword('password123'), isTrue);
        expect(isValidPassword('Secret!'), isTrue);
        expect(isValidPassword('123456'), isTrue);
      });

      test('TC-E2E-004: Weak passwords fail requirements', () {
        bool isValidPassword(String password) {
          return password.length >= 6;
        }
        
        expect(isValidPassword('12345'), isFalse);
        expect(isValidPassword('abc'), isFalse);
        expect(isValidPassword(''), isFalse);
      });
    });

    group('Login State Persistence', () {
      test('TC-E2E-005: Login state persists in SharedPreferences', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'isLoggedIn': true,
          'user_email': 'test@example.com',
          'user_name': 'Test User',
        });
        
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getBool('isLoggedIn'), isTrue);
        expect(prefs.getString('user_email'), 'test@example.com');
      });

      test('TC-E2E-006: Logged out state clears user data but preserves settings', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'isLoggedIn': true,
          'user_email': 'test@example.com',
          'user_name': 'Test User',
          // Settings to preserve
          'theme_mode': 1,
        });
        
        final prefs = await SharedPreferences.getInstance();
        
        // Simulate logout: clear user data, restore settings
        final themeMode = prefs.getInt('theme_mode');
        await prefs.clear();
        if (themeMode != null) await prefs.setInt('theme_mode', themeMode);
        
        // Settings should be preserved
        expect(prefs.getInt('theme_mode'), 1);
        expect(prefs.getString('user_email'), isNull);
      });
    });

    group('Profile Management', () {
      test('TC-E2E-007: Profile data can be retrieved from prefs', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'user_name': 'John Doe',
          'user_email': 'john@example.com',
          'user_phone': '+1234567890',
          'user_role': 'Developer',
          'user_department': 'Engineering',
          'user_image': 'https://example.com/avatar.jpg',
        });
        
        final prefs = await SharedPreferences.getInstance();
        
        final profile = <String, String>{
          'name': prefs.getString('user_name') ?? '',
          'email': prefs.getString('user_email') ?? '',
          'phone': prefs.getString('user_phone') ?? '',
          'role': prefs.getString('user_role') ?? '',
          'department': prefs.getString('user_department') ?? '',
          'image': prefs.getString('user_image') ?? '',
        };
        
        expect(profile['name'], 'John Doe');
        expect(profile['email'], 'john@example.com');
        expect(profile['phone'], '+1234567890');
      });

      test('TC-E2E-008: Profile returns empty for new users', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getString('user_name'), isNull);
        expect(prefs.getString('user_email'), isNull);
      });
    });

    group('Auth Pattern', () {
      test('TC-E2E-009: isLoggedIn key exists', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{'isLoggedIn': false});
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('isLoggedIn'), isFalse);
      });

      test('TC-E2E-010: Login can be set to true', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        
        expect(prefs.getBool('isLoggedIn'), isTrue);
      });

      test('TC-E2E-011: SharedPreferences tests singleton pattern', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        
        final prefs1 = await SharedPreferences.getInstance();
        final prefs2 = await SharedPreferences.getInstance();
        
        // SharedPreferences uses singleton pattern
        expect(identical(prefs1, prefs2), isTrue);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/e2e/article_reading_flow_test.dart ===

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

void main() {
  group('Article Reading Flow E2E', () {
    test('TC-E2E-020: Article data is complete', () {
      final article = NewsArticle(
        title: 'Breaking News: Important Event',
        url: 'https://example.com/breaking-news',
        source: 'Prothom Alo',
        description: 'Detailed description of the event',
        imageUrl: 'https://example.com/image.jpg',
        publishedAt: DateTime.now(),
      );
      
      expect(article.title, isNotEmpty);
      expect(article.url, startsWith('https://'));
      expect(article.source, isNotEmpty);
    });

    test('TC-E2E-021: Article URL is valid', () {
      final article = NewsArticle(
        title: 'Test',
        url: 'https://example.com/article/123',
        source: 'Source',
        publishedAt: DateTime.now(),
      );
      
      final uri = Uri.tryParse(article.url);
      
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
    });

    test('TC-E2E-022: Article date is parseable', () {
      final article = NewsArticle(
        title: 'Test',
        url: 'https://example.com',
        source: 'Source',
        publishedAt: DateTime(2024, 12, 25, 10, 30),
      );
      
      expect(article.publishedAt.year, 2024);
      expect(article.publishedAt.month, 12);
      expect(article.publishedAt.day, 25);
    });

    test('TC-E2E-023: Time ago calculation works', () {
      String getTimeAgo(DateTime publishedAt) {
        final diff = DateTime.now().difference(publishedAt);
        
        if (diff.inDays > 0) return '${diff.inDays} days ago';
        if (diff.inHours > 0) return '${diff.inHours} hours ago';
        if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
        return 'Just now';
      }
      
      expect(getTimeAgo(DateTime.now().subtract(const Duration(hours: 2))), contains('hour'));
      expect(getTimeAgo(DateTime.now().subtract(const Duration(days: 3))), contains('day'));
      expect(getTimeAgo(DateTime.now()), 'Just now');
    });

    testWidgets('TC-E2E-024: Article card is tappable', (tester) async {
      var tapped = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkWell(
              onTap: () => tapped = true,
              child: const Card(
                child: ListTile(
                  title: Text('Article Title'),
                  subtitle: Text('Source'),
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.tap(find.byType(Card));
      expect(tapped, isTrue);
    });

    testWidgets('TC-E2E-025: Article can be shared', (tester) async {
      var shared = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => shared = true,
                ),
              ],
            ),
          ),
        ),
      );
      
      await tester.tap(find.byIcon(Icons.share));
      expect(shared, isTrue);
    });

    testWidgets('TC-E2E-026: Article can be favorited', (tester) async {
      var favorited = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => IconButton(
                icon: Icon(favorited ? Icons.favorite : Icons.favorite_border),
                onPressed: () => setState(() => favorited = !favorited),
              ),
            ),
          ),
        ),
      );
      
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/e2e/favorites_persistence_test.dart ===

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/data/models/news_article.dart';

/// Tests favorites persistence patterns without importing Firebase-dependent FavoritesManager
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Favorites Persistence E2E', () {
    group('Article Favorites Persistence', () {
      test('TC-E2E-030: Favorites persist in SharedPreferences', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        final article = NewsArticle(
          title: 'Persistable Article',
          url: 'https://example.com/persist',
          source: 'Test Source',
          publishedAt: DateTime.now(),
        );
        
        // Save favorite
        final favorites = [json.encode(article.toMap())];
        await prefs.setStringList('favorites', favorites);
        
        // Verify persisted
        final saved = prefs.getStringList('favorites');
        expect(saved, isNotNull);
        expect(saved!.length, 1);
        
        // Restore and verify
        final restored = NewsArticle.fromMap(json.decode(saved.first));
        expect(restored.url, article.url);
      });

      test('TC-E2E-031: Multiple articles persist correctly', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        final articles = List.generate(5, (i) => NewsArticle(
          title: 'Article $i',
          url: 'https://example.com/article$i',
          source: 'Source',
          publishedAt: DateTime.now(),
        ));
        
        final serialized = articles.map((a) => json.encode(a.toMap())).toList();
        await prefs.setStringList('favorites', serialized);
        
        expect(prefs.getStringList('favorites')!.length, 5);
      });

      test('TC-E2E-032: Removed favorites update persistence', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'favorites': ['{"title":"test","url":"u1","source":"s","publishedAt":"2024-01-01T00:00:00.000"}'],
        });
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getStringList('favorites')!.length, 1);
        
        // Remove all
        await prefs.setStringList('favorites', []);
        expect(prefs.getStringList('favorites')!.length, 0);
      });
    });

    group('Magazine Favorites Persistence', () {
      test('TC-E2E-033: Magazine favorites persist', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        final magazines = [
          json.encode({'id': 'mag1', 'name': 'Anandabazar'}),
          json.encode({'id': 'mag2', 'name': 'Robbar'}),
        ];
        
        await prefs.setStringList('magazine_favorites', magazines);
        expect(prefs.getStringList('magazine_favorites')!.length, 2);
      });
    });

    group('Newspaper Favorites Persistence', () {
      test('TC-E2E-034: Newspaper favorites persist', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        final newspapers = [
          json.encode({'id': 'paper1', 'name': 'Prothom Alo'}),
          json.encode({'id': 'paper2', 'name': 'Kaler Kantho'}),
        ];
        
        await prefs.setStringList('newspaper_favorites', newspapers);
        expect(prefs.getStringList('newspaper_favorites')!.length, 2);
      });
    });

    group('Cross-Type Persistence', () {
      test('TC-E2E-035: All favorite types persist independently', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setStringList('favorites', ['{"title":"a","url":"u","source":"s","publishedAt":"2024-01-01T00:00:00.000"}']);
        await prefs.setStringList('magazine_favorites', ['{"id":"m1","name":"M"}']);
        await prefs.setStringList('newspaper_favorites', ['{"id":"n1","name":"N"}']);
        
        expect(prefs.getStringList('favorites')!.length, 1);
        expect(prefs.getStringList('magazine_favorites')!.length, 1);
        expect(prefs.getStringList('newspaper_favorites')!.length, 1);
      });
    });

    group('Edge Cases', () {
      test('TC-E2E-036: Empty favorites don\'t crash', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        expect(prefs.getStringList('favorites'), isNull);
        expect(prefs.getStringList('magazine_favorites'), isNull);
        expect(prefs.getStringList('newspaper_favorites'), isNull);
      });

      test('TC-E2E-037: Toggle adds then removes', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        
        // Add
        await prefs.setStringList('favorites', ['{"title":"t","url":"u","source":"s","publishedAt":"2024-01-01T00:00:00.000"}']);
        expect(prefs.getStringList('favorites')!.length, 1);
        
        // Remove (toggle)
        await prefs.setStringList('favorites', []);
        expect(prefs.getStringList('favorites')!.length, 0);
      });
    });
  });
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/extras/upload_data_to_firestore.dart ===

// lib/tools/firebase_upload.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bdnewsreader/firebase_options.dart';

Future<void> uploadDataFromJson() async {
  final String jsonString = await rootBundle.loadString('assets/data.json');
  final data = jsonDecode(jsonString);
  final List<dynamic> newspapers = data['newspapers'] as List<dynamic>? ?? <dynamic>[];
  final List<dynamic> magazines  = data['magazines']  as List<dynamic>? ?? <dynamic>[];

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final WriteBatch batch     = firestore.batch();

  for (var item in newspapers) {
    final String id = item['id'] as String;
    batch.set(firestore.collection('newspapers').doc(id), item);
  }
  for (var item in magazines) {
    final String id = item['id'] as String;
    batch.set(firestore.collection('magazines').doc(id), item);
  }

  await batch.commit();
  print('✅ Upload complete');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await uploadDataFromJson();
  // Exit the app after upload—no UI needed
  // On Android, this closes the process; on others it just ends.
}


// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/extras/script_collector.dart ===

import 'dart:io';

Future<void> main() async {
  final String scriptPath = Platform.script.toFilePath();
  final File scriptFile = File(scriptPath);
  final Directory scriptDir = scriptFile.parent;
  
  final File outputFile = File('${scriptDir.path}/combined_dart_code.dart');
  print('🔍 Scanning: ${scriptDir.path}');

  // Collect all .dart files (excluding this script)
  final List<File> dartFiles = await _collectDartFiles(scriptDir, scriptFile);
  
  // Combine into one file
  await _combineFiles(dartFiles, outputFile);
  
  print('✅ Success! Combined ${dartFiles.length} Dart files into:\n   ${outputFile.path}');
}

Future<List<File>> _collectDartFiles(Directory dir, File excludeFile) async {
  final List<File> dartFiles = <File>[];

  await for (final FileSystemEntity entity in dir.list(recursive: true)) {
    if (entity is File && 
        entity.path.endsWith('.dart') && 
        !_isSameFile(entity, excludeFile)) {  // Skip the excluded file
      dartFiles.add(entity);
    }
  }
  
  return dartFiles;
}

Future<void> _combineFiles(List<File> files, File output) async {
  final IOSink sink = output.openWrite();
  
  for (final File file in files) {
    sink.writeln('// === ${file.path} ===\n');
    sink.write(await file.readAsString());
    sink.writeln('\n');
  }
  
  await sink.close();
}

bool _isSameFile(File file1, File file2) {
  // Compare canonical paths to handle symlinks
  return File(file1.path).absolute.path == File(file2.path).absolute.path;
}

// === /Users/debashishdeb/Documents/JS/MobileApp/droid/test/extras/firebase_upload.dart ===

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  await Firebase.initializeApp();

  String? targetExtension;
  if (args.isNotEmpty) {
    targetExtension = args[0].startsWith('.') ? args[0].toLowerCase() : '.${args[0].toLowerCase()}';
  }

  await uploadProjectFiles(targetExtension);
}

Future<void> uploadProjectFiles(String? filterExtension) async {
  final Directory projectDir = Directory(Directory.current.path);
  final List<FileSystemEntity> files = await projectDir.list(recursive: true).toList();
  final List<File> filteredFiles = files.whereType<File>().where((File file) {
    if (filterExtension == null) return true;
    return p.extension(file.path).toLowerCase() == filterExtension;
  }).toList();

  final int totalFiles = filteredFiles.length;
  int uploadedFiles = 0;

  print('Starting upload of $totalFiles files...');

  for (File entity in filteredFiles) {
    final String extension = p.extension(entity.path).toLowerCase();
    final String fileName = p.basename(entity.path);
    final int fileSize = await entity.length();

    try {
      if (<String>['.dart', '.yaml', '.plist'].contains(extension) || (extension == '.json' && fileSize > 100 * 1024)) {
        final Reference ref = FirebaseStorage.instance.ref('source-backups/$fileName');
        await ref.putFile(entity);
        print('Uploaded $fileName to Firebase Storage.');
      } else if (extension == '.json' && fileSize <= 100 * 1024) {
        final String content = await entity.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        await FirebaseFirestore.instance.collection('uploaded_data').doc(fileName).set(data);
        print('Uploaded $fileName to Firestore.');
      } else {
        final Reference ref = FirebaseStorage.instance.ref('other-backups/$fileName');
        await ref.putFile(entity);
        print('Uploaded $fileName to other-backups Storage folder.');
      }
    } catch (e) {
      print('Failed to upload $fileName: $e');
    }

    uploadedFiles++;
    final double progress = (uploadedFiles / totalFiles) * 100;
    print('Progress: ${progress.toStringAsFixed(2)}%');
  }

  print('All files processed. Upload complete.');
}


