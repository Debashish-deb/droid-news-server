import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../../core/theme/theme.dart';

class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsExtension>()!;
    final isDark = theme.brightness == Brightness.dark;
    final baseGradient = <Color>[
      theme.scaffoldBackgroundColor,
      appColors.surface.withValues(alpha: isDark ? 1 : 0.98),
    ];

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android already owns the launch experience via the platform splash.
      // Keep the Flutter-side bootstrap surface visually neutral so there is
      // not a second branded splash layer after the native one.
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const SizedBox.expand(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              baseGradient[0],
              Color.alphaBlend(
                appColors.proBlue.withValues(alpha: isDark ? 0.08 : 0.06),
                baseGradient[0],
              ),
              baseGradient[1],
            ],
          ),
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(
                    alpha: isDark ? 0.20 : 0.72,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: isDark ? 0.45 : 0.65,
                    ),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.22 : 0.12,
                      ),
                      blurRadius: 30,
                      spreadRadius: 4,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Image.asset(
                  'assets/play_store_512-app.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
