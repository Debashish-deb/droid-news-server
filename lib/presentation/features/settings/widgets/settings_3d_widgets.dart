import 'package:flutter/material.dart';
import '../../../../core/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/enums/theme_mode.dart';
import '../../../providers/theme_providers.dart';

/// Premium 3D Container wrapping a standard Icon to give it depth and presence
class Settings3DIcon extends ConsumerWidget {

  const Settings3DIcon({
    required this.icon, super.key,
    this.color,
    this.size = 22, // Larger default size
    this.compact = false,
    this.useColorAsBackground = false,
  });
  final IconData icon;
  final Color? color;
  final double size;
  final bool compact;
  final bool useColorAsBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBangladesh = themeMode == AppThemeMode.bangladesh;

    // Premium Glass Face Colors
    final Color faceColor = isDark 
        ? Colors.white.withOpacity(0.08) 
        : Colors.black.withOpacity(0.05);

    final Color iconColor = isDark ? Colors.white : Colors.black87;

    // Shadow/Depth Colors
    final Color shadowColor = isDark ? Colors.black87 : Colors.grey.withOpacity(0.4);
    final Color highlightColor = isDark ? Colors.white12 : Colors.white;

    final double boxSize = compact ? 34 : 42; // More compact
    final double borderRadius = compact ? 10 : 12;

    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: faceColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ]
              : [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.7),
                  Colors.white.withOpacity(0.5),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
          BoxShadow(
            color: highlightColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(-2, -2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon, 
        size: compact ? size * 1.1 : size * 1.3, 
        color: iconColor,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 2,
            offset: const Offset(0.5, 0.5),
          ),
        ],
      ),
    );
  }
}

/// Premium 3D Button implementation for Settings actions
class Settings3DButton extends ConsumerStatefulWidget {

  const Settings3DButton({
    required this.onTap, super.key,
    this.label,
    this.icon,
    this.isSelected = false,
    this.isDestructive = false,
    this.color,
    this.width,
    this.fontSize,
  });
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final bool isSelected;
  final bool isDestructive;
  final Color? color;
  final double? width;
  final double? fontSize;

  @override
  ConsumerState<Settings3DButton> createState() => _Settings3DButtonState();
}

class _Settings3DButtonState extends ConsumerState<Settings3DButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 150)
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _elevationAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) => _controller.reverse().then((_) => widget.onTap());
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(currentThemeModeProvider);
    final isBangladesh = themeMode == AppThemeMode.bangladesh;
    
    // Premium Color Scheme
    final Color baseColor;
    final Color contentColor;
    final Color glowColor;
    final selectionColor = ref.watch(navIconColorProvider);
    
    final Color activeGlow;
    if (themeMode == AppThemeMode.bangladesh) {
      activeGlow = Colors.redAccent;
    } else if (themeMode == AppThemeMode.light) {
      activeGlow = Colors.blueAccent;
    } else {
      activeGlow = const Color(0xFFFFC107); // Amber for dark/default
    }
    
    const deepGrey = Color(0xFF1A1C1E);
    
    if (widget.isDestructive) {
      baseColor = Colors.redAccent.withOpacity(0.25);
      contentColor = Colors.redAccent;
      glowColor = Colors.redAccent;
    } else {
      baseColor = isDark 
          ? deepGrey.withOpacity(0.9)
          : Colors.black.withOpacity(0.08);
          
      if (widget.isSelected) {
        contentColor = isDark ? Colors.white : Colors.black;
        glowColor = activeGlow;
      } else {
        contentColor = isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7);
        glowColor = Colors.transparent;
      }
    }

    final bool isLuminous = isDark || isBangladesh;
    final double buttonWidth = widget.width ?? 120;
    const double buttonHeight = 42; // Further reduced from 48 for ultra-compactness

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: buttonWidth,
              height: buttonHeight,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(buttonHeight / 2), // Perfect pill shape
                
                // Premium Gradient
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isLuminous
                      ? [
                          Colors.white.withOpacity(0.35),
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ]
                      : [
                          Colors.white.withOpacity(0.98),
                          Colors.white.withOpacity(0.85),
                          Colors.white.withOpacity(0.7),
                        ],
                ),
                
                // Premium 3D Shadows & Glow
                boxShadow: [
                  // Main shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(isLuminous ? 0.9 : 0.2),
                    offset: Offset(0, _elevationAnimation.value * 5),
                    blurRadius: _elevationAnimation.value * 15,
                    spreadRadius: -1,
                  ),
                  
                  // Selection glow (Dynamic Theme Color)
                  if (widget.isSelected)
                    BoxShadow(
                      color: glowColor.withOpacity(0.6),
                      blurRadius: 25,
                      spreadRadius: 1,
                    ),
                  if (widget.isSelected)
                    BoxShadow(
                      color: glowColor.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                ],
                
                // Premium Border
                border: Border.all(
                  color: widget.isSelected 
                      ? glowColor.withOpacity(0.9)
                      : (isLuminous ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1)),
                  width: widget.isSelected ? 2.2 : 1.2,
                ),
              ),
              
              // Premium Content Layout
              child: Stack(
                children: [
                  // Premium Top Highlight
                  Positioned(
                    top: 2,
                    left: 15,
                    right: 15,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(isLuminous ? 0.4 : 0.8),
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Premium Content Stack for absolute centering
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (widget.icon != null)
                          Positioned(
                            left: 14,
                            child: Icon(
                              widget.icon,
                              size: widget.label == null ? 24 : 18,
                              color: widget.isSelected ? selectionColor : contentColor,
                            ),
                          ),
                        if (widget.label != null)
                          Padding(
                            padding: EdgeInsets.only(
                              left: widget.icon != null ? 36 : 12,
                              right: 12,
                            ),
                            child: Text(
                              widget.label!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: contentColor,
                                fontWeight: FontWeight.w900,
                                fontSize: widget.fontSize ?? (buttonWidth > 140 ? 14 : 12),
                                fontFamily: AppTypography.fontFamily,
                                height: 1.15,
                                letterSpacing: -0.2,
                                  shadows: [
                                    if (widget.isSelected)
                                      Shadow(
                                        color: glowColor.withOpacity(0.8),
                                        blurRadius: 8,
                                      ),
                                    Shadow(
                                      color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                                      blurRadius: 2,
                                      offset: const Offset(1, 1),
                                    ),
                                  ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}