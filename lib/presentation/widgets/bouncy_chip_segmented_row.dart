import 'package:flutter/material.dart';
import '../../core/theme/theme_skeleton.dart';

import 'category_chips_bar.dart';

class SegmentedChipOption<T> {
  const SegmentedChipOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Reusable segmented row built on top of [Bouncy3DChip].

class BouncyChipSegmentedRow<T> extends StatelessWidget {
  const BouncyChipSegmentedRow({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    super.key,
    this.disableMotion = false,
    this.spacing = 8,
    this.fillAvailableWidth = false,
    this.backgroundColor,
    this.borderColor,
  });

  final List<SegmentedChipOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final bool disableMotion;
  final double spacing;
  final bool fillAvailableWidth;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final bg =
        backgroundColor ??
        (isLight
            ? Colors.black.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.04));
    final stroke =
        borderColor ??
        (isLight
            ? Colors.black.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.1));

    return Container(
      height: 48, // Matches ChipsBar exactly
      padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: ThemeSkeleton.shared.circular(28),
        border: Border.all(color: stroke, width: 1.2),
      ),
      child: Row(
        mainAxisSize: fillAvailableWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            if (fillAvailableWidth)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Bouncy3DChip(
                    label: options[i].label,
                    selected: options[i].value == selectedValue,
                    expanded: true,
                    disableMotion: disableMotion,
                    onTap: () => onSelected(options[i].value),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Bouncy3DChip(
                  label: options[i].label,
                  selected: options[i].value == selectedValue,
                  disableMotion: disableMotion,
                  onTap: () => onSelected(options[i].value),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
