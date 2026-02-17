import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/generated/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  List<_OnboardingPage> _getPages(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return <_OnboardingPage>[
      _OnboardingPage(
        title: loc.onboardingWelcome,
        description: loc.appDescription,
        animationAsset: 'assets/lottie/news.json',
      ),
    ];
  }

  Future<void> _completeOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
    if (mounted) context.go('/login');
  }

  void _nextPage(int pagesCount) {
    HapticFeedback.lightImpact();
    if (_currentIndex < pagesCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final loc = AppLocalizations.of(context)!;
    final pages = _getPages(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface.withOpacity(0.85),
              cs.surfaceVariant.withOpacity(0.85),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // LOGO + APP NAME
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.05,
                  bottom: 15,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.25),
                            blurRadius: 30,
                            spreadRadius: 2,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Image.asset(
                            'assets/app_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'BD News',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // PAGE VIEW
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (int index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final _OnboardingPage page = pages[index];
                    return _OnboardingCard(page: page);
                  },
                ),
              ),

              // INDICATOR + BUTTON
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                child: Column(
                  children: <Widget>[
                    if (pages.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pages.length, (int idx) {
                            final bool selected = idx == _currentIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              width: selected ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: selected
                                    ? cs.primary
                                    : cs.onSurface.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _nextPage(pages.length),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: cs.primary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentIndex == pages.length - 1
                              ? loc.getStarted
                              : loc.continueBtn,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ONBOARDING CARD
class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.page});
  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.75),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: cs.onSurface.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 200,
                child: Transform.translate(
                  offset: const Offset(0, -10),
                  child: Lottie.asset(
                    page.animationAsset,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1.15,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                page.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: cs.onSurface.withOpacity(0.65),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PAGE MODEL
class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.animationAsset,
  });

  final String title;
  final String description;
  final String animationAsset;
}
