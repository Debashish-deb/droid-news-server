import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/reader_article.dart';
import '../controllers/reader_controller.dart';
import 'widgets/reader_smart_bar.dart';
import 'widgets/smart_summary_sheet.dart';
import 'widgets/explanation_sheet.dart';
import 'widgets/reader_appearance_sheet.dart';
import '../models/reader_settings.dart';
import '../../../../application/ai/ai_service.dart';
import '../../../../core/tts/presentation/widgets/tts_player_bar.dart';

import '../../../../l10n/generated/app_localizations.dart' show AppLocalizations;

class NativeReaderView extends ConsumerWidget {

  const NativeReaderView({
    required this.article, super.key,
  });
  final ReaderArticle article;

  void _showSummary(BuildContext context, WidgetRef ref, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartSummarySheet(
        content: content,
        aiService: ref.read(aiServiceProvider),
      ),
    );
  }

  void _showAppearance(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReaderAppearanceSheet(),
    );
  }

  Future<void> _explainTerm(BuildContext context, WidgetRef ref, String selectedText) async {
    final aiService = ref.read(aiServiceProvider);
    
    final explanation = await aiService.explainComplexTerm(selectedText, article.textContent);

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => ExplanationSheet(
          term: selectedText,
          explanation: explanation,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Watch controller for highlighting state
    final readerState = ref.watch(readerControllerProvider);
    final currentChunkIndex = readerState.currentChunkIndex;
    final contentToRender = readerState.processedContent ?? article.content;
    
    // Watch TTS state for the bar
    final isTtsActive = currentChunkIndex != -1;

    // --- PERSONALIZATION LOGIC ---
    Color bgColor = Colors.transparent;
    Color textColor = theme.colorScheme.onSurface;
    Color subColor = theme.colorScheme.onSurfaceVariant;
    
    // Apply Theme
    switch(readerState.readerTheme) {
      case ReaderTheme.white:
        bgColor = Colors.white;
        textColor = Colors.black87;
        subColor = Colors.black54;
        break;
      case ReaderTheme.sepia:
        bgColor = const Color(0xFFF4ECD8);
        textColor = const Color(0xFF5B4636);
        subColor = const Color(0xFF8B735B);
        break;
      case ReaderTheme.night:
        bgColor = const Color(0xFF1A1A1A);
        textColor = const Color(0xFFCCCCCC);
        subColor = const Color(0xFF888888);
        break;
      case ReaderTheme.system:
        bgColor = theme.scaffoldBackgroundColor;
        break;
    }

    // Apply Font
    final baseFont = readerState.fontFamily == ReaderFontFamily.serif 
        ? GoogleFonts.merriweather 
        : GoogleFonts.inter;
    
    final titleFont = readerState.fontFamily == ReaderFontFamily.serif 
        ? GoogleFonts.libreBaskerville 
        : GoogleFonts.inter;
    
    final titleStyle = titleFont(
      fontSize: readerState.fontSize + 8,
      fontWeight: FontWeight.bold,
      color: textColor,
      height: 1.3,
    );

    final bylineStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: subColor,
    );

    final bodyStyle = baseFont(
      fontSize: readerState.fontSize,
      height: 1.8,
      color: textColor.withOpacity(0.9),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          SelectionArea(
            contextMenuBuilder: (context, selectableRegionState) {
              final List<ContextMenuButtonItem> buttonItems = 
                  selectableRegionState.contextMenuButtonItems;
              
              // Add custom "Explain" button
              buttonItems.insert(
                0, // Top of the list
                ContextMenuButtonItem(
                  label: AppLocalizations.of(context).readerExplainWithAi,
                  onPressed: () async {
                    // Use Clipboard to get selected text since SelectableRegionState 
                    // doesn't expose a controller directly.
                    selectableRegionState.copySelection(SelectionChangedCause.toolbar);
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final selectedText = data?.text ?? '';
                    
                    selectableRegionState.hideToolbar();
                    if (selectedText.isNotEmpty && context.mounted) {
                      _explainTerm(context, ref, selectedText.trim());
                    }
                  },
                ),
              );

              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: selectableRegionState.contextMenuAnchors,
                buttonItems: buttonItems,
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), // Extra bottom padding for bar
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    article.title,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 12),
                  
                  // Metadata Row
                  if (article.byline != null || article.siteName != null)
                    Row(
                      children: [
                        if (article.siteName != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: readerState.readerTheme == ReaderTheme.system 
                                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                                  : textColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              article.siteName!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: readerState.readerTheme == ReaderTheme.system 
                                    ? theme.colorScheme.primary 
                                    : textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (article.byline != null)
                          Expanded(
                            child: Text(
                              article.byline!,
                              style: bylineStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  
                  const SizedBox(height: 24),
                  Divider(color: subColor.withOpacity(0.3)),
                  const SizedBox(height: 24),

                  // Content
                  HtmlWidget(
                    contentToRender,
                    textStyle: bodyStyle,
                    customStylesBuilder: (element) {
                      if (element.localName == 'a') {
                        final linkColorHex = readerState.readerTheme == ReaderTheme.system 
                            ? '#2196F3' 
                            : '#${textColor.value.toRadixString(16).substring(2)}';
                        return {
                          'text-decoration': 'none', 
                          'color': linkColorHex,
                        };
                      }
                      if (element.localName == 'img') {
                        return {'margin': '16px 0', 'border-radius': '8px'};
                      }
                      if (element.localName == 'pre' || element.localName == 'code') {
                         return {
                           'font-family': 'monospace',
                           'background-color': isDark ? '#333' : '#f5f5f5',
                           'padding': '8px',
                           'border-radius': '4px',
                         };
                      }
                      
                      // Highlighting Logic
                      if (element.classes.contains('reader-sentence')) {
                        final indexStr = element.attributes['data-index'];
                        if (indexStr != null) {
                          final index = int.tryParse(indexStr);
                          if (index == currentChunkIndex) {
                            return {
                              'background-color': readerState.readerTheme == ReaderTheme.night 
                                  ? 'rgba(255, 255, 255, 0.15)' 
                                  : 'rgba(255, 235, 59, 0.4)', 
                              'border-radius': '3px',
                              'transition': 'background-color 0.3s ease',
                            };
                          }
                        }
                      }
                      
                      return null;
                    },
                    onLoadingBuilder: (context, element, loadingProgress) => 
                       const Center(child: CircularProgressIndicator.adaptive()),
                  ),
                ],
              ),
            ),
          ),

          // Floating Smart Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TtsPlayerBar(),
                ReaderSmartBar(
                  isTtsPlaying: isTtsActive,
                  onSummaryPressed: () => _showSummary(context, ref, article.textContent),
                  onTtsPressed: () {
                    if (isTtsActive) {
                      ref.read(readerControllerProvider.notifier).stopTts();
                    } else {
                      ref.read(readerControllerProvider.notifier).playFullArticle();
                    }
                  },
                  onAppearancePressed: () => _showAppearance(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
