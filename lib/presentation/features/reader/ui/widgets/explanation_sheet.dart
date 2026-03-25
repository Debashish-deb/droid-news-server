import 'package:flutter/material.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../widgets/glass_icon_button.dart';

class ExplanationSheet extends StatelessWidget {

  const ExplanationSheet({
    required this.term, required this.explanation, super.key,
  });
  final String term;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).readerAiExplanation,
                  style: GoogleFonts.inter(
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
          const SizedBox(height: 16),
          
          Text(
            term,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            explanation,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).readerGotIt),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
