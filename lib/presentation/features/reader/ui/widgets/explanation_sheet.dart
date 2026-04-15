import 'package:flutter/material.dart';
import '../../../../../core/theme/theme_skeleton.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/glass_icon_button.dart';

class ExplanationSheet extends StatelessWidget {
  const ExplanationSheet({
    required this.term,
    required this.explanation,
    super.key,
  });
  final String term;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: ThemeSkeleton.shared.insetsAll(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: ThemeSkeleton.shared.radius(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
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
          const SizedBox(height: ThemeSkeleton.size20),

          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 24),
              const SizedBox(width: ThemeSkeleton.size12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).readerAiExplanation,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GlassIconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icons.close,
                isDark: theme.brightness == Brightness.dark,
              ),
            ],
          ),
          const SizedBox(height: ThemeSkeleton.size16),

          Text(
            term,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: ThemeSkeleton.size12),

          Text(
            explanation,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: ThemeSkeleton.size32),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).readerGotIt),
            ),
          ),
          const SizedBox(height: ThemeSkeleton.size12),
        ],
      ),
    );
  }
}
