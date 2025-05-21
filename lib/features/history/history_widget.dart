// lib/features/history/history_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as https;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '/core/theme_provider.dart';
import '/core/theme.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class HistoryWidget extends StatefulWidget {
  const HistoryWidget({Key? key}) : super(key: key);

  @override
  State<HistoryWidget> createState() => _HistoryWidgetState();
}

class _HistoryWidgetState extends State<HistoryWidget> {
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
      'https://byabbe.se/on-this-day/${currentDate.month}/${currentDate.day}/events.json'
    );

    try {
      final response = await https.get(url);
      if (response.statusCode == 200) {
        setState(() {
          data = json.decode(response.body);
          isLoading = false;
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

  Widget _modernIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final prov = context.watch<ThemeProvider>();
    return Material(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: prov.glassColor,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 24, color: Theme.of(context).iconTheme.color),
        onPressed: onPressed,
      ),
    );
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
    final prov = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final todayLabel = DateFormat('MMMM d').format(currentDate);

    // pick gradient based on theme mode
    final colors = AppGradients.getGradientColors(prov.appThemeMode);
    final bgGradient = [
      colors[0].withOpacity(0.9),
      colors[1].withOpacity(0.9),
    ];

    final events = (data?['events'] as List<dynamic>? ?? []).toList();
    final textStyle = prov.floatingTextStyle(color: Colors.white);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('History • $todayLabel', style: textStyle.copyWith(fontSize: 22)),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: prov.glassColor),
          ),
        ),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : (error != null
          ? Center(child: Text(error!, style: prov.floatingTextStyle(color: theme.colorScheme.error)))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: bgGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, color: theme.iconTheme.color, size: 26),
                            const SizedBox(width: 8),
                            Text('Major Historical Events', style: textStyle.copyWith(fontSize: 24)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 4,
                          width: 160,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors[1], colors[0]],
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Events list
                  Expanded(
                    child: events.isEmpty
                      ? Center(child: Text('No events found.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: events.length,
                          itemBuilder: (ctx, i) {
                            final ev = events[i];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: prov.appThemeMode == AppThemeMode.light
                                    ? [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)]
                                    : [Colors.black54, Colors.black38],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  width: 2,
                                  color: prov.borderColor.withOpacity(0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Year & actions
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, color: theme.iconTheme.color, size: 20),
                                            const SizedBox(width: 6),
                                            Text(ev['year'].toString(), style: textStyle.copyWith(fontSize: 20)),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            _modernIconButton(
                                              icon: Icons.share,
                                              tooltip: 'Share',
                                              onPressed: () => Share.share(
                                                'On this day in ${ev['year']}: ${ev['description']}'
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            _modernIconButton(
                                              icon: Icons.copy,
                                              tooltip: 'Copy',
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(
                                                  text: 'On this day in ${ev['year']}: ${ev['description']}',
                                                ));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Copied to clipboard'))
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Separator
                                    Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: bgGradient),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Description
                                    Text(
                                      ev['description'] ?? '',
                                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodyMedium?.color),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            )
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgGradient),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 12)],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton.filled(
              onPressed: _goToPreviousDay,
              icon: const Icon(Icons.navigate_before),
              style: IconButton.styleFrom(
                backgroundColor: prov.glassColor,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: Colors.black45,
                padding: const EdgeInsets.all(12),
              ),
            ),
            IconButton.filledTonal(
              onPressed: fetchHistory,
              icon: const Icon(Icons.refresh),
              style: IconButton.styleFrom(
                backgroundColor: prov.glassColor,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: Colors.black45,
                padding: const EdgeInsets.all(12),
              ),
            ),
            IconButton.filled(
              onPressed: _goToNextDay,
              icon: const Icon(Icons.navigate_next),
              style: IconButton.styleFrom(
                backgroundColor: prov.glassColor,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: Colors.black45,
                padding: const EdgeInsets.all(12),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.exit_to_app),
              style: IconButton.styleFrom(
                backgroundColor: prov.glassColor,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: Colors.black45,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
