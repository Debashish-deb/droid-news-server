import 'package:flutter/material.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../application/ai/ai_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../widgets/glass_icon_button.dart';

class SmartSummarySheet extends StatefulWidget {

  const SmartSummarySheet({
    required this.content, required this.aiService, super.key,
  });
  final String content;
  final AIService aiService;

  @override
  State<SmartSummarySheet> createState() => _SmartSummarySheetState();
}

class _SmartSummarySheetState extends State<SmartSummarySheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _tldr;
  String? _keyPoints;
  String? _detailed;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _generateSummaries();
  }

  Future<void> _generateSummaries() async {
    setState(() => _isLoading = true);
    
    // Simulate thinking delay for premium feel
    await Future.delayed(const Duration(milliseconds: 800));

    final results = await Future.wait([
      widget.aiService.summarize(widget.content, type: SummaryType.tldr),
      widget.aiService.summarize(widget.content, type: SummaryType.keyPoints),
      widget.aiService.summarize(widget.content),
    ]);

    if (mounted) {
      setState(() {
        _tldr = results[0];
        _keyPoints = results[1];
        _detailed = results[2];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).readerAiSmartSummary,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                GlassIconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icons.close,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: AppLocalizations.of(context).readerTldr),
              Tab(text: AppLocalizations.of(context).readerKeyPoints),
              Tab(text: AppLocalizations.of(context).readerDetailed),
            ],
          ),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator.adaptive())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _SummaryContent(text: _tldr ?? ""),
                    _SummaryContent(text: _keyPoints ?? ""),
                    _SummaryContent(text: _detailed ?? ""),
                  ],
                ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SummaryContent extends StatefulWidget {

  const _SummaryContent({required this.text});
  final String text;

  @override
  State<_SummaryContent> createState() => _SummaryContentState();
}

class _SummaryContentState extends State<_SummaryContent> {
  String _displayedText = "";
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    if (widget.text.isEmpty) return;
    
    const duration = Duration(milliseconds: 10);
    Future.doWhile(() async {
      await Future.delayed(duration);
      if (!mounted) return false;
      
      setState(() {
        _charIndex++;
        _displayedText = widget.text.substring(0, _charIndex);
      });
      
      return _charIndex < widget.text.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: SelectableText(
        _displayedText,
        style: GoogleFonts.inter(
          fontSize: 15,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
