import 'package:flutter/material.dart';
import '../../../../core/enums/theme_mode.dart' show AppThemeMode;
import '../../../../core/theme/theme_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../providers/theme_providers.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/utils/number_localization.dart';
import '../../../providers/language_providers.dart';

final Map<AppThemeMode, List<Color>> _professionalHeaderGradientCache =
    <AppThemeMode, List<Color>>{};

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
    final cs = theme.colorScheme;
    final rules = theme.extension<AppThemeRulesExtension>();
    final bool isDark = theme.brightness == Brightness.dark;
    final Color subtitleColor = cs.onSurface.withValues(
      alpha: isDark ? 0.74 : 0.62,
    );
    final Color accentColor = cs.primary;
    final List<Color> colors = _professionalHeaderGradientCache.putIfAbsent(
      themeMode,
      () => AppGradients.getGradientColors(themeMode),
    );

    final localizedCategory = _localizedCategoryLabel(loc);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: AppSpacing.horizontalLg.add(
          ThemeSkeleton.shared.insetsSymmetric(vertical: 4),
        ),
        padding: ThemeSkeleton.shared.insetsSymmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors[0].withValues(alpha: 0.15),
              colors[1].withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.xlBorder,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.36 : 0.28),
            width: AppBorders.regular,
          ),
          boxShadow: isDark
              ? <BoxShadow>[
                  BoxShadow(
                    color: (rules?.navShadow ?? Colors.black).withValues(
                      alpha: 0.26,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: ThemeSkeleton.shared.insetsAll(AppSpacing.xs),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: AppRadius.smBorder,
              ),
              child: Icon(
                Icons
                    .notifications_active_rounded, // Changed to notification icon
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              localizeNumber(articleCount, ref.watch(languageCodeProvider)),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            const SizedBox(width: ThemeSkeleton.size4),
            Text(
              localizedCategory ?? loc.latest,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: localizedCategory != null ? accentColor : subtitleColor,
              ),
            ),
            const Spacer(),
            _StatBadge(
              icon: Icons.fiber_manual_record,
              label: loc.live,
              color: Colors.green,
              isDark: isDark,
            ),
            const SizedBox(width: ThemeSkeleton.size12),
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
      case 'latest':
        return loc.latest;
      case 'trending':
        return loc.trending;
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

class _StatBadge extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: color, size: 12),
        const SizedBox(width: ThemeSkeleton.size4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isDark
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.black87,
          ),
        ),
      ],
    );
  }
}
