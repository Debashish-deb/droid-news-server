import 'package:flutter/material.dart';

import '../../../../core/enums/theme_mode.dart';
import '../../../../core/theme/theme_skeleton.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../common/publisher_navigation.dart';
import '../../../widgets/publisher_brand_card.dart';

class NewspaperCard extends StatelessWidget {
  const NewspaperCard({
    required this.news,
    required this.mode,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.searchQuery,
    super.key,
    this.highlight = true,
    this.onTap,
    this.preferFlatSurface = false,
    this.lightweightMode = false,
    this.skeleton = ThemeSkeleton.shared,
  });

  final Map<String, dynamic> news;
  final AppThemeMode mode;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final bool highlight;
  final String searchQuery;
  final VoidCallback? onTap;
  final bool preferFlatSurface;
  final bool lightweightMode;
  final ThemeSkeleton skeleton;

  String? _getLocalLogoPath() {
    final media = news['media'];
    if (media != null) {
      final logo = media['logo'];
      if (logo != null && logo.toString().startsWith('assets/')) {
        return logo.toString();
      }
    }
    final id = news['id']?.toString();
    return id != null ? 'assets/logos/$id.png' : null;
  }

  Future<void> _open(BuildContext context) async {
    await openPublisherWebView(
      context,
      publisher: news,
      fallbackTitle: AppLocalizations.of(context).unknownNewspaper,
      noUrlMessage: AppLocalizations.of(context).noUrlAvailable,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = news['name']?.toString() ?? '';
    final normalized = name.trim();
    final fallbackText = normalized.isEmpty
        ? 'NP'
        : normalized.characters.take(2).toString().toUpperCase();

    return PublisherBrandCard(
      publisherName: name,
      localLogoPath: _getLocalLogoPath(),
      fallbackText: fallbackText,
      mode: mode,
      highlight: highlight,
      isFavorite: isFavorite,
      onTap: onTap ?? () => _open(context),
      preferFlatSurface: preferFlatSurface,
      lightweightMode: lightweightMode,
      skeleton: skeleton,
    );
  }
}
