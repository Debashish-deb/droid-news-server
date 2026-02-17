
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import '../../../core/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../core/theme.dart';
import '../../providers/theme_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/widgets/settings_3d_widgets.dart';
import '../../widgets/glass_pill_button.dart';
import '../../widgets/glass_icon_button.dart';

class HistoryWidget extends ConsumerStatefulWidget {
  const HistoryWidget({super.key});

  @override
  ConsumerState<HistoryWidget> createState() => _HistoryWidgetState();
}

class _HistoryWidgetState extends ConsumerState<HistoryWidget> {
  bool isLoading = true;
  Map<String, dynamic>? data;
  String? error;
  AppLocalizations get loc => AppLocalizations.of(context);
  DateTime currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    setState(() => isLoading = true);
    // FIX: Added missing slash in https://
    final url = Uri.parse(
      'https://byabbe.se/on-this-day/${currentDate.month}/${currentDate.day}/events.json',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          data = json.decode(response.body);
          isLoading = false;
          error = null;
        });
      } else {
        setState(() {
          error = 'Error ${response.statusCode}: Unable to fetch data';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Exception: $e';
        isLoading = false;
      });
    }
  }

  void _goToPreviousDay() {
    setState(() => currentDate = currentDate.subtract(const Duration(days: 1)));
    fetchHistory();
  }

  void _goToNextDay() {
    setState(() => currentDate = currentDate.add(const Duration(days: 1)));
    fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final themeMode = ref.watch(currentThemeModeProvider);
    final isDark = themeMode == AppThemeMode.dark;
    final todayLabel = DateFormat('MMMM d').format(currentDate);
    final events = (data?['events'] as List<dynamic>? ?? []).toList();

    final gradientColors = AppGradients.getBackgroundGradient(themeMode);
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final navIconColor = ref.watch(navIconColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '${loc.historicalHistory} • $todayLabel'.toUpperCase(),
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.5,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: Center(
          child: GlassIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
            isDark: isDark,
          ),
        ),
        leadingWidth: 64,
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColors[0].withOpacity(0.85),
                    gradientColors[1].withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // 2. Content
          SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : (error != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              error!,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: AppTypography.fontFamily,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Settings3DButton(
                              onTap: fetchHistory,
                              icon: Icons.refresh,
                              label: loc.retry,
                              width: 160,
                              isDestructive: true,
                            ),
                          ],
                        ),
                      ),
                    )
                    : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  color: navIconColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  loc.historicalEvents.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    fontFamily: AppTypography.fontFamily,
                                    letterSpacing: 1.2,
                                    color: (isDark ? Colors.white : Colors.black87).withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: navIconColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: navIconColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                loc.eventsFound(events.length).toUpperCase(),
                                style: TextStyle(
                                  color: navIconColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontFamily: AppTypography.fontFamily,
                                ),
                              ),
                            ),
                          ),
                        ),

                        events.isEmpty
                            ? SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  loc.noEventsFound,
                                  style: TextStyle(
                                    color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                                    fontFamily: AppTypography.fontFamily,
                                  ),
                                ),
                              ),
                            )
                            : SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final event = events[index];
                                    return _buildEventCard(
                                      context,
                                      event: event,
                                      themeMode: themeMode,
                                      glassColor: glassColor,
                                      borderColor: borderColor,
                                      navIconColor: navIconColor,
                                    );
                                  }, childCount: events.length),
                                ),
                              ),
                      ],
                    )),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, themeMode, glassColor, borderColor, navIconColor),
    );
  }

  Widget _buildEventCard(
    BuildContext context, {
    required Map<String, dynamic> event,
    required AppThemeMode themeMode,
    required Color glassColor,
    required Color borderColor,
    required Color navIconColor,
  }) {
    final year = event['year']?.toString() ?? '????';
    final description = event['description']?.toString() ?? loc.noDescriptionAvailable;
    final isDark = themeMode == AppThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: navIconColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: navIconColor.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: navIconColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                year,
                                style: TextStyle(
                                  color: navIconColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: AppTypography.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Settings3DButton(
                               icon: Icons.share_rounded,
                               onTap: () => Share.share(loc.onThisDayIn(year, description)),
                              width: 56,
                            ),
                            const SizedBox(width: 8),
                            Settings3DButton(
                              icon: Icons.copy_rounded,
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: loc.onThisDayIn(year, description)));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(loc.copiedToClipboardFlat),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: navIconColor,
                                  ),
                                );
                              },
                              width: 56,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      description,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        height: 1.5,
                        fontFamily: '.SF Pro Text',
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    AppThemeMode mode,
    Color glassColor,
    Color borderColor,
    Color navIconColor,
  ) {
    final isDark = mode == AppThemeMode.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              // Prev Button
              Expanded(
                child: GlassPillButton(
                  onPressed: _goToPreviousDay,
                  label: loc.prev,
                  icon: Icons.navigate_before_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              // Refresh Button
              GlassIconButton(
                onPressed: fetchHistory,
                icon: Icons.refresh_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              // Next Button
              Expanded(
                child: GlassPillButton(
                  onPressed: _goToNextDay,
                  label: loc.nextCaps,
                  icon: Icons.navigate_next_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              // Close Button
              GlassIconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icons.close_rounded,
                isDark: isDark,
                color: Colors.redAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

