// lib/features/news/widgets/news_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/enums/theme_mode.dart';
import '../../../../core/navigation/app_paths.dart';
import '../../../../core/navigation/url_safety_policy.dart';
import '../../../../core/config/performance_config.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../features/common/webview_args.dart';

import '../../../../core/theme/theme.dart' show AppGradients;
import '../../../providers/theme_providers.dart' show themeProvider;

class NewspaperCard extends ConsumerStatefulWidget {
  const NewspaperCard({
    required this.news,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.searchQuery,
    super.key,
    this.highlight = true,
  });
  final Map<String, dynamic> news;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool highlight;
  final String searchQuery;

  @override
  ConsumerState<NewspaperCard> createState() => _NewspaperCardState();
}

class _NewspaperCardState extends ConsumerState<NewspaperCard> {
  Future<void> _open(BuildContext context) async {
    final maybeWebsite = widget.news['contact']?['website'];
    final maybeUrl = widget.news['url'] ?? widget.news['link'];
    final url = (maybeWebsite is String && maybeWebsite.isNotEmpty)
        ? maybeWebsite
        : (maybeUrl is String ? maybeUrl : '');

    final title = widget.news['name'] ?? 'News';

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noUrlAvailable)),
      );
      return;
    }

    final decision = UrlSafetyPolicy.evaluate(url);
    switch (decision.disposition) {
      case UrlSafetyDisposition.allowInApp:
        final uri = decision.uri;
        if (uri == null) {
          return;
        }
        context.push(
          AppPaths.webview,
          extra: WebViewArgs(
            url: uri,
            title: title.toString(),
            origin: WebViewOrigin.publisher,
          ),
        );
        return;
      case UrlSafetyDisposition.openExternal:
        final uri = decision.uri;
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
      case UrlSafetyDisposition.reject:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).invalidArticleData),
          ),
        );
        return;
    }
  }

  String? _getLocalLogoPath() {
    final media = widget.news['media'];
    if (media != null) {
      final logo = media['logo'];
      if (logo != null && logo.toString().startsWith('assets/')) {
        return logo.toString();
      }
    }
    final id = widget.news['id']?.toString();
    return id != null ? 'assets/logos/$id.png' : null;
  }

  void _share() {
    final title = widget.news['name'] ?? 'Newspaper';
    final url = widget.news['url'] ?? widget.news['link'] ?? '';
    if (url is String && url.isNotEmpty) {
      Share.share('$title\n$url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final mode = themeState.mode;
    final List<Color> gradientColors = AppGradients.getGradientColors(mode);
    final localLogoPath = _getLocalLogoPath();
    final perf = PerformanceConfig.of(context);

    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDesh = mode == AppThemeMode.bangladesh;
    final enableGlassEffects =
        !perf.reduceEffects && !perf.lowPowerMode && !perf.isLowEndDevice;
    final publisherName = widget.news['name']?.toString() ?? '';
    final normalizedPublisherName = publisherName.trim();
    final fallbackText = normalizedPublisherName.isEmpty
        ? 'NP'
        : normalizedPublisherName.characters.take(2).toString().toUpperCase();

    final Color cardColor = isDark
        ? scheme.surface.withValues(alpha: 0.14)
        : theme.cardColor.withValues(alpha: 0.04);

    final Color wrapperBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : scheme.onSurface.withValues(alpha: 0.35);

    const BoxShadow subtleHalo = BoxShadow(
      color: Color(0x0F7F7F7F),
      blurRadius: 12,
      spreadRadius: 2,
      offset: Offset(0, 6),
    );

    final BoxShadow favouriteHalo = BoxShadow(
      color: scheme.primary.withValues(alpha: 0.45),
      blurRadius: 26,
      spreadRadius: 4,
      offset: const Offset(0, 8),
    );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _open(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: cardColor,
            border: Border.all(color: wrapperBorderColor, width: 1.5),
            boxShadow: <BoxShadow>[
              widget.isFavorite ? favouriteHalo : subtleHalo,
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: AspectRatio(
              aspectRatio: 3 / 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.highlight
                        ? gradientColors
                        : const <Color>[Colors.white24, Colors.white10],
                  ),
                ),
                padding: const EdgeInsets.all(1.5),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.1),
                      width: 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (enableGlassEffects)
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0.02),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: Colors.white.withValues(
                              alpha: isDark ? 0.04 : 0.02,
                            ),
                          ),
                        if (isDark || isDesh)
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.white30, Colors.transparent],
                              ),
                            ),
                          ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.25 : 0.1,
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow:
                                    widget.highlight && (isDark || isDesh)
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 24,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : const [],
                              ),
                              padding: const EdgeInsets.all(8),
                              child: localLogoPath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.asset(
                                        localLogoPath,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _fallbackAvatar(fallbackText),
                                      ),
                                    )
                                  : _fallbackAvatar(fallbackText),
                            ),
                          ),
                        ),
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
                                      : theme.iconTheme.color,
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
      ),
    );
  }

  Widget _fallbackAvatar(String initials) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}
