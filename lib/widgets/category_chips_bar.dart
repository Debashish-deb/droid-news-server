import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/theme_provider.dart';

class ChipsBar extends StatelessWidget {
  final List<String> items;
  final int selectedIndex;
  final void Function(int index) onTap;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool glow;

  const ChipsBar({
    Key? key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.height = 52,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.glow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ThemeProvider>();
    final theme = Theme.of(context);

    final baseColor = prov.glassColor;
    final glowColor = prov.borderColor.withOpacity(0.3);
    final selectedColor = const Color(0xFFFFD700); // Gold

    return Padding(
      padding: padding,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: glowColor, width: 1),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final selected = i == selectedIndex;
            return ChoiceChip(
              label: Text(
                items[i],
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: fontSize,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected
                      ? Colors.black
                      : (prov.appThemeMode == AppThemeMode.light
                          ? Colors.black54
                          : Colors.white70),
                  shadows: selected
                      ? const [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black26,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
              ),
              selected: selected,
              onSelected: (_) => onTap(i),
              backgroundColor: baseColor,
              selectedColor: selectedColor,
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected ? Colors.transparent : glowColor,
                  width: 1,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
