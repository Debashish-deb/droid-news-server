import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    required this.onTap,
    super.key,
    this.label,
    this.icon,
    this.isSelected = false,
    this.isDestructive = false,
    this.width,
    this.height,
    this.fontSize,
    this.iconSize,
    this.padding,
  });

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final bool isSelected;
  final bool isDestructive;
  final double? width;
  final double? height;
  final double? fontSize;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<Settings3DButton> createState() => _Settings3DButtonState();
}

class _Settings3DButtonState extends ConsumerState<Settings3DButton> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(navIconColorProvider);

    final Color activeColor = widget.isDestructive ? Colors.redAccent : accent;

    return GestureDetector(
      onTapDown: (_) => _animController.forward(),
      onTapUp: (_) => _animController.reverse().then((_) => widget.onTap()),
      onTapCancel: () => _animController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height ?? 54,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), // Rounded rectangle for switch look
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Frosted Glass Background
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.transparent),
                ),

                // Electric Switch Indicator (Left side)
                if (widget.isSelected)
                  Positioned(
                    left: 0,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withOpacity(0.6),
                            blurRadius: 10,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null)
                      Icon(
                        widget.icon,
                        size: widget.iconSize ?? 20,
                        color: widget.isSelected
                            ? activeColor
                            : (isDark
                                ? Colors.white.withOpacity(0.4)
                                : Colors.black.withOpacity(0.4)),
                      ),
                    if (widget.icon != null && widget.label != null) const SizedBox(height: 2),
                    if (widget.label != null)
                      Text(
                        widget.label!,
                        style: TextStyle(
                          fontSize: widget.fontSize ?? 11,
                          fontWeight: FontWeight.w600,
                          color: widget.isSelected
                              ? activeColor
                              : (isDark
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.black.withOpacity(0.4)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}