import 'package:bdnewsreader/core/di/providers.dart';
import 'package:bdnewsreader/core/bootstrap/startup_controller.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/presentation/features/news/widgets/newspaper_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required Map<String, dynamic> news,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final startupController = StartupController();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        startupControllerProvider.overrideWith((ref) => startupController),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: NewspaperCard(
            news: news,
            mode: AppThemeMode.system,
            isFavorite: false,
            onFavoriteToggle: () {},
            searchQuery: '',
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('publisher card does not crash for empty or single-char names', (
    WidgetTester tester,
  ) async {
    await _pumpCard(tester, news: {'name': '', 'url': 'https://example.com'});
    expect(tester.takeException(), isNull);

    await _pumpCard(tester, news: {'name': 'A', 'url': 'https://example.com'});
    expect(tester.takeException(), isNull);
  });
}
