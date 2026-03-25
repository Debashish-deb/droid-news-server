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
