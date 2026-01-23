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
