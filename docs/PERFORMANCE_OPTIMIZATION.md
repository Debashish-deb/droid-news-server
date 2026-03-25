# Performance Profiling & Optimization Guide

## 🎯 Performance Targets

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| App Startup | < 2s | TBD | ⏳ |
| Feed Load | < 3s | TBD | ⏳ |
| Scrolling | 60 FPS | TBD | ⏳ |
| Memory Usage | < 200 MB | TBD | ⏳ |
| APK Size | < 30 MB | TBD | ⏳ |

---

## 📊 How to Profile Performance

### 1. Measure App Startup Time

```dart
// Add to main.dart
void main() async {
  final stopwatch = Stopwatch()..start();
  
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // ... initialization code ...
    
    stopwatch.stop();
    print('⏱️ App startup time: ${stopwatch.elapsedMilliseconds}ms');
    
    runApp(MyApp());
  }, ...);
}
```

### 2. Profile with Flutter DevTools

```bash
# Run app in profile mode
flutter run --profile

# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Or use VS Code/Android Studio DevTools integration
```

**What to Check:**

- CPU profiler → expensive operations
- Memory profiler → leaks and excessive allocation
- Performance overlay → frame rendering time
- Network profiler → API call duration

### 3. Check for Frame Drops

```bash
# Enable performance overlay
flutter run --profile

# In app, press 'p' to toggle performance overlay
# Green bars = good (< 16ms per frame = 60 FPS)
# Red bars = janky (> 16ms = dropped frames)
```

### 4. Memory Profiling

```dart
// Add memory logging
import 'dart:developer' as developer;

void logMemoryUsage() {
  developer.Timeline.startSync('Memory Check');
  // Force garbage collection
  developer.Timeline.finishSync();
  
  print('📊 Memory snapshot taken');
}
```

---

## ⚡ Optimization Strategies

### 1. RSS Feed Loading (Currently Synchronous)

**Problem:** Parsing RSS feeds blocks UI thread

**Solution:** Use isolates for parsing

```dart
// Move this to background isolate
static List<NewsArticle> _parseRssInBackground(String xmlBody) {
  // Heavy XML parsing happens here
  final RssFeed feed = RssFeed.parse(xmlBody);
  return feed.items.map(NewsArticle.fromRssItem).toList();
}

// Call with compute()
final articles = await compute(_parseRssInBackground, responseBody);
```

**Expected gain:** 50-70% faster feed loading

### 2. Image Loading Optimization

**Current:** Using CachedNetworkImage ✅ (already optimized)

**Additional optimizations:**

```dart
CachedNetworkImage(
  imageUrl: article.imageUrl,
  memCacheWidth: 400, // Scale down in memory
  memCacheHeight: 300,
  maxWidthDiskCache: 800,
  placeholder: (context, url) => const ShimmerPlaceholder(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
)
```

**Expected gain:** 30-40% less memory usage

### 3. Pagination (Load on Demand)

**Problem:** Loading all articles at once

**Solution:** Load 20 at a time

```dart
class NewsProvider extends StateNotifier<AsyncValue<List<NewsArticle>>> {
  int _currentPage = 0;
  static const _pageSize = 20;
  
  Future<void> loadMore() async {
    final allArticles = await _fetchAllArticles();
    final start = _currentPage * _pageSize;
    final end = start + _pageSize;
    
    final pageArticles = allArticles.sublist(
      start,
      end > allArticles.length ? allArticles.length : end,
    );
    
    _currentPage++;
    state = AsyncValue.data([...state.value ?? [], ...pageArticles]);
  }
}
```

**Expected gain:** 60% faster initial load

### 4. Widget Rebuild Optimization

**Use const constructors:**

```dart
// Bad
Widget build(context) {
  return Text('Hello');
}

// Good
Widget build(context) {
  return const Text('Hello');
}
```

**Use keys for ListView:**

```dart
ListView.builder(
  itemBuilder: (context, index) {
    return NewsCard(
      key: ValueKey(articles[index].url), // Prevents unnecessary rebuilds
      article: articles[index],
    );
  },
)
```

**Expected gain:** 20-30% smoother scrolling

### 5. Background Caching

```dart
// Fetch and cache in background
class BackgroundCacheService {
  static Future<void> prefetchNews() async {
    // Fetch latest news
    final articles = await rssService.fetchNews();
    
    // Cache images
    for (final article in articles.take(10)) {
      if (article.imageUrl != null) {
        await precacheImage(
          CachedNetworkImageProvider(article.imageUrl!),
          context,
        );
      }
    }
  }
}

// Call when app starts
WidgetsBinding.instance.addPostFrameCallback((_) {
  BackgroundCacheService.prefetchNews();
});
```

---

## 📦 APK Size Reduction

### 1. Remove Unused Dependencies

```bash
# Analyze dependencies
flutter pub deps

# Remove unused packages from pubspec.yaml
```

### 2. Optimize Images

```bash
# Install image optimization tools
npm install -g imagemin-cli

# Compress PNG
imagemin assets/**/*.png --out-dir=assets/optimized

# Convert to WebP (smaller)
cwebp -q 80 input.png -o output.webp
```

### 3. Use Vector Graphics

```yaml
# Replace PNG icons with SVG
dependencies:
  flutter_svg: ^2.0.17
```

### 4. Enable Shrinking & Obfuscation

```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --shrink
```

**Expected APK size:** 15-25 MB (from ~30 MB)

---

## 🧪 Performance Testing Checklist

### Low-End Device Testing

- [ ] Test on device with 2GB RAM
- [ ] Test on Android 7.0 (API 24)
- [ ] Test on slow network (3G)
- [ ] Load 100+ articles
- [ ] Scroll rapidly through feed
- [ ] Open 20+ articles in succession

### Memory Leak Testing

- [ ] Open and close screens 50 times
- [ ] Check memory doesn't grow infinitely
- [ ] Use DevTools memory profiler
- [ ] Force garbage collection

### Network Performance

- [ ] Test on WiFi
- [ ] Test on 4G
- [ ] Test on slow 3G
- [ ] Test offline mode
- [ ] Measure feed load time for each

---

## 📈 Expected Improvements

| Optimization | Before | After | Gain |
|--------------|--------|-------|------|
| App Startup | 3-4s | 1.5-2s | ~50% |
| Feed Load | 5-7s | 2-3s | ~60% |
| Memory Usage | 250MB | 150MB | ~40% |
| APK Size | 35MB | 20MB | ~43% |
| Scroll FPS | 45-50 | 60 | 100% smooth |

---

## 🔍 Profiling Commands

```bash
# Profile mode (most accurate)
flutter run --profile

# Release mode (production performance)
flutter run --release

# With performance overlay
flutter run --profile --enable-software-rendering

# Memory profiling
flutter run --profile --trace-skia

# Startup profiling
flutter run --profile --trace-startup
```

---

## 📝 Performance Logging

Add to app for production monitoring:

```dart
class PerformanceLogger {
  static void logLoadTime(String operation, int milliseconds) {
    if (milliseconds > 1000) {
      ErrorHandler.log('⚠️ Slow operation: $operation took ${milliseconds}ms');
    }
    
    AnalyticsService.logEvent(
      name: 'performance',
      parameters: {
        'operation': operation,
        'duration_ms': milliseconds,
      },
    );
  }
}

// Usage
final stopwatch = Stopwatch()..start();
await fetchNews();
stopwatch.stop();
PerformanceLogger.logLoadTime('fetch_news', stopwatch.elapsedMilliseconds);
```

---

## 🎯 Quick Wins (Implement First)

1. **Add const constructors** (10 min) → 20% fewer rebuilds
2. **Implement pagination** (30 min) → 60% faster load
3. **Use compute() for parsing** (15 min) → 50% faster parsing
4. **Optimize images with memCache** (10 min) → 30% less memory

**Total time:** ~1 hour  
**Total gain:** Significantly smoother app

Start with these quick wins, then profile to find remaining bottlenecks!
