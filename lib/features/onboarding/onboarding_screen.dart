import 'package:flutter/material.dart';
// iOS-style widgets
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // SF Pro-like typography

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<_OnboardingPage> _pages = const <_OnboardingPage>[
    _OnboardingPage(
      title: 'Welcome to BD News',
      description:
          'Your trusted source for latest news, live updates, and personalized feeds.',
      animationAsset: 'assets/lottie/news.json',
    ),
  ];

  // COMPLETE ONBOARDING
  Future<void> _completeOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
    if (mounted) context.go('/login');
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // APP LOGO AT TOP (iOS style)
            Padding(
              padding: const EdgeInsets.only(top: 60, bottom: 20),
              child: Column(
                children: [
                  // App Icon with iOS-style shadow
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        22,
                      ), // iOS app icon radius
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // App Name (SF Pro-inspired)
                  Text(
                    'BD News',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5, // Apple's tight spacing
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
                itemCount: _pages.length,
                onPageChanged:
                    (int index) => setState(() => _currentIndex = index),
                itemBuilder: (BuildContext context, int index) {
                  final _OnboardingPage page = _pages[index];
                  return _OnboardingCard(page: page);
                },
              ),
            ),

            // BOTTOM SECTION
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: Column(
                children: <Widget>[
                  // PAGE INDICATORS (iOS style dots)
                  if (_pages.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (int idx) {
                          final bool selected = idx == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: selected ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  selected
                                      ? cs.primary
                                      : cs.onSurface.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),

                  // GET STARTED BUTTON (iOS style)
                  SizedBox(
                    width: double.infinity,
                    height: 56, // iOS standard button height
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        elevation: 0, // Flat iOS style
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            14,
                          ), // iOS corner radius
                        ),
                      ),
                      child: Text(
                        _currentIndex == _pages.length - 1
                            ? 'Get Started'
                            : 'Continue',
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
    );
  }
}

// ONBOARDING CARD (iOS minimal style)
class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.page});
  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // ANIMATION
          SizedBox(
            height: 280,
            child: Lottie.asset(
              page.animationAsset,
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 48),

          // TITLE (SF Pro-inspired large title style)
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5, // Apple's tight letter-spacing
              height: 1.15,
              color: cs.onSurface,
            ),
          ),

          const SizedBox(height: 16),

          // DESCRIPTION (iOS body style)
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurface.withOpacity(0.7),
              height: 1.5,
              letterSpacing: -0.3,
            ),
          ),
        ],
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
