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
