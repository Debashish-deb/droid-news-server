import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:change_case/change_case.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/providers/theme_providers.dart';
import 'core/enums/theme_mode.dart';
import 'presentation/providers/tab_providers.dart';

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Optimize provider watching - only rebuild when specific values change
    final mode = ref.watch(themeProvider.select((s) => s.mode));
    final loc = AppLocalizations.of(context);

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final String locale = Localizations.localeOf(context).languageCode;

    // Cache color values - these are derived from theme, not direct providers
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
            return false; 
          }
          return true; 
        }

        navigationShell.goBranch(0);
        ref.read(tabProvider.notifier).setTab(0);
        return false;
      },
      child: Scaffold(
        body: navigationShell, 

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
            // Add RepaintBoundary to isolate expensive blur operation
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(iconNames.length, (int i) {
                      final bool selected = i == navigationShell.currentIndex;

                   
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
                              activeColor: ref.watch(navIconColorProvider),
                              mode: mode,
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
      ),
    );
  }

  void _onItemTapped(WidgetRef ref, int index) {
  
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
    required Color activeColor,
    required AppThemeMode mode,
  }) {

    const double iconSize = 26;

    final String displayLabel = locale == 'en' ? label.toSentenceCase() : label;
    
    // For Desh theme, inactive is Green; otherwise standard grey/opacity
    Color inactiveColor;
    if (mode == AppThemeMode.bangladesh) {
       inactiveColor = const Color(0xFF006A4E); // Green
    } else {
       inactiveColor = cs.onSurface.withOpacity(0.6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Simplified animation - removed AnimatedScale for better performance
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              selected ? activeIcon : icon,
              key: ValueKey(selected),
              size: iconSize,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: 4),
          
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? activeColor : inactiveColor,
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
