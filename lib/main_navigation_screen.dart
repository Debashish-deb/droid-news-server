import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/home/home_screen.dart';
import 'features/news/newspaper_screen.dart';
import 'features/magazine/magazine_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/extras/extras_screen.dart';
import 'l10n/app_localizations.dart';
import 'core/theme_provider.dart';
import 'core/theme.dart';

class MainNavigationScreen extends StatefulWidget {
  final int selectedTab;
  const MainNavigationScreen({Key? key, this.selectedTab = 0}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late final List<Widget> _tabs;

  final List<String> _iconNames = [
    'home',
    'newspapers',
    'magazines',
    'settings',
    'Extras',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedTab;
    _tabs = const [
      HomeScreen(),
      NewspaperScreen(),
      MagazineScreen(),
      SettingsScreen(),
      ExtrasScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final mode = themeProv.appThemeMode;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    final labels = [
      loc.home,
      loc.newspapers,
      loc.magazines,
      loc.settings,
      'Extras',
    ];

    final activeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppGradients.getGradientColors(mode),
    );

    final inactiveGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        cs.surfaceVariant.withOpacity(0.3),
        cs.surface.withOpacity(0.3),
      ],
    );

    String themeSuffix;
    switch (mode) {
      case AppThemeMode.dark:
        themeSuffix = 'dark';
        break;
      case AppThemeMode.bangladesh:
        themeSuffix = 'desh';
        break;
      default:
        themeSuffix = 'light';
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.background.withOpacity(0.85),
                  cs.surface.withOpacity(0.65),
                ],
              ),
              border: Border.all(color: themeProv.borderColor, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_tabs.length, (i) {
                final selected = i == _currentIndex;
                final String assetPath = 'assets/icons/${_iconNames[i]}_$themeSuffix.png';
                return GestureDetector(
                  onTap: () => _onItemTapped(i),
                  child: _buildNavIcon(
                    assetPath: assetPath,
                    label: labels[i],
                    selected: selected,
                    activeGradient: activeGradient,
                    inactiveGradient: inactiveGradient,
                    textTheme: textTheme,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon({
    required String assetPath,
    required String label,
    required bool selected,
    required Gradient activeGradient,
    required Gradient inactiveGradient,
    required TextTheme textTheme,
  }) {
    final double size = 60;
    final double iconSize = size;
    final Color shadowColor =
        selected ? activeGradient.colors.first.withOpacity(0.4) : Colors.black26;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected ? activeGradient : inactiveGradient,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Image.asset(
              assetPath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: selected
                ? textTheme.labelLarge?.color
                : textTheme.labelLarge?.color?.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
