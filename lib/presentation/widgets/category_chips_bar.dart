import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart';
import '../../core/enums/theme_mode.dart';

class ChipsBar extends ConsumerStatefulWidget {
  const ChipsBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    super.key,
    this.height = 64,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.glow = false,
    this.autoCenter = true,
  });

  final List<String> items;
  final int selectedIndex;
  final void Function(int index) onTap;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final bool autoCenter;

  @override
  ConsumerState<ChipsBar> createState() => _ChipsBarState();
}

class _ChipsBarState extends ConsumerState<ChipsBar> {
  final ScrollController _controller = ScrollController();
  final List<GlobalKey> _keys = <GlobalKey<State<StatefulWidget>>>[];

  @override
  void initState() {
    super.initState();
    _keys.addAll(List.generate(widget.items.length, (_) => GlobalKey()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
  }

  @override
  void didUpdateWidget(covariant ChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex && widget.autoCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
    }
  }

  void _centerSelected() {
    if (!widget.autoCenter) return;
    if (widget.selectedIndex < 0 || widget.selectedIndex >= _keys.length) return;

    final ctx = _keys[widget.selectedIndex].currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final bool isLight = themeState.mode == AppThemeMode.light;

    final Color glassColor = ref.watch(glassColorProvider);
    final Color glowColor = ref.watch(borderColorProvider).withOpacity(0.35);

    return Padding(
      padding: widget.padding,
      child: Hero(
        tag: 'chips-bar',
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withOpacity(0.025)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isLight
                    ? Colors.black.withOpacity(0.06)
                    : Colors.white.withOpacity(0.12),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isLight ? 0.05 : 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4), // Reduced from 8
              itemBuilder: (context, i) {
                final bool selected = widget.selectedIndex == i;

                return Padding(
                  key: _keys[i],
                  padding: const EdgeInsets.symmetric(vertical: 2), // Reduced from 6
                  child: Bouncy3DChip(
                    label: widget.items[i],
                    selected: selected,
                    fontSize: widget.fontSize,
                    baseColor: glassColor,
                    glowColor: glowColor,
                    textColor: selected
                        ? Colors.black
                        : (isLight ? Colors.black54 : Colors.white70),
                    onTap: () => widget.onTap(i),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// 3D CHIP
// =========================================================
class Bouncy3DChip extends ConsumerStatefulWidget {
  const Bouncy3DChip({
    required this.label, required this.selected, required this.onTap, super.key,
    this.fontSize = 13,
    this.baseColor = const Color(0xFFF5F5F5),
    this.glowColor = Colors.transparent,
    this.textColor = Colors.black,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final Color baseColor;
  final Color glowColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  ConsumerState<Bouncy3DChip> createState() => _Bouncy3DChipState();
}

class _Bouncy3DChipState extends ConsumerState<Bouncy3DChip>
    with SingleTickerProviderStateMixin {
  Offset _tiltOffset = Offset.zero;
  bool _isPressed = false;

  void _onPanUpdate(DragUpdateDetails details) {
    final dx = (details.localPosition.dx / 120).clamp(-1.0, 1.0);
    final dy = (details.localPosition.dy / 60).clamp(-1.0, 1.0);
    setState(() => _tiltOffset = Offset(dx, dy));
  }

  void _onPanEnd(_) => setState(() => _tiltOffset = Offset.zero);

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isBangladesh = themeMode == AppThemeMode.bangladesh;
    final bool isLuminous = isDark || isBangladesh;

    final Color baseColor = isBangladesh
        ? const Color(0xFF006A4E).withOpacity(0.88)
        : isDark
            ? const Color(0xFF2D3035).withOpacity(0.88)
            : Colors.black.withOpacity(0.045);

    final Color contentColor =
        isLuminous ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.9);

    final Color selectionColor = ref.watch(navIconColorProvider);

    final Matrix4 matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(-_tiltOffset.dy * 0.18)
      ..rotateY(_tiltOffset.dx * 0.18);

    final double scale = _isPressed ? 0.95 : (widget.selected ? 1.03 : 1.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: matrix,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced from 18x10
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(16), // Reduced from 32
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isLuminous
                    ? [
                        Colors.white.withOpacity(0.28),
                        Colors.white.withOpacity(0.04),
                      ]
                    : [
                        Colors.white.withOpacity(0.95),
                        Colors.white.withOpacity(0.75),
                      ],
              ),
              border: Border.all(
                color: widget.selected
                    ? selectionColor.withOpacity(isLuminous ? 0.75 : 0.5)
                    : (isLuminous
                        ? Colors.white.withOpacity(0.28)
                        : Colors.black.withOpacity(0.12)),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isLuminous ? 0.6 : 0.14),
                  offset: const Offset(3, 3),
                  blurRadius: 9,
                ),
                if (widget.selected)
                  BoxShadow(
                    color: selectionColor.withOpacity(
                      isLuminous ? 0.45 : 0.3,
                    ),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                if (isLuminous)
                  BoxShadow(
                    color: Colors.white.withOpacity(0.06),
                    blurRadius: 8,
                    spreadRadius: -1,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: selectionColor,
                    ),
                  ),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight:
                        widget.selected ? FontWeight.w900 : FontWeight.w700,
                    color: widget.selected
                        ? (isLuminous ? Colors.white : selectionColor)
                        : contentColor,
                    letterSpacing: -0.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
