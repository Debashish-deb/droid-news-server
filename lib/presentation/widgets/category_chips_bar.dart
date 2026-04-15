import 'dart:ui' as ui;
import '../../core/theme/theme_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/performance_config.dart';
import '../providers/theme_providers.dart';

class ChipsBar extends ConsumerStatefulWidget {
  const ChipsBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    super.key,
    this.height = 48,
    this.fontSize = 13,
    this.padding = ThemeSkeleton.insetsH12,
    this.glow = false,
    this.autoCenter = true,
    this.disableMotion = false,
  });

  final List<String> items;
  final int selectedIndex;
  final void Function(int index) onTap;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final bool autoCenter;
  final bool disableMotion;

  @override
  ConsumerState<ChipsBar> createState() => _ChipsBarState();
}

class _ChipsBarState extends ConsumerState<ChipsBar> {
  final ScrollController _controller = ScrollController();
  final List<GlobalKey> _keys = <GlobalKey<State<StatefulWidget>>>[];

  bool get _shouldDisableMotion {
    final perf = PerformanceConfig.of(context);
    return widget.disableMotion ||
        perf.reduceMotion ||
        perf.lowPowerMode ||
        perf.isLowEndDevice;
  }

  @override
  void initState() {
    super.initState();
    _syncKeysWithItems();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
  }

  @override
  void didUpdateWidget(covariant ChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _syncKeysWithItems();
    }

    if (widget.selectedIndex != oldWidget.selectedIndex &&
        widget.autoCenter &&
        !_shouldDisableMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelected());
    }
  }

  void _syncKeysWithItems() {
    final targetLen = widget.items.length;
    if (_keys.length == targetLen) return;
    if (_keys.length > targetLen) {
      _keys.removeRange(targetLen, _keys.length);
      return;
    }
    _keys.addAll(List.generate(targetLen - _keys.length, (_) => GlobalKey()));
  }

  void _centerSelected() {
    if (!widget.autoCenter || _shouldDisableMotion) return;
    if (!_controller.hasClients) return;
    if (widget.selectedIndex < 0 || widget.selectedIndex >= _keys.length) {
      return;
    }

    final ctx = _keys[widget.selectedIndex].currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 220),
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
    final theme = Theme.of(context);
    final bool isLight = theme.brightness == Brightness.light;
    final Color highContrast = isLight ? Colors.black : Colors.white;

    final Color glassColor = ref.watch(glassColorProvider);
    final Color selectedBorderColor = theme.colorScheme.primary;
    final Color glowColor = selectedBorderColor.withValues(alpha: 0.35);

    return Padding(
      padding: widget.padding,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          height: widget.height,
          child: RepaintBoundary(
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: _shouldDisableMotion
                  ? const ClampingScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 10),
              itemCount: widget.items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: ThemeSkeleton.size4), // Reduced from 8
              itemBuilder: (context, i) {
                final bool selected = widget.selectedIndex == i;

                return Padding(
                  key: _keys[i],
                  padding: ThemeSkeleton.shared.insetsSymmetric(
                    vertical: 2,
                  ), // Reduced from 6
                  child: Bouncy3DChip(
                    label: widget.items[i],
                    selected: selected,
                    fontSize: widget.fontSize,
                    baseColor: glassColor,
                    glowColor: glowColor,
                    textColor: highContrast,
                    selectedBorderColor: selectedBorderColor,
                    disableMotion: widget.disableMotion,
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
class Bouncy3DChip extends StatefulWidget {
  const Bouncy3DChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.fontSize = 13,
    this.baseColor = const Color(0xFFF5F5F5),
    this.glowColor = Colors.transparent,
    this.textColor = Colors.black,
    this.selectedBorderColor = Colors.blueAccent,
    this.expanded = false,
    this.disableMotion = false,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final Color baseColor;
  final Color glowColor;
  final Color textColor;
  final Color selectedBorderColor;
  final bool expanded;
  final bool disableMotion;
  final VoidCallback onTap;

  @override
  State<Bouncy3DChip> createState() => _Bouncy3DChipState();
}

class _Bouncy3DChipState extends State<Bouncy3DChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final perf = PerformanceConfig.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLuminous = isDark;
    final Color labelColor = isLuminous ? Colors.white : Colors.black;
    final Color chipBorder = labelColor.withValues(
      alpha: isLuminous ? 0.74 : 0.80,
    );
    final bool disableMotion =
        widget.disableMotion ||
        perf.reduceMotion ||
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice;
    final double scale = disableMotion
        ? 1.0
        : (_isPressed ? 0.95 : (widget.selected ? 1.03 : 1.0));
    final bool allowGlassBlur =
        widget.selected &&
        !disableMotion &&
        !perf.reduceEffects &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        perf.performanceTier == DevicePerformanceTier.flagship;

    return GestureDetector(
      onTapDown: (_) {
        if (!disableMotion) setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (!disableMotion) setState(() => _isPressed = false);
      },
      onTapCancel: () {
        if (!disableMotion) setState(() => _isPressed = false);
      },
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: scale,
        duration: disableMotion
            ? Duration.zero
            : const Duration(milliseconds: 90),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: AnimatedContainer(
            duration: disableMotion
                ? Duration.zero
                : const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: widget.expanded ? double.infinity : null,
            padding: ThemeSkeleton.shared.insetsSymmetric(
              horizontal: 20,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              borderRadius: ThemeSkeleton.shared.circular(12),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              border: Border.all(
                color: widget.selected
                    ? widget.selectedBorderColor
                    : chipBorder,
                width: widget.selected ? 1.35 : 1.1,
              ),
            ),
            child: ClipRRect(
              borderRadius: ThemeSkeleton.shared.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Frosted Glass (Gated by performance)
                  if (allowGlassBlur)
                    BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(color: Colors.transparent),
                    ),

                  // Content
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: widget.selected
                          ? FontWeight.w800
                          : FontWeight.w700,
                      color: labelColor.withValues(
                        alpha: widget.selected ? 1.0 : 0.92,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
