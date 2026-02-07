import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppBarTitle extends StatelessWidget {
  const AppBarTitle(this.title, {super.key, TextStyle? styleOverride});
  final String title;

  @override
  Widget build(BuildContext context) {
    final appBarTextStyle =
        Theme.of(context).appBarTheme.titleTextStyle ??
        GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface,
        );

    return Text(title, textAlign: TextAlign.center, style: appBarTextStyle);
  }
}
