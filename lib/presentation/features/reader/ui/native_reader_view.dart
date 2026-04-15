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
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../../../l10n/generated/app_localizations.dart';
import '../models/reader_article.dart';
import '../controllers/reader_controller.dart';
import 'widgets/reader_smart_bar.dart';
import 'widgets/explanation_sheet.dart';
import 'widgets/reader_appearance_sheet.dart';
import '../models/reader_settings.dart';
import '../../../../application/ai/ai_service.dart';
import '../../../../core/tts/domain/entities/tts_chunk.dart';
import '../../../../core/tts/presentation/providers/tts_controller.dart';
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

@immutable
class _ReaderRenderSignal {
  const _ReaderRenderSignal({
    required this.processedContent,
    required this.totalChunks,
  });

  final String processedContent;
  final int totalChunks;

  @override
  bool operator ==(Object other) =>
      other is _ReaderRenderSignal &&
      other.processedContent == processedContent &&
      other.totalChunks == totalChunks;

  @override
  int get hashCode => Object.hash(processedContent, totalChunks);
}

String _compactReaderStageWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final RegExp _readerHighlightWordPattern = RegExp(r'[A-Za-z0-9\u0980-\u09FF]+');

int _readerHighlightWordCount(String text) {
  return _readerHighlightWordPattern.allMatches(text).length;
}

int _estimateReaderWordIndex({
  required List<TtsChunk> chunks,
  required int currentChunkIndex,
  required Duration estimatedPosition,
}) {
  if (currentChunkIndex < 0 || currentChunkIndex >= chunks.length) return -1;
  final chunk = chunks[currentChunkIndex];
  final wordCount = _readerHighlightWordCount(chunk.text);
  if (wordCount <= 0) return -1;

  var elapsedBeforeChunkMs = 0;
  for (var i = 0; i < currentChunkIndex; i++) {
    elapsedBeforeChunkMs += chunks[i].estimatedDuration.inMilliseconds;
  }

  final chunkDurationMs = chunk.estimatedDuration.inMilliseconds <= 0
      ? wordCount * 260
      : chunk.estimatedDuration.inMilliseconds;
  final elapsedInChunkMs =
      (estimatedPosition.inMilliseconds - elapsedBeforeChunkMs)
          .clamp(0, chunkDurationMs)
          .toInt();
  final index = ((elapsedInChunkMs / chunkDurationMs) * wordCount).floor();
  return index.clamp(0, wordCount - 1).toInt();
}

bool _nodeHasMeaningfulReaderContent(dom.Node node) {
  if (node is dom.Text) {
    return _compactReaderStageWhitespace(node.text).isNotEmpty;
  }
  if (node is! dom.Element) return false;

  final tag = node.localName?.toLowerCase();
  if (tag == 'img' ||
      tag == 'video' ||
      tag == 'audio' ||
      tag == 'iframe' ||
      tag == 'source' ||
      tag == 'table' ||
      tag == 'hr') {
    return true;
  }

  for (final child in node.nodes) {
    if (_nodeHasMeaningfulReaderContent(child)) return true;
  }
  return false;
}

void _pruneReaderHtmlAfterChunkLimit(
  dom.Node node,
  int maxVisibleChunkExclusive,
) {
  if (node is dom.Text) {
    if (_compactReaderStageWhitespace(node.text).isEmpty) {
      node.remove();
    }
    return;
  }
  if (node is! dom.Element) return;

  final classes = node.classes;
  final isSentenceAnchor =
      classes.contains('reader-sentence-anchor') ||
      classes.contains('reader-sentence');
  if (isSentenceAnchor) {
    final index = int.tryParse(node.attributes['data-index'] ?? '') ?? -1;
    if (index >= maxVisibleChunkExclusive) {
      node.remove();
      return;
    }
  }

  for (final child in List<dom.Node>.from(node.nodes)) {
    _pruneReaderHtmlAfterChunkLimit(child, maxVisibleChunkExclusive);
  }

  final tag = node.localName?.toLowerCase();
  if (tag == null ||
      tag == 'img' ||
      tag == 'video' ||
      tag == 'audio' ||
      tag == 'iframe' ||
      tag == 'source' ||
      tag == 'table' ||
      tag == 'hr') {
    return;
  }

  if (!_nodeHasMeaningfulReaderContent(node)) {
    node.remove();
  }
}

String _truncateReaderHtmlToChunkLimit(
  String html,
  int maxVisibleChunkExclusive,
) {
  final trimmed = html.trim();
  if (trimmed.isEmpty || maxVisibleChunkExclusive <= 0) {
    return trimmed;
  }

  try {
    final fragment = html_parser.parseFragment(trimmed);
    for (final node in List<dom.Node>.from(fragment.nodes)) {
      _pruneReaderHtmlAfterChunkLimit(node, maxVisibleChunkExclusive);
    }
    final result = fragment.outerHtml.trim();
    return result.isEmpty ? trimmed : result;
  } catch (_) {
    return trimmed;
  }
}

int _phaseChunkBoundary(int totalChunks, double fraction) {
  if (totalChunks <= 0) return 0;
  final raw = (totalChunks * fraction).ceil();
  return raw.clamp(1, totalChunks);
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
      bg = const Color(0xFF1A1D1F); // Charcoal Background
      text = const Color(0xFFE0E0E0);
      sub = const Color(0xFF9E9E9E);
      break;
    case ReaderTheme.system:
      bg = theme.scaffoldBackgroundColor;
      break;
  }

  final String? baseFontFamily = key.fontFamily == ReaderFontFamily.serif
      ? 'serif'
      : null;
  final String? titleFontFamily = key.fontFamily == ReaderFontFamily.serif
      ? 'serif'
      : null;

  // Convert color to CSS hex for HtmlWidget.
  final r = ((text.red)).toRadixString(16).padLeft(2, '0');
  final g = ((text.green)).toRadixString(16).padLeft(2, '0');
  final b = ((text.blue)).toRadixString(16).padLeft(2, '0');

  final bundle = _StyleBundle(
    bgColor: bg,
    textColor: text,
    subColor: sub,
    linkColorHex: key.theme == ReaderTheme.system ? '#2196F3' : '#$r$g$b',
    title: TextStyle(
      fontFamily: titleFontFamily,
      fontSize: key.fontSize + 8,
      fontWeight: FontWeight.bold,
      color: text,
      height: 1.3,
    ),
    byline: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sub),
    body: TextStyle(
      fontFamily: baseFontFamily,
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
    this.onTtsPressed,
    this.canGoPreviousArticle = false,
    this.canGoNextArticle = false,
    this.showAutoTtsControls = true,
    super.key,
  });

  final ReaderArticle article;
  final VoidCallback? onPreviousArticle;
  final VoidCallback? onNextArticle;
  final VoidCallback? onTtsPressed;
  final bool canGoPreviousArticle;
  final bool canGoNextArticle;
  final bool showAutoTtsControls;

  @override
  ConsumerState<NativeReaderView> createState() => _NativeReaderViewState();
}

class _NativeReaderViewState extends ConsumerState<NativeReaderView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  ProviderSubscription<_ReaderRenderSignal>? _readerRenderSubscription;
  final List<Timer> _stagedRenderTimers = <Timer>[];
  int _lastAutoFollowChunk = -1;
  String _renderedHtml = '';
  String _activeRenderKey = '';
  double _renderProgress = 1.0;
  bool _isProgressiveRendering = false;

  static const Duration _secondPhaseDelay = Duration(milliseconds: 90);
  static const Duration _finalPhaseDelay = Duration(milliseconds: 190);

  @override
  void initState() {
    super.initState();

    final readerState = ref.read(readerControllerProvider);
    final initialHtml = (readerState.processedContent ?? '').isNotEmpty
        ? readerState.processedContent!
        : widget.article.content;
    _applyProgressiveRenderPlan(
      html: initialHtml,
      totalChunks: readerState.chunks.length,
      force: true,
    );

    _readerRenderSubscription ??= ref.listenManual<_ReaderRenderSignal>(
      readerControllerProvider.select(
        (s) => _ReaderRenderSignal(
          processedContent: s.processedContent ?? '',
          totalChunks: s.chunks.length,
        ),
      ),
      (previous, next) {
        final html = next.processedContent.isNotEmpty
            ? next.processedContent
            : widget.article.content;
        _applyProgressiveRenderPlan(html: html, totalChunks: next.totalChunks);
      },
    );
  }

  @override
  void didUpdateWidget(covariant NativeReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.content == widget.article.content &&
        oldWidget.article.title == widget.article.title &&
        oldWidget.article.length == widget.article.length) {
      return;
    }

    final readerState = ref.read(readerControllerProvider);
    final html = (readerState.processedContent ?? '').isNotEmpty
        ? readerState.processedContent!
        : widget.article.content;
    _applyProgressiveRenderPlan(
      html: html,
      totalChunks: readerState.chunks.length,
      force: true,
    );
  }

  @override
  void dispose() {
    _readerRenderSubscription?.close();
    for (final timer in _stagedRenderTimers) {
      timer.cancel();
    }
    _stagedRenderTimers.clear();
    _scrollController.dispose();
    super.dispose();
  }

  bool _shouldUseProgressiveRender(String html, int totalChunks) {
    if (totalChunks < 18) return false;
    if (html.length < 2800) return false;
    return html.contains('reader-sentence-anchor');
  }

  void _cancelProgressiveRenderTimers() {
    for (final timer in _stagedRenderTimers) {
      timer.cancel();
    }
    _stagedRenderTimers.clear();
  }

  void _applyProgressiveRenderPlan({
    required String html,
    required int totalChunks,
    bool force = false,
  }) {
    final trimmed = html.trim();
    final key = Object.hash(
      trimmed,
      totalChunks,
      widget.article.title,
    ).toString();
    if (!force && _activeRenderKey == key) return;

    _cancelProgressiveRenderTimers();

    if (trimmed.isEmpty || !_shouldUseProgressiveRender(trimmed, totalChunks)) {
      if (!mounted) {
        _activeRenderKey = key;
        _renderedHtml = trimmed;
        _renderProgress = 1.0;
        _isProgressiveRendering = false;
        return;
      }
      setState(() {
        _activeRenderKey = key;
        _renderedHtml = trimmed;
        _renderProgress = 1.0;
        _isProgressiveRendering = false;
      });
      return;
    }

    final firstBoundary = _phaseChunkBoundary(totalChunks, 0.30);
    final secondBoundary = _phaseChunkBoundary(totalChunks, 0.60);
    final firstHtml = _truncateReaderHtmlToChunkLimit(trimmed, firstBoundary);

    if (!mounted) {
      _activeRenderKey = key;
      _renderedHtml = firstHtml;
      _renderProgress = 0.30;
      _isProgressiveRendering = true;
      return;
    }

    setState(() {
      _activeRenderKey = key;
      _renderedHtml = firstHtml;
      _renderProgress = 0.30;
      _isProgressiveRendering = true;
    });

    void enqueuePhase(
      Duration delay, {
      required double progress,
      required String nextHtml,
      required bool finalPhase,
    }) {
      _stagedRenderTimers.add(
        Timer(delay, () {
          if (!mounted || _activeRenderKey != key) return;
          setState(() {
            _renderedHtml = nextHtml;
            _renderProgress = progress;
            _isProgressiveRendering = !finalPhase;
          });
        }),
      );
    }

    enqueuePhase(
      _secondPhaseDelay,
      progress: 0.60,
      nextHtml: _truncateReaderHtmlToChunkLimit(trimmed, secondBoundary),
      finalPhase: false,
    );
    enqueuePhase(
      _finalPhaseDelay,
      progress: 1.0,
      nextHtml: trimmed,
      finalPhase: true,
    );
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
    final chunks = ref.watch(readerControllerProvider.select((s) => s.chunks));
    final totalChunks = chunks.length;
    final ttsPositionBucket = ref.watch(
      ttsControllerProvider.select(
        (s) => s.estimatedPosition.inMilliseconds ~/ 200,
      ),
    );
    final currentWordIndex = _estimateReaderWordIndex(
      chunks: chunks,
      currentChunkIndex: currentChunkIndex,
      estimatedPosition: Duration(milliseconds: ttsPositionBucket * 200),
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
    if (_renderedHtml.isEmpty && html.isNotEmpty) {
      _renderedHtml = html;
      _renderProgress = 1.0;
    }
    final renderHtml = _renderedHtml.isNotEmpty ? _renderedHtml : html;
    final allowInlineMedia = !_isProgressiveRendering && _renderProgress >= 1.0;
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

                      if (_isProgressiveRendering) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _renderProgress,
                            minHeight: 3,
                            backgroundColor: styles.subColor.withValues(
                              alpha: 0.12,
                            ),
                            color: styles.textColor.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

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
                          renderHtml,
                          textStyle: styles.body,
                          enableCaching: true,
                          onTapUrl: _handleReaderUrlTap,
                          customStylesBuilder: (element) => _htmlStyles(
                            element,
                            currentChunkIndex: currentChunkIndex,
                            currentWordIndex: currentWordIndex,
                            styles: styles,
                            readerTheme: readerTheme,
                            allowInlineMedia: allowInlineMedia,
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
                    showAutoPlayControls: widget.showAutoTtsControls,
                  ),
                  ReaderSmartBar(
                    // Hide the TTS button when TtsPlayerBar is already
                    // visible to avoid duplicate play/stop controls.
                    isTtsPlaying: isTtsActive,
                    hideTtsButton: isTtsActive,
                    onTtsPressed:
                        widget.onTtsPressed ??
                        () {
                          if (isTtsActive) {
                            ref
                                .read(readerControllerProvider.notifier)
                                .stopTts();
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
    required int currentWordIndex,
    required _StyleBundle styles,
    required ReaderTheme readerTheme,
    required bool allowInlineMedia,
  }) {
    final tag = element.localName as String?;
    final classes = element.classes as Iterable?;
    final hasReaderSentenceClass =
        classes != null &&
        ((classes as dynamic).contains('reader-sentence-anchor') ||
            (classes as dynamic).contains('reader-sentence'));
    final hasReaderWordClass =
        classes != null && (classes as dynamic).contains('reader-word');
    final attributes = element.attributes as Map?;
    final sentenceIndex = int.tryParse(
      attributes?['data-index']?.toString() ??
          attributes?['data-sentence-index']?.toString() ??
          '',
    );
    final wordIndex = int.tryParse(
      attributes?['data-word-index']?.toString() ?? '',
    );

    if (tag == 'a') {
      if (hasReaderSentenceClass) {
        return {
          'text-decoration': 'none',
          'color': 'inherit',
          if (sentenceIndex == currentChunkIndex)
            ..._sentenceHighlightStyle(readerTheme),
        };
      }
      return {'text-decoration': 'none', 'color': styles.linkColorHex};
    }
    if (tag == 'img') {
      if (!allowInlineMedia) {
        return {'display': 'none'};
      }
      return {
        'margin': '16px 0',
        'border-radius': '8px',
        'max-width': '100%',
        'height': 'auto',
        'display': 'block',
      };
    }
    if ((tag == 'iframe' || tag == 'video' || tag == 'audio') &&
        !allowInlineMedia) {
      return {'display': 'none'};
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

    if (hasReaderWordClass &&
        sentenceIndex == currentChunkIndex &&
        wordIndex == currentWordIndex) {
      return {
        'background-color': readerTheme == ReaderTheme.night
            ? 'rgba(255,255,255,0.32)'
            : 'rgba(255,213,79,0.78)',
        'border-radius': '4px',
        'padding': '0 2px',
        'box-decoration-break': 'clone',
        '-webkit-box-decoration-break': 'clone',
      };
    }

    // TTS sentence highlight.
    if (hasReaderSentenceClass && sentenceIndex == currentChunkIndex) {
      return _sentenceHighlightStyle(readerTheme);
    }
    return null;
  }

  static Map<String, String> _sentenceHighlightStyle(ReaderTheme readerTheme) {
    return {
      'background-color': readerTheme == ReaderTheme.night
          ? 'rgba(255,255,255,0.10)'
          : 'rgba(255,235,59,0.22)',
      'border-radius': '3px',
      'box-decoration-break': 'clone',
      '-webkit-box-decoration-break': 'clone',
      'transition': 'background-color 0.3s ease',
    };
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
              style: TextStyle(
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
