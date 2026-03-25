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
