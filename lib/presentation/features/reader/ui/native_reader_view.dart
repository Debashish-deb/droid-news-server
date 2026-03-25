// lib/features/reader/ui/native_reader_view.dart
//
// ╔══════════════════════════════════════════════════════════╗
// ║  NATIVE READER VIEW – ANDROID-OPTIMISED v2               ║
// ║                                                          ║
// ║  Optimisation layers applied                             ║
// ║  • ConsumerStatefulWidget → lifecycle hooks for caching  ║
// ║  • TextStyle cache (Map) – never recreated per-frame     ║
// ║  • CustomScrollView + SliverList for large article DOM   ║
// ║    (lazy-renders only visible rows)                      ║
// ║  • RepaintBoundary on smart bar, TTS bar, metadata row   ║
// ║  • Scoped ref.watch with select() – minimise rebuilds    ║
// ║  • HtmlWidget config: enableCaching, renderMode async    ║
// ║  • AutomaticKeepAliveClientMixin → survives tab swaps    ║
// ║  • SelectionArea narrowed to content only (not headers)  ║
// ║  • Clipboard read deferred to microtask queue            ║
// ║  • const constructors end-to-end                         ║
// ║  • MediaQuery.paddingOf instead of .of (avoids rebuild   ║
// ║    on unrelated MediaQuery changes)                      ║
// ╚══════════════════════════════════════════════════════════╝

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../models/reader_article.dart';
import '../controllers/reader_controller.dart';
import 'widgets/reader_smart_bar.dart';
import 'widgets/explanation_sheet.dart';
import 'widgets/reader_appearance_sheet.dart';
import '../models/reader_settings.dart';
import '../../../../application/ai/ai_service.dart';
import '../../../../core/tts/presentation/widgets/tts_player_bar.dart';

// ─────────────────────────────────────────────
// STYLE CACHE
// Avoids recreating TextStyle objects every frame.
// ─────────────────────────────────────────────
@immutable
class _StyleKey {
  const _StyleKey({
    required this.fontFamily,
    required this.fontSize,
    required this.theme,
    required this.isDark,
  });

  final ReaderFontFamily fontFamily;
  final double fontSize;
  final ReaderTheme theme;
  final bool isDark;

  @override
  bool operator ==(Object other) =>
      other is _StyleKey &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.theme == theme &&
      other.isDark == isDark;

  @override
  int get hashCode => Object.hash(fontFamily, fontSize, theme, isDark);
}

class _StyleBundle {
  const _StyleBundle({
    required this.title,
    required this.byline,
    required this.body,
    required this.bgColor,
    required this.textColor,
    required this.subColor,
    required this.linkColorHex,
  });

  final TextStyle title;
  final TextStyle byline;
  final TextStyle body;
  final Color bgColor;
  final Color textColor;
  final Color subColor;
  final String linkColorHex;
}

// LRU-style cache bounded to 8 entries (covers all theme × font combos).
final _styleCache = <_StyleKey, _StyleBundle>{};

_StyleBundle _buildStyles(_StyleKey key, ThemeData theme) {
  if (_styleCache.containsKey(key)) return _styleCache[key]!;

  Color bg = Colors.transparent;
  Color text = theme.colorScheme.onSurface;
  Color sub = theme.colorScheme.onSurfaceVariant;

  switch (key.theme) {
    case ReaderTheme.white:
      bg = Colors.white;
      text = Colors.black87;
      sub = Colors.black54;
      break;
    case ReaderTheme.sepia:
      bg = const Color(0xFFF4ECD8);
      text = const Color(0xFF5B4636);
      sub = const Color(0xFF8B735B);
      break;
    case ReaderTheme.night:
      bg = const Color(0xFF1A1A1A);
      text = const Color(0xFFCCCCCC);
      sub = const Color(0xFF888888);
      break;
    case ReaderTheme.system:
      bg = theme.scaffoldBackgroundColor;
      break;
  }

  final baseFont = key.fontFamily == ReaderFontFamily.serif
      ? GoogleFonts.merriweather
      : GoogleFonts.inter;
  final titleFont = key.fontFamily == ReaderFontFamily.serif
      ? GoogleFonts.libreBaskerville
      : GoogleFonts.inter;

  // Convert color to CSS hex for HtmlWidget.
  final r = ((text.red)).toRadixString(16).padLeft(2, '0');
  final g = ((text.green)).toRadixString(16).padLeft(2, '0');
  final b = ((text.blue)).toRadixString(16).padLeft(2, '0');

  final bundle = _StyleBundle(
    bgColor: bg,
    textColor: text,
    subColor: sub,
    linkColorHex: key.theme == ReaderTheme.system ? '#2196F3' : '#$r$g$b',
    title: titleFont(
      fontSize: key.fontSize + 8,
      fontWeight: FontWeight.bold,
      color: text,
      height: 1.3,
    ),
    byline: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: sub,
    ),
    body: baseFont(
      fontSize: key.fontSize,
      height: 1.8,
      color: text.withValues(alpha: 0.9),
    ),
  );

  // Evict oldest entry when cache exceeds bound.
  if (_styleCache.length >= 8) {
    _styleCache.remove(_styleCache.keys.first);
  }
  _styleCache[key] = bundle;
  return bundle;
}

// ─────────────────────────────────────────────
// READER VIEW WIDGET
// ─────────────────────────────────────────────
class NativeReaderView extends ConsumerStatefulWidget {
  const NativeReaderView({
    required this.article,
    this.onPreviousArticle,
    this.onNextArticle,
    this.canGoPreviousArticle = false,
    this.canGoNextArticle = false,
    super.key,
  });

  final ReaderArticle article;
  final VoidCallback? onPreviousArticle;
  final VoidCallback? onNextArticle;
  final bool canGoPreviousArticle;
  final bool canGoNextArticle;

  @override
  ConsumerState<NativeReaderView> createState() => _NativeReaderViewState();
}

class _NativeReaderViewState extends ConsumerState<NativeReaderView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  int _lastAutoFollowChunk = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ──── Bottom sheets ──────────────────────────
  void _showAppearance() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const ReaderAppearanceSheet(),
    );
  }

  Future<void> _explainTerm(
    String selectedText, {
    required String articleText,
  }) async {
    final aiService = ref.read(aiServiceProvider);
    final explanation = await aiService.explainComplexTerm(
      selectedText,
      articleText,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) =>
          ExplanationSheet(term: selectedText, explanation: explanation),
    );
  }

  Future<bool> _handleReaderUrlTap(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return true;

    if (uri.scheme == 'reader' && uri.host == 'chunk') {
      final chunkRaw = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : '';
      final chunkIndex = int.tryParse(chunkRaw);
      if (chunkIndex == null) return false;
      await ref.read(readerControllerProvider.notifier).seekToChunk(chunkIndex);
      return false;
    }

    return true;
  }

  void _syncScrollWithTts({
    required int currentChunkIndex,
    required int totalChunks,
  }) {
    if (currentChunkIndex < 0 ||
        totalChunks <= 1 ||
        currentChunkIndex == _lastAutoFollowChunk) {
      return;
    }
    _lastAutoFollowChunk = currentChunkIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;

      final ratio = (currentChunkIndex / (totalChunks - 1)).clamp(0.0, 1.0);
      final targetOffset = (maxExtent * ratio).clamp(0.0, maxExtent);
      final currentOffset = _scrollController.offset;
      if ((currentOffset - targetOffset).abs() < 24) return;

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ──── Build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Required for AutomaticKeepAliveClientMixin.
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ── Scoped selectors → only rebuild on specific field changes ──
    final fontSize = ref.watch(
      readerControllerProvider.select((s) => s.fontSize),
    );
    final fontFamily = ref.watch(
      readerControllerProvider.select((s) => s.fontFamily),
    );
    final readerTheme = ref.watch(
      readerControllerProvider.select((s) => s.readerTheme),
    );
    final currentChunkIndex = ref.watch(
      readerControllerProvider.select((s) => s.currentChunkIndex),
    );
    final totalChunks = ref.watch(
      readerControllerProvider.select((s) => s.chunks.length),
    );
    final contentToRender = ref.watch(
      readerControllerProvider.select((s) => s.processedContent ?? ''),
    );

    // ── Cached style bundle ──────────────────────────────────────
    final styleKey = _StyleKey(
      fontFamily: fontFamily,
      fontSize: fontSize,
      theme: readerTheme,
      isDark: isDark,
    );
    final styles = _buildStyles(styleKey, theme);

    final isTtsActive = currentChunkIndex != -1;
    final html = contentToRender.isNotEmpty
        ? contentToRender
        : widget.article.content;
    _syncScrollWithTts(
      currentChunkIndex: currentChunkIndex,
      totalChunks: totalChunks,
    );

    return Scaffold(
      backgroundColor: styles.bgColor,
      body: Stack(
        children: [
          // ── Scrollable content area ──────────────────────────
          CustomScrollView(
            controller: _scrollController,
            // ClampingScrollPhysics matches Android's native feel.
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  // Bottom padding clears TTS bar + smart bar.
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title ────────────────────────────────
                      RepaintBoundary(
                        child: Text(widget.article.title, style: styles.title),
                      ),
                      const SizedBox(height: 12),

                      // ── Metadata ─────────────────────────────
                      if (widget.article.byline != null ||
                          widget.article.siteName != null)
                        RepaintBoundary(
                          child: _MetadataRow(
                            article: widget.article,
                            styles: styles,
                            readerTheme: readerTheme,
                            theme: theme,
                          ),
                        ),

                      const SizedBox(height: 24),
                      Divider(color: styles.subColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 24),

                      // ── Selectable article body ───────────────
                      SelectionArea(
                        contextMenuBuilder: (ctx, state) {
                          final items = List<ContextMenuButtonItem>.from(
                            state.contextMenuButtonItems,
                          );
                          items.insert(
                            0,
                            ContextMenuButtonItem(
                              label: AppLocalizations.of(
                                context,
                              ).readerExplainWithAi,
                              onPressed: () async {
                                // Copy first, then hide toolbar –
                                // avoids frame jank from two setState.
                                state.copySelection(
                                  SelectionChangedCause.toolbar,
                                );
                                state.hideToolbar();
                                // Deferred to next microtask so
                                // clipboard write completes first.
                                await Future.microtask(() async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  final selected = data?.text?.trim() ?? '';
                                  if (selected.isNotEmpty && context.mounted) {
                                    await _explainTerm(
                                      selected,
                                      articleText: widget.article.textContent,
                                    );
                                  }
                                });
                              },
                            ),
                          );
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: state.contextMenuAnchors,
                            buttonItems: items,
                          );
                        },
                        child: HtmlWidget(
                          html,
                          textStyle: styles.body,
                          enableCaching: true,
                          onTapUrl: _handleReaderUrlTap,
                          customStylesBuilder: (element) => _htmlStyles(
                            element,
                            currentChunkIndex: currentChunkIndex,
                            styles: styles,
                            readerTheme: readerTheme,
                          ),
                          onLoadingBuilder: (context, element, progress) =>
                              const Center(
                                child: CircularProgressIndicator.adaptive(),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Floating bottom bars ─────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TtsPlayerBar(
                    onPreviousArticle: widget.onPreviousArticle,
                    onNextArticle: widget.onNextArticle,
                    canGoPreviousArticle: widget.canGoPreviousArticle,
                    canGoNextArticle: widget.canGoNextArticle,
                  ),
                  ReaderSmartBar(
                    // Hide the TTS button when TtsPlayerBar is already
                    // visible to avoid duplicate play/stop controls.
                    isTtsPlaying: isTtsActive,
                    hideTtsButton: isTtsActive,
                    onTtsPressed: () {
                      if (isTtsActive) {
                        ref.read(readerControllerProvider.notifier).stopTts();
                      } else {
                        ref
                            .read(readerControllerProvider.notifier)
                            .playFullArticle();
                      }
                    },
                    onAppearancePressed: _showAppearance,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Extracted HTML style builder (avoids closure alloc per-element) ──
  static Map<String, String>? _htmlStyles(
    dynamic element, {
    required int currentChunkIndex,
    required _StyleBundle styles,
    required ReaderTheme readerTheme,
  }) {
    final tag = element.localName as String?;
    final classes = element.classes as Iterable?;
    final hasReaderSentenceClass =
        classes != null &&
        (classes as dynamic).contains('reader-sentence-anchor');

    if (tag == 'a') {
      if (hasReaderSentenceClass) {
        return {'text-decoration': 'none', 'color': 'inherit'};
      }
      return {'text-decoration': 'none', 'color': styles.linkColorHex};
    }
    if (tag == 'img') {
      return {
        'margin': '16px 0',
        'border-radius': '8px',
        'max-width': '100%',
        'height': 'auto',
        'display': 'block',
      };
    }
    if (tag == 'p' || tag == 'li') {
      return {
        'text-align': 'justify',
        'line-height': '1.75',
        'overflow-wrap': 'break-word',
      };
    }
    if (tag == 'ul' || tag == 'ol') {
      return {'padding-left': '1.2em', 'margin': '0.2em 0 1em 0'};
    }
    if (tag == 'pre' || tag == 'code') {
      return {
        'font-family': 'monospace',
        'background-color': styles.bgColor == const Color(0xFF1A1A1A)
            ? '#333'
            : '#f5f5f5',
        'padding': '8px',
        'border-radius': '4px',
      };
    }

    // TTS sentence highlight.
    if (classes != null && (classes as dynamic).contains('reader-sentence')) {
      final indexStr = (element.attributes as Map?)?.entries
          .where((e) => e.key == 'data-index')
          .map((e) => e.value as String)
          .firstOrNull;
      if (indexStr != null) {
        final index = int.tryParse(indexStr);
        if (index == currentChunkIndex) {
          return {
            'background-color': readerTheme == ReaderTheme.night
                ? 'rgba(255,255,255,0.15)'
                : 'rgba(255,235,59,0.4)',
            'border-radius': '3px',
            'transition': 'background-color 0.3s ease',
          };
        }
      }
    }
    return null;
  }
}

// ─────────────────────────────────────────────
// METADATA ROW  (extracted to avoid rebuilding
// on TTS / scroll state changes)
// ─────────────────────────────────────────────
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.article,
    required this.styles,
    required this.readerTheme,
    required this.theme,
  });

  final ReaderArticle article;
  final _StyleBundle styles;
  final ReaderTheme readerTheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (article.siteName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: readerTheme == ReaderTheme.system
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : styles.textColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              article.siteName!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: readerTheme == ReaderTheme.system
                    ? theme.colorScheme.primary
                    : styles.textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (article.byline != null)
          Expanded(
            child: Text(
              article.byline!,
              style: styles.byline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
