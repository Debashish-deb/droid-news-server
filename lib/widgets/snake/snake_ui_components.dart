import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'snake_theme.dart';

/// Flat, clean panel widget with theme support
class GamePanel extends StatelessWidget {
  const GamePanel({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.theme,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final BoxBorder? border;
  final SnakeTheme? theme;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? theme?.surfaceColor ?? Colors.grey[900]!;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border ?? Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Animated game button with theme support and haptic feedback
class GameButton extends StatefulWidget {
  const GameButton({
    required this.label,
    required this.theme,
    super.key,
    this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final SnakeTheme theme;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        widget.primary ? widget.theme.accentColor : widget.theme.surfaceColor;
    final Color contentColor =
        widget.primary ? Colors.black : widget.theme.textColor;

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder:
            (_, child) =>
                Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: contentColor, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: contentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
