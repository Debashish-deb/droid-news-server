import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/presentation/providers/theme_providers.dart';
import '/core/services/theme_providers.dart';
import '/core/theme_provider.dart';

class ChipsBar extends ConsumerStatefulWidget {
  const ChipsBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    super.key,
    this.height = 52,
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
    if (widget.selectedIndex < 0 || widget.selectedIndex >= _keys.length) {
      return;
    }

    final BuildContext? ctx = _keys[widget.selectedIndex].currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
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
    // Use Riverpod providers instead of legacy context.watch
    final themeState = ref.watch(themeProvider);
    final bool isLight = themeState.mode == AppThemeMode.light;
    final Color baseColor = ref.watch(glassColorProvider);
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
              color: baseColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: glowColor),
              boxShadow:
                  widget.glow
                      ? <BoxShadow>[
                        BoxShadow(
                          color: glowColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                      : <BoxShadow>[],
            ),
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int i) {
                final bool selected = widget.selectedIndex == i;

                return Padding(
                  key: _keys[i],
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _AnimatedChip(
                    label: widget.items[i],
                    selected: selected,
                    fontSize: widget.fontSize,
                    baseColor: baseColor,
                    glowColor: glowColor,
                    textColor:
                        selected
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
// ANIMATED CHIP
// =========================================================
class _AnimatedChip extends StatelessWidget {
  const _AnimatedChip({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.baseColor,
    required this.glowColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final Color baseColor;
  final Color glowColor;
  final Color textColor;
  final VoidCallback onTap;

  static const Color _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.07 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? _gold : baseColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? Colors.transparent : glowColor),
          boxShadow:
              selected
                  ? <BoxShadow>[
                    BoxShadow(
                      color: _gold.withOpacity(0.55),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : <BoxShadow>[],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          splashColor: _gold.withOpacity(0.25),
          highlightColor: _gold.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: <Widget>[
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? Colors.black : textColor,
                    shadows:
                        selected
                            ? const <Shadow>[
                              Shadow(
                                blurRadius: 6,
                                color: Colors.black26,
                                offset: Offset(0, 2),
                              ),
                            ]
                            : <Shadow>[],
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
