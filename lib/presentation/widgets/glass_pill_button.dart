import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassPillButton extends StatefulWidget {

  const GlassPillButton({
    required this.onPressed, required this.label, required this.isDark, super.key,
    this.icon,
    this.width,
    this.height = 44,
    this.isDestructive = false,
    this.isPrimary = false,
    this.fontSize,
  });
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isDestructive;
  final bool isPrimary;
  final bool isDark;
  final double? width;
  final double height;
  final double? fontSize;

  @override
  State<GlassPillButton> createState() => _GlassPillButtonState();
}

class _GlassPillButtonState extends State<GlassPillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _scale = Tween<double>(begin: 1, end: 0.96)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    _controller.forward();
    HapticFeedback.selectionClick();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed == null) return;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color textColor = widget.isDark ? Colors.white : Colors.black;
    Color iconColor = widget.isDark ? Colors.white70 : Colors.black87;
    Color borderColor =
        widget.isDark ? Colors.white24 : Colors.black12;
    Color glassColor =
        widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);

    if (widget.isDestructive) {
      textColor = Colors.redAccent;
      iconColor = Colors.redAccent;
      borderColor = Colors.redAccent.withOpacity(0.35);
      glassColor = Colors.red.withOpacity(0.06);
    } else if (widget.isPrimary) {
      textColor = Colors.white;
      iconColor = Colors.white;
      borderColor = theme.colorScheme.primary.withOpacity(0.45);
      glassColor = theme.colorScheme.primary.withOpacity(0.85);
    }

    final disabled = widget.onPressed == null;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                borderRadius: BorderRadius.circular(999),
                splashColor: theme.colorScheme.primary.withOpacity(0.08),
                highlightColor: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: widget.width,
                  height: widget.height,
                  alignment: Alignment.center, // Ensure vertical centering
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: glassColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                            widget.isDark ? 0.25 : 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.icon != null)
                        Positioned(
                          left: 12,
                          child: Icon(widget.icon, size: 18, color: iconColor),
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.icon != null ? 36 : 12,
                        ),
                        child: Text(
                          widget.label.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: textColor,
                            fontSize: widget.fontSize ?? 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
