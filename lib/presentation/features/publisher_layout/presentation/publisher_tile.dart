import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/theme_mode.dart';
import '../../../../core/utils/source_logos.dart';
import '../publisher_layout_provider.dart';
import '../../../providers/theme_providers.dart';

import '../../../../core/app_icons.dart' show AppIcons;

class PublisherTile extends ConsumerStatefulWidget {
  const PublisherTile({
    required this.publisher, required this.onTap, required this.isFavorite, required this.onFavoriteToggle, super.key,
  });

  final Map<String, dynamic> publisher;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  ConsumerState<PublisherTile> createState() => _PublisherTileState();
}

class _PublisherTileState extends ConsumerState<PublisherTile>
    with TickerProviderStateMixin {
  late final AnimationController _jiggle;
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  Offset _tiltOffset = Offset.zero;
  bool _isPressed = false;
  bool _lastEditMode = false;

  @override
  void initState() {
    super.initState();

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
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _floatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _jiggle.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _updateAnimationState(bool isEditMode) {
    if (_lastEditMode == isEditMode) return;
    _lastEditMode = isEditMode;

    if (isEditMode) {
      _jiggle.repeat(reverse: true);
      _floatController.stop();
    } else {
      _jiggle.stop();
      _jiggle.reset();
      _floatController.repeat(reverse: true);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(currentThemeModeProvider);
    final isBangladesh = themeMode == AppThemeMode.bangladesh;
    
    // Luminous OLED Dark Ash or Desh Green Background
    final Color baseColor;
    if (isBangladesh) {
       baseColor = const Color(0xFF006A4E).withOpacity(0.2); // Glassy Green base
    } else if (isDark) {
       baseColor = const Color(0xFF2D3035).withOpacity(0.85); // Luminous Dark Ash
    } else {
       baseColor = Colors.black.withOpacity(0.04);
    }
    
    final bool isLuminous = isDark || isBangladesh;
    final Color contentColor = isLuminous ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.9);

    return Container(
      height: 108, // Reduced from 120 (10% reduction)
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          // 3D Depth Shadow
          BoxShadow(
            color: isBangladesh 
                ? const Color(0xFF006A4E).withOpacity(0.3) // Green glow for Desh
                : (isLuminous ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.1)),
            offset: const Offset(4, 4),
            blurRadius: 12,
          ),
          if (isLuminous) // Inner Glow for Luminosity (Backlighting the entire glass)
            BoxShadow(
              color: isBangladesh 
                  ? const Color(0xFFF42A41).withOpacity(0.1) // Red glow for Desh
                  : Colors.white.withOpacity(0.08), 
              spreadRadius: -1,
              blurRadius: 12,
            ),
        ],
        border: Border.all(
          color: isBangladesh 
              ? const Color(0xFFF42A41).withOpacity(0.3) // Red border for Desh
              : (isLuminous ? Colors.white.withOpacity(0.28) : Colors.black.withOpacity(0.08)),
          width: 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isBangladesh 
              ? [const Color(0xFF006A4E).withOpacity(0.3), const Color(0xFF004d38).withOpacity(0.5)] // Green gradient
              : (isLuminous
                  ? [Colors.white.withOpacity(0.32), Colors.white.withOpacity(0.06)] // Maximum top-down luminosity
                  : [Colors.white.withOpacity(0.98), Colors.white.withOpacity(0.7)]),
        ),
      ),
      child: Stack(
        children: [
          // Panoramic Lens Flare (Top-edge shine)
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
                    Colors.white.withOpacity(isLuminous ? 0.28 : 0.6),
                    Colors.white.withOpacity(0.0),
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
                    children: List.generate(4, (i) => Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 2), // Reduced from 3
                      decoration: BoxDecoration(
                        color: contentColor.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                    )),
                  ),
                ),
                
                // Centered Hero Logo (Restored with Luminous Context)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8), // Reduced from 12
                      child: widget.publisher['id'] != null
                          ? Image.asset(
                              'assets/logos/${widget.publisher['id']}.png',
                              height: 65, // Reduced from 75
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                if (SourceLogos.logos[name] != null) {
                                  return Image.asset(
                                    SourceLogos.logos[name]!,
                                    height: 65,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _buildDefaultIcon(context),
                                  );
                                }
                                return _buildDefaultIcon(context);
                              },
                            )
                          : SourceLogos.logos[name] != null
                              ? Image.asset(
                                  SourceLogos.logos[name]!,
                                  height: 65,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _buildDefaultIcon(context),
                                )
                              : _buildDefaultIcon(context),
                    ),
                  ),
                ),
                
                // Action Suite (Share, Fav, Menu - High-Precision Fit)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4), // Reduced from 6
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
                            color: contentColor.withOpacity(0.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2), // Reduced from 4
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
                            widget.isFavorite ? AppIcons.favorite : AppIcons.favoriteBorder,
                            size: 22,
                            color: widget.isFavorite ? Colors.redAccent : contentColor.withOpacity(0.3),
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
                            color: contentColor.withOpacity(0.4),
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
              title: Text(widget.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
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

    _updateAnimationState(isEditMode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(-_tiltOffset.dy * 0.22)
          ..rotateY(_tiltOffset.dx * 0.28);

        return AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, isEditMode ? 0 : -_floatAnimation.value),
              child: Transform(
                transform: matrix,
                alignment: FractionalOffset.center,
                child: child,
              ),
            );
          },
          child: isEditMode
              ? RotationTransition(
                  turns: _jiggle,
                  child: _buildTile(context),
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