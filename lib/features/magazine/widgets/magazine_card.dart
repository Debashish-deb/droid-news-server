// lib/features/magazine/widgets/magazine_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme_provider.dart';
import '../../../core/theme.dart';
import '../../../widgets/tiger_stripes_overlay.dart';
import '../../../presentation/providers/theme_providers.dart';

class MagazineCard extends ConsumerStatefulWidget {
  const MagazineCard({
    required this.magazine,
    required this.isFavorite,
    required this.onFavoriteToggle,
    super.key,
    this.highlight = true,
  });
  final Map<String, dynamic> magazine;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool highlight;

  @override
  ConsumerState<MagazineCard> createState() => _MagazineCardState();
}

class _MagazineCardState extends ConsumerState<MagazineCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _open(BuildContext context) {
    final String url =
        widget.magazine['contact']?['website'] as String? ??
        widget.magazine['url'] as String? ??
        '';
    final String title = widget.magazine['name'] as String? ?? 'Magazine';
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No URL available')));
      return;
    }
    context.push(
      '/webview',
      extra: <String, String>{'url': url, 'title': title},
    );
  }

  String? _getLocalLogoPath() {
    final String? id = widget.magazine['id']?.toString();
    return id != null ? 'assets/logos/$id.png' : null;
  }

  void _share() {
    final String title = widget.magazine['name'] as String? ?? 'Magazine';
    final String url = widget.magazine['contact']?['website'] as String? ?? '';
    if (url.isNotEmpty) Share.share('$title\n$url');
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);

    final AppThemeMode mode = themeMode;
    final List<Color> gradientColors = AppGradients.getGradientColors(mode);
    final String? localLogo = _getLocalLogoPath();
    final String initials =
        (widget.magazine['name'] as String? ?? 'MG')
            .substring(0, 2)
            .toUpperCase();

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => _open(context),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: AspectRatio(
            aspectRatio: 3 / 1,
            child: Container(
              // 1) Outer gradient border
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      widget.highlight
                          ? gradientColors
                          : <Color>[Colors.white24, Colors.white10],
                ),
              ),
              padding: const EdgeInsets.all(
                1.5,
              ), // border thickness - reduced from 2
              child: Container(
                // 2) Inner frosted-glass card
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color:
                      mode == AppThemeMode.dark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey.shade100,
                  border: Border.all(
                    color:
                        mode == AppThemeMode.dark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.1),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // Frosted backdrop
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Colors.white.withOpacity(0.08),
                                Colors.white.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Dark/Bangladesh overlay
                      if (mode == AppThemeMode.dark ||
                          mode == AppThemeMode.bangladesh)
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Colors.white30,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                      // Tiger stripes overlay (Bangladesh theme only)
                      if (mode == AppThemeMode.bangladesh)
                        const TigerStripesOverlay(
                          opacity: 0.06,
                          stripeWidth: 2.5,
                          stripeSpacing: 14.0,
                        ),

                      // Centered logo circle
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: <Color>[
                                  Colors.white.withOpacity(
                                    mode == AppThemeMode.dark ? 0.25 : 0.1,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow:
                                  widget.highlight
                                      ? <BoxShadow>[
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.15),
                                          blurRadius: 24,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                      : <BoxShadow>[],
                            ),
                            padding: const EdgeInsets.all(8),
                            child:
                                localLogo != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.asset(
                                        localLogo,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (_, __, ___) =>
                                                _fallbackAvatar(initials),
                                      ),
                                    )
                                    : _fallbackAvatar(initials),
                          ),
                        ),
                      ),

                      // Favorite + share at bottom-left
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            IconButton(
                              icon: Icon(
                                widget.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    widget.isFavorite
                                        ? Colors.redAccent
                                        : Colors.white,
                                size: 20,
                              ),
                              onPressed: widget.onFavoriteToggle,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              icon: const Icon(Icons.share, size: 20),
                              color:
                                  mode == AppThemeMode.dark
                                      ? Colors.white70
                                      : Colors.black54,
                              onPressed: _share,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar(String txt) => Container(
    decoration: BoxDecoration(
      color: Colors.grey.shade200.withOpacity(0.4),
      borderRadius: BorderRadius.circular(16),
    ),
    alignment: Alignment.center,
    child: Text(
      txt,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    ),
  );
}
