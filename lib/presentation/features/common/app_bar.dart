import 'package:flutter/material.dart';
import '../../providers/theme_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppBarTitle extends ConsumerWidget {
  const AppBarTitle(this.title, {super.key, this.styleOverride});
  final String title;
  final TextStyle? styleOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    ref.watch(currentThemeModeProvider);

    final appBarTextStyle =
        styleOverride ??
        theme.appBarTheme.titleTextStyle ??
        TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
        );

    return Text(title, textAlign: TextAlign.center, style: appBarTextStyle);
  }
}
