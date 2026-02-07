import 'dart:ui';
import '../../core/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart';
import '../../core/enums/theme_mode.dart';

class BottomNavBar extends ConsumerWidget {
  
  const BottomNavBar({super.key, this.navigationShell});
  final StatefulNavigationShell? navigationShell;

  void _onItemTapped(BuildContext context, int index) {
    // Unfocus any active input (keyboard, search bars, etc.) when switching tabs
    FocusManager.instance.primaryFocus?.unfocus();

    if (navigationShell != null) {
      if (index != navigationShell!.currentIndex) {
         // Haptic feedback for premium feel
         HapticFeedback.lightImpact();
      }
      
      navigationShell!.goBranch(
        index,
        initialLocation: index == navigationShell!.currentIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = navigationShell?.currentIndex ?? 0;
    final theme = Theme.of(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine Text Color based on strict rules
    Color textColor;
    if (themeMode == AppThemeMode.bangladesh || themeMode == AppThemeMode.dark) {
      textColor = Colors.white;
    } else {
      // Light or System -> User requested Black
      // Note: If System is actually Dark, standard logic would be White. 
      // But user specifically said "black in system theme". 
      // I will assume they mean "Default/Light System Theme".
      // Safe bet: checks brightness if system.
      if (themeMode == AppThemeMode.system && isDark) {
         textColor = Colors.white; 
      } else {
         textColor = Colors.black;
      }
    }

    // Glass styling from providers
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider).withOpacity(0.5);
    final selectionColor = ref.watch(navIconColorProvider);
    final isBangladesh = themeMode == AppThemeMode.bangladesh;

    final items = [
      const _NavItem('assets/images/home.png', 'Home', AppIcons.navHome),
      const _NavItem('assets/images/news.png', 'Papers', AppIcons.navNewspaper),
      const _NavItem('assets/images/magazine.png', 'Magazine', AppIcons.navMagazine),
      const _NavItem('assets/images/search.png', 'Search', AppIcons.search),
      const _NavItem('assets/images/settings.png', 'Settings', AppIcons.navSettings),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), // Float above bottom
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32), // High pill radius
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // Stronger Blur
          child: Container(
            height: 80, // Taller touch area to prevent overflow
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3), // Darker shadow
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                
                return Expanded(
                  child: Bouncy3DIcon(
                    assetPath: item.assetPath,
                    fallbackIcon: item.fallbackIcon,
                    label: item.label,
                    isSelected: isSelected,
                    color: selectionColor,
                    isDark: isDark,
                    isBangladesh: isBangladesh,
                    textColor: textColor,
                    onTap: () => _onItemTapped(context, index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.assetPath, this.label, this.fallbackIcon);
  final String assetPath;
  final String label;
  final IconData fallbackIcon;
}

class Bouncy3DIcon extends StatefulWidget {

  const Bouncy3DIcon({
    required this.assetPath, required this.fallbackIcon, required this.label, required this.isSelected, required this.color, required this.isDark, required this.isBangladesh, required this.textColor, required this.onTap, super.key,
  });
  final String assetPath;
  final IconData fallbackIcon;
  final String label;
  final bool isSelected;
  final Color color;
  final bool isDark;
  final bool isBangladesh;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<Bouncy3DIcon> createState() => _Bouncy3DIconState();
}

class _Bouncy3DIconState extends State<Bouncy3DIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.8,
      value: 1.0,
    );
    _scaleAnimation = _controller; // Direct mapping
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    _controller.animateTo(0.8, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  void _onTapUp(_) {
    _controller.animateTo(1.0, duration: const Duration(milliseconds: 600), curve: Curves.elasticOut);
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.animateTo(1.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                widget.assetPath,
                width: 34, // Increased by 5% (was 32)
                height: 34,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    widget.fallbackIcon,
                    size: 32, // Increased by 5% (was 30)
                    color: widget.isSelected ? widget.color : (widget.isDark ? Colors.white54 : Colors.black54),
                  );
                },
              ),
              
              const SizedBox(height: 2),
              
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.visible, 
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.w800,
                  fontFamily: AppTypography.fontFamily,
                  color: widget.textColor.withOpacity(widget.isSelected ? 1.0 : 0.6), 
                ),
              ),

              if (widget.isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isBangladesh ? const Color(0xFFF42A41) : widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isBangladesh ? const Color(0xFFF42A41) : widget.color).withOpacity(0.6),
                        blurRadius: 4,
                      )
                    ]
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
