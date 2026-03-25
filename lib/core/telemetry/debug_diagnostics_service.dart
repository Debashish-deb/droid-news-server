import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import 'app_logger.dart';

/// Collects lightweight performance diagnostics in debug/profile builds
/// so engineers can review logs without attaching DevTools.
class DebugDiagnosticsService {
  DebugDiagnosticsService({this.interval = const Duration(seconds: 60)});

  final Duration interval;

  final List<int> _uiMicros = <int>[];
  final List<int> _rasterMicros = <int>[];
  final List<double> _rssHistoryMb = <double>[];
  final Map<String, _WebViewEntry> _webViews = <String, _WebViewEntry>{};
  Timer? _timer;
  bool _started = false;

  static const int _jankThresholdUs = 16667; // 16.7ms frame budget @ 60fps
  static const int _rssHistoryWindow = 6;

  void start() {
    if (_started || (!_isDevBuild)) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_handleTimings);
    _timer = Timer.periodic(interval, (_) => _logSnapshot());
    AppLogger.info(
      '🔍 Debug diagnostics enabled (interval=${interval.inSeconds}s)',
    );
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    SchedulerBinding.instance.removeTimingsCallback(_handleTimings);
  }

  void _handleTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _uiMicros.add(timing.buildDuration.inMicroseconds);
      _rasterMicros.add(timing.rasterDuration.inMicroseconds);
    }

    // ✅ Fix: Cap historical data to prevent memory leak in long sessions
    if (_uiMicros.length > 5000) {
      _uiMicros.removeRange(0, _uiMicros.length - 5000);
    }
    if (_rasterMicros.length > 5000) {
      _rasterMicros.removeRange(0, _rasterMicros.length - 5000);
    }
  }

  void _logSnapshot() {
    if (_uiMicros.isEmpty || _rasterMicros.isEmpty) {
      logResourceSnapshot(reason: 'periodic');
      return;
    }

    final _FrameStats uiStats = _summarize(_uiMicros);
    final _FrameStats rasterStats = _summarize(_rasterMicros);

    final double rssMb = ProcessInfo.currentRss / (1024 * 1024);
    final imageCache = PaintingBinding.instance.imageCache;
    final double cacheUsageMb = imageCache.currentSizeBytes / (1024 * 1024);
    final double cacheLimitMb = imageCache.maximumSizeBytes / (1024 * 1024);

    AppLogger.metric('frame_ui_p99_ms', uiStats.p99.round());
    AppLogger.metric('frame_raster_p99_ms', rasterStats.p99.round());

    AppLogger.info(
      '📈 PerfDiag | frames=${uiStats.total} | '
      'UI(ms) p50=${uiStats.p50.toStringAsFixed(1)} '
      'p90=${uiStats.p90.toStringAsFixed(1)} p99=${uiStats.p99.toStringAsFixed(1)} '
      'jank=${uiStats.jankCount} | '
      'Raster(ms) p50=${rasterStats.p50.toStringAsFixed(1)} '
      'p90=${rasterStats.p90.toStringAsFixed(1)} p99=${rasterStats.p99.toStringAsFixed(1)} '
      'jank=${rasterStats.jankCount} | '
      'RSS=${rssMb.toStringAsFixed(1)}MB | '
      'ImageCache=${cacheUsageMb.toStringAsFixed(1)}MB/${cacheLimitMb.toStringAsFixed(1)}MB '
      '(live=${imageCache.currentSize}, pending=${imageCache.pendingImageCount}) | '
      'WebViews=${_webViews.length}',
    );
    _recordAndAnalyzeMemory(rssMb);
    _analyzeWebViewLifetimes();

    _uiMicros.clear();
    _rasterMicros.clear();

    logResourceSnapshot(reason: 'periodic');
  }

  void logResourceSnapshot({String reason = 'manual'}) {
    if (!_isDevBuild || kProfileMode) return;

    final double rssMb = ProcessInfo.currentRss / (1024 * 1024);
    final double maxRssMb = ProcessInfo.maxRss / (1024 * 1024);
    final imageCache = PaintingBinding.instance.imageCache;

    AppLogger.info(
      '🧠 Resource snapshot [$reason] | '
      'RSS=${rssMb.toStringAsFixed(1)}MB/${maxRssMb.toStringAsFixed(1)}MB | '
      'ImageCache=${(imageCache.currentSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB '
      '(entries=${imageCache.currentSize}) | '
      'WebViews=${_webViews.values.map((e) => e.label).joinOr('none')}',
    );
    _recordAndAnalyzeMemory(rssMb);
    _analyzeWebViewLifetimes();
  }

  void _recordAndAnalyzeMemory(double rssMb) {
    _rssHistoryMb.add(rssMb);
    if (_rssHistoryMb.length > _rssHistoryWindow) {
      _rssHistoryMb.removeAt(0);
    }
    if (_rssHistoryMb.length < _rssHistoryWindow) return;

    final growth = _rssHistoryMb.last - _rssHistoryMb.first;
    int risingSamples = 0;
    for (int i = 1; i < _rssHistoryMb.length; i++) {
      if ((_rssHistoryMb[i] - _rssHistoryMb[i - 1]) > 8.0) {
        risingSamples++;
      }
    }

    if (growth > 48.0 && risingSamples >= (_rssHistoryMb.length - 2)) {
      AppLogger.warn(
        '⚠️ Potential memory leak pattern: RSS +${growth.toStringAsFixed(1)}MB '
        'over ${_rssHistoryMb.length} samples (activeWebViews=${_webViews.length})',
      );
    }
  }

  void _analyzeWebViewLifetimes() {
    final now = DateTime.now();
    for (final entry in _webViews.values) {
      if (entry.leakWarned) continue;
      if (now.difference(entry.createdAt) > const Duration(minutes: 10)) {
        entry.leakWarned = true;
        AppLogger.warn(
          '⚠️ Long-lived WebView candidate: ${entry.label} '
          '(age=${now.difference(entry.createdAt).inMinutes}m, '
          'navigations=${entry.navigationCount})',
        );
      }
    }
  }

  void registerWebView(String id, {required String url}) {
    if (!_isDevBuild) return;
    _webViews[id] = _WebViewEntry(
      createdAt: DateTime.now(),
      lastUrl: url,
      createdRssMb: ProcessInfo.currentRss / (1024 * 1024),
    );
    AppLogger.info(
      '🕸️ WebView[$id] registered url=$url (active=${_webViews.length})',
    );
  }

  void markWebViewNavigation(String id, {required String url}) {
    if (!_isDevBuild) return;
    final entry = _webViews[id];
    if (entry == null) return;
    entry.lastUrl = url;
    entry.navigationCount++;
    entry.lastUpdated = DateTime.now();
  }

  void unregisterWebView(String id) {
    if (!_isDevBuild) return;
    final entry = _webViews.remove(id);
    if (entry == null) return;
    final duration = DateTime.now().difference(entry.createdAt).inSeconds;
    final double rssMb = ProcessInfo.currentRss / (1024 * 1024);
    AppLogger.info(
      '🧹 WebView[$id] disposed | lifetime=${duration}s | '
      'navigations=${entry.navigationCount} | '
      'lastUrl=${entry.lastUrl} | '
      'rss_delta=${(rssMb - entry.createdRssMb).toStringAsFixed(1)}MB | '
      'active=${_webViews.length}',
    );
    final delta = rssMb - entry.createdRssMb;
    if (delta > 80) {
      AppLogger.warn(
        '⚠️ High RSS delta after WebView dispose: ${delta.toStringAsFixed(1)}MB '
        '(url=${entry.lastUrl})',
      );
    }
  }

  _FrameStats _summarize(List<int> samples) {
    if (samples.isEmpty) {
      return const _FrameStats(p50: 0, p90: 0, p99: 0, jankCount: 0, total: 0);
    }

    final List<int> sorted = List<int>.from(samples)..sort();
    double percentile(double ratio) {
      final double position = ratio * (sorted.length - 1);
      final int lowerIndex = position.floor().clamp(0, sorted.length - 1);
      final int upperIndex = position.ceil().clamp(0, sorted.length - 1);
      final double blend = position - lowerIndex;
      final double lowerValue = sorted[lowerIndex] / 1000.0;
      final double upperValue = sorted[upperIndex] / 1000.0;
      return lowerValue + (upperValue - lowerValue) * blend;
    }

    final int jankCount = samples.where((t) => t > _jankThresholdUs).length;

    return _FrameStats(
      p50: percentile(0.50),
      p90: percentile(0.90),
      p99: percentile(0.99),
      jankCount: jankCount,
      total: samples.length,
    );
  }
}

class _FrameStats {
  const _FrameStats({
    required this.p50,
    required this.p90,
    required this.p99,
    required this.jankCount,
    required this.total,
  });

  final double p50;
  final double p90;
  final double p99;
  final int jankCount;
  final int total;
}

class _WebViewEntry {
  _WebViewEntry({
    required this.createdAt,
    required this.lastUrl,
    required this.createdRssMb,
  });

  final DateTime createdAt;
  DateTime? lastUpdated;
  String lastUrl;
  int navigationCount = 0;
  final double createdRssMb;
  bool leakWarned = false;

  String get label {
    final uri = Uri.tryParse(lastUrl);
    if (uri == null) return lastUrl;
    return uri.host.isNotEmpty ? uri.host : lastUrl;
  }
}

extension _JoinOrExt on Iterable<String> {
  String joinOr(String fallback, {String separator = ', '}) {
    if (isEmpty) return fallback;
    return join(separator);
  }
}

const bool _isDevBuild = kDebugMode || kProfileMode;
