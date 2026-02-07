import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/theme_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/theme_mode.dart';

class AppBarTitle extends ConsumerWidget {
  const AppBarTitle(this.title, {super.key, this.styleOverride});
  final String title;
  final TextStyle? styleOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = theme.brightness == Brightness.dark;
    final isDesh = themeMode == AppThemeMode.bangladesh;

    final appBarTextStyle = styleOverride ??
        theme.appBarTheme.titleTextStyle?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ) ??
        GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: (isDark || isDesh) ? Colors.white : Colors.black,
        );

    return Text(
      title,
      textAlign: TextAlign.center,
      style: appBarTextStyle,
    );
  }
}
