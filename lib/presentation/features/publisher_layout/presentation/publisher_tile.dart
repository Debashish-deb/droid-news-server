import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_icons.dart' show AppIcons;
import '../../../../core/enums/theme_mode.dart';
import '../../../../core/config/performance_config.dart';
import '../../../../core/utils/source_logos.dart';
import '../publisher_layout_provider.dart';
import '../../../providers/theme_providers.dart';
import '../../../widgets/publisher_brand_palette.dart';

class PublisherTile extends ConsumerStatefulWidget {
  const PublisherTile({
    required this.layoutKey,
    required this.publisher,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.disableMotion = false,
    this.lightweightMode = false,
    super.key,
  });

  final String layoutKey;
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
  static final Map<String, BoxDecoration> _tileDecorationCache =
      <String, BoxDecoration>{};

  AnimationController? _jiggle;
  AnimationController? _floatController;
  Animation<double>? _floatAnimation;

  Offset _tiltOffset = Offset.zero;
  bool _isPressed = false;
  bool _lastEditMode = false;
  bool _allowFullMotion = false;

  @override
  void initState() {
    super.initState();
  }

  void _ensureControllersIfNeeded() {
    if (!_allowFullMotion || widget.disableMotion || widget.lightweightMode) {
      return;
    }
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
  }

  void _disposeControllers() {
    _jiggle?.dispose();
    _floatController?.dispose();
    _jiggle = null;
    _floatController = null;
    _floatAnimation = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    final nextAllowFullMotion =
        !widget.disableMotion &&
        !widget.lightweightMode &&
        !perf.reduceMotion &&
        !perf.reduceEffects &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        perf.performanceTier == DevicePerformanceTier.flagship;
    if (nextAllowFullMotion == _allowFullMotion) return;
    _allowFullMotion = nextAllowFullMotion;
    if (_allowFullMotion) {
      _ensureControllersIfNeeded();
      _updateAnimationState(ref.read(editModeProvider(widget.layoutKey)));
      return;
    }

    _disposeControllers();
    if (_tiltOffset != Offset.zero || _isPressed) {
      setState(() {
        _tiltOffset = Offset.zero;
        _isPressed = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant PublisherTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disableMotion == widget.disableMotion &&
        oldWidget.lightweightMode == widget.lightweightMode) {
      return;
    }

    if (widget.disableMotion || widget.lightweightMode || !_allowFullMotion) {
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
    _updateAnimationState(ref.read(editModeProvider(widget.layoutKey)));
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _updateAnimationState(bool isEditMode) {
    if (!_allowFullMotion || widget.disableMotion || widget.lightweightMode) {
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
      // Keep idle tiles static; only interactive gestures should animate.
      floatController
        ..stop()
        ..value = 0;
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

  Widget _buildTile(BuildContext context, AppThemeMode themeMode) {
    final publisher = widget.publisher;
    final name = publisher['name'] ?? 'Unknown';
    final isEditMode = ref.read(editModeProvider(widget.layoutKey));

    String? logoPath;
    final media = publisher['media'];
    if (media != null &&
        media['logo'] != null &&
        media['logo'].toString().startsWith('assets/')) {
      logoPath = media['logo'].toString();
    } else if (publisher['id'] != null) {
      logoPath = 'assets/logos/${publisher['id']}.png';
    }

    final theme = Theme.of(context);
    final publisherPalette = theme.extension<PublisherBrandPalette>()!;
    final isDark = theme.brightness == Brightness.dark;
    final isBangladesh = themeMode.name == 'bangladesh';
    const isAmoled = false;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final logoCacheWidth = (220 * devicePixelRatio).round();
    final logoCacheHeight = (96 * devicePixelRatio).round();
    const logoFilterQuality = FilterQuality.low;
    final perf = PerformanceConfig.of(context);
    final bool lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;
    if (isEditMode) {
      return _buildEditModeTile(
        context,
        name: name.toString(),
        logoPath: logoPath,
        themeMode: themeMode,
        isDark: isDark,
        logoFilterQuality: logoFilterQuality,
        logoCacheSize: (176 * devicePixelRatio).round(),
      );
    }

    if (widget.lightweightMode) {
      return _buildLightweightTile(
        context,
        name: name.toString(),
        logoPath: logoPath,
        themeMode: themeMode,
        isDark: isDark,
        logoFilterQuality: logoFilterQuality,
        logoCacheSize: (152 * devicePixelRatio).round(),
      );
    }

    // Premium Luminous Glass Backgrounds
    final Color baseColor;
    if (isBangladesh) {
      baseColor = publisherPalette.surfaceBottom.withValues(
        alpha: 0.95,
      ); // Teal-leaning publisher tint
    } else if (isDark) {
      baseColor = publisherPalette.surfaceTop.withValues(
        alpha: 0.85,
      ); // Dashboard-aligned charcoal secondary glass
    } else {
      baseColor = Colors.white.withValues(alpha: 0.65);
    }

    final bool isLuminous = isDark || isBangladesh || isAmoled;
    // Keep full 3D visuals only when effects budget allows.
    final bool fastSurface =
        widget.lightweightMode || lowEffects || !_allowFullMotion;
    final Color contentColor = isLuminous
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.black.withValues(alpha: 0.9);
    final decoration = _resolveTileDecoration(
      fastSurface: fastSurface,
      baseColor: baseColor,
      isBangladesh: isBangladesh,
      isLuminous: isLuminous,
      isDark: isDark,
      isAmoled: isAmoled,
      publisherPalette: publisherPalette,
    );
    final content = _buildTileVisualContent(
      context,
      name: name.toString(),
      logoPath: logoPath,
      isBangladesh: isBangladesh,
      isDark: isDark,
      isAmoled: isAmoled,
      isLuminous: isLuminous,
      fastSurface: fastSurface,
      contentColor: contentColor,
      publisherPalette: publisherPalette,
      logoFilterQuality: logoFilterQuality,
      logoCacheWidth: logoCacheWidth,
      logoCacheHeight: logoCacheHeight,
    );

    return Container(
      height: 120,
      decoration: decoration,
      child: ClipRRect(borderRadius: BorderRadius.circular(50), child: content),
    );
  }

  BoxDecoration _resolveTileDecoration({
    required bool fastSurface,
    required Color baseColor,
    required bool isBangladesh,
    required bool isLuminous,
    required bool isDark,
    required bool isAmoled,
    required PublisherBrandPalette publisherPalette,
  }) {
    final key = [
      'fast=$fastSurface',
      'base=${baseColor.value}',
      'desh=$isBangladesh',
      'lum=$isLuminous',
      'dark=$isDark',
      'amoled=$isAmoled',
      'top=${publisherPalette.surfaceTop.value}',
      'bottom=${publisherPalette.surfaceBottom.value}',
      'accent=${publisherPalette.accent.value}',
    ].join('|');

    return _tileDecorationCache.putIfAbsent(key, () {
      final deshShadowColor = publisherPalette.shadow.withValues(alpha: 0.46);
      return BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        boxShadow: fastSurface
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color: isBangladesh
                      ? deshShadowColor
                      : (isLuminous
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.1)),
                  offset: const Offset(3, 5),
                  blurRadius: isBangladesh ? 10 : 12,
                ),
                if (isLuminous && !isBangladesh)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    spreadRadius: -1,
                    blurRadius: 12,
                  ),
              ],
        border: Border.all(
          color: isBangladesh
              ? publisherPalette.surfaceBorder.withValues(alpha: 0.34)
              : isDark
              ? publisherPalette.surfaceBorder.withValues(alpha: 0.58)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.5,
        ),
        gradient: fastSurface
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isBangladesh
                    ? [
                        publisherPalette.surfaceTop.withValues(alpha: 0.92),
                        publisherPalette.surfaceBottom.withValues(alpha: 0.97),
                      ]
                    : isAmoled
                    ? [
                        publisherPalette.surfaceTop.withValues(alpha: 0.75),
                        publisherPalette.surfaceBottom.withValues(alpha: 0.90),
                      ]
                    : (isLuminous
                          ? [
                              publisherPalette.surfaceTop.withValues(
                                alpha: 0.96,
                              ),
                              publisherPalette.surfaceBottom.withValues(
                                alpha: 0.98,
                              ),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.98),
                              Colors.white.withValues(alpha: 0.7),
                            ]),
              ),
        color: fastSurface ? baseColor : null,
      );
    });
  }

  Widget _buildTileVisualContent(
    BuildContext context, {
    required String name,
    required String? logoPath,
    required bool isBangladesh,
    required bool isDark,
    required bool isAmoled,
    required bool isLuminous,
    required bool fastSurface,
    required Color contentColor,
    required PublisherBrandPalette publisherPalette,
    required FilterQuality logoFilterQuality,
    required int logoCacheWidth,
    required int logoCacheHeight,
  }) {
    return Stack(
      children: [
        if (isBangladesh)
          Center(
            child: Container(
              width: 140,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    publisherPalette.ambientGlow.withValues(alpha: 0.16),
                    publisherPalette.surfaceTop.withValues(alpha: 0.10),
                    publisherPalette.ambientGlow.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        if (isDark)
          Center(
            child: Container(
              width: 140,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    publisherPalette.accent.withValues(
                      alpha: isAmoled ? 0.06 : 0.08,
                    ),
                    publisherPalette.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        if (!fastSurface)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(
                      alpha: isBangladesh ? 0.08 : (isLuminous ? 0.15 : 0.4),
                    ),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        if (isLuminous && !fastSurface)
          Center(
            child: Container(
              width: 200,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: isAmoled ? 0.12 : 0.10),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: _buildCenterLogo(
              context,
              name: name,
              logoPath: logoPath,
              logoFilterQuality: logoFilterQuality,
              logoCacheWidth: logoCacheWidth,
              logoCacheHeight: logoCacheHeight,
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 14,
          child: _buildActionButton(
            color: contentColor,
            onTap: () => _showCardMenu(context),
            child: Icon(
              AppIcons.more,
              size: 18,
              color: contentColor.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterLogo(
    BuildContext context, {
    required String name,
    required String? logoPath,
    required FilterQuality logoFilterQuality,
    required int logoCacheWidth,
    required int logoCacheHeight,
  }) {
    final fallbackPath = SourceLogos.logos[name];
    final candidatePath = logoPath ?? fallbackPath;

    if (candidatePath == null) {
      return _buildDefaultIcon(context);
    }

    return Image.asset(
      candidatePath,
      height: 104,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: logoFilterQuality,
      cacheWidth: logoCacheWidth,
      cacheHeight: logoCacheHeight,
      errorBuilder: (_, _, _) {
        if (fallbackPath != null && fallbackPath != candidatePath) {
          return Image.asset(
            fallbackPath,
            height: 104,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: logoFilterQuality,
            cacheWidth: logoCacheWidth,
            cacheHeight: logoCacheHeight,
            errorBuilder: (_, _, _) => _buildDefaultIcon(context),
          );
        }
        return _buildDefaultIcon(context);
      },
    );
  }

  Widget _buildActionButton({
    required Color color,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.05),
        ),
        child: child,
      ),
    );
  }

  Widget _buildLightweightTile(
    BuildContext context, {
    required String name,
    required String? logoPath,
    required AppThemeMode themeMode,
    required bool isDark,
    required FilterQuality logoFilterQuality,
    required int logoCacheSize,
  }) {
    final isBangladesh = themeMode.name == 'bangladesh';
    final publisherPalette = Theme.of(
      context,
    ).extension<PublisherBrandPalette>()!;

    final bgColor = isBangladesh
        ? publisherPalette.surfaceBottom.withValues(alpha: 0.95)
        : isDark
        ? publisherPalette.surfaceTop.withValues(alpha: 0.90)
        : Colors.black.withValues(alpha: 0.04);

    final borderColor = isBangladesh
        ? publisherPalette.surfaceBorder.withValues(alpha: 0.28)
        : isDark
        ? publisherPalette.surfaceBorder.withValues(alpha: 0.58)
        : Colors.black.withValues(alpha: 0.08);

    final textColor = isDark ? Colors.white : Colors.black87;

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
                  width: 68, // Increased from 54
                  height: 68,
                  child: Center(
                    child: logoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              logoPath,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              filterQuality: logoFilterQuality,
                              cacheWidth: logoCacheSize,
                              cacheHeight: logoCacheSize,
                              errorBuilder: (_, _, _) =>
                                  _buildDefaultIcon(context),
                            ),
                          )
                        : (SourceLogos.logos[name] != null
                              ? Image.asset(
                                  SourceLogos.logos[name]!,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  filterQuality: logoFilterQuality,
                                  cacheWidth: logoCacheSize,
                                  cacheHeight: logoCacheSize,
                                  errorBuilder: (_, _, _) =>
                                      _buildDefaultIcon(context),
                                )
                              : _buildDefaultIcon(context)),
                  ),
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
            onPressed: _enterEditMode,
            icon: Icon(AppIcons.more, color: textColor.withValues(alpha: 0.65)),
            style: IconButton.styleFrom(minimumSize: const Size.square(48)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditModeTile(
    BuildContext context, {
    required String name,
    required String? logoPath,
    required AppThemeMode themeMode,
    required bool isDark,
    required FilterQuality logoFilterQuality,
    required int logoCacheSize,
  }) {
    final isBangladesh = themeMode.name == 'bangladesh';
    final publisherPalette = Theme.of(
      context,
    ).extension<PublisherBrandPalette>()!;

    final bgColor = isBangladesh
        ? publisherPalette.surfaceBottom.withValues(alpha: 0.95)
        : isDark
        ? publisherPalette.surfaceTop.withValues(alpha: 0.90)
        : Colors.black.withValues(alpha: 0.04);

    final borderColor = isBangladesh
        ? publisherPalette.surfaceBorder.withValues(alpha: 0.28)
        : isDark
        ? publisherPalette.surfaceBorder.withValues(alpha: 0.58)
        : Colors.black.withValues(alpha: 0.08);

    final fallbackPath = SourceLogos.logos[name];
    final candidatePath = logoPath ?? fallbackPath;

    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: candidatePath != null
          ? Image.asset(
              candidatePath,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: logoFilterQuality,
              cacheWidth: logoCacheSize,
              cacheHeight: logoCacheSize,
              errorBuilder: (_, _, _) {
                if (fallbackPath != null && fallbackPath != candidatePath) {
                  return Image.asset(
                    fallbackPath,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: logoFilterQuality,
                    cacheWidth: logoCacheSize,
                    cacheHeight: logoCacheSize,
                    errorBuilder: (_, _, _) => _buildDefaultIcon(context),
                  );
                }
                return _buildDefaultIcon(context);
              },
            )
          : _buildDefaultIcon(context),
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
                widget.isFavorite
                    ? AppIcons.favorite
                    : Icons.favorite_border_rounded,
                color: widget.isFavorite
                    ? Theme.of(context).colorScheme.primary
                    : null,
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
    final themeMode = ref.watch(currentThemeModeProvider);
    final isEditMode = ref.watch(editModeProvider(widget.layoutKey));
    final disableMotion =
        widget.disableMotion || widget.lightweightMode || !_allowFullMotion;

    _updateAnimationState(isEditMode);

    if (disableMotion) {
      if (isEditMode) {
        return _buildTile(context, themeMode);
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: _enterEditMode,
        child: _buildTile(context, themeMode),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureControllersIfNeeded();
        final jiggle = _jiggle;
        final floatAnimation = _floatAnimation;
        if (jiggle == null || floatAnimation == null) {
          return _buildTile(context, themeMode);
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
              ? RotationTransition(
                  turns: jiggle,
                  child: _buildTile(context, themeMode),
                )
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
                    child: _buildTile(context, themeMode),
                  ),
                ),
        );
      },
    );
  }

  void _enterEditMode() {
    final notifier = ref.read(editModeProvider(widget.layoutKey).notifier);
    if (notifier.state) {
      return;
    }
    notifier.state = true;
    HapticFeedback.selectionClick();
  }

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  Widget _buildDefaultIcon(BuildContext context) {
    return Icon(
      Icons.newspaper_rounded,
      size: 48,
      color: Theme.of(context).primaryColor,
    );
  }
}
