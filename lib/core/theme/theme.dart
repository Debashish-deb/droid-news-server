import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../enums/theme_mode.dart';
import 'design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static const Color _primaryBlue = Color(0xFF0061A4);
  static const Color _lightBackground = Color(0xFFF8F9FF);
  static const Color _gold = AppColors.gold;

  static const Color _secondaryLight = Color(0xFF535F70);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: lightColorScheme,
    scaffoldBackgroundColor: _lightBackground,
    textTheme: _lightTextTheme,
    appBarTheme: _lightAppBarTheme(lightColorScheme),
    cardTheme: _lightCardTheme,
    inputDecorationTheme: _inputDecorationTheme(lightColorScheme),
    dropdownMenuTheme: _dropdownMenuTheme(lightColorScheme),
    chipTheme: _chipTheme(lightColorScheme),
    dividerTheme: _dividerTheme(lightColorScheme),
    iconTheme: const IconThemeData(color: Color(0xFF191C1E), size: 24),

    splashFactory: InkSparkle.splashFactory,
    navigationBarTheme: _navigationBarTheme(lightColorScheme),
    tabBarTheme: _tabBarTheme(lightColorScheme),
    bottomSheetTheme: _bottomSheetTheme(lightColorScheme),
    snackBarTheme: _snackBarTheme(lightColorScheme),
    dialogTheme: _dialogTheme(lightColorScheme),
    listTileTheme: _listTileTheme(lightColorScheme),
    switchTheme: _switchTheme(lightColorScheme, _primaryBlue),
    floatingActionButtonTheme: _fabTheme(lightColorScheme, _primaryBlue),

    elevatedButtonTheme: _elevatedButtonTheme(_primaryBlue, lightColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_primaryBlue, lightColorScheme),
    textButtonTheme: _textButtonTheme(_primaryBlue, lightColorScheme),

    pageTransitionsTheme: _androidTransitions,
    extensions: const [
      AppColorsExtension(
        bg: _lightBackground,
        surface: Color(0xFFFFFFFF),
        card: Color(0xFFFFFFFF),
        cardBorder: Color(0xFFD1D1D1),
        textPrimary: Color(0xFF000000),
        textSecondary: Color(0xFF2C2C2C),
        textHint: Color(0xFF555555),
        goldStart: Color(0xFFD4A853),
        goldMid: Color(0xFFB8893C),
        goldGlow: Color(0x33D4A853),
        successGreen: Color(0xFF22C55E),
        errorRed: Color(0xFFBA1A1A),
        proBlue: _primaryBlue,
      ),
      AppThemeRulesExtension(
        drawerBrandColor: Color(0xFF1565D8),
        navSurface: Color(0xEBFFFFFF),
        navSurfaceTint: Color(0x0D1565D8),
        navTopBorder: Color(0x47000000),
        navActiveIcon: Color(0xFF111111),
        navInactiveIcon: Color(0xE6000000),
        navActiveLabel: Color(0xFF111111),
        navInactiveLabel: Color(0xE6000000),
        navIndicator: Color(0x24111111),
        navIndicatorSplash: Color(0x1A111111),
        navShadow: Color(0x1F000000),
        navBlurEnabled: false,
        themeWaveColor: Color(0x661565D8),
      ),
    ],
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: const Color(0xFF0B0B14),
    textTheme: _darkTextTheme,
    appBarTheme: _darkAppBarTheme(darkColorScheme, _gold),
    cardTheme: _darkCardTheme(_gold),
    inputDecorationTheme: _inputDecorationTheme(
      darkColorScheme,
      overrideFocus: _gold,
    ),
    dropdownMenuTheme: _dropdownMenuTheme(darkColorScheme),
    chipTheme: _chipTheme(darkColorScheme),
    dividerTheme: _dividerTheme(darkColorScheme),

    splashFactory: InkSparkle.splashFactory,
    navigationBarTheme: _navigationBarTheme(darkColorScheme),
    tabBarTheme: _tabBarTheme(darkColorScheme),
    bottomSheetTheme: _bottomSheetTheme(darkColorScheme),
    snackBarTheme: _snackBarTheme(darkColorScheme),
    dialogTheme: _dialogTheme(darkColorScheme),
    listTileTheme: _listTileTheme(darkColorScheme),
    switchTheme: _switchTheme(darkColorScheme, _gold),
    floatingActionButtonTheme: _fabTheme(darkColorScheme, _gold),

    elevatedButtonTheme: _elevatedButtonTheme(_gold, darkColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, darkColorScheme),
    textButtonTheme: _textButtonTheme(_gold, darkColorScheme),

    iconTheme: const IconThemeData(color: Color(0xFFF2F2FA), size: 24),

    pageTransitionsTheme: _androidTransitions,
    extensions: const [
      AppColorsExtension(
        bg: Color(0xFF0B0B14),
        surface: Color(0xFF13131F),
        card: Color(0xFF1A1A28),
        cardBorder: Color(0xFF2A2A3E),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFB0B0C8), // Fixed hierarchy
        textHint: Color(0xFFB0B0C0),
        goldStart: Color(0xFFD4A853),
        goldMid: Color(0xFFB8893C),
        goldGlow: Color(0x33D4A853),
        successGreen: Color(0xFF22C55E),
        errorRed: Color(0xFFEF4444),
        proBlue: Color(0xFF4F8EF7),
      ),
      AppThemeRulesExtension(
        drawerBrandColor: Color(0xFFFFC247),
        navSurface: Color(0xF013131F),
        navSurfaceTint: Color(0x0DFFFFFF),
        navTopBorder: Color(0x4DFFFFFF),
        navActiveIcon: Color(0xFFFFFFFF),
        navInactiveIcon: Color(0xE6FFFFFF),
        navActiveLabel: Color(0xFFFFFFFF),
        navInactiveLabel: Color(0xE6FFFFFF),
        navIndicator: Color(0x33FFFFFF),
        navIndicatorSplash: Color(0x1FFFFFFF),
        navShadow: Color(0x80000000),
        navBlurEnabled: false,
        themeWaveColor: Color(0x66FFC247),
      ),
    ],
  );

  static final ThemeData _amoledTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: amoledColorScheme,
    scaffoldBackgroundColor: Colors.black,
    textTheme: _darkTextTheme,
    appBarTheme: _amoledAppBarTheme(amoledColorScheme),
    cardTheme: _amoledCardTheme,
    inputDecorationTheme: _inputDecorationTheme(
      amoledColorScheme,
      overrideFocus: _gold,
    ),
    dropdownMenuTheme: _dropdownMenuTheme(amoledColorScheme),
    chipTheme: _chipTheme(amoledColorScheme),
    dividerTheme: _dividerTheme(amoledColorScheme),

    splashFactory: InkSparkle.splashFactory,
    navigationBarTheme: _navigationBarTheme(amoledColorScheme),
    tabBarTheme: _tabBarTheme(amoledColorScheme),
    bottomSheetTheme: _bottomSheetTheme(amoledColorScheme),
    snackBarTheme: _snackBarTheme(amoledColorScheme),
    dialogTheme: _dialogTheme(amoledColorScheme),
    listTileTheme: _listTileTheme(amoledColorScheme),
    switchTheme: _switchTheme(amoledColorScheme, _gold),
    floatingActionButtonTheme: _fabTheme(amoledColorScheme, _gold),

    elevatedButtonTheme: _elevatedButtonTheme(_gold, amoledColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, amoledColorScheme),
    textButtonTheme: _textButtonTheme(_gold, amoledColorScheme),

    iconTheme: const IconThemeData(color: Color(0xFFEBEBF5), size: 22),

    pageTransitionsTheme: _androidTransitions,
    extensions: const [
      AppColorsExtension(
        bg: Colors.black,
        surface: Color(0xFF0B0B0B),
        card: Color(0xFF000000),
        cardBorder: Color(0xFF1F1F1F),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFEBEBF5),
        textHint: Color(0xFF8E8E93),
        goldStart: Color(0xFFD4A853),
        goldMid: Color(0xFFB8893C),
        goldGlow: Color(0x33D4A853),
        successGreen: Color(0xFF22C55E),
        errorRed: Color(0xFFFF453A),
        proBlue: Color(0xFF0A84FF),
      ),
      AppThemeRulesExtension(
        drawerBrandColor: Color(0xFFFFC247),
        navSurface: Color(0xF0000000),
        navSurfaceTint: Color(0x08FFFFFF),
        navTopBorder: Color(0x57FFFFFF),
        navActiveIcon: Color(0xFFFFFFFF),
        navInactiveIcon: Color(0xE6FFFFFF),
        navActiveLabel: Color(0xFFFFFFFF),
        navInactiveLabel: Color(0xE6FFFFFF),
        navIndicator: Color(0x2EFFFFFF),
        navIndicatorSplash: Color(0x1FFFFFFF),
        navShadow: Color(0x99000000),
        navBlurEnabled: false,
        themeWaveColor: Color(0x66FFC247),
      ),
    ],
  );

  static ThemeData get amoledTheme => _amoledTheme;

  static final ThemeData bangladeshTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: bangladeshColorScheme,
    scaffoldBackgroundColor: const Color(0xFF000000),
    textTheme: _bangladeshTextTheme,
    appBarTheme: _bangladeshAppBarTheme(bangladeshColorScheme),
    cardTheme: _bangladeshCardTheme,
    inputDecorationTheme: _inputDecorationTheme(
      bangladeshColorScheme,
      overrideFocus: _gold,
    ),
    dropdownMenuTheme: _dropdownMenuTheme(bangladeshColorScheme),
    chipTheme: _chipTheme(bangladeshColorScheme),
    dividerTheme: _dividerTheme(bangladeshColorScheme),

    splashFactory: InkSparkle.splashFactory,
    navigationBarTheme: _navigationBarTheme(bangladeshColorScheme),
    tabBarTheme: _tabBarTheme(bangladeshColorScheme),
    bottomSheetTheme: _bottomSheetTheme(bangladeshColorScheme),
    snackBarTheme: _snackBarTheme(bangladeshColorScheme),
    dialogTheme: _dialogTheme(bangladeshColorScheme),
    listTileTheme: _listTileTheme(bangladeshColorScheme),
    switchTheme: _switchTheme(bangladeshColorScheme, _gold),
    floatingActionButtonTheme: _fabTheme(bangladeshColorScheme, _gold),

    elevatedButtonTheme: _elevatedButtonTheme(_gold, bangladeshColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, bangladeshColorScheme),
    textButtonTheme: _textButtonTheme(_gold, bangladeshColorScheme),

    iconTheme: const IconThemeData(color: _gold, size: 22),
    primaryIconTheme: const IconThemeData(color: _gold, size: 22),

    pageTransitionsTheme: _androidTransitions,
    extensions: const [
      AppColorsExtension(
        bg: Color(0xFF002117), // Deep Green
        surface: Color(0xFF003829),
        card: Color(0xFF004D38),
        cardBorder: Color(0xFF006A4E),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFB0D8C6),
        textHint: Color(0xFF5C8A75),
        goldStart: Color(0xFFFFD700),
        goldMid: Color(0xFFD4AF37),
        goldGlow: Color(0x33FFD700),
        successGreen: Color(0xFF006A4E),
        errorRed: Color(0xFFF44336),
        proBlue: Color(0xFF42A5F5),
      ),
      AppThemeRulesExtension(
        drawerBrandColor: Color(0xFF9E2B4D),
        navSurface: Color(0xF50D0F0E),
        navSurfaceTint: Color(0x14006A4E),
        navTopBorder: Color(0x52FFFFFF),
        navActiveIcon: Color(0xFFFFFFFF),
        navInactiveIcon: Color(0xEBFFFFFF),
        navActiveLabel: Color(0xFFFFFFFF),
        navInactiveLabel: Color(0xEBFFFFFF),
        navIndicator: Color(0xFFB63C54),
        navIndicatorSplash: Color(0x26B63C54),
        navShadow: Color(0x8C000000),
        navBlurEnabled: false,
        themeWaveColor: Color(0x66B63C54),
      ),
    ],
  );

  // PREMIUM TYPOGRAPHY HELPER
  // Standardized on Inter for best Android readability and premium feel
  static TextStyle _fontStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required double letterSpacing,
    required Color color,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
      decoration: TextDecoration.none,
    );
  }

  static final TextTheme _lightTextTheme = TextTheme(
    displayLarge: _fontStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: Colors.black,
      height: 1.12,
    ),
    displayMedium: _fontStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.black,
      height: 1.15,
    ),
    displaySmall: _fontStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.black,
      height: 1.22,
    ),

    headlineLarge: _fontStyle(
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.black,
    ),
    headlineMedium: _fontStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.black,
    ),
    headlineSmall: _fontStyle(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.black,
    ),

    titleLarge: _fontStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: Colors.black,
    ),
    titleMedium: _fontStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: Colors.black,
    ),
    titleSmall: _fontStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Colors.black,
    ),

    bodyLarge: _fontStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: Colors.black,
    ),
    bodyMedium: _fontStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: _secondaryLight,
    ),
    bodySmall: _fontStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: _secondaryLight,
    ),

    labelLarge: _fontStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: _primaryBlue,
    ),
  );

  static final TextTheme _darkTextTheme = TextTheme(
    displayLarge: _fontStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: Colors.white,
      height: 1.12,
    ),
    displayMedium: _fontStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.white,
      height: 1.15,
    ),
    displaySmall: _fontStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.white,
      height: 1.22,
    ),

    headlineLarge: _fontStyle(
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.white,
    ),
    headlineMedium: _fontStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.white,
    ),
    headlineSmall: _fontStyle(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: Colors.white,
    ),

    titleLarge: _fontStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: Colors.white,
    ),
    titleMedium: _fontStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: Colors.white,
    ),
    titleSmall: _fontStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Colors.white,
    ),

    bodyLarge: _fontStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: Colors.white,
    ),
    bodyMedium: _fontStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: Colors.white,
    ),
    bodySmall: _fontStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: Colors.white70,
    ),

    labelLarge: _fontStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Colors.white,
    ),
  );

  static final TextTheme _bangladeshTextTheme = TextTheme(
    displayLarge: _fontStyle(
      fontSize: 34,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.37,
      color: Colors.white,
      height: 1.2,
    ),
    displayMedium: _fontStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.36,
      color: Colors.white,
      height: 1.2,
    ),
    displaySmall: _fontStyle(
      fontSize: 22,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.35,
      color: Colors.white,
      height: 1.2,
    ),

    headlineMedium: _fontStyle(
      fontSize: 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.38,
      color: Colors.white,
      height: 1.2,
    ),
    headlineSmall: _fontStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.41,
      color: Colors.white,
      height: 1.3,
    ),

    titleLarge: _fontStyle(
      fontSize: 34,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.37,
      color: Colors.white,
    ),
    titleMedium: _fontStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.38,
      color: Colors.white,
    ),
    titleSmall: _fontStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.23,
      color: Colors.white,
    ),

    bodyLarge: _fontStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.41,
      color: Colors.white,
      height: 1.3,
    ),
    bodyMedium: _fontStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.23,
      color: Colors.white,
      height: 1.4,
    ),
    bodySmall: _fontStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.08,
      color: Colors.white,
      height: 1.4,
    ),

    labelLarge: _fontStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.1,
      color: _gold,
    ),
  );

  static AppBarTheme _lightAppBarTheme(ColorScheme scheme) => AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: const Color(0xFF191C1E),
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: _overlayStyle(Brightness.light),
    iconTheme: const IconThemeData(color: Color(0xFF191C1E), size: 24),
    actionsIconTheme: const IconThemeData(color: Color(0xFF191C1E), size: 24),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF191C1E),
    ),
    scrolledUnderElevation: 0,
  );

  static AppBarTheme _darkAppBarTheme(ColorScheme scheme, Color gold) =>
      AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: _overlayStyle(Brightness.dark),
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 24),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        scrolledUnderElevation: 0,
      );

  static AppBarTheme _amoledAppBarTheme(ColorScheme scheme) => AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: const Color(0xFFFFFFFF),
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: _overlayStyle(Brightness.dark),
    iconTheme: const IconThemeData(color: Color(0xFFFFFFFF), size: 22),
    actionsIconTheme: const IconThemeData(color: Color(0xFFFFFFFF), size: 22),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.38,
      color: const Color(0xFFFFFFFF),
    ),
    scrolledUnderElevation: 0,
  );

  static AppBarTheme _bangladeshAppBarTheme(ColorScheme scheme) => AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: _gold,
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: _overlayStyle(Brightness.dark),
    iconTheme: const IconThemeData(color: _gold, size: 22),
    actionsIconTheme: const IconThemeData(color: _gold, size: 22),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: Colors.white,
    ),
    scrolledUnderElevation: 0,
  );

  static SystemUiOverlayStyle _overlayStyle(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static Color _contrastLabelColor(ColorScheme scheme) {
    return scheme.brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  static Color _contrastMutedLabelColor(ColorScheme scheme) {
    final base = _contrastLabelColor(scheme);
    return base.withValues(
      alpha: scheme.brightness == Brightness.dark ? 0.94 : 0.96,
    );
  }

  static Color _contrastBorderColor(ColorScheme scheme) {
    final base = _contrastLabelColor(scheme);
    if (scheme.brightness == Brightness.light) {
      return const Color(0xFF111111);
    }
    return base.withValues(alpha: 0.72);
  }

  static NavigationBarThemeData _navigationBarTheme(ColorScheme scheme) =>
      NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final labelColor = selected
              ? _contrastLabelColor(scheme)
              : _contrastMutedLabelColor(scheme);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: labelColor,
          );
        }),
      );

  static TabBarThemeData _tabBarTheme(ColorScheme scheme) {
    final labelColor = _contrastLabelColor(scheme);
    return TabBarThemeData(
      labelColor: labelColor,
      unselectedLabelColor: labelColor.withValues(alpha: 0.92),
      indicatorColor: labelColor,
      dividerColor: _contrastBorderColor(
        scheme,
      ).withValues(alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.3),
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800),
      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
    );
  }

  static FloatingActionButtonThemeData _fabTheme(
    ColorScheme scheme,
    Color accent,
  ) => FloatingActionButtonThemeData(
    backgroundColor: accent,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 6,
    hoverElevation: 8,
    focusElevation: 8,
    highlightElevation: 12,
  );

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme scheme) =>
      BottomSheetThemeData(
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(32, 4),
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 0,
      );

  static SnackBarThemeData _snackBarTheme(ColorScheme scheme) =>
      SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.inter(color: scheme.onInverseSurface),
        elevation: 6,
      );

  static DialogThemeData _dialogTheme(ColorScheme scheme) => DialogThemeData(
    backgroundColor: scheme.surfaceContainerHigh,
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    ),
    contentTextStyle: GoogleFonts.inter(
      fontSize: 16,
      color: scheme.onSurfaceVariant,
    ),
  );

  static ListTileThemeData _listTileTheme(ColorScheme scheme) =>
      ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 24,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );

  static SwitchThemeData _switchTheme(ColorScheme scheme, Color accent) =>
      SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.5)
              : scheme.surfaceVariant,
        ),
      );

  static final CardThemeData _lightCardTheme = CardThemeData(
    color: const Color(0xFFFFFFFF),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFDFE2EB)),
    ),
  );

  static CardThemeData _darkCardTheme(Color gold) => CardThemeData(
    color: const Color(0xFF1A1A28), // Match Settings screen cards
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(
        color: Color(0xFF2A2A3E), // Match Settings screen card borders
      ),
    ),
  );

  static final CardThemeData _amoledCardTheme = CardThemeData(
    color: Colors.black,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF1F1F1F)),
    ),
  );

  static const CardThemeData _bangladeshCardTheme = CardThemeData(
    color: Color(0xFF1C1C1E),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: _gold),
    ),
  );

  static ElevatedButtonThemeData _elevatedButtonTheme(
    Color accent,
    ColorScheme scheme,
  ) {
    final labelColor = _contrastLabelColor(scheme);
    final borderColor = labelColor;

    return ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.pressed)) {
            return accent.withValues(alpha: 0.8);
          }
          return accent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          return labelColor;
        }),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return 1;
          if (states.contains(WidgetState.hovered)) return 4;
          return 0; // Flat premium look
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(
              color: borderColor.withValues(alpha: 0.25),
              width: 1.2,
            );
          }
          return BorderSide(color: borderColor, width: 1.4);
        }),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        minimumSize: WidgetStateProperty.all(const Size(88, 50)),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(
    Color accent,
    ColorScheme scheme,
  ) {
    final labelColor = _contrastLabelColor(scheme);
    final borderColor = labelColor;
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return labelColor.withValues(alpha: 0.42);
          }
          return labelColor;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return accent.withValues(alpha: 0.10);
          }
          if (states.contains(WidgetState.hovered)) {
            return accent.withValues(alpha: 0.05);
          }
          return Colors.transparent;
        }),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: labelColor.withValues(alpha: 0.18));
          }
          return BorderSide(
            color: borderColor,
            width: states.contains(WidgetState.pressed) ? 1.4 : 1.2,
          );
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        minimumSize: WidgetStateProperty.all(const Size(88, 50)),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(
    Color accent,
    ColorScheme scheme,
  ) {
    final labelColor = _contrastLabelColor(scheme);
    final borderColor = labelColor;
    return TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return labelColor.withValues(alpha: 0.42);
          }
          return labelColor;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return accent.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return accent.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: borderColor.withValues(alpha: 0.18));
          }
          return BorderSide(color: borderColor, width: 1.2);
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        minimumSize: WidgetStateProperty.all(const Size(64, 44)),
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    ColorScheme scheme, {
    Color? overrideFocus,
  }) {
    final focus = overrideFocus ?? scheme.primary;
    final isDark = scheme.brightness == Brightness.dark;
    final labelColor = _contrastLabelColor(scheme);
    final borderColor = _contrastBorderColor(scheme);

    return InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? const Color(0xFF13131F)
          : const Color(0xFFF2F2F7), // Match Settings surface
      border: _outline(
        color: borderColor.withValues(alpha: isDark ? 0.5 : 0.35),
      ),
      enabledBorder: _outline(
        color: borderColor.withValues(alpha: isDark ? 0.62 : 0.45),
      ),
      focusedBorder: _outline(color: focus, width: 2.0),
      errorBorder: _outline(color: scheme.error),
      focusedErrorBorder: _outline(color: scheme.error, width: 2.0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(
        color: labelColor.withValues(alpha: isDark ? 0.72 : 0.75),
      ),
      labelStyle: GoogleFonts.inter(
        color: labelColor.withValues(alpha: isDark ? 0.88 : 0.95),
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: focus,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static OutlineInputBorder _outline({Color? color, double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: color ?? Colors.transparent,
          width: width,
        ),
      );

  static DropdownMenuThemeData _dropdownMenuTheme(ColorScheme scheme) =>
      DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(scheme.surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        ),
      );

  static ChipThemeData _chipTheme(ColorScheme scheme) {
    final labelColor = _contrastLabelColor(scheme);
    return ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      labelStyle: GoogleFonts.inter(
        color: labelColor,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        color: labelColor,
        fontWeight: FontWeight.w800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: labelColor, width: 1.1),
      ),
    );
  }

  static DividerThemeData _dividerTheme(ColorScheme scheme) => DividerThemeData(
    thickness: 1,
    color: _contrastBorderColor(
      scheme,
    ).withValues(alpha: scheme.brightness == Brightness.dark ? 0.25 : 0.18),
  );

  static const PageTransitionsTheme _androidTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android:
          PredictiveBackPageTransitionsBuilder(), // Modern Android
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );
}

// ─────────────────────────────────────────────
// COLOR SCHEMES
// ─────────────────────────────────────────────

const ColorScheme lightColorScheme = ColorScheme.light(
  primary: Color(0xFF0061A4),
  primaryContainer: Color(0xFFD1E4FF),
  onPrimaryContainer: Color(0xFF001D36),
  secondary: Color(0xFF535F70),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFD7E3F7),
  onSecondaryContainer: Color(0xFF101C2B),
  tertiary: Color(0xFF6B5778),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFF2DAFF),
  onTertiaryContainer: Color(0xFF251431),
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  background: Color(0xFFF8F9FF),
  onBackground: Color(0xFF191C1E),
  surface: Color(0xFFF8F9FF),
  onSurface: Color(0xFF191C1E),
  surfaceVariant: Color(0xFFDFE2EB),
  onSurfaceVariant: Color(0xFF43474E),
  outline: Color(0xFF73777F),
);

const ColorScheme darkColorScheme = ColorScheme.dark(
  primary: Color(0xFF99CBFF),
  onPrimary: Color(0xFF003355),
  primaryContainer: Color(0xFF00497B),
  onPrimaryContainer: Color(0xFFD1E4FF),
  secondary: Color(0xFFBFC8D8),
  onSecondary: Color(0xFF29313E),
  secondaryContainer: Color(0xFF3F4756),
  onSecondaryContainer: Color(0xFFD7E3F7),
  tertiary: Color(0xFFD7BEE4),
  onTertiary: Color(0xFF3B2948),
  tertiaryContainer: Color(0xFF523F5F),
  onTertiaryContainer: Color(0xFFF3DAFF),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  background: Color(0xFF0B0B14), // Match Settings screen
  surface: Color(0xFF13131F), // Match Settings screen
  surfaceVariant: Color(0xFF43474E),
  onSurfaceVariant: Color(0xFFFFFFFF),
  outline: Color(0xFF8D9199),
);

const ColorScheme amoledColorScheme = ColorScheme.dark(
  primary: Color(0xFF0A84FF),
  onPrimary: Color(0xFF003366),
  primaryContainer: Color(0xFF00214D),
  onPrimaryContainer: Color(0xFFD6E9FF),
  secondary: Color(0xFF636366),
  secondaryContainer: Color(0xFF1C1C1E),
  onSecondaryContainer: Color(0xFFEBEBF5),
  tertiary: Color(0xFF64D2FF),
  onTertiary: Color(0xFF000000),
  error: Color(0xFFFF453A),
  errorContainer: Color(0xFF1A0000),
  onErrorContainer: Color(0xFFFF8A80),
  background: Color(0xFF000000),
  surface: Color(0xFF000000),
  surfaceVariant: Color(0xFF1C1C1E),
  onSurfaceVariant: Color(0xFFEBEBF5),
  surfaceContainerHighest: Color(0xFF0B0B0B),
  outline: Color(0xFF303030),
  outlineVariant: Color(0xFF1F1F1F),
);

const ColorScheme bangladeshColorScheme = ColorScheme.dark(
  primary: Color(0xFF006A4E),
  onPrimary: Colors.white,
  secondary: Color(0xFFFFD700),
  tertiary: Color(0xFFFFD700),
  background: Color(0xFF000000),
  surface: Color(0xFF000000),
  surfaceVariant: Color(0xFF0F0F10),
  onSurfaceVariant: Colors.white,
  surfaceContainerHighest: Color(0xFF0A0A0A),
  outline: Color(0xFFEFEFEF),
  outlineVariant: Color(0x80FFFFFF),
);

// ─────────────────────────────────────────────
// THEME EXTENSIONS
// ─────────────────────────────────────────────

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.bg,
    required this.surface,
    required this.card,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.goldStart,
    required this.goldMid,
    required this.goldGlow,
    required this.successGreen,
    required this.errorRed,
    required this.proBlue,
  });

  final Color bg;
  final Color surface;
  final Color card;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color goldStart;
  final Color goldMid;
  final Color goldGlow;
  final Color successGreen;
  final Color errorRed;
  final Color proBlue;

  @override
  AppColorsExtension copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? goldStart,
    Color? goldMid,
    Color? goldGlow,
    Color? successGreen,
    Color? errorRed,
    Color? proBlue,
  }) {
    return AppColorsExtension(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      goldStart: goldStart ?? this.goldStart,
      goldMid: goldMid ?? this.goldMid,
      goldGlow: goldGlow ?? this.goldGlow,
      successGreen: successGreen ?? this.successGreen,
      errorRed: errorRed ?? this.errorRed,
      proBlue: proBlue ?? this.proBlue,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      goldStart: Color.lerp(goldStart, other.goldStart, t)!,
      goldMid: Color.lerp(goldMid, other.goldMid, t)!,
      goldGlow: Color.lerp(goldGlow, other.goldGlow, t)!,
      successGreen: Color.lerp(successGreen, other.successGreen, t)!,
      errorRed: Color.lerp(errorRed, other.errorRed, t)!,
      proBlue: Color.lerp(proBlue, other.proBlue, t)!,
    );
  }
}

@immutable
class AppThemeRulesExtension extends ThemeExtension<AppThemeRulesExtension> {
  const AppThemeRulesExtension({
    required this.drawerBrandColor,
    required this.navSurface,
    required this.navSurfaceTint,
    required this.navTopBorder,
    required this.navActiveIcon,
    required this.navInactiveIcon,
    required this.navActiveLabel,
    required this.navInactiveLabel,
    required this.navIndicator,
    required this.navIndicatorSplash,
    required this.navShadow,
    required this.navBlurEnabled,
    required this.themeWaveColor,
  });

  final Color drawerBrandColor;
  final Color navSurface;
  final Color navSurfaceTint;
  final Color navTopBorder;
  final Color navActiveIcon;
  final Color navInactiveIcon;
  final Color navActiveLabel;
  final Color navInactiveLabel;
  final Color navIndicator;
  final Color navIndicatorSplash;
  final Color navShadow;
  final bool navBlurEnabled;
  final Color themeWaveColor;

  @override
  AppThemeRulesExtension copyWith({
    Color? drawerBrandColor,
    Color? navSurface,
    Color? navSurfaceTint,
    Color? navTopBorder,
    Color? navActiveIcon,
    Color? navInactiveIcon,
    Color? navActiveLabel,
    Color? navInactiveLabel,
    Color? navIndicator,
    Color? navIndicatorSplash,
    Color? navShadow,
    bool? navBlurEnabled,
    Color? themeWaveColor,
  }) {
    return AppThemeRulesExtension(
      drawerBrandColor: drawerBrandColor ?? this.drawerBrandColor,
      navSurface: navSurface ?? this.navSurface,
      navSurfaceTint: navSurfaceTint ?? this.navSurfaceTint,
      navTopBorder: navTopBorder ?? this.navTopBorder,
      navActiveIcon: navActiveIcon ?? this.navActiveIcon,
      navInactiveIcon: navInactiveIcon ?? this.navInactiveIcon,
      navActiveLabel: navActiveLabel ?? this.navActiveLabel,
      navInactiveLabel: navInactiveLabel ?? this.navInactiveLabel,
      navIndicator: navIndicator ?? this.navIndicator,
      navIndicatorSplash: navIndicatorSplash ?? this.navIndicatorSplash,
      navShadow: navShadow ?? this.navShadow,
      navBlurEnabled: navBlurEnabled ?? this.navBlurEnabled,
      themeWaveColor: themeWaveColor ?? this.themeWaveColor,
    );
  }

  @override
  AppThemeRulesExtension lerp(
    ThemeExtension<AppThemeRulesExtension>? other,
    double t,
  ) {
    if (other is! AppThemeRulesExtension) return this;
    return AppThemeRulesExtension(
      drawerBrandColor: Color.lerp(
        drawerBrandColor,
        other.drawerBrandColor,
        t,
      )!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      navSurfaceTint: Color.lerp(navSurfaceTint, other.navSurfaceTint, t)!,
      navTopBorder: Color.lerp(navTopBorder, other.navTopBorder, t)!,
      navActiveIcon: Color.lerp(navActiveIcon, other.navActiveIcon, t)!,
      navInactiveIcon: Color.lerp(navInactiveIcon, other.navInactiveIcon, t)!,
      navActiveLabel: Color.lerp(navActiveLabel, other.navActiveLabel, t)!,
      navInactiveLabel: Color.lerp(
        navInactiveLabel,
        other.navInactiveLabel,
        t,
      )!,
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t)!,
      navIndicatorSplash: Color.lerp(
        navIndicatorSplash,
        other.navIndicatorSplash,
        t,
      )!,
      navShadow: Color.lerp(navShadow, other.navShadow, t)!,
      navBlurEnabled: t < 0.5 ? navBlurEnabled : other.navBlurEnabled,
      themeWaveColor: Color.lerp(themeWaveColor, other.themeWaveColor, t)!,
    );
  }
}

// ─────────────────────────────────────────────
// GRADIENT UTILITY
// ─────────────────────────────────────────────

class AppGradients {
  const AppGradients._();

  static const List<Color> _lightGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFE0E0E0),
  ];
  static const List<Color> _deshGradient = [
    Color(0xFFFFD700),
    Color(0xFF006A4E),
  ];
  static const List<Color> _amoledGradient = [
    Color(0xFF000000),
    Color(0xFF000000),
  ];
  static const List<Color> _lightBackgroundGradient = [
    Color(0xFFF8F9FF),
    Color(0xFFF2F2F7),
  ];
  static const List<Color> _deshBackgroundGradient = [
    Color(0xFF006A4E),
    Color(0xFF450D15),
  ];
  static bool _isSystemDark() {
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  static List<Color> getGradientColors(AppThemeMode mode) {
    switch (normalizeThemeMode(mode)) {
      case AppThemeMode.amoled:
        return _amoledGradient;
      case AppThemeMode.bangladesh:
        return _deshGradient;
      case AppThemeMode.system:
      case AppThemeMode.light:
      case AppThemeMode.dark:
        return _isSystemDark() ? _amoledGradient : _lightGradient;
    }
  }

  static List<Color> getBackgroundGradient(AppThemeMode mode) {
    switch (normalizeThemeMode(mode)) {
      case AppThemeMode.amoled:
        return _amoledGradient;
      case AppThemeMode.bangladesh:
        return _deshBackgroundGradient;
      case AppThemeMode.system:
      case AppThemeMode.light:
      case AppThemeMode.dark:
        return _isSystemDark() ? _amoledGradient : _lightBackgroundGradient;
    }
  }

  static List<Color> getHighlightGradient(AppThemeMode mode) {
    return getGradientColors(mode);
  }
}
