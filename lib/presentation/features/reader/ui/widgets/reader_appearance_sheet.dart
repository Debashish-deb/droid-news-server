import 'package:flutter/material.dart';
import '../../../../../core/theme/theme_skeleton.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reader_settings.dart';
import '../../controllers/reader_controller.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../widgets/glass_icon_button.dart';

class ReaderAppearanceSheet extends ConsumerWidget {
  const ReaderAppearanceSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(readerControllerProvider);
    final notifier = ref.read(readerControllerProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      padding: ThemeSkeleton.shared.insetsAll(AppSpacing.xxl),
      decoration: BoxDecoration(
        color:
            theme.bottomSheetTheme.backgroundColor ??
            theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: ThemeSkeleton.shared.radius(AppRadius.xxl),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
            ),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: ThemeSkeleton.shared.circular(2),
                ),
              ),
            ),
            const SizedBox(height: ThemeSkeleton.size24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).readerAppearance,
                  style:
                      theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ) ??
                      const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                GlassIconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icons.close,
                  isDark: theme.brightness == Brightness.dark,
                ),
              ],
            ),
            const SizedBox(height: ThemeSkeleton.size32),

            // Font Size
            _buildSectionTitle(
              context,
              AppLocalizations.of(context).readerFontSize,
            ),
            const SizedBox(height: ThemeSkeleton.size12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: state.fontSize > 12
                      ? () => notifier.setFontSize(state.fontSize - 1)
                      : null,
                ),
                Expanded(
                  child: Slider(
                    value: state.fontSize,
                    min: 12,
                    max: 28,
                    divisions: 16,
                    label: state.fontSize.round().toString(),
                    onChanged: (val) => notifier.setFontSize(val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: state.fontSize < 28
                      ? () => notifier.setFontSize(state.fontSize + 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: ThemeSkeleton.size24),

            // Font Family
            _buildSectionTitle(
              context,
              AppLocalizations.of(context).readerTypography,
            ),
            const SizedBox(height: ThemeSkeleton.size12),
            Row(
              children: [
                _buildChoiceChip(
                  context: context,
                  label: AppLocalizations.of(context).readerSerif,
                  isSelected: state.fontFamily == ReaderFontFamily.serif,
                  onTap: () => notifier.setFontFamily(ReaderFontFamily.serif),
                ),
                const SizedBox(width: ThemeSkeleton.size12),
                _buildChoiceChip(
                  context: context,
                  label: AppLocalizations.of(context).readerSans,
                  isSelected: state.fontFamily == ReaderFontFamily.sans,
                  onTap: () => notifier.setFontFamily(ReaderFontFamily.sans),
                ),
              ],
            ),
            const SizedBox(height: ThemeSkeleton.size24),

            // Themes
            _buildSectionTitle(
              context,
              AppLocalizations.of(context).readerBackground,
            ),
            const SizedBox(height: ThemeSkeleton.size12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildThemeCircle(
                  context: context,
                  themeType: ReaderTheme.white,
                  color: Colors.white,
                  isSelected: state.readerTheme == ReaderTheme.white,
                  onTap: () => notifier.setReaderTheme(ReaderTheme.white),
                ),
                _buildThemeCircle(
                  context: context,
                  themeType: ReaderTheme.sepia,
                  color: const Color(0xFFF4ECD8),
                  isSelected: state.readerTheme == ReaderTheme.sepia,
                  onTap: () => notifier.setReaderTheme(ReaderTheme.sepia),
                ),
                _buildThemeCircle(
                  context: context,
                  themeType: ReaderTheme.night,
                  color: const Color(0xFF1A1A1A),
                  isSelected: state.readerTheme == ReaderTheme.night,
                  onTap: () => notifier.setReaderTheme(ReaderTheme.night),
                ),
                _buildThemeCircle(
                  context: context,
                  themeType: ReaderTheme.system,
                  color: Colors.transparent,
                  isSystem: true,
                  isSelected: state.readerTheme == ReaderTheme.system,
                  onTap: () => notifier.setReaderTheme(ReaderTheme.system),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ), // Reduced from 40 for bottom sheet spacing
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style:
          theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ) ??
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
    );
  }

  Widget _buildChoiceChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: ThemeSkeleton.shared.insetsSymmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
            borderRadius: AppRadius.mdBorder,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style:
                theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ) ??
                TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCircle({
    required BuildContext context,
    required ReaderTheme themeType,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    bool isSystem = false,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isSystem
                ? Icon(
                    Icons.brightness_medium,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : (themeType == ReaderTheme.night
                      ? const Icon(
                          Icons.nightlight_round,
                          color: Colors.white70,
                        )
                      : null),
          ),
          const SizedBox(height: ThemeSkeleton.size8),
          Text(
            _getThemeLabel(context, themeType, isSystem),
            style:
                theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ) ??
                TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  String _getThemeLabel(
    BuildContext context,
    ReaderTheme theme,
    bool isSystem,
  ) {
    final l10n = AppLocalizations.of(context);
    if (isSystem) return l10n.readerSystem;
    switch (theme) {
      case ReaderTheme.white:
        return l10n.readerWhite;
      case ReaderTheme.sepia:
        return l10n.readerSepia;
      case ReaderTheme.night:
        return l10n.readerNight;
      case ReaderTheme.system:
        return l10n.readerSystem;
    }
  }
}
