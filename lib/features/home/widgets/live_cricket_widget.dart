import 'dart:async';
import 'dart:math';            // for min()
import 'dart:ui';             // for ImageFilter
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/data/models/news_article.dart';
import '/data/services/rss_service.dart';

/// A polished live‐score panel with visible controls and pull‐to‐refresh.
class LiveCricketWidget extends StatefulWidget {
  final double height;
  const LiveCricketWidget({Key? key, this.height = 200}) : super(key: key);

  @override
  State<LiveCricketWidget> createState() => _LiveCricketWidgetState();
}

class _LiveCricketWidgetState extends State<LiveCricketWidget> {
  static const _feedUrl = 'https://www.espncricinfo.com/rss/livescores.xml';
  final Uri _moreUri =
      Uri.parse('https://www.espncricinfo.com/live-cricket-score');

  bool _loading = true;
  bool _error = false;
  bool _expanded = false;
  bool _autoRefresh = false;
  String _filter = 'All';
  DateTime? _lastUpdated;

  List<NewsArticle> _matches = [];
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _fetchLive();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLive() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final items = await RssService.fetchRssFeeds([_feedUrl]);
      setState(() {
        _matches = items;
        _lastUpdated = DateTime.now();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });
    _autoTimer?.cancel();
    if (_autoRefresh) {
      _autoTimer =
          Timer.periodic(const Duration(minutes: 1), (_) => _fetchLive());
    }
  }

  Future<void> _openMore() =>
      launchUrl(_moreUri, mode: LaunchMode.externalApplication);

  List<NewsArticle> get _filtered {
    if (_filter == 'All') return _matches;
    return _matches.where((m) => m.title.contains(_filter)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Card(
        color: Colors.black.withOpacity(0.3),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 6),
                  _buildControls(),
                  const SizedBox(height: 6),
                  Expanded(child: _buildList()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Image.asset('assets/images/logo.png', width: 28, height: 28),
        const SizedBox(width: 6),
        Text('Live Cricket',
            style: theme.textTheme.titleLarge!
                .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (_lastUpdated != null)
          Text(
            '${_lastUpdated!.hour.toString().padLeft(2, '0')}:'
            '${_lastUpdated!.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh Now',
          onPressed: _fetchLive,
        ),
        IconButton(
          icon: Icon(
            _autoRefresh ? Icons.av_timer : Icons.timer_off,
            color: _autoRefresh ? Colors.lightGreenAccent : Colors.white,
          ),
          tooltip: 'Toggle Auto-Refresh',
          onPressed: _toggleAutoRefresh,
        ),
        IconButton(
          icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white),
          tooltip: _expanded ? 'Show Less' : 'Show More',
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
      ],
    );
  }

  Widget _buildControls() {
    final filters = ['All', 'ODI', 'T20', 'Test'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = f == _filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f, style: const TextStyle(color: Colors.white)),
              selected: selected,
              selectedColor: Colors.blueAccent.withOpacity(0.7),
              backgroundColor: Colors.grey.withOpacity(0.3),
              onSelected: (_) => setState(() => _filter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          onPressed: _fetchLive,
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(child: Text('No live matches'));
    }
    final count = _expanded ? list.length : min(2, list.length);

    return RefreshIndicator(
      onRefresh: _fetchLive,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: count + 1, // +1 for “View All”
        itemBuilder: (ctx, i) {
          if (i == count) {
            return Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openMore,
                child: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
            );
          }
          final match = list[i];
          return _buildMatchCard(match);
        },
      ),
    );
  }

  Widget _buildMatchCard(NewsArticle match) {
    final parts = match.title.split(' at ');
    final teams = parts[0];
    final venue = parts.length > 1 ? parts[1] : '';
    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.sports_cricket, color: Colors.amber),
        title: Text(teams, style: const TextStyle(color: Colors.white)),
        subtitle: Text(venue, style: const TextStyle(color: Colors.white70)),
        trailing: const Icon(Icons.open_in_new, color: Colors.white),
        onTap: () => launchUrl(Uri.parse(match.url),
            mode: LaunchMode.externalApplication),
      ),
    );
  }
}
