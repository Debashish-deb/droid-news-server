import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../providers/theme_providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/utils/number_localization.dart';
import '../../../providers/language_providers.dart';

class ProfessionalHeader extends ConsumerWidget {
  const ProfessionalHeader({
    required this.articleCount,
    this.category,
    super.key,
  });

  final int articleCount;
  final String? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final List<Color> colors = AppGradients.getGradientColors(themeMode);

    final localizedCategory = _localizedCategoryLabel(loc);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: AppSpacing.horizontalLg.add(
          const EdgeInsets.symmetric(vertical: 4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors[0].withValues(alpha: 0.15), colors[1].withValues(alpha: 0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.xlBorder,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.25),
            width: AppBorders.regular,
          ),
          boxShadow: isDark
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.1),
                borderRadius: AppRadius.smBorder,
              ),
              child: Icon(
                Icons
                    .notifications_active_rounded, // Changed to notification icon
                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              localizeNumber(articleCount, ref.watch(languageCodeProvider)),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              localizedCategory ?? loc.latest,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: localizedCategory != null
                    ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
                    : subtitleColor,
              ),
            ),
            const Spacer(),
            _StatBadge(
              icon: Icons.fiber_manual_record,
              label: loc.live,
              color: Colors.green,
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _StatBadge(
              icon: Icons.access_time,
              label: loc.now,
              color: Colors.orange,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  String? _localizedCategoryLabel(AppLocalizations loc) {
    final normalized = category?.trim().toLowerCase();
    switch (normalized) {
      case 'national':
        return loc.national;
      case 'international':
        return loc.international;
      case 'sports':
        return loc.sports;
      case 'entertainment':
        return loc.entertainment;
      default:
        return null;
    }
  }
}

class _StatBadge extends ConsumerWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
          ),
        ),
      ],
    );
  }
}
