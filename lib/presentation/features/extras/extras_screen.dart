import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart' show AppLocalizations;
import '../../widgets/app_drawer.dart' show AppDrawer;
import '../common/app_bar.dart' show AppBarTitle;
import '../../../core/design_tokens.dart';
import '../../../core/theme.dart';
import '../../../core/enums/theme_mode.dart';

import '../../providers/tab_providers.dart';
import '../../providers/theme_providers.dart';
import '../history/history_widget.dart';
import '../quiz/daily_quiz_widget.dart';
import '../../widgets/glass_icon_button.dart' show GlassIconButton;

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

    } catch (e) {
   
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    final int currentTab = ref.watch(currentTabIndexProvider);

    if (currentTab == 4 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final AppThemeMode mode = themeMode;
    final List<Color> gradient = AppGradients.getBackgroundGradient(mode);
    final Color start = gradient[0], end = gradient[1];
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        title: AppBarTitle(loc.extras),
        leading: Builder(
          builder: (context) => Center(
            child: GlassIconButton(
              icon: Icons.menu_rounded,
              onPressed: () => Scaffold.of(context).openDrawer(),
              isDark: isDark,
            ),
          ),
        ),
        leadingWidth: 64,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    start.withOpacity(0.85),
                    end.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // 3. Content
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
             
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      loc.exploreFeatures,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        fontFamily: '.SF Pro Display', 
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  
                  _ProfessionalCard(
                    icon: Icons.calendar_today_rounded,
                    iconGradient: const <Color>[
                      Color(0xFFFC4A1A),
                      Color(0xFFF7B733),
                    ],
                    title: loc.onThisDay,
                    subtitle: loc.onThisDayDesc,
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const HistoryWidget(),
                          ),
                        ),
                  ),

                  const SizedBox(height: AppSpacing.lg), 
              
                  _ProfessionalCard(
                    icon: Icons.psychology_rounded,
                    iconGradient: const <Color>[
                      Color(0xFF36D1DC),
                      Color(0xFF5B86E5),
                    ],
                    title: loc.brainBuzz,
                    subtitle: loc.brainBuzzDesc,
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const DailyQuizWidget(),
                          ),
                        ),
                  ),



                  const SizedBox(height: 40),

       
                  Center(
                    child: Text(
                      loc.moreFeaturesComingSoon,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black45,
                        fontStyle: FontStyle.italic,
                        fontFamily: '.SF Pro Text',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalCard extends ConsumerWidget {
  const _ProfessionalCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final navIconColor = ref.watch(navIconColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 3D Glass Pill Decoration Logic
    final themeMode = ref.watch(currentThemeModeProvider);
    final isBangladesh = themeMode == AppThemeMode.bangladesh;
    final bool isLuminous = isDark || isBangladesh;
    
    // Determining Colors (mimicking Settings3DButton unselected state)
    // OLED Luminous Dark Ash Background for Dark Mode
    final Color baseColor = isDark 
        ? const Color(0xFF2D3035).withOpacity(0.85) 
        : Colors.black.withOpacity(0.04);
        
    final Color contentColor = isDark ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.9);
    final Color selectionColor = navIconColor; // Just for reference if needed

    // Glassmorphic Card Container
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(24), 
          border: Border.all(
            color: isLuminous 
                ? Colors.white.withOpacity(0.28)
                : Colors.black.withOpacity(0.08),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: isLuminous ? Colors.black.withOpacity(0.7) : Colors.black.withOpacity(0.12),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
            if (isLuminous) // Inner Glow for Luminosity
              BoxShadow(
                color: Colors.white.withOpacity(0.06),
                spreadRadius: -1,
                blurRadius: 7,
              ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLuminous
                ? [Colors.white.withOpacity(0.30), Colors.white.withOpacity(0.05)]
                : [Colors.white.withOpacity(0.98), Colors.white.withOpacity(0.7)],
          ),
        ),
        child: Stack(
          children: [
             // Horizontal Lens Flare (Stretched along the top - Scaled for Card width)
             Positioned(
               top: 4,
               left: 40,
               right: 40,
               child: Container(
                 height: 12,
                 decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(20),
                   gradient: LinearGradient(
                     begin: Alignment.topCenter,
                     end: Alignment.bottomCenter,
                     colors: [
                       Colors.white.withOpacity(isLuminous ? 0.28 : 0.6),
                       Colors.white.withOpacity(0.0),
                     ],
                   ),
                 ),
               ),
             ),
             
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: iconGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18), 
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.last.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: contentColor, // Use 3D content color
                            letterSpacing: 0.2,
                            fontFamily: AppTypography.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.3,
                            fontFamily: '.SF Pro Text',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: navIconColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
