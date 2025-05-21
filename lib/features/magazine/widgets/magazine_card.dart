// lib/features/magazine/widgets/magazine_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme_provider.dart';
import '../../../core/theme.dart';

class MagazineCard extends StatefulWidget {
  final Map<String, dynamic> magazine;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool highlight;

  const MagazineCard({
    Key? key,
    required this.magazine,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.highlight = true,
  }) : super(key: key);

  @override
  State<MagazineCard> createState() => _MagazineCardState();
}

class _MagazineCardState extends State<MagazineCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _open(BuildContext context) {
    final url = widget.magazine['contact']?['website'] as String? ??
        widget.magazine['url'] as String? ??
        '';
    final title = widget.magazine['name'] as String? ?? 'Magazine';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available')),
      );
      return;
    }
    context.push('/webview', extra: {'url': url, 'title': title});
  }

  String? _getLocalLogoPath() {
    final id = widget.magazine['id']?.toString();
    return id != null ? 'assets/logos/$id.png' : null;
  }

  void _share() {
    final title = widget.magazine['name'] as String? ?? 'Magazine';
    final url = widget.magazine['contact']?['website'] as String? ?? '';
    if (url.isNotEmpty) Share.share('$title\n$url');
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ThemeProvider>();
    final mode = prov.appThemeMode;
    final gradientColors = AppGradients.getGradientColors(mode);
    final localLogo = _getLocalLogoPath();
    final initials = (widget.magazine['name'] as String? ?? 'MG')
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: AspectRatio(
            aspectRatio: 3 / 1,
            child: Container(
              // 1) Outer gradient border
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.highlight
                      ? gradientColors
                      : [Colors.white24, Colors.white10],
                ),
              ),
              padding: const EdgeInsets.all(2), // border thickness
              child: Container(
                // 2) Inner frosted-glass card
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: mode == AppThemeMode.dark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.white.withOpacity(0.02),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Frosted backdrop
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
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
                              colors: [
                                Colors.white30,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                      // Centered logo circle
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.5,
                                colors: [
                                  Colors.white.withOpacity(
                                      mode == AppThemeMode.dark ? 0.25 : 0.1),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: widget.highlight
                                  ? [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.15),
                                        blurRadius: 24,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: localLogo != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      localLogo,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
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
                          children: [
                            IconButton(
                              icon: Icon(
                                widget.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: widget.isFavorite
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
                              color: Colors.white70,
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
