import 'package:flutter/material.dart';
import 'premium_background.dart';
import 'premium_screen_header.dart';

/// A premium scaffold that automatically applies the universal theme background
/// and provides integrated header support for consistent UI across all screens.
class PremiumScaffold extends StatelessWidget {
  const PremiumScaffold({
    required this.body,
    this.title,
    this.subtitle,
    this.headerLeading = PremiumHeaderLeading.back,
    this.headerActions = const [],
    this.headerHeight = 108,
    this.showBackgroundParticles = true,
    this.useBackground = true,
    this.extendBodyBehindAppBar = false,
    this.drawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.appBar,
    this.resizeToAvoidBottomInset,
    this.onHeaderLeadingTap,
    this.scaffoldKey,
    super.key,
  });

  /// The main content of the screen.
  final Widget body;

  /// Optional title for the integrated [PremiumScreenHeader].
  final String? title;

  /// Optional subtitle for the integrated [PremiumScreenHeader].
  final String? subtitle;

  /// Leading widget type for the integrated header.
  final PremiumHeaderLeading headerLeading;

  /// Custom tap handler for the header leading widget.
  final VoidCallback? onHeaderLeadingTap;

  /// Action widgets for the integrated header.
  final List<Widget> headerActions;

  /// Height of the integrated header.
  final double headerHeight;

  /// Whether to show decorative particles in the background.
  final bool showBackgroundParticles;

  /// Whether to apply the theme's background gradient.
  /// Set to false if the screen is already wrapped in a [PremiumBackground].
  final bool useBackground;

  /// Whether the body should extend behind the app bar area.
  final bool extendBodyBehindAppBar;

  /// Standard Flutter Scaffold properties.
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final bool? resizeToAvoidBottomInset;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  Widget build(BuildContext context) {
    final effectiveAppBar =
        appBar ??
        (title != null
            ? PremiumScreenHeader(
                title: title!,
                subtitle: subtitle,
                leading: headerLeading,
                onLeadingTap: onHeaderLeadingTap,
                actions: headerActions,
                height: headerHeight,
              )
            : null);

    final content = useBackground
        ? PremiumBackground(showParticles: showBackgroundParticles, child: body)
        : body;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: backgroundColor ?? Colors.transparent,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawer: drawer,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: effectiveAppBar,
      body: content,
    );
  }
}
