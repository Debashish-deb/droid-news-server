import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_icons.dart' show AppIcons;
import '../../../../core/enums/theme_mode.dart';
import '../../../../core/utils/source_logos.dart';
import '../publisher_layout_provider.dart';
import '../../../providers/theme_providers.dart';

class PublisherTile extends ConsumerStatefulWidget {
  const PublisherTile({
    required this.publisher,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.disableMotion = false,
    this.lightweightMode = false,
    super.key,
  });

  final Map<String, dynamic> publisher;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool disableMotion;
  final bool lightweightMode;

  @override
  ConsumerState<PublisherTile> createState() => _PublisherTileState();
}

class _PublisherTileState extends ConsumerState<PublisherTile>
    with TickerProviderStateMixin {
  AnimationController? _jiggle;
  AnimationController? _floatController;
  Animation<double>? _floatAnimation;

  Offset _tiltOffset = Offset.zero;
  bool _isPressed = false;
  bool _lastEditMode = false;

  @override
  void initState() {
    super.initState();
    _ensureControllersIfNeeded();
  }

  void _ensureControllersIfNeeded() {
    if (widget.disableMotion) return;
    if (_jiggle != null &&
        _floatController != null &&
        _floatAnimation != null) {
      return;
    }

    _jiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: -0.003,
      upperBound: 0.003,
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _floatAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _floatController!, curve: Curves.easeInOut),
    );

    _floatController!.repeat(reverse: true);
  }

  void _disposeControllers() {
    _jiggle?.dispose();
    _floatController?.dispose();
    _jiggle = null;
    _floatController = null;
    _floatAnimation = null;
  }

  @override
  void didUpdateWidget(covariant PublisherTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disableMotion == widget.disableMotion) {
      return;
    }

    if (widget.disableMotion) {
      _disposeControllers();
      if (_tiltOffset != Offset.zero || _isPressed) {
        setState(() {
          _tiltOffset = Offset.zero;
          _isPressed = false;
        });
      }
      return;
    }

    _ensureControllersIfNeeded();
    _updateAnimationState(ref.read(editModeProvider));
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _updateAnimationState(bool isEditMode) {
    if (widget.disableMotion) {
      _floatController?.stop();
      return;
    }
    _ensureControllersIfNeeded();
    final jiggle = _jiggle;
    final floatController = _floatController;
    if (jiggle == null || floatController == null) return;

    if (_lastEditMode == isEditMode) return;
    _lastEditMode = isEditMode;

    if (isEditMode) {
      jiggle.repeat(reverse: true);
      floatController.stop();
    } else {
      jiggle.stop();
      jiggle.reset();
      floatController.repeat(reverse: true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final dx = (details.localPosition.dx / size.width) * 2 - 1;
    final dy = (details.localPosition.dy / size.height) * 2 - 1;

    if (_tiltOffset.dx != dx || _tiltOffset.dy != dy) {
      setState(() => _tiltOffset = Offset(dx, dy));
    }
  }

  void _onPanEnd(_) {
    if (_tiltOffset != Offset.zero) {
      setState(() => _tiltOffset = Offset.zero);
    }
  }

  Widget _buildTile(BuildContext context) {
    final publisher = widget.publisher;
    final name = publisher['name'] ?? 'Unknown';

    String? logoPath;
    final media = publisher['media'];
    if (media != null &&
        media['logo'] != null &&
        media['logo'].toString().startsWith('assets/')) {
      logoPath = media['logo'].toString();
    } else if (publisher['id'] != null) {
      logoPath = 'assets/logos/${publisher['id']}.png';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(currentThemeModeProvider);
    final isBangladesh = themeMode == AppThemeMode.bangladesh;
    if (widget.lightweightMode) {
      return _buildLightweightTile(
        context,
        name: name.toString(),
        logoPath: logoPath,
        isDark: isDark,
      );
    }

    // Luminous OLED Dark Ash or Desh Green Background
    final Color baseColor;
    if (isBangladesh) {
      baseColor = const Color(
        0xFF006A4E,
      ).withValues(alpha: 0.2); // Glassy Green base
    } else if (isDark) {
      baseColor = const Color(
        0xFF2D3035,
      ).withValues(alpha: 0.85); // Luminous Dark Ash
    } else {
      baseColor = Colors.black.withValues(alpha: 0.04);
    }

    final bool isLuminous = isDark || isBangladesh;
    // Keep 3D visuals intact; lightweight mode is the only style-reduction path.
    final bool fastSurface = widget.lightweightMode;
    final Color contentColor = isLuminous
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.black.withValues(alpha: 0.9);

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: fastSurface
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color: isBangladesh
                      ? const Color(0xFF006A4E).withValues(alpha: 0.3)
                      : (isLuminous
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.1)),
                  offset: const Offset(4, 4),
                  blurRadius: 12,
                ),
                if (isLuminous)
                  BoxShadow(
                    color: isBangladesh
                        ? const Color(0xFFF42A41).withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.08),
                    spreadRadius: -1,
                    blurRadius: 12,
                  ),
              ],
        border: Border.all(
          color: isBangladesh
              ? const Color(0xFFF42A41).withValues(
                  alpha: 0.3,
                ) // Red border for Desh
              : (isLuminous
                    ? Colors.white.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.08)),
          width: 1.5,
        ),
        gradient: fastSurface
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isBangladesh
                    ? [
                        const Color(0xFF006A4E).withValues(alpha: 0.3),
                        const Color(0xFF004d38).withValues(alpha: 0.5),
                      ]
                    : (isLuminous
                          ? [
                              Colors.white.withValues(alpha: 0.32),
                              Colors.white.withValues(alpha: 0.06),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.98),
                              Colors.white.withValues(alpha: 0.7),
                            ]),
              ),
      ),
      child: Stack(
        children: [
          // Panoramic Lens Flare (Top-edge shine)
          if (!fastSurface)
            Positioned(
              top: 6,
              left: 40,
              right: 40,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isLuminous ? 0.28 : 0.6),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

          // Row Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Tactile Dots (Left Side)
                SizedBox(
                  width: 12,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (i) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: contentColor.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

                // Centered Hero Logo (Restored with Luminous Context)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: logoPath != null
                          ? Image.asset(
                              logoPath,
                              height: 75,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.low,
                              cacheWidth: 220,
                              cacheHeight: 120,
                              errorBuilder: (context, error, stackTrace) {
                                if (SourceLogos.logos[name] != null) {
                                  return Image.asset(
                                    SourceLogos.logos[name]!,
                                    height: 75,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.low,
                                    cacheWidth: 220,
                                    cacheHeight: 120,
                                    errorBuilder: (_, _, _) =>
                                        _buildDefaultIcon(context),
                                  );
                                }
                                return _buildDefaultIcon(context);
                              },
                            )
                          : SourceLogos.logos[name] != null
                          ? Image.asset(
                              SourceLogos.logos[name]!,
                              height: 75,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.low,
                              cacheWidth: 220,
                              cacheHeight: 120,
                              errorBuilder: (_, _, _) =>
                                  _buildDefaultIcon(context),
                            )
                          : _buildDefaultIcon(context),
                    ),
                  ),
                ),

                // Action Suite (Share, Fav, Menu - High-Precision Fit)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // More Menu
                      GestureDetector(
                        onTap: () => _showCardMenu(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          child: Icon(
                            AppIcons.more,
                            size: 18,
                            color: contentColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Favorite Toggle
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onFavoriteToggle();
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          child: Icon(
                            widget.isFavorite
                                ? AppIcons.favorite
                                : AppIcons.favoriteBorder,
                            size: 22,
                            color: widget.isFavorite
                                ? Colors.redAccent
                                : contentColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Quick Share
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          child: Icon(
                            CupertinoIcons.share,
                            size: 18,
                            color: contentColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightweightTile(
    BuildContext context, {
    required String name,
    required String? logoPath,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.10);

    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: logoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            logoPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.low,
                            cacheWidth: 160,
                            cacheHeight: 160,
                            errorBuilder: (_, _, _) =>
                                _buildDefaultIcon(context),
                          ),
                        )
                      : _buildDefaultIcon(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onFavoriteToggle,
            icon: Icon(
              widget.isFavorite ? AppIcons.favorite : AppIcons.favoriteBorder,
              color: widget.isFavorite
                  ? Colors.redAccent
                  : textColor.withValues(alpha: 0.7),
            ),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: _enterEditMode,
            icon: Icon(AppIcons.more, color: textColor.withValues(alpha: 0.65)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _showCardMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                widget.isFavorite ? AppIcons.favorite : CupertinoIcons.heart,
                color: widget.isFavorite ? Colors.red : null,
              ),
              title: Text(
                widget.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onFavoriteToggle();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(editModeProvider);
    final disableMotion = widget.disableMotion || widget.lightweightMode;

    _updateAnimationState(isEditMode);

    if (disableMotion) {
      if (isEditMode) {
        return _buildTile(context);
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: _enterEditMode,
        child: _buildTile(context),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureControllersIfNeeded();
        final jiggle = _jiggle;
        final floatAnimation = _floatAnimation;
        if (jiggle == null || floatAnimation == null) {
          return _buildTile(context);
        }

        final size = constraints.biggest;

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(-_tiltOffset.dy * 0.22)
          ..rotateY(_tiltOffset.dx * 0.28);

        return AnimatedBuilder(
          animation: floatAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, isEditMode ? 0 : -floatAnimation.value),
              child: Transform(
                transform: matrix,
                alignment: FractionalOffset.center,
                child: child,
              ),
            );
          },
          child: isEditMode
              ? RotationTransition(turns: jiggle, child: _buildTile(context))
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => _onPanUpdate(d, size),
                  onPanEnd: _onPanEnd,
                  onPanCancel: () => _onPanEnd(null),
                  onTapDown: (_) => _setPressed(true),
                  onTapUp: (_) => _setPressed(false),
                  onTapCancel: () => _setPressed(false),
                  onTap: widget.onTap,
                  onLongPress: _enterEditMode,
                  child: AnimatedScale(
                    scale: _isPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    child: _buildTile(context),
                  ),
                ),
        );
      },
    );
  }

  void _enterEditMode() {
    ref.read(editModeProvider.notifier).state = true;
    HapticFeedback.lightImpact();
  }

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  Widget _buildDefaultIcon(BuildContext context) {
    return Icon(
      CupertinoIcons.news,
      size: 48,
      color: Theme.of(context).primaryColor,
    );
  }
}
