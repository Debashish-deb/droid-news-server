part of '../signup_screen.dart';
class _EntranceContent extends StatelessWidget {
  const _EntranceContent({
    required this.cardFade,
    required this.cardSlide,
    required this.fieldFades,
    required this.fieldSlides,
    required this.entranceCtrl,
    required this.width,
    required this.loc,
    required this.accent,
    required this.nameCtl,
    required this.emailCtl,
    required this.passCtl,
    required this.nameFocus,
    required this.emailFocus,
    required this.passFocus,
    required this.obscureNotifier,
    required this.strengthNotifier,
    required this.avatarNotifier,
    required this.loadingNotifier,
    required this.errorNotifier,
    required this.onSignup,
    required this.onGoogle,
    required this.onBackToLogin,
  });

  final Animation<double> cardFade;
  final Animation<double> cardSlide;
  final List<Animation<double>> fieldFades;
  final List<Animation<double>> fieldSlides;
  final AnimationController entranceCtrl;
  final double width;
  final AppLocalizations loc;
  final Color accent;

  final TextEditingController nameCtl;
  final TextEditingController emailCtl;
  final TextEditingController passCtl;
  final FocusNode nameFocus;
  final FocusNode emailFocus;
  final FocusNode passFocus;

  final ValueNotifier<bool> obscureNotifier;
  final ValueNotifier<_Strength> strengthNotifier;
  final ValueNotifier<String> avatarNotifier;
  final ValueNotifier<bool> loadingNotifier;
  final ValueNotifier<String?> errorNotifier;

  final VoidCallback onSignup;
  final VoidCallback onGoogle;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    // Build the scrollable child ONCE as a variable.
    // AnimatedBuilder will pass it through unchanged –
    // only the Transform.translate wrapper gets rebuilt per tick.
    final scrollChild = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(horizontal: width * 0.055, vertical: 16),
      child: Column(
        children: [
          // Header with avatar preview
          _Header(accent: accent, avatarNotifier: avatarNotifier),
          const SizedBox(height: 28),

          // Form card
          RepaintBoundary(
            child: _FormCard(
              loc: loc,
              accent: accent,
              fieldFades: fieldFades,
              fieldSlides: fieldSlides,
              entranceCtrl: entranceCtrl,
              nameCtl: nameCtl,
              emailCtl: emailCtl,
              passCtl: passCtl,
              nameFocus: nameFocus,
              emailFocus: emailFocus,
              passFocus: passFocus,
              obscureNotifier: obscureNotifier,
              strengthNotifier: strengthNotifier,
              loadingNotifier: loadingNotifier,
              errorNotifier: errorNotifier,
              onSignup: onSignup,
              onGoogle: onGoogle,
            ),
          ),
          const SizedBox(height: 24),

          _Footer(loc: loc, accent: accent, onBackToLogin: onBackToLogin),
          const SizedBox(height: 16),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: entranceCtrl,
      // child is set here: AnimatedBuilder passes it to builder
      // without rebuilding it on each animation tick.
      child: scrollChild,
      builder: (_, child) => FadeTransition(
        opacity: cardFade,
        child: Transform.translate(
          offset: Offset(0, cardSlide.value),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER  (avatar notifier drives only avatar)
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.accent, required this.avatarNotifier});

  final Color accent;
  final ValueNotifier<String> avatarNotifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 48),
        // Only the avatar container repaints when name changes.
        ValueListenableBuilder<String>(
          valueListenable: avatarNotifier,
          builder: (_, initial, _) {
            final hasName = initial != '?';
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
                border: Border.all(
                  color: hasName
                      ? accent.withValues(alpha: 0.5)
                      : _T.silverFaint,
                  width: 1.5,
                ),
                boxShadow: hasName
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.20),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: hasName ? accent : _T.silverMuted,
                    fontFamily: 'Georgia',
                    height: 1.0,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const _GoldRule(width: 40),
        const SizedBox(height: 10),
        const Text(
          'Create Account',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'JOIN BD NEWSREADER TODAY',
          style: TextStyle(
            fontSize: 11,
            color: _T.silverMuted,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FORM CARD
// ─────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.loc,
    required this.accent,
    required this.fieldFades,
    required this.fieldSlides,
    required this.entranceCtrl,
    required this.nameCtl,
    required this.emailCtl,
    required this.passCtl,
    required this.nameFocus,
    required this.emailFocus,
    required this.passFocus,
    required this.obscureNotifier,
    required this.strengthNotifier,
    required this.loadingNotifier,
    required this.errorNotifier,
    required this.onSignup,
    required this.onGoogle,
  });

  final AppLocalizations loc;
  final Color accent;
  final List<Animation<double>> fieldFades;
  final List<Animation<double>> fieldSlides;
  final AnimationController entranceCtrl;

  final TextEditingController nameCtl;
  final TextEditingController emailCtl;
  final TextEditingController passCtl;
  final FocusNode nameFocus;
  final FocusNode emailFocus;
  final FocusNode passFocus;

  final ValueNotifier<bool> obscureNotifier;
  final ValueNotifier<_Strength> strengthNotifier;
  final ValueNotifier<bool> loadingNotifier;
  final ValueNotifier<String?> errorNotifier;

  final VoidCallback onSignup;
  final VoidCallback onGoogle;

  // Build a staggered field once (not inside AnimatedBuilder).
  Widget _staggeredField(int i, Widget field) {
    return AnimatedBuilder(
      animation: entranceCtrl,
      // Pass field as child so it isn't recreated each tick.
      child: field,
      builder: (_, child) => FadeTransition(
        opacity: fieldFades[i],
        child: Transform.translate(
          offset: Offset(0, fieldSlides[i].value),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perf = PerformanceConfig.of(context);
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final bool cheapComposite =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        preferMaterialChrome;
    final Color faceColor = preferMaterialChrome
        ? materialSurfaceOverlayColor(
            theme.colorScheme,
            tone: MaterialSurfaceTone.highest,
            surfaceAlpha: 0.94,
          )
        : const Color(0xFF141420).withValues(alpha: 0.72);
    final Color outlineColor = preferMaterialChrome
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.55)
        : _T.goldDim.withValues(alpha: 0.35);
    final List<BoxShadow> boxShadows = preferMaterialChrome
        ? const <BoxShadow>[
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 48,
              offset: const Offset(0, 24),
            ),
            BoxShadow(
              color: _T.goldBright.withValues(alpha: 0.03),
              blurRadius: 80,
              spreadRadius: 8,
            ),
          ];

    final formContent = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_T.radiusCard),
        color: faceColor,
        border: Border.all(color: outlineColor),
        boxShadow: boxShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                _GoldDot(),
                SizedBox(width: 10),
                Text(
                  'NEW ACCOUNT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _T.goldBright,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── Name field ────────────────────
            _staggeredField(
              0,
              _PremiumField(
                controller: nameCtl,
                focusNode: nameFocus,
                label: loc.fullName,
                icon: Icons.person_outline,
                accent: accent,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => emailFocus.requestFocus(),
              ),
            ),
            const SizedBox(height: 13),

            // ── Email field ───────────────────
            _staggeredField(
              1,
              _PremiumField(
                controller: emailCtl,
                focusNode: emailFocus,
                label: loc.email,
                icon: Icons.alternate_email_rounded,
                accent: accent,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => passFocus.requestFocus(),
              ),
            ),
            const SizedBox(height: 13),

            // ── Password field + strength ─────
            _staggeredField(
              2,
              Column(
                children: [
                  // Password field – obscure driven by notifier.
                  ValueListenableBuilder<bool>(
                    valueListenable: obscureNotifier,
                    builder: (_, obscure, _) => _PremiumField(
                      controller: passCtl,
                      focusNode: passFocus,
                      label: loc.password,
                      icon: Icons.shield_outlined,
                      accent: accent,
                      obscureText: obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onSignup(),
                      suffixIcon: GestureDetector(
                        onTap: () => obscureNotifier.value = !obscure,
                        child: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: obscure ? _T.silverMuted : accent,
                        ),
                      ),
                    ),
                  ),
                  // Strength bar – only repaints when strength changes.
                  ValueListenableBuilder<_Strength>(
                    valueListenable: strengthNotifier,
                    builder: (_, strength, _) {
                      if (strength == _Strength.empty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _StrengthBar(strength: strength),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Error banner ──────────────────
            ValueListenableBuilder<String?>(
              valueListenable: errorNotifier,
              builder: (_, error, _) {
                if (error == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _ErrorBanner(message: error),
                );
              },
            ),

            const SizedBox(height: 26),

            // ── CTA button ────────────────────
            ValueListenableBuilder<bool>(
              valueListenable: loadingNotifier,
              builder: (_, loading, _) => _GoldButton(
                label: loc.signup,
                loading: loading,
                onTap: loading ? null : onSignup,
              ),
            ),
            const SizedBox(height: 20),

            // ── Divider ───────────────────────
            const Row(
              children: [
                Expanded(child: Divider(color: _T.silverFaint, thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 11,
                      color: _T.silverMuted,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: _T.silverFaint, thickness: 1)),
              ],
            ),
            const SizedBox(height: 20),

            // ── Google button ─────────────────
            ValueListenableBuilder<bool>(
              valueListenable: loadingNotifier,
              builder: (_, loading, _) => _GoogleButton(
                loading: loading,
                onTap: loading ? null : onGoogle,
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(_T.radiusCard),
      child: cheapComposite
          ? formContent
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: formContent,
            ),
    );
  }
}

// ─────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer({
    required this.loc,
    required this.accent,
    required this.onBackToLogin,
  });
  final AppLocalizations loc;
  final Color accent;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          style: TextStyle(fontSize: 13, color: _T.silverMuted),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onBackToLogin,
          child: Text(
            'Sign in',
            style: TextStyle(
              fontSize: 13,
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: .3,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// AMBIENT BACKGROUND  (RepaintBoundary parent)
// ─────────────────────────────────────────────
class _AmbientBg extends StatelessWidget {
  const _AmbientBg({required this.gradient, required this.accent});
  final List<Color> gradient;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradient[0].withValues(alpha: 0.88),
                  gradient[1].withValues(alpha: 0.88),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: -60,
            left: -60,
            child: _RadialOrb(color: accent, size: 300, opacity: 0.14),
          ),
          Positioned(
            bottom: 40,
            right: -40,
            child: _RadialOrb(color: accent, size: 220, opacity: 0.08),
          ),
        ],
      ),
    );
  }
}

/// Extracted to avoid allocating `BoxDecoration` closures in a Stack.
class _RadialOrb extends StatelessWidget {
  const _RadialOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
      child: SizedBox(width: size, height: size),
    );
  }
}

// ─────────────────────────────────────────────
// PREMIUM FIELD
// Focus state is managed internally via listener so
// only this widget repaints on focus change, not the
// parent screen.
// ─────────────────────────────────────────────
class _PremiumField extends StatefulWidget {
  const _PremiumField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.accent,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final Color accent;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  @override
  State<_PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<_PremiumField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  void _onFocus() {
    // Only this widget rebuilds on focus change.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFocus = widget.focusNode.hasFocus;
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final fillColor = preferMaterialChrome
        ? Colors.white.withValues(alpha: hasFocus ? 0.98 : 0.94)
        : (hasFocus
              ? _T.inkMuted.withValues(alpha: 0.9)
              : _T.inkMuted.withValues(alpha: 0.6));
    final textColor = preferMaterialChrome ? _T.ink : Colors.white;
    final mutedColor = preferMaterialChrome
        ? _T.ink.withValues(alpha: 0.55)
        : _T.silverMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_T.radiusField),
        color: fillColor,
        border: Border.all(
          color: hasFocus
              ? widget.accent.withValues(alpha: 0.6)
              : _T.silverFaint,
          width: hasFocus ? 1.5 : 1.0,
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        autocorrect: false,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: .2,
        ),
        cursorColor: widget.accent,
        cursorWidth: 1.5,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            fontSize: 13,
            color: hasFocus ? widget.accent : mutedColor,
            fontWeight: FontWeight.w500,
            letterSpacing: .3,
          ),
          floatingLabelStyle: TextStyle(
            fontSize: 12,
            color: widget.accent,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              widget.icon,
              size: 18,
              color: hasFocus ? widget.accent : mutedColor,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: widget.suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: widget.suffixIcon,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STRENGTH BAR  (fixed: fill now actually animates)
// ─────────────────────────────────────────────
class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength});
  final _Strength strength;

  @override
  Widget build(BuildContext context) {
    final color = _strengthColor(strength);
    final fill = _strengthFill(strength);
    final label = _strengthLabel(strength);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                const ColoredBox(
                  color: _T.silverFaint,
                  child: SizedBox(height: 3, width: double.infinity),
                ),
                // AnimatedFractionallySizedBox correctly animates
                // the fractional width of the fill bar.
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  widthFactor: fill,
                  child: ColoredBox(
                    color: color,
                    child: const SizedBox(height: 3),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            key: ValueKey(label),
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: .4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// GOLD BUTTON
// ─────────────────────────────────────────────
class _GoldButton extends StatefulWidget {
  const _GoldButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed ? _T.press : _T.release,
        curve: Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_T.radiusButton),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [_T.goldMid, _T.goldDim]
                  : [_T.goldBright, _T.goldMid],
            ),
            boxShadow: _pressed
                ? null
                : [
                    BoxShadow(
                      color: _T.goldBright.withValues(alpha: 0.30),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: _T.goldBright.withValues(alpha: 0.10),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF0D0A00)),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_ButtonLabel(label: widget.label)],
                ),
        ),
      ),
    );
  }
}

// Extracted to a const-capable widget.
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0D0A00),
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 10),
        const Icon(
          Icons.arrow_forward_rounded,
          size: 18,
          color: Color(0xFF0D0A00),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// GOOGLE BUTTON
// ─────────────────────────────────────────────
class _GoogleButton extends StatefulWidget {
  const _GoogleButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed ? _T.press : _T.release,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_T.radiusButton),
            color: _pressed
                ? _T.silverFaint.withValues(alpha: 0.9)
                : _T.silverFaint.withValues(alpha: 0.6),
            border: Border.all(color: _T.silver.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  color: _T.silver,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _T.errorRed.withValues(alpha: 0.12),
        border: Border.all(color: _T.errorRed.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: _T.errorRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _T.errorRed,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────
class _TopRule extends StatelessWidget {
  const _TopRule();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, _T.goldMid, Colors.transparent],
        ),
      ),
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}

class _GoldRule extends StatelessWidget {
  const _GoldRule({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, _T.goldBright, Colors.transparent],
        ),
      ),
      child: SizedBox(width: width, height: 1.5),
    );
  }
}

class _GoldDot extends StatelessWidget {
  const _GoldDot();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(color: _T.goldBright, shape: BoxShape.circle),
    child: SizedBox(width: 5, height: 5),
  );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
