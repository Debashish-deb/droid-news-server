import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '/core/theme.dart';
import '/core/theme_provider.dart';
import '/core/design_tokens.dart';
import '/features/common/app_bar.dart';
import '/widgets/app_drawer.dart';
import '/l10n/app_localizations.dart';
import '../history/history_widget.dart';
import '../quiz/daily_quiz_widget.dart';
import '../../widgets/snake_widget.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../presentation/providers/tab_providers.dart';

class ExtrasScreen extends ConsumerStatefulWidget {
  const ExtrasScreen({super.key});

  @override
  ConsumerState<ExtrasScreen> createState() => _ExtrasScreenState();
}

class _ExtrasScreenState extends ConsumerState<ExtrasScreen> {
  final ScrollController _scrollController = ScrollController();
  final bool _firstBuild = true;

  @override
  void dispose() {
    try {
      // Tab listener managed by Riverpod - removed;
    } catch (e) {
      // Context might be unavailable
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Listen to tab changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Tab listener managed by Riverpod - removed;
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    final int currentTab = ref.watch(currentTabIndexProvider);
    // This is tab 4 (Extras)
    if (currentTab == 4 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final AppThemeMode mode = themeMode;
    // Use getBackgroundGradient for correct Dark Mode colors (Black)
    final List<Color> gradient = AppGradients.getBackgroundGradient(mode);
    final Color start = gradient[0], end = gradient[1];
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: AppBarTitle(loc.extras),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[start.withOpacity(0.85), end.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    loc.exploreFeatures,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // OnThisDay Card
                _ProfessionalCard(
                  icon: Icons.calendar_today_rounded,
                  iconGradient: const <Color>[
                    Color(0xFFFC4A1A),
                    Color(0xFFF7B733),
                  ],
                  title: loc.onThisDay,
                  subtitle: loc.onThisDayDesc,
                  isDark: isDark,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const HistoryWidget(),
                        ),
                      ),
                ),

                const SizedBox(height: AppSpacing.lg), // Design tokens
                // BrainBuzz Card
                _ProfessionalCard(
                  icon: Icons.psychology_rounded,
                  iconGradient: const <Color>[
                    Color(0xFF36D1DC),
                    Color(0xFF5B86E5),
                  ],
                  title: loc.brainBuzz,
                  subtitle: loc.brainBuzzDesc,
                  isDark: isDark,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const DailyQuizWidget(),
                        ),
                      ),
                ),

                const SizedBox(height: AppSpacing.lg), // Design tokens
                // Snake Game Card
                _ProfessionalCard(
                  icon: Icons.videogame_asset_rounded,
                  iconGradient: const <Color>[
                    Color(0xFF00b09b),
                    Color(0xFF96c93d),
                  ],
                  title: loc.snakeCircuit,
                  subtitle: loc.snakeCircuitDesc,
                  isDark: isDark,
                  onTap:
                      () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const SnakeWidget(),
                        ),
                      ),
                ),

                const SizedBox(height: 40),

                // Footer hint
                Center(
                  child: Text(
                    loc.moreFeaturesComingSoon,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
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

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg), // Design tokens
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.xxlBorder, // Design tokens
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm), // Design tokens
            child: Row(
              children: <Widget>[
                // App Icon Style Container
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: iconGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadius.lgBorder, // Design tokens
                    boxShadow: [
                      BoxShadow(
                        color: iconGradient.last.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Gloss effect
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.lg),
                            ), // Design tokens
                          ),
                        ),
                      ),
                      // Icon
                      Center(
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: AppIconSize.lg, // Design tokens
                        ),
                      ),
                      // Inner Border for detail
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF2D3436),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.grey,
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
