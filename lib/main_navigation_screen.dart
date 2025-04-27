import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';        // <-- HomeScreen must be imported
import 'features/magazine/magazine_screen.dart';
import 'features/news/newspaper_screen.dart';
import 'features/settings/settings_screen.dart';
import 'widgets/app_drawer.dart';
import 'localization/l10n/app_localizations.dart';

class MainNavigationScreen extends StatefulWidget {
  final int selectedTab;
  const MainNavigationScreen({super.key, this.selectedTab = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  // 1) Create a GlobalKey for the public HomeScreenState
  final GlobalKey<HomeScreenState> _homeKey =
      GlobalKey<HomeScreenState>();

  // 2) Assign the key when instantiating HomeScreen
  late final List<Widget> _tabs = [
    HomeScreen(key: _homeKey),
    const NewspaperScreen(),
    const MagazineScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedTab;
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;

    setState(() => _currentIndex = index);

    // 3) When user taps the Home tab, tell it to reset itself
    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _homeKey.currentState?.resetFromNav();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final List<Color> tabColors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.primary.withOpacity(0.8),
    ];

    final labels = [
      loc.home,
      loc.newspapers,
      loc.magazines,
      loc.settings
    ];
    final icons = [
      Icons.home,
      Icons.article,
      Icons.book,
      Icons.settings,
    ];

    return Scaffold(
      drawer: const AppDrawer(),
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.bottomNavigationBarTheme.backgroundColor ??
              theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedItemColor: tabColors[_currentIndex],
          unselectedItemColor:
              theme.colorScheme.onSurface.withOpacity(0.6),
          items: List.generate(_tabs.length, (index) {
            final isSelected = index == _currentIndex;
            final color = tabColors[index];
            return BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(6),
                decoration: isSelected
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.7),
                            color
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                    : null,
                child: Icon(
                  icons[index],
                  size: isSelected ? 30 : 24,
                  color: isSelected ? Colors.white : null,
                ),
              ),
              label: labels[index],
            );
          }),
        ),
      ),
    );
  }
}
