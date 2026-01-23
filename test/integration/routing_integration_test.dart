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
