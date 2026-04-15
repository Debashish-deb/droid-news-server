import 'package:flutter/material.dart';

import '../../../../core/enums/theme_mode.dart';
import '../../../../core/theme/theme_skeleton.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../common/publisher_navigation.dart';
import '../../../widgets/publisher_brand_card.dart';

class MagazineCard extends StatelessWidget {
  const MagazineCard({
    required this.magazine,
    required this.mode,
    required this.isFavorite,
    required this.onFavoriteToggle,
    super.key,
    this.highlight = true,
    this.onTap,
    this.preferFlatSurface = false,
    this.lightweightMode = false,
    this.skeleton = ThemeSkeleton.shared,
  });

  final Map<String, dynamic> magazine;
  final AppThemeMode mode;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool highlight;
  final VoidCallback? onTap;
  final bool preferFlatSurface;
  final bool lightweightMode;
  final ThemeSkeleton skeleton;

  String? _getLocalLogoPath() {
    final media = magazine['media'];
    if (media != null) {
      final logo = media['logo'];
      if (logo != null && logo.toString().startsWith('assets/')) {
        return logo.toString();
      }
    }
    final id = magazine['id']?.toString();
    return id != null ? 'assets/logos/$id.png' : null;
  }

  Future<void> _open(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    await openPublisherWebView(
      context,
      publisher: magazine,
      fallbackTitle: loc.unknownMagazine,
      noUrlMessage: loc.noUrlAvailable,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = magazine['name']?.toString() ?? '';
    final normalized = name.trim();
    final fallbackText = normalized.isEmpty
        ? 'MG'
        : normalized.characters.take(2).toString().toUpperCase();

    return PublisherBrandCard(
      publisherName: name,
      localLogoPath: _getLocalLogoPath(),
      fallbackText: fallbackText,
      mode: mode,
      highlight: highlight,
      isFavorite: isFavorite,
      onTap: onTap ?? () => _open(context),
      clipLogo: true,
      preferFlatSurface: preferFlatSurface,
      lightweightMode: lightweightMode,
      skeleton: skeleton,
    );
  }
}
