import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme colorCombinationForMode', () {
    test('returns dark combination for dark mode', () {
      final combo = AppTheme.colorCombinationForMode(AppThemeMode.dark);

      expect(combo.glassColor, const Color(0xE02B3033));
      expect(combo.borderColor, Colors.white);
      expect(combo.textColor, Colors.white);
    });

    test('returns bangladesh combination for desh mode', () {
      final combo = AppTheme.colorCombinationForMode(AppThemeMode.bangladesh);

      expect(combo.glassColor, const Color(0x9900392C));
      expect(combo.borderColor, Colors.white);
      expect(combo.navIndicatorColor, const Color(0x2EFFFFFF));
    });

    test('returns light system combination when platform is light', () {
      final combo = AppTheme.colorCombinationForMode(AppThemeMode.system);

      expect(combo.glassColor, const Color(0xCCFFFFFF));
      expect(combo.selectionColor, Colors.black);
      expect(combo.textColor, Colors.black);
    });

    test('returns dark system combination when platform is dark', () {
      final combo = AppTheme.colorCombinationForMode(
        AppThemeMode.system,
        systemBrightness: Brightness.dark,
      );

      expect(combo.glassColor, const Color(0xB8151A21));
      expect(combo.selectionColor, Colors.white);
      expect(combo.textColor, Colors.white);
    });
  });
}
