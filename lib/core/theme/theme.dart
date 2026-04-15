import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../enums/theme_mode.dart';
import 'design_tokens.dart';
import '../../presentation/widgets/premium_shell_palette.dart';
import '../../presentation/widgets/publisher_brand_palette.dart';

class AppTheme {
  const AppTheme._();

  static const Color _primaryBlue = Color(0xFF0061A4);
  static const Color _lightBackground = Color(0xFFF8F9FF);
  static const Color _gold = AppColors.gold;
  static const Color _darkBackground = AppColors.darkBackground;
  static const Color _darkBackgroundGradientEnd = AppColors.darkSurface;
  static const Color _amoledBackground = Color(0xFF131E2A);
  static const Color _amoledSurface = Color(0xFF1A2A3B);
  static const Color _amoledCard = Color(0xFF22354A);
  static const Color _amoledCardBorder = Color(0xFF4B6787);
  static const Color _amoledSurfaceHigh = Color(0xFF2A3F57);
  static const Color _deshBackground = Color(0xFF12362F);
  static const Color _deshSurface = Color(0xFF1A473E);
  static const Color _deshCard = Color(0xFF24584D);
  static const Color _deshBorder = Color(0x8CFFFFFF);
  static const Color _deshAccent = Color(0xFF2DBE86);
  static const Color _deshAccentSoft = Color(0xFF8ADDB5);
  static const AppThemeColorCombination _darkColorCombination =
      AppThemeColorCombination(
        glassColor: Color(0xE02B3033),
        glassShadowColor: Color(0x38000000),
        borderColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFFFFFFFF),
        navIndicatorColor: Color(0x33FF5A5F),
        textColor: Color(0xFFFFFFFF),
      );
  static const AppThemeColorCombination _bangladeshColorCombination =
      AppThemeColorCombination(
        glassColor: Color(0x9900392C),
        glassShadowColor: Color(0x38000000),
        borderColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFFFFFFFF),
        navIndicatorColor: Color(0x2EFFFFFF),
        textColor: Color(0xFFFFFFFF),
      );
  static const AppThemeColorCombination _systemDarkColorCombination =
      AppThemeColorCombination(
        glassColor: Color(0xB8151A21),
        glassShadowColor: Color(0x3D000000),
        borderColor: Color(0xFFFFFFFF),
        selectionColor: Color(0xFFFFFFFF),
        navIndicatorColor: Color(0x2EFFFFFF),
        textColor: Color(0xFFFFFFFF),
      );
  static const AppThemeColorCombination _systemLightColorCombination =
      AppThemeColorCombination(
        glassColor: Color(0xCCFFFFFF),
        glassShadowColor: Color(0x1F000000),
        borderColor: Color(0xFF000000),
        selectionColor: Color(0xFF000000),
        navIndicatorColor: Color(0x2E000000),
        textColor: Color(0xFF000000),
      );

  static const Color _secondaryLight = Color(0xFF535F70);

  /// Returns a theme-owned color combination for non-structural UI accents.
  ///
  /// The skeleton (geometry/sizing) remains shared globally; only this color
  /// set varies by selected theme mode.
  static AppThemeColorCombination colorCombinationForMode(
    AppThemeMode mode, {
    Brightness systemBrightness = Brightness.light,
  }) {
    switch (normalizeThemeMode(mode)) {
      case AppThemeMode.dark:
        return _darkColorCombination;
      case AppThemeMode.bangladesh:
        return _bangladeshColorCombination;
      case AppThemeMode.system:
        return systemBrightness == Brightness.dark
            ? _systemDarkColorCombination
            : _systemLightColorCombination;
    }
  }

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
    iconTheme: const IconThemeData(
      color: Color(0xFF191C1E),
      size: AppSize.iconLg,
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(AppSize.minTouchTarget, AppSize.minTouchTarget),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

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
    filledButtonTheme: _filledButtonTheme(_primaryBlue, lightColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_primaryBlue, lightColorScheme),
    textButtonTheme: _textButtonTheme(_primaryBlue, lightColorScheme),

    pageTransitionsTheme: _androidTransitions,
    extensions: [
      const AppColorsExtension(
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
        slideBlue: AppColors.slideBlue,
        slideGreen: AppColors.slideGreen,
        slideRed: AppColors.slideRed,
      ),
      const AppThemeRulesExtension(
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
        accentGlowColor: Color(0xFF0061A4),
      ),
      _lightPremiumPalette,
      _lightPublisherBrandPalette,
    ],
  );

  static ThemeData lightThemeForScheme(ColorScheme scheme) =>
      lightTheme.copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.background,
        textTheme: _lightTextThemeFor(scheme),
        appBarTheme: _lightAppBarTheme(scheme),
        cardTheme: _lightCardThemeForScheme(scheme),
        inputDecorationTheme: _inputDecorationTheme(scheme),
        dropdownMenuTheme: _dropdownMenuTheme(scheme),
        chipTheme: _chipTheme(scheme),
        dividerTheme: _dividerTheme(scheme),
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppSize.iconLg),
        navigationBarTheme: _navigationBarTheme(scheme),
        tabBarTheme: _tabBarTheme(scheme),
        bottomSheetTheme: _bottomSheetTheme(scheme),
        snackBarTheme: _snackBarTheme(scheme),
        dialogTheme: _dialogTheme(scheme),
        listTileTheme: _listTileTheme(scheme),
        switchTheme: _switchTheme(scheme, scheme.primary),
        floatingActionButtonTheme: _fabTheme(scheme, scheme.primary),
        elevatedButtonTheme: _elevatedButtonTheme(scheme.primary, scheme),
        filledButtonTheme: _filledButtonTheme(scheme.primary, scheme),
        outlinedButtonTheme: _outlinedButtonTheme(scheme.primary, scheme),
        textButtonTheme: _textButtonTheme(scheme.primary, scheme),
        extensions: <ThemeExtension<dynamic>>[
          _lightColorsExtension(scheme),
          _lightThemeRulesExtension(scheme),
          _premiumPaletteForScheme(scheme),
          _publisherBrandPaletteForScheme(scheme),
        ],
      );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: _darkBackground,
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
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(AppSize.minTouchTarget, AppSize.minTouchTarget),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

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
    filledButtonTheme: _filledButtonTheme(_gold, darkColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, darkColorScheme),
    textButtonTheme: _textButtonTheme(_gold, darkColorScheme),

    iconTheme: const IconThemeData(
      color: Color(0xFFF2F2FA),
      size: AppSize.iconLg,
    ),

    pageTransitionsTheme: _androidTransitions,
    extensions: [
      const AppColorsExtension(
        bg: _darkBackground,
        surface: AppColors.darkSurface,
        card: AppColors.darkSecondary,
        cardBorder: AppColors.darkTertiary,
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFEBEBEF),
        textHint: Color(0xFFA1A1A1),
        goldStart: Color(0xFFD4A853),
        goldMid: Color(0xFFB8893C),
        goldGlow: Color(0x33D4A853),
        successGreen: Color(0xFF22C55E),
        errorRed: Color(0xFFEF4444),
        proBlue: AppColors.dashboardRed,
        slideBlue: AppColors.slideBlueDark,
        slideGreen: AppColors.slideGreenDark,
        slideRed: AppColors.slideRedDark,
      ),
      const AppThemeRulesExtension(
        drawerBrandColor: AppColors.dashboardRed,
        navSurface: Color(0xF0171B1D),
        navSurfaceTint: Color(0x0DFFFFFF),
        navTopBorder: Color(0x1AFFFFFF),
        navActiveIcon: Color(0xFFFFFFFF),
        navInactiveIcon: Color(0x99FFFFFF),
        navActiveLabel: Color(0xFFFFFFFF),
        navInactiveLabel: Color(0x99FFFFFF),
        navIndicator: Color(0x33FF5A5F),
        navIndicatorSplash: Color(0x1AFF5A5F),
        navShadow: Color(0x80000000),
        navBlurEnabled: false,
        themeWaveColor: Color(0x33FF5A5F),
        accentGlowColor: AppColors.dashboardRed,
      ),
      _darkPremiumPalette,
      _darkPublisherBrandPalette,
    ],
  );

  static final ThemeData _amoledTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: amoledColorScheme,
    scaffoldBackgroundColor: _amoledBackground,
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
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(AppSize.minTouchTarget, AppSize.minTouchTarget),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

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
    filledButtonTheme: _filledButtonTheme(_gold, amoledColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(_gold, amoledColorScheme),
    textButtonTheme: _textButtonTheme(_gold, amoledColorScheme),

    iconTheme: const IconThemeData(
      color: Color(0xFFEBEBF5),
      size: AppSize.iconLg,
    ),

    pageTransitionsTheme: _androidTransitions,
    extensions: [
      const AppColorsExtension(
        bg: _amoledBackground,
        surface: _amoledSurface,
        card: _amoledCard,
        cardBorder: _amoledCardBorder,
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFEBEBF5),
        textHint: Color(0xFF8E8E93),
        goldStart: Color(0xFFD4A853),
        goldMid: Color(0xFFB8893C),
        goldGlow: Color(0x33D4A853),
        successGreen: Color(0xFF22C55E),
        errorRed: Color(0xFFFF453A),
        proBlue: Color(0xFF0A84FF),
        slideBlue: AppColors.slideBlueDark,
        slideGreen: AppColors.slideGreenDark,
        slideRed: AppColors.slideRedDark,
      ),
      const AppThemeRulesExtension(
        drawerBrandColor: Color(0xFFFFC247),
        navSurface: Color(0xF0131E2A),
        navSurfaceTint: Color(0x0DFFFFFF),
        navTopBorder: Color(0x4DFFFFFF),
        navActiveIcon: Color(0xFFFFFFFF),
        navInactiveIcon: Color(0xE6FFFFFF),
        navActiveLabel: Color(0xFFFFFFFF),
        navInactiveLabel: Color(0xE6FFFFFF),
        navIndicator: Color(0x33FFFFFF),
        navIndicatorSplash: Color(0x1FFFFFFF),
        navShadow: Color(0x7A06101B),
        navBlurEnabled: false,
        themeWaveColor: Color(0x66FFC247),
        accentGlowColor: Color(0xFFFFD700),
      ),
      _amoledPremiumPalette,
      _amoledPublisherBrandPalette,
    ],
  );

  static ThemeData get amoledTheme => _amoledTheme;

  static final ThemeData bangladeshTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: bangladeshColorScheme,
    scaffoldBackgroundColor: _deshBackground,
    textTheme: _bangladeshTextTheme,
    appBarTheme: _bangladeshAppBarTheme(bangladeshColorScheme),
    cardTheme: _bangladeshCardTheme,
    inputDecorationTheme: _inputDecorationTheme(
      bangladeshColorScheme,
      overrideFocus: _deshAccent,
    ),
    dropdownMenuTheme: _dropdownMenuTheme(bangladeshColorScheme),
    chipTheme: _chipTheme(bangladeshColorScheme),
    dividerTheme: _dividerTheme(bangladeshColorScheme),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(
          Size(AppSize.minTouchTarget, AppSize.minTouchTarget),
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    splashFactory: InkSparkle.splashFactory,
    navigationBarTheme: _navigationBarTheme(bangladeshColorScheme),
    tabBarTheme: _tabBarTheme(bangladeshColorScheme),
    bottomSheetTheme: _bottomSheetTheme(bangladeshColorScheme),
    snackBarTheme: _snackBarTheme(bangladeshColorScheme),
    dialogTheme: _dialogTheme(bangladeshColorScheme),
    listTileTheme: _listTileTheme(bangladeshColorScheme),
    switchTheme: _switchTheme(bangladeshColorScheme, _deshAccent),
    floatingActionButtonTheme: _fabTheme(bangladeshColorScheme, _deshAccent),

    elevatedButtonTheme: _elevatedButtonTheme(
      _deshAccent,
      bangladeshColorScheme,
    ),
    filledButtonTheme: _filledButtonTheme(_deshAccent, bangladeshColorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(
      _deshAccent,
      bangladeshColorScheme,
    ),
    textButtonTheme: _textButtonTheme(_deshAccent, bangladeshColorScheme),

    iconTheme: const IconThemeData(
      color: _deshAccentSoft,
      size: AppSize.iconLg,
    ),
    primaryIconTheme: const IconThemeData(
      color: _deshAccentSoft,
      size: AppSize.iconLg,
    ),

    pageTransitionsTheme: _androidTransitions,
    extensions: [
      const AppColorsExtension(
        bg: _deshBackground,
        surface: _deshSurface,
        card: _deshCard,
        cardBorder: _deshBorder,
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFC5E2D4),
        textHint: Color(0xFF729886),
        goldStart: Color(0xFFFFD700),
        goldMid: Color(0xFFD4AF37),
        goldGlow: Color(0x33FFD700),
        successGreen: _deshAccent,
        errorRed: Color(0xFFF44336),
        proBlue: _deshAccentSoft,
        slideBlue: AppColors.slideBlueDark,
        slideGreen: AppColors.slideGreenDark,
        slideRed: AppColors.slideRedDark,
      ),
      const AppThemeRulesExtension(
        drawerBrandColor: _deshAccentSoft,
        navSurface: Color(0xF50A251B),
        navSurfaceTint: Color(0x14239167),
        navTopBorder: Color(0x52FFFFFF),
        navActiveIcon: Color(0xFFFFFFFF),
        navInactiveIcon: Color(0xEBFFFFFF),
        navActiveLabel: Color(0xFFFFFFFF),
        navInactiveLabel: Color(0xEBFFFFFF),
        navIndicator: Color(0xFF2C8F67),
        navIndicatorSplash: Color(0x262C8F67),
        navShadow: Color(0x8C000000),
        navBlurEnabled: false,
        themeWaveColor: Color(0x29FFFFFF),
        accentGlowColor: Color(0xB3FFFFFF),
      ),
      _bangladeshPremiumPalette,
      _bangladeshPublisherBrandPalette,
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
    return AppTypography.style(
      size: fontSize,
      weight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
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
      color: Colors.white,
      height: 1.4,
    ),

    labelLarge: _fontStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: _gold,
    ),
  );

  static TextTheme _lightTextThemeFor(ColorScheme scheme) {
    final base = _lightTextTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return base.copyWith(
      bodyMedium: base.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      bodySmall: base.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(color: scheme.primary),
    );
  }

  static AppColorsExtension _lightColorsExtension(ColorScheme scheme) =>
      AppColorsExtension(
        bg: scheme.background,
        surface: scheme.surface,
        card: scheme.surface,
        cardBorder: scheme.outlineVariant.withValues(alpha: 0.88),
        textPrimary: scheme.onSurface,
        textSecondary: scheme.onSurfaceVariant,
        textHint: scheme.onSurfaceVariant.withValues(alpha: 0.82),
        goldStart: const Color(0xFFD4A853),
        goldMid: const Color(0xFFB8893C),
        goldGlow: const Color(0x33D4A853),
        successGreen: const Color(0xFF22C55E),
        errorRed: scheme.error,
        proBlue: scheme.primary,
        slideBlue: AppColors.slideBlue,
        slideGreen: AppColors.slideGreen,
        slideRed: AppColors.slideRed,
      );

  static AppThemeRulesExtension _lightThemeRulesExtension(ColorScheme scheme) =>
      AppThemeRulesExtension(
        drawerBrandColor: scheme.primary,
        navSurface: scheme.surface.withValues(alpha: 0.92),
        navSurfaceTint: scheme.primary.withValues(alpha: 0.08),
        navTopBorder: scheme.outline.withValues(alpha: 0.28),
        navActiveIcon: scheme.onSurface,
        navInactiveIcon: scheme.onSurfaceVariant.withValues(alpha: 0.86),
        navActiveLabel: scheme.onSurface,
        navInactiveLabel: scheme.onSurfaceVariant.withValues(alpha: 0.86),
        navIndicator: scheme.primary.withValues(alpha: 0.14),
        navIndicatorSplash: scheme.primary.withValues(alpha: 0.08),
        navShadow: scheme.shadow.withValues(alpha: 0.12),
        navBlurEnabled: false,
        themeWaveColor: scheme.primary.withValues(alpha: 0.38),
        accentGlowColor: scheme.primary,
      );

  static AppBarTheme _lightAppBarTheme(ColorScheme scheme) => AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: const Color(0xFF191C1E),
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: _overlayStyle(Brightness.light),
    iconTheme: const IconThemeData(
      color: Color(0xFF191C1E),
      size: AppSize.iconLg,
    ),
    actionsIconTheme: const IconThemeData(
      color: Color(0xFF191C1E),
      size: AppSize.iconLg,
    ),
    titleTextStyle: AppTypography.style(
      size: AppTypography.titleLarge,
      weight: FontWeight.w700,
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
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: AppSize.iconLg,
        ),
        actionsIconTheme: const IconThemeData(
          color: Colors.white,
          size: AppSize.iconLg,
        ),
        titleTextStyle: AppTypography.style(
          size: AppTypography.titleLarge,
          weight: FontWeight.w700,
          color: Colors.white,
        ),
        scrolledUnderElevation: 0,
      );

  static AppBarTheme _amoledAppBarTheme(ColorScheme scheme) => AppBarTheme(
    backgroundColor: _amoledBackground,
    foregroundColor: const Color(0xFFFFFFFF),
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: _overlayStyle(Brightness.dark),
    iconTheme: const IconThemeData(
      color: Color(0xFFFFFFFF),
      size: AppSize.iconLg,
    ),
    actionsIconTheme: const IconThemeData(
      color: Color(0xFFFFFFFF),
      size: AppSize.iconLg,
    ),
    titleTextStyle: AppTypography.style(
      size: AppSpacing.xl,
      weight: FontWeight.w700,
      letterSpacing: 0.38,
      color: const Color(0xFFFFFFFF),
    ),
    scrolledUnderElevation: 0,
  );

  static AppBarTheme _bangladeshAppBarTheme(ColorScheme scheme) => AppBarTheme(
    backgroundColor: _deshBackground,
    foregroundColor: _deshAccentSoft,
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: _overlayStyle(Brightness.dark),
    iconTheme: const IconThemeData(
      color: _deshAccentSoft,
      size: AppSize.iconLg,
    ),
    actionsIconTheme: const IconThemeData(
      color: _deshAccentSoft,
      size: AppSize.iconLg,
    ),
    titleTextStyle: AppTypography.style(
      size: AppSpacing.xl,
      weight: FontWeight.w700,
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
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.10),
          scheme.primaryContainer,
        ),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        height: AppSize.navBarHeight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: AppSize.iconLg,
            color: selected
                ? _contrastLabelColor(scheme)
                : scheme.onSurfaceVariant.withValues(alpha: 0.86),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final labelColor = selected
              ? _contrastLabelColor(scheme)
              : _contrastMutedLabelColor(scheme);
          return AppTypography.style(
            size: AppSize.navLabelSize,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
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
      labelStyle: AppTypography.style(
        size: AppTypography.titleSmall,
        weight: FontWeight.w800,
        color: labelColor,
      ),
      unselectedLabelStyle: AppTypography.style(
        size: AppTypography.titleSmall,
        weight: FontWeight.w700,
        color: labelColor.withValues(alpha: 0.92),
      ),
    );
  }

  static FloatingActionButtonThemeData _fabTheme(
    ColorScheme scheme,
    Color accent,
  ) => FloatingActionButtonThemeData(
    backgroundColor: accent,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
    elevation: AppElevation.level1,
    hoverElevation: AppElevation.level2,
    focusElevation: AppElevation.level2,
    highlightElevation: AppElevation.level3,
  );

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme scheme) =>
      BottomSheetThemeData(
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(
          AppSize.dragHandleWidth,
          AppSize.dragHandleHeight,
        ),
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        elevation: AppElevation.none,
      );

  static SnackBarThemeData _snackBarTheme(ColorScheme scheme) =>
      SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        backgroundColor: scheme.primary,
        contentTextStyle: AppTypography.style(
          size: AppTypography.bodyMedium,
          weight: FontWeight.w700,
          color: scheme.onPrimary,
          letterSpacing: 0.1,
        ),
        elevation: AppElevation.level4,
      );

  static DialogThemeData _dialogTheme(ColorScheme scheme) => DialogThemeData(
    backgroundColor: scheme.surface,
    elevation: AppElevation.none,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xxlBorder,
      side: BorderSide(color: scheme.outlineVariant, width: 0.5),
    ),
    titleTextStyle: AppTypography.style(
      size: AppTypography.headlineSmall,
      weight: FontWeight.w800,
      color: scheme.primary,
      letterSpacing: -0.5,
    ),
    contentTextStyle: AppTypography.style(
      size: AppTypography.bodyLarge,
      weight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    ),
  );

  static ListTileThemeData _listTileTheme(ColorScheme scheme) =>
      ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        minLeadingWidth: AppSize.listTileMinLeadingWidth,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: AppTypography.style(
          size: AppTypography.titleMedium,
          weight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: AppTypography.style(
          size: AppTypography.bodyMedium,
          weight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
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
    elevation: AppElevation.none,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.lgBorder,
      side: const BorderSide(color: Color(0xFFDFE2EB)),
    ),
  );

  static CardThemeData _lightCardThemeForScheme(ColorScheme scheme) =>
      CardThemeData(
        color: scheme.surface,
        elevation: AppElevation.none,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.85),
          ),
        ),
      );

  static CardThemeData _darkCardTheme(Color gold) => CardThemeData(
    color: const Color(0xFF1A1A28), // Match Settings screen cards
    elevation: AppElevation.none,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.lgBorder,
      side: const BorderSide(
        color: Color(0xFF2A2A3E), // Match Settings screen card borders
      ),
    ),
  );

  static final CardThemeData _amoledCardTheme = CardThemeData(
    color: _amoledCard,
    elevation: AppElevation.none,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.lgBorder,
      side: const BorderSide(color: _amoledCardBorder),
    ),
  );

  static const CardThemeData _bangladeshCardTheme = CardThemeData(
    color: _deshCard,
    elevation: AppElevation.none,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      side: BorderSide(color: _deshBorder),
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
          AppTypography.style(
            size: AppTypography.labelLarge,
            weight: FontWeight.w800,
            color: labelColor,
            letterSpacing: 0.2,
          ),
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return AppElevation.level1;
          if (states.contains(WidgetState.hovered)) return AppElevation.level3;
          return AppElevation.none;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: borderColor.withValues(alpha: 0.25));
          }
          return BorderSide(color: borderColor, width: AppBorders.regular);
        }),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
        minimumSize: WidgetStateProperty.all(
          const Size(88, AppSize.buttonHeight),
        ),
        animationDuration: AppDuration.fast,
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(
    Color accent,
    ColorScheme scheme,
  ) {
    final labelColor = _contrastLabelColor(scheme);
    return FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.pressed)) {
            return accent.withValues(alpha: 0.84);
          }
          if (states.contains(WidgetState.hovered)) {
            return Color.alphaBlend(
              scheme.shadow.withValues(alpha: 0.08),
              accent,
            );
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
          AppTypography.style(
            size: AppTypography.labelLarge,
            weight: FontWeight.w800,
            color: labelColor,
            letterSpacing: 0.2,
          ),
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return AppElevation.level1;
          if (states.contains(WidgetState.hovered)) return AppElevation.level2;
          return AppElevation.none;
        }),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
        minimumSize: WidgetStateProperty.all(
          const Size(88, AppSize.buttonHeight),
        ),
        animationDuration: AppDuration.fast,
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
          AppTypography.style(
            size: AppTypography.labelLarge,
            weight: FontWeight.w800,
            color: labelColor,
            letterSpacing: 0.2,
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: labelColor.withValues(alpha: 0.18));
          }
          return BorderSide(
            color: borderColor,
            width: states.contains(WidgetState.pressed)
                ? AppBorders.regular
                : AppBorders.thin,
          );
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
        minimumSize: WidgetStateProperty.all(
          const Size(88, AppSize.buttonHeight),
        ),
        animationDuration: AppDuration.fast,
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
          AppTypography.style(
            size: AppTypography.labelLarge,
            weight: FontWeight.w800,
            color: labelColor,
            letterSpacing: 0.2,
          ),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: borderColor.withValues(alpha: 0.18));
          }
          return BorderSide(color: borderColor);
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
        minimumSize: WidgetStateProperty.all(
          const Size(64, AppSize.minTouchTarget),
        ),
        animationDuration: AppDuration.fast,
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
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerHighest,
      border: _outline(
        color: borderColor.withValues(alpha: isDark ? 0.5 : 0.35),
      ),
      enabledBorder: _outline(
        color: borderColor.withValues(alpha: isDark ? 0.62 : 0.45),
      ),
      focusedBorder: _outline(color: focus, width: 2.0),
      errorBorder: _outline(color: scheme.error),
      focusedErrorBorder: _outline(color: scheme.error, width: 2.0),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      hintStyle: AppTypography.style(
        size: AppTypography.bodyMedium,
        weight: FontWeight.w400,
        color: labelColor.withValues(alpha: isDark ? 0.72 : 0.75),
      ),
      labelStyle: AppTypography.style(
        size: AppTypography.bodyMedium,
        weight: FontWeight.w500,
        color: labelColor.withValues(alpha: isDark ? 0.88 : 0.95),
      ),
      floatingLabelStyle: AppTypography.style(
        size: AppTypography.bodyMedium,
        weight: FontWeight.w600,
        color: focus,
      ),
    );
  }

  static OutlineInputBorder _outline({Color? color, double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.mdBorder,
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
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          ),
        ),
      );

  static ChipThemeData _chipTheme(ColorScheme scheme) {
    final labelColor = _contrastLabelColor(scheme);
    return ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.primaryContainer,
      labelStyle: AppTypography.style(
        size: AppTypography.labelMedium,
        weight: FontWeight.w700,
        color: labelColor,
      ),
      secondaryLabelStyle: AppTypography.style(
        size: AppTypography.labelMedium,
        weight: FontWeight.w800,
        color: labelColor,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smBorder,
        side: BorderSide(color: labelColor),
      ),
    );
  }

  static DividerThemeData _dividerTheme(ColorScheme scheme) => DividerThemeData(
    thickness: AppBorders.thin,
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

  static PremiumShellPalette _premiumPaletteForScheme(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final isBangladeshTheme = cs.primary.value == _deshAccent.value;
    final isLightPremiumShell = !isDark && !isBangladeshTheme;

    final brand = isBangladeshTheme
        ? const Color(0xFFFFFFFF)
        : isDark
        ? const Color(0xFF46515A)
        : const Color(0xFF1565D8);
    final surface = cs.background;
    final darkHeaderBlendAlpha = isDark
        ? 0.34
        : isLightPremiumShell
        ? 0.42
        : 0.25;
    final darkFooterBlendAlpha = isDark
        ? 0.28
        : isLightPremiumShell
        ? 0.40
        : 0.24;

    // Header Set (Higher Intensity)
    final hStart = Color.alphaBlend(
      brand.withValues(alpha: darkHeaderBlendAlpha),
      surface,
    );
    final hMid = surface; // Keep the adjacent header arc clean for contrast.
    final hEnd =
        surface; // Fade back to a light section instead of blue-on-blue.

    // Footer Set (Lower Intensity)
    final fStart = isLightPremiumShell
        ? Color.alphaBlend(brand.withValues(alpha: 0.24), surface)
        : surface;
    final fMid = isLightPremiumShell
        ? Color.alphaBlend(brand.withValues(alpha: 0.18), surface)
        : surface;
    final fEnd = Color.alphaBlend(
      brand.withValues(alpha: darkFooterBlendAlpha),
      surface,
    );
    final waveColor = isBangladeshTheme
        ? const Color(0x5AA7E1C8)
        : isDark
        ? Color.alphaBlend(
            AppColors.dashboardRed.withValues(alpha: 0.16),
            AppColors.darkTertiary,
          )
        : Colors.white.withValues(alpha: 0.92);
    final iconBackground = isBangladeshTheme
        ? const Color(0x3396D6BE)
        : isDark
        ? Color.alphaBlend(
            AppColors.dashboardRed.withValues(alpha: 0.08),
            AppColors.darkSecondary,
          )
        : Colors.white.withValues(alpha: 0.76);
    final iconBorder = isBangladeshTheme
        ? const Color(0x80D8F2E6)
        : isDark
        ? AppColors.dashboardRed.withValues(alpha: 0.38)
        : Colors.white.withValues(alpha: 0.92);
    final textColor = isBangladeshTheme
        ? const Color(0xFFFCFFFD)
        : isDark
        ? Colors.white.withValues(alpha: 0.95)
        : const Color(0xFF253A56);
    final subtitleColor = isBangladeshTheme
        ? const Color(0xFFD5F4E4)
        : isDark
        ? Colors.white.withValues(alpha: 0.92)
        : const Color(0xFF2B4362);
    final glossColor = isBangladeshTheme
        ? const Color(0x33A7E1C8)
        : isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.white.withValues(alpha: 0.24);
    final borderColor = isBangladeshTheme
        ? Colors.white.withValues(alpha: 0.30)
        : isDark
        ? AppColors.dashboardRed.withValues(alpha: 0.24)
        : brand.withValues(alpha: 0.18);

    return PremiumShellPalette(
      gradientStart: hStart,
      gradientMid: hMid,
      gradientEnd: hEnd,
      waveColor: waveColor,
      iconBackground: iconBackground,
      iconBorder: iconBorder,
      textColor: textColor,
      subtitleColor: subtitleColor,
      glossColor: glossColor,
      borderColor: borderColor,
      headerGradient: LinearGradient(
        colors: [hStart, hMid, hEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      footerGradient: LinearGradient(
        colors: [fStart, fMid, fEnd],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
      glossGradient: LinearGradient(
        colors: [
          hStart.withValues(alpha: 0.6),
          hMid.withValues(alpha: 0.4),
          hEnd.withValues(alpha: 0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static PublisherBrandPalette _publisherBrandPaletteForScheme(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final isBangladeshTheme = cs.primary.value == _deshAccent.value;

    if (isBangladeshTheme) {
      return const PublisherBrandPalette(
        surfaceTop: Color(0xFF2E8C7B),
        surfaceBottom: Color(0xFF1D6659),
        surfaceBorder: Color(0xFFFFFFFF),
        accent: Color(0xFF4DB892),
        favoriteGlow: Color(0xFFFFFFFF),
        ambientGlow: Color(0xFF4DB892),
        shadow: Color(0xFF071F20),
      );
    }

    if (isDark) {
      return const PublisherBrandPalette(
        surfaceTop: Color(0xFF5A6268),
        surfaceBottom: Color(0xFF42494F),
        surfaceBorder: AppColors.dashboardRed,
        accent: AppColors.dashboardRed,
        favoriteGlow: AppColors.dashboardRed,
        ambientGlow: AppColors.dashboardRed,
        shadow: Color(0xFF080A0B),
      );
    }

    return PublisherBrandPalette(
      surfaceTop: Colors.white,
      surfaceBottom: cs.surface,
      surfaceBorder: cs.onSurface,
      accent: cs.primary,
      favoriteGlow: cs.primary,
      ambientGlow: cs.primary,
      shadow: cs.shadow,
    );
  }

  static final PremiumShellPalette _lightPremiumPalette =
      _premiumPaletteForScheme(lightColorScheme);
  static final PremiumShellPalette _darkPremiumPalette =
      _premiumPaletteForScheme(darkColorScheme);
  static final PremiumShellPalette _amoledPremiumPalette =
      _premiumPaletteForScheme(amoledColorScheme);
  static final PremiumShellPalette _bangladeshPremiumPalette =
      _premiumPaletteForScheme(bangladeshColorScheme);
  static final PublisherBrandPalette _lightPublisherBrandPalette =
      _publisherBrandPaletteForScheme(lightColorScheme);
  static final PublisherBrandPalette _darkPublisherBrandPalette =
      _publisherBrandPaletteForScheme(darkColorScheme);
  static final PublisherBrandPalette _amoledPublisherBrandPalette =
      _publisherBrandPaletteForScheme(amoledColorScheme);
  static final PublisherBrandPalette _bangladeshPublisherBrandPalette =
      _publisherBrandPaletteForScheme(bangladeshColorScheme);
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
  primary: AppColors.dashboardRed,
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFF93000A),
  onPrimaryContainer: Color(0xFFFFDAD6),
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
  background: AppTheme._darkBackground,
  surface: AppColors.darkSurface,
  surfaceVariant: AppColors.darkSecondary,
  onSurfaceVariant: Color(0xFFFFFFFF),
  outline: Color(0xFF8D9199),
);

const ColorScheme amoledColorScheme = ColorScheme.dark(
  primary: Color(0xFF8DC7FF),
  onPrimary: Color(0xFF0A1A2B),
  primaryContainer: Color(0xFF26415F),
  onPrimaryContainer: Color(0xFFE0F0FF),
  secondary: Color(0xFF9DBDDF),
  secondaryContainer: AppTheme._amoledSurface,
  onSecondaryContainer: Color(0xFFEBEBF5),
  tertiary: Color(0xFFC2DEFF),
  onTertiary: Color(0xFF08131E),
  error: Color(0xFFFF453A),
  errorContainer: Color(0xFF1A0000),
  onErrorContainer: Color(0xFFFF8A80),
  background: AppTheme._amoledBackground,
  surface: AppTheme._amoledBackground,
  surfaceVariant: AppTheme._amoledSurface,
  onSurfaceVariant: Color(0xFFEBEBF5),
  surfaceContainerHighest: AppTheme._amoledSurfaceHigh,
  outline: AppTheme._amoledCardBorder,
  outlineVariant: AppTheme._amoledSurface,
);

const ColorScheme bangladeshColorScheme = ColorScheme.dark(
  primary: AppTheme._deshAccent,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFF12543C),
  onPrimaryContainer: Color(0xFFD3F5E5),
  secondary: AppTheme._deshAccentSoft,
  secondaryContainer: Color(0xFF143E2F),
  onSecondaryContainer: Color(0xFFD7F0E4),
  tertiary: Color(0xFF49B486),
  onTertiary: Colors.white,
  background: AppTheme._deshBackground,
  surface: AppTheme._deshBackground,
  surfaceVariant: AppTheme._deshSurface,
  onSurfaceVariant: Colors.white,
  surfaceContainerHighest: AppTheme._deshCard,
  outline: AppTheme._deshBorder,
  outlineVariant: Color(0x52FFFFFF),
);

@immutable
class AppThemeColorCombination {
  const AppThemeColorCombination({
    required this.glassColor,
    required this.glassShadowColor,
    required this.borderColor,
    required this.selectionColor,
    required this.navIndicatorColor,
    required this.textColor,
  });

  final Color glassColor;
  final Color glassShadowColor;
  final Color borderColor;
  final Color selectionColor;
  final Color navIndicatorColor;
  final Color textColor;
}

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
    required this.slideBlue,
    required this.slideGreen,
    required this.slideRed,
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
  final Color slideBlue;
  final Color slideGreen;
  final Color slideRed;

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
    Color? slideBlue,
    Color? slideGreen,
    Color? slideRed,
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
      slideBlue: slideBlue ?? this.slideBlue,
      slideGreen: slideGreen ?? this.slideGreen,
      slideRed: slideRed ?? this.slideRed,
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
      slideBlue: Color.lerp(slideBlue, other.slideBlue, t)!,
      slideGreen: Color.lerp(slideGreen, other.slideGreen, t)!,
      slideRed: Color.lerp(slideRed, other.slideRed, t)!,
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
    required this.accentGlowColor,
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
  final Color accentGlowColor;

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
    Color? accentGlowColor,
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
      accentGlowColor: accentGlowColor ?? this.accentGlowColor,
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
      accentGlowColor: Color.lerp(accentGlowColor, other.accentGlowColor, t)!,
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
  static const List<Color> _darkBackgroundGradient = [
    AppTheme._darkBackground,
    AppTheme._darkBackgroundGradientEnd,
  ];
  static const List<Color> _lightBackgroundGradient = [
    Color(0xFFF8F9FF),
    Color(0xFFF2F2F7),
  ];
  static const List<Color> _deshBackgroundGradient = [
    AppTheme._deshBackground,
    AppTheme._deshSurface,
  ];
  static bool _isSystemDark() {
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  static List<Color> getGradientColors(AppThemeMode mode) {
    switch (normalizeThemeMode(mode)) {
      case AppThemeMode.dark:
        return _darkBackgroundGradient;
      case AppThemeMode.bangladesh:
        return _deshGradient;
      case AppThemeMode.system:
        return _isSystemDark() ? _darkBackgroundGradient : _lightGradient;
    }
  }

  static List<Color> getBackgroundGradient(AppThemeMode mode) {
    switch (normalizeThemeMode(mode)) {
      case AppThemeMode.dark:
        return _darkBackgroundGradient;
      case AppThemeMode.bangladesh:
        return _deshBackgroundGradient;
      case AppThemeMode.system:
        return _isSystemDark()
            ? _darkBackgroundGradient
            : _lightBackgroundGradient;
    }
  }

  static List<Color> getHighlightGradient(AppThemeMode mode) {
    return getGradientColors(mode);
  }
}
