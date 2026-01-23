// lib/features/history/history_widget.dart
// Completely rebuilt to properly respect system configuration and match other screens

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '/core/theme_provider.dart';
import '/core/theme.dart';
import '/widgets/animated_theme_container.dart';
import '../../presentation/providers/theme_providers.dart';
import '/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryWidget extends ConsumerStatefulWidget {
  const HistoryWidget({super.key});

  @override
  ConsumerState<HistoryWidget> createState() => _HistoryWidgetState();
}

class _HistoryWidgetState extends ConsumerState<HistoryWidget> {
  bool isLoading = true;
  Map<String, dynamic>? data;
  String? error;
  DateTime currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    setState(() => isLoading = true);
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
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Migrated to Riverpod
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final todayLabel = DateFormat('MMMM d').format(currentDate);
    final events = (data?['events'] as List<dynamic>? ?? []).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'History • $todayLabel',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface.withOpacity(0.95),
      ),
      body: AnimatedThemeContainer(
        color: theme.scaffoldBackgroundColor,
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : (error != null
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              error!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: fetchHistory,
                              icon: const Icon(Icons.refresh),
                              label: Text(loc.retry),
                            ),
                          ],
                        ),
                      ),
                    )
                    : CustomScrollView(
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  color: colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Major Historical Events',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Events count badge
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${events.length} events',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Events list
                        events.isEmpty
                            ? SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  'No events found for this date.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                            : SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final event = events[index];
                                return _buildEventCard(
                                  context,
                                  event: event,
                                  theme: theme,
                                  colorScheme: colorScheme,
                                  themeMode: ref.watch(
                                    currentThemeModeProvider,
                                  ),
                                );
                              }, childCount: events.length),
                            ),

                        // Bottom spacing
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ],
                    )),
      ),
      bottomNavigationBar: _buildBottomBar(context, theme, colorScheme),
    );
  }

  Widget _buildEventCard(
    BuildContext context, {
    required Map<String, dynamic> event,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required AppThemeMode themeMode,
  }) {
    final year = event['year']?.toString() ?? 'Unknown';
    final description = event['description']?.toString() ?? 'No description';

    // Match NewsCard styling pattern
    final bool isDark = themeMode != AppThemeMode.light;
    final cardColor =
        theme.cardTheme.color ??
        (isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.02));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        // Outer gradient border (matching NewsCard pattern)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppGradients.getGradientColors(themeMode),
          ),
        ),
        padding: const EdgeInsets.all(1.5), // Border thickness
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18.5),
              onTap: () {
                // Optional: could add detail view
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Year badge and actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Year badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppGradients.getGradientColors(themeMode),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                year,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share, size: 20),
                              color: colorScheme.primary,
                              tooltip: 'Share',
                              onPressed: () {
                                Share.share(
                                  'On this day in $year: $description',
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              color: colorScheme.primary,
                              tooltip: 'Copy',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: 'On this day in $year: $description',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied to clipboard'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Divider
                    Divider(
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                      height: 1,
                    ),

                    const SizedBox(height: 12),

                    // Description
                    Text(
                      description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.5,
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
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return AnimatedThemeContainer(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous day
            FilledButton.tonalIcon(
              onPressed: _goToPreviousDay,
              icon: const Icon(Icons.navigate_before),
              label: Text(AppLocalizations.of(context)!.previous),
            ),

            // Refresh
            IconButton.filled(
              onPressed: fetchHistory,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
            ),

            // Next day
            FilledButton.tonalIcon(
              onPressed: _goToNextDay,
              icon: const Icon(Icons.navigate_next),
              label: Text(AppLocalizations.of(context)!.next),
              style: FilledButton.styleFrom(iconAlignment: IconAlignment.end),
            ),

            // Close
            IconButton.outlined(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }
}
