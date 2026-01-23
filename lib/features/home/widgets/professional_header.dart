import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/design_tokens.dart';
import '../../../presentation/providers/theme_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/number_localization.dart';
import '../../../presentation/providers/language_providers.dart';

class ProfessionalHeader extends ConsumerWidget {
  const ProfessionalHeader({required this.articleCount, super.key});

  final int articleCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final themeMode = ref.watch(currentThemeModeProvider);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final List<Color> colors = AppGradients.getGradientColors(themeMode);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: AppSpacing.horizontalSm.add(
          AppSpacing.verticalMd,
        ), // Design tokens
        padding: AppSpacing.allXl, // Design tokens
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors[0].withOpacity(0.15), colors[1].withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.xlBorder, // Design tokens
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.25),
            width: AppBorders.regular, // Design tokens
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm), // Design tokens
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.1),
                    borderRadius: AppRadius.mdBorder, // Design tokens
                  ),
                  child: Icon(
                    Icons.article,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    size: AppIconSize.md, // Design tokens
                  ),
                ),
                const SizedBox(width: AppSpacing.md), // Design tokens
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Localize the number counting articles
                      Text(
                        localizeNumber(
                          articleCount,
                          ref.watch(languageCodeProvider),
                        ),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark
                                  ? Colors.blue.shade200
                                  : Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        loc.latestNewsUpdates,
                        style: TextStyle(fontSize: 13, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _StatBadge(
                  icon: Icons.fiber_manual_record,
                  label: loc.live,
                  color: Colors.green,
                  isDark: isDark,
                ),
                _StatBadge(
                  icon: Icons.article,
                  label: localizeNumber(
                    loc.storiesCount(articleCount),
                    ref.watch(languageCodeProvider),
                  ),
                  color: Colors.blue,
                  isDark: isDark,
                ),
                _StatBadge(
                  icon: Icons.access_time,
                  label: loc.now,
                  sublabel: loc.updated,
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends ConsumerWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.sublabel,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (sublabel != null)
          Text(
            sublabel!,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
      ],
    );
  }
}
