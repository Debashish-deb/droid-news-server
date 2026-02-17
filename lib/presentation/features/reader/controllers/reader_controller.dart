import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/reader_article.dart';
import '../../../../core/tts/domain/entities/tts_chunk.dart';
import '../../../../core/tts/presentation/providers/tts_controller.dart';
import '../models/reader_settings.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../providers/app_settings_providers.dart';

class ReaderState {

  const ReaderState({
    this.isReaderMode = false,
    this.isLoading = false,
    this.article,
    this.errorMessage,
    this.chunks = const [],
    this.currentChunkIndex = -1,
    this.processedContent,
    this.fontSize = 16.0,
    this.fontFamily = ReaderFontFamily.serif,
    this.readerTheme = ReaderTheme.system,
  });
  final bool isReaderMode;
  final bool isLoading;
  final ReaderArticle? article;
  final String? errorMessage;
  
  // TTS State
  final List<TtsChunk> chunks;
  final int currentChunkIndex;
  final String? processedContent; // HTML with spans

  // Personalization settings
  final double fontSize;
  final ReaderFontFamily fontFamily;
  final ReaderTheme readerTheme;

  ReaderState copyWith({
    bool? isReaderMode,
    bool? isLoading,
    ReaderArticle? article,
    String? errorMessage,
    List<TtsChunk>? chunks,
    int? currentChunkIndex,
    String? processedContent,
    double? fontSize,
    ReaderFontFamily? fontFamily,
    ReaderTheme? readerTheme,
  }) {
    return ReaderState(
      isReaderMode: isReaderMode ?? this.isReaderMode,
      isLoading: isLoading ?? this.isLoading,
      article: article ?? this.article,
      errorMessage: errorMessage ?? this.errorMessage,
      chunks: chunks ?? this.chunks,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      processedContent: processedContent ?? this.processedContent,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      readerTheme: readerTheme ?? this.readerTheme,
    );
  }
}

class ReaderController extends StateNotifier<ReaderState> {
  ReaderController(this.ref) : super(const ReaderState()) {
    // Listen to TTS updates for highlighting
    _ttsSubscription = ref.listen(ttsControllerProvider, (previous, next) {
      if (state.isReaderMode && state.chunks.isNotEmpty) {
        state = state.copyWith(currentChunkIndex: next.currentChunk);
      }
    });

    _loadSettings();
  }
  
  final Ref ref;
  late final SettingsRepository _repository = ref.read(settingsRepositoryProvider);
  ProviderSubscription? _ttsSubscription;
  InAppWebViewController? _webViewController;
  String? _readabilityScript;

  @override
  void dispose() {
    _ttsSubscription?.close();
    super.dispose();
  }

  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  Future<void> _loadReadabilityScript() async {
    if (_readabilityScript != null) return;
    try {
      _readabilityScript = await rootBundle.loadString('assets/js/readability.js');
    } catch (e) {
      state = state.copyWith(errorMessage: "Failed to load Readability script: $e");
    }
  }

  Future<void> toggleReaderMode() async {
    if (state.isReaderMode) {
      state = state.copyWith(isReaderMode: false);
      stopTts();
    } else {
      if (state.article != null) {
        state = state.copyWith(isReaderMode: true);
        return;
      }
      await extractContent();
    }
  }

  Future<void> extractContent() async {
    if (_webViewController == null) return;
    
    state = state.copyWith(isLoading: true);

    try {
      await _loadReadabilityScript();
      if (_readabilityScript == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      await _webViewController!.evaluateJavascript(source: _readabilityScript!);

      final result = await _webViewController!.evaluateJavascript(source: '''
        (function() {
          try {
            var documentClone = document.cloneNode(true); 
            var article = new Readability(documentClone).parse();
            return JSON.stringify(article);
          } catch(e) {
            return null;
          }
        })();
      ''');

      if (result != null) {
        final Map<String, dynamic> jsonMap = json.decode(result);
        final article = ReaderArticle.fromJson(jsonMap);
        
        // Process HTML for TTS
        final processingResult = _processHtmlForTts(article);

        state = state.copyWith(
          isReaderMode: true,
          isLoading: false,
          article: article,
          processedContent: processingResult.html,
          chunks: processingResult.chunks,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Failed to extract content. Page might not be compatible.",
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error during extraction: $e",
      );
    }
  }

  ({String html, List<TtsChunk> chunks}) _processHtmlForTts(ReaderArticle article, {String language = 'en'}) {
    final document = html_parser.parseFragment(article.content);
    final List<TtsChunk> chunks = [];
    int chunkCount = 0;

    // Prep Humanized Cues
    final titleLabel = language.startsWith('bn') ? 'শিরোনাম: ' : 'Title: ';
    final introPhrase = language.startsWith('bn') ? 'বিস্তারিত খবরে আসছি' : 'Moving on to detailed news';
    final reporterLabel = language.startsWith('bn') ? 'প্রতিবেদক: ' : 'Reporter: ';
    final siteLabel = language.startsWith('bn') ? 'উৎস: ' : 'Source: ';
    final metadataWarning = language.startsWith('bn') ? 'সতর্কবার্তা, এটি সংবাদ সংশ্লিষ্ট তথ্য মাত্র: ' : 'Notice, the following is metadata only: ';

    // 1. Initial Metadata Chunks (Wait, these won't be highlightable in the HTML, but that's okay for start)
    if (article.title.isNotEmpty) {
      chunks.add(TtsChunk(
        index: chunkCount++,
        text: '$titleLabel ${article.title}. $introPhrase.',
        estimatedDuration: Duration(milliseconds: (article.title.length + 50) * 40),
      ));
    }

    if (article.byline != null || article.siteName != null) {
       String metaText = '$metadataWarning. ';
       if (article.byline != null) metaText += '$reporterLabel ${article.byline}. ';
       if (article.siteName != null) metaText += '$siteLabel ${article.siteName}. ';
       
       chunks.add(TtsChunk(
         index: chunkCount++,
         text: metaText,
         estimatedDuration: Duration(milliseconds: metaText.length * 40),
       ));
    }

    void walk(dom.Node node) {
      if (node.nodeType == dom.Node.TEXT_NODE) {
        final String text = node.text?.trim() ?? '';
        if (text.isNotEmpty && text.length > 5) {
           final RegExp sentenceRegExp = RegExp(r"(?<!\w\.\w.)(?<![A-Z][a-z]\.)(?<=\.|\?|\!)\s");
           final parts = text.split(sentenceRegExp);

           final parent = node.parentNode;
           if (parent != null) {
             final indexInParent = parent.nodes.indexOf(node);
             parent.nodes.removeAt(indexInParent);

             for (var i = 0; i < parts.length; i++) {
               final part = parts[i];
               if (part.trim().isEmpty) continue;
               
               final finalPart = i < parts.length - 1 ? "$part " : part;
               
               final chunk = TtsChunk(
                 index: chunkCount,
                 text: finalPart.trim(),
                 estimatedDuration: Duration(milliseconds: finalPart.length * 40),
               );
               chunks.add(chunk);
               
               final span = dom.Element.tag('span');
               span.classes.add('reader-sentence');
               span.attributes['data-index'] = chunkCount.toString();
               span.text = "$finalPart "; 
               
               parent.nodes.insert(indexInParent + i, span);
               chunkCount++;
             }
           }
        }
      } else if (node.hasChildNodes()) {
         for (var child in List.from(node.nodes)) {
           walk(child);
         }
      }
    }

    walk(document);

    return (html: document.outerHtml, chunks: chunks);
  }

  // TTS Controls
  Future<void> playFullArticle() async {
    if (state.chunks.isEmpty) return;
    
    final ttsController = ref.read(ttsControllerProvider.notifier);
    await ttsController.playChunks(state.chunks); 
  }
  
  void pauseTts() {
    ref.read(ttsControllerProvider.notifier).pause();
  }
  
  void resumeTts() {
    ref.read(ttsControllerProvider.notifier).resume();
  }

  void stopTts() {
    ref.read(ttsControllerProvider.notifier).stop();
    state = state.copyWith(currentChunkIndex: -1);
  }

  // Personalization logic
  Future<void> _loadSettings() async {
    final fontSizeRes = await _repository.getReaderFontSize();
    final fontFamilyRes = await _repository.getReaderFontFamily();
    final readerThemeRes = await _repository.getReaderTheme();

    state = state.copyWith(
      fontSize: fontSizeRes.fold((l) => 16.0, (r) => r),
      fontFamily: fontFamilyRes.fold((l) => ReaderFontFamily.serif, (r) => ReaderFontFamily.values[r]),
      readerTheme: readerThemeRes.fold((l) => ReaderTheme.system, (r) => ReaderTheme.values[r]),
    );
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    await _repository.setReaderFontSize(size);
  }

  Future<void> setFontFamily(ReaderFontFamily family) async {
    state = state.copyWith(fontFamily: family);
    await _repository.setReaderFontFamily(family.index);
  }

  Future<void> setReaderTheme(ReaderTheme theme) async {
    state = state.copyWith(readerTheme: theme);
    await _repository.setReaderTheme(theme.index);
  }
}

final readerControllerProvider = StateNotifierProvider.autoDispose<ReaderController, ReaderState>((ref) {
  return ReaderController(ref);
});
