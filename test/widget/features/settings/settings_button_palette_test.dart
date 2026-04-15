import 'package:bdnewsreader/core/theme/theme.dart';
import 'package:bdnewsreader/presentation/features/settings/settings_button_palette.dart';
import 'package:bdnewsreader/presentation/widgets/premium_shell_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'active settings button palette reuses the premium shell palette',
    (tester) async {
      late SettingsButtonPalette buttonPalette;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              buttonPalette = resolveSettingsButtonPalette(
                context,
                active: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final shellPalette = AppTheme.lightTheme.extension<PremiumShellPalette>()!;
      final gradient = buttonPalette.decoration.gradient! as LinearGradient;

      expect(gradient.colors, <Color>[
        shellPalette.gradientStart,
        shellPalette.gradientMid,
        shellPalette.gradientEnd,
      ]);
      expect(buttonPalette.foreground, shellPalette.textColor);
    },
  );
}
