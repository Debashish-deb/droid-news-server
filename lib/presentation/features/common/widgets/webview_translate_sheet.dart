import 'dart:ui';
import 'package:flutter/material.dart';

enum TranslateEngine { google, bing, deepl }

// ─────────────────────────────────────────────
// TRANSLATE BOTTOM SHEET
// ─────────────────────────────────────────────
class WebTranslateSheet extends StatelessWidget {
  const WebTranslateSheet({required this.url, super.key});
  final String url;

  static const _engines = [
    (
      engine: TranslateEngine.google,
      label: 'Google Translate',
      sub: 'Accurate, widely supported',
    ),
    (
      engine: TranslateEngine.bing,
      label: 'Microsoft Bing',
      sub: 'Good for news content',
    ),
    (
      engine: TranslateEngine.deepl,
      label: 'DeepL',
      sub: 'Best for natural Bengali',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface;
    final bg = cs.surface;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: bg.withValues(alpha: 0.92),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: base.withValues(alpha: 0.18),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'TRANSLATE TO BENGALI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final e in _engines)
                EngineRow(
                  label: e.label,
                  sub: e.sub,
                  onTap: () => Navigator.of(context).pop(e.engine),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class EngineRow extends StatefulWidget {
  const EngineRow({
    required this.label,
    required this.sub,
    required this.onTap,
    super.key,
  });
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  State<EngineRow> createState() => _EngineRowState();
}

class _EngineRowState extends State<EngineRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.onSurface;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _pressed
              ? cs.surfaceContainerHighest.withValues(alpha: 0.65)
              : cs.surfaceContainerHigh.withValues(alpha: 0.42),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.7),
            width: .8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: base,
                      letterSpacing: -.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.sub,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: base.withValues(alpha: 0.45),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: base.withValues(alpha: 0.28),
            ),
          ],
        ),
      ),
    );
  }
}
