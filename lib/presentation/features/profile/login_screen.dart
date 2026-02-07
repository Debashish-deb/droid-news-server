// lib/features/auth/login_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/theme_providers.dart' 
    show currentThemeModeProvider, navIconColorProvider;
import '../../providers/feature_providers.dart';
import '../../widgets/animated_theme_container.dart';
import '../../widgets/premium_theme_icon.dart';
import '../../../core/constants.dart' show AppPerformance;
import '../../../core/performance_config.dart';
import '../../../core/theme.dart' show AppGradients;
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> 
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _passCtl = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  List<Particle> _particles = [];
  bool _reduceMotion = false;
  bool _reduceEffects = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeParticles();
    _setupFocusListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    if (perf.reduceMotion != _reduceMotion || perf.reduceEffects != _reduceEffects) {
      _reduceMotion = perf.reduceMotion;
      _reduceEffects = perf.reduceEffects;
      _animationController.duration = _reduceMotion
          ? AppPerformance.animationDuration
          : const Duration(milliseconds: 800);
      if (_reduceEffects) {
        _particles = [];
      } else if (_particles.isEmpty) {
        _initializeParticles();
      }
    }
  }

  void _initializeAnimations() {
    const Duration duration = AppPerformance.reduceMotion
        ? AppPerformance.animationDuration
        : Duration(milliseconds: 800);
    const Curve scaleCurve =
        AppPerformance.reduceMotion ? Curves.easeOutCubic : Curves.elasticOut;
    _animationController = AnimationController(
      duration: duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: scaleCurve),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  void _initializeParticles() {
    if (_reduceEffects) return;
    final random = Random();
    _particles = List.generate(15, (index) {
      return Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 2 + 1,
        speed: random.nextDouble() * 0.1 + 0.05,
        color: Colors.white.withOpacity(random.nextDouble() * 0.1 + 0.05),
      );
    });
  }

  void _setupFocusListeners() {
    _emailFocus.addListener(() {
      if (mounted) setState(() {}); // Rebuild for border color
      if (!_emailFocus.hasFocus) {
        _validateEmail();
      }
    });
    _passwordFocus.addListener(() {
      if (mounted) setState(() {}); // Rebuild for border color
    });
  }

  String? _validateEmail() {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) return null;
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _error = 'Please enter a valid email address';
      });
      return 'Invalid email format';
    }
    return null;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final emailError = _validateEmail();
    if (emailError != null) return;

    if (_emailCtl.text.isEmpty || _passCtl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final String? msg = await ref.read(authServiceProvider).login(
      _emailCtl.text.trim(),
      _passCtl.text.trim(),
    );
    
    setState(() => _loading = false);
    
    if (msg != null) {
      setState(() => _error = msg);
      _showErrorSnackbar(msg);
    } else {
      if (!mounted) return;
      _navigateToHome();
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    final String? result = await ref.read(authServiceProvider).signInWithGoogle();
    
    setState(() => _loading = false);
    
    if (!mounted) return;
    
    if (result != null) {
      _showErrorSnackbar(result);
    } else {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    context.go('/home');
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_mapError(AppLocalizations.of(context), message)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildParticleBackground() {
    if (_reduceEffects) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: ParticlePainter(
              particles: _particles,
              animationValue: _animationController.value,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final AppThemeMode mode = ref.watch(currentThemeModeProvider);
    final Color textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final selectionColor = ref.watch(navIconColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Background
                  _buildPremiumBackground(mode),
                  
                  // Particle effect
                  _buildParticleBackground(),
                  
                  // Content
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, 
                          vertical: 10
                        ),
                        child: Column(
                          children: [
                            // App logo/header
                            Container(
                              margin: const EdgeInsets.only(bottom: 24), // Reduced from 40
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: selectionColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selectionColor.withOpacity(0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: selectionColor.withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image.asset(
                                          'assets/app_logo.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.article_rounded,
                                              size: 30,
                                              color: Colors.white,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'BD NewsReader',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    loc.loginToContinue,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Login form
                            GlassContainer(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              borderRadius: const BorderRadius.all(Radius.circular(24)),
                              blurStrength: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    loc.login,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16), // Reduced from 24

                                  // Email field
                                  _buildPremiumTextField(
                                    context: context,
                                    label: loc.email,
                                    controller: _emailCtl,
                                    focusNode: _emailFocus,
                                    icon: Icons.email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                                  ),
                                  const SizedBox(height: 12), // Reduced from 20

                                  // Password field
                                  _buildPasswordField(
                                    context: context,
                                    label: loc.password,
                                    controller: _passCtl,
                                    focusNode: _passwordFocus,
                                    obscure: _obscurePassword,
                                    onToggleObscure: () => setState(
                                      () => _obscurePassword = !_obscurePassword
                                    ),
                                    onSubmitted: (_) => _login(),
                                  ),

                                  const SizedBox(height: 16),

                                  // Error message
                                  if (_error != null)
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _mapError(loc, _error!),
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  if (_error != null) const SizedBox(height: 24),

                                  // Login button
                                  AnimatedThemeContainer(
                                    onTap: _loading ? null : _login,
                                    enableHoverEffect: true,
                                    borderRadius: BorderRadius.circular(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          selectionColor.withOpacity(0.9),
                                          selectionColor.withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: selectionColor.withOpacity(0.4),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      height: 56,
                                      alignment: Alignment.center,
                                      child: _loading
                                          ? const CircularProgressIndicator.adaptive(
                                              valueColor: AlwaysStoppedAnimation(
                                                Colors.white,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const PremiumThemeIcon(
                                                  Icons.login_rounded,
                                                  darkColor: Colors.white,
                                                  lightColor: Colors.white,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  loc.login,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: textColor.withOpacity(0.2),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          loc.orContinueWith,
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: textColor.withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Google login button
                                  AnimatedThemeContainer(
                                    onTap: _loading ? null : _loginWithGoogle,
                                    enableHoverEffect: true,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                    child: Container(
                                      height: 56,
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/google_logo.png',
                                            height: 24,
                                            width: 24,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.g_mobiledata_rounded,
                                                size: 28,
                                                color: Colors.white,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              loc.continueWithGoogle,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Sign up link
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          loc.noAccount,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => context.go('/signup'),
                                        child: Text(
                                          loc.createAccount,
                                          style: TextStyle(
                                            color: selectionColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumTextField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectionColor = ref.watch(navIconColorProvider);
    final hasFocus = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus 
              ? selectionColor.withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
          width: hasFocus ? 2 : 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isDark ? 0.1 : 0.15),
            Colors.white.withOpacity(isDark ? 0.05 : 0.08),
          ],
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: selectionColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color ?? Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: hasFocus 
                ? selectionColor 
                : theme.textTheme.bodyLarge?.color?.withOpacity(0.5) ?? Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: TextStyle(
            color: selectionColor,
            fontWeight: FontWeight.w900,
          ),
          prefixIcon: PremiumThemeIcon(
            icon,
            size: 22,
            darkColor: hasFocus ? selectionColor : Colors.white70,
            lightColor: hasFocus ? selectionColor : Colors.grey,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          filled: false,
        ),
        cursorColor: selectionColor,
      ),
    );
  }

  Widget _buildPasswordField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscure,
    required VoidCallback onToggleObscure,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onSubmitted,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectionColor = ref.watch(navIconColorProvider);
    final hasFocus = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus 
              ? selectionColor.withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
          width: hasFocus ? 2 : 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isDark ? 0.1 : 0.15),
            Colors.white.withOpacity(isDark ? 0.05 : 0.08),
          ],
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: selectionColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: hasFocus 
                      ? selectionColor 
                      : theme.textTheme.bodyLarge?.color?.withOpacity(0.5) ?? Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: TextStyle(
                  color: selectionColor,
                  fontWeight: FontWeight.w900,
                ),
                prefixIcon: PremiumThemeIcon(
                  Icons.lock_rounded,
                  size: 22,
                  darkColor: hasFocus ? selectionColor : Colors.white70,
                  lightColor: hasFocus ? selectionColor : Colors.grey,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                filled: false,
              ),
              cursorColor: selectionColor,
            ),
          ),
          IconButton(
            onPressed: onToggleObscure,
            icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: hasFocus ? selectionColor : Colors.white70,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBackground(AppThemeMode mode) {
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withOpacity(0.85),
            colors[1].withOpacity(0.85),
          ],
        ),
      ),
    );
  }

  String _mapError(AppLocalizations loc, String msg) {
    switch (msg) {
      case 'Invalid email or password.':
        return loc.invalidCredentials;
      case 'No account found. Please sign up first.':
        return loc.noAccountFound;
      case 'Account already exists. Please log in.':
        return loc.accountExists;
      case 'Please enter a valid email address':
        return loc.invalidEmail;
      case 'Please fill in all fields':
        return loc.fillAllFields;
      default:
        return msg;
    }
  }
}

class Particle {

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
  });
  final double x;
  final double y;
  final double size;
  final double speed;
  final Color color;
}

class ParticlePainter extends CustomPainter {

  ParticlePainter({
    required this.particles,
    required this.animationValue,
  });
  final List<Particle> particles;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final offsetY = (particle.y + animationValue * particle.speed) % 1.0;
      final opacity = particle.color.opacity *
          (0.5 + 0.5 * sin(animationValue * 2 * pi + particle.x * pi));

      paint.color = particle.color.withOpacity(opacity);

      canvas.drawCircle(
        Offset(particle.x * size.width, offsetY * size.height),
        particle.size * (1 + 0.2 * sin(animationValue * 2 * pi)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return true;
  }
}
