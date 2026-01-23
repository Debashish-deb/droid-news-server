import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:change_case/change_case.dart';
import 'l10n/app_localizations.dart';
import 'core/services/theme_providers.dart';
import 'core/theme_provider.dart';
import 'presentation/providers/theme_providers.dart';
import 'presentation/providers/tab_providers.dart';

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use Riverpod providers instead of legacy context.watch
    final themeState = ref.watch(themeProvider);
    final AppThemeMode mode = themeState.mode;
    final loc = AppLocalizations.of(context)!;

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final String locale = Localizations.localeOf(context).languageCode;

    // Get theme colors from Riverpod providers
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);

    final List<String> iconNames = <String>[
      'home',
      'newspapers',
      'magazines',
      'settings',
      'extras',
    ];

    final List<String> labels = <String>[
      loc.home,
      loc.newspapers,
      loc.magazines,
      loc.settings,
      getExtrasLabel(context),
    ];

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

    DateTime? lastBackPressed;

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();

        // If on first tab (home), require double press to exit
        if (navigationShell.currentIndex == 0) {
          if (lastBackPressed == null ||
              now.difference(lastBackPressed!) > const Duration(seconds: 2)) {
            lastBackPressed = now;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Text('👋', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        loc.pressBackToExit,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            return false; // Don't exit
          }
          return true; // Exit app
        }

        // For other tabs, go back to home
        navigationShell.goBranch(0);
        ref.read(tabProvider.notifier).setTab(0);
        return false;
      },
      child: Scaffold(
        body: navigationShell, // The branch content

        extendBody: true,
        bottomNavigationBar: UnconstrainedBox(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: borderColor.withOpacity(0.5),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
                if (mode == AppThemeMode.bangladesh)
                  const BoxShadow(
                    color: Color(0xFF006A4E),
                    blurRadius: 15,
                    spreadRadius: -5,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(iconNames.length, (int i) {
                      final bool selected = i == navigationShell.currentIndex;

                      // Vector Icons Logic
                      IconData icon;
                      IconData activeIcon;

                      switch (i) {
                        case 0:
                          icon = Icons.home_outlined;
                          activeIcon = Icons.home_rounded;
                          break;
                        case 1:
                          icon = Icons.newspaper_outlined;
                          activeIcon = Icons.newspaper_rounded;
                          break;
                        case 2:
                          icon = Icons.auto_stories_outlined;
                          activeIcon = Icons.auto_stories;
                          break;
                        case 3:
                          icon = Icons.settings_outlined;
                          activeIcon = Icons.settings_rounded;
                          break;
                        case 4:
                          icon = Icons.widgets_outlined;
                          activeIcon = Icons.widgets_rounded;
                          break;
                        default:
                          icon = Icons.circle_outlined;
                          activeIcon = Icons.circle;
                      }

                      return Expanded(
                        child: Semantics(
                          label:
                              '${labels[i]} tab${selected ? ', selected' : ''}',
                          button: true,
                          selected: selected,
                          child: GestureDetector(
                            onTap: () => _onItemTapped(ref, i),
                            behavior: HitTestBehavior.opaque,
                            child: _buildNavIcon(
                              icon: icon,
                              activeIcon: activeIcon,
                              label: labels[i],
                              selected: selected,
                              cs: cs,
                              textTheme: textTheme,
                              locale: locale,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onItemTapped(WidgetRef ref, int index) {
    // Broadcast tab change using Riverpod
    ref.read(tabProvider.notifier).setTab(index);
    navigationShell.goBranch(index);
  }

  Widget _buildNavIcon({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool selected,
    required ColorScheme cs,
    required TextTheme textTheme,
    required String locale,
  }) {
    // Stylish Vector Implementation
    const double iconSize = 26;

    final String displayLabel = locale == 'en' ? label.toSentenceCase() : label;
    final Color accentColor = cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Icon Animation
          AnimatedScale(
            scale: selected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                size: iconSize,
                color: selected ? accentColor : cs.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Label
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? accentColor : cs.onSurface.withOpacity(0.6),
              letterSpacing: -0.1,
            ),
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Hardcoded bilingual label for "Extras"
  String getExtrasLabel(BuildContext context) {
    final String locale = Localizations.localeOf(context).languageCode;
    return locale == 'bn' ? 'বিবিধ' : 'Extras';
  }
}
