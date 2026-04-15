import 'package:bdnewsreader/core/config/performance_config.dart';
import 'package:bdnewsreader/core/theme/theme.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';
import 'package:bdnewsreader/presentation/providers/tab_providers.dart';
import 'package:bdnewsreader/presentation/widgets/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatefulNavigationShell extends Mock
    implements StatefulNavigationShell {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockStatefulNavigationShell';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({
    required ProviderContainer container,
    required StatefulNavigationShell shell,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: PerformanceConfig.defaults(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            bottomNavigationBar: BottomNavBar(navigationShell: shell),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'bottom nav reflects tapped tab immediately before shell index catches up',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final shellIndex = 0;
      final shell = _MockStatefulNavigationShell();
      when(() => shell.currentIndex).thenAnswer((_) => shellIndex);
      when(
        () => shell.goBranch(
          any(),
          initialLocation: any(named: 'initialLocation'),
        ),
      ).thenAnswer((_) {});

      await tester.pumpWidget(buildTestApp(container: container, shell: shell));
      await tester.pumpAndSettle();

      expect(container.read(currentTabIndexProvider), 0);

      await tester.tap(find.text('Search'));
      await tester.pump();

      expect(container.read(currentTabIndexProvider), 2);
      expect(
        tester.widget<Text>(find.text('Search')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(shellIndex, 0);
      verify(() => shell.goBranch(2, initialLocation: true)).called(1);
    },
  );

  testWidgets(
    'bottom nav previews selected tab on pointer down before tap commit',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final shellIndex = 0;
      final shell = _MockStatefulNavigationShell();
      when(() => shell.currentIndex).thenAnswer((_) => shellIndex);
      when(
        () => shell.goBranch(
          any(),
          initialLocation: any(named: 'initialLocation'),
        ),
      ).thenAnswer((_) {});

      await tester.pumpWidget(buildTestApp(container: container, shell: shell));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Search')),
      );
      await tester.pump();

      expect(container.read(currentTabIndexProvider), 0);
      expect(
        tester.widget<Text>(find.text('Search')).style?.fontWeight,
        FontWeight.w700,
      );
      verifyNever(
        () => shell.goBranch(
          any(),
          initialLocation: any(named: 'initialLocation'),
        ),
      );

      await gesture.up();
      await tester.pump();

      expect(container.read(currentTabIndexProvider), 2);
      verify(() => shell.goBranch(2, initialLocation: true)).called(1);
    },
  );
}
