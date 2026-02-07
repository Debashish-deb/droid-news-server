import 'package:flutter/material.dart';

/// High-performance animated text widget that smoothly transitions
/// text color during theme changes
class AnimatedThemeText extends StatelessWidget {
  const AnimatedThemeText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 500), 
      curve: Curves.easeInOutCubic,
      style: style ?? DefaultTextStyle.of(context).style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      softWrap: softWrap ?? true,
      child: Text(data),
    );
  }
}
