import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as ffw;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/di/providers.dart' show appNetworkServiceProvider;
import '../../core/config/performance_config.dart';
import '../providers/app_settings_providers.dart';

/// Optimized cached image widget with consistent configuration
class OptimizedCachedImage extends ConsumerWidget {
  const OptimizedCachedImage({
    required this.imageUrl,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.semanticLabel,
  });

  static const Set<String> _volatileQueryParams = <String>{
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'fbclid',
    'gclid',
    'width',
    'height',
    'w',
    'h',
    'quality',
    'q',
  };

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final String? semanticLabel;

  /// Memory cache limits for optimization
  static const int memCacheHeight = 400;
  static const int memCacheWidth = 800;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool dataSaver = ref.watch(dataSaverProvider);
    final perf = PerformanceConfig.of(context);
    final cacheKey = _normalizeCacheKey(imageUrl);
    final bool allowImages = ref.watch(
      appNetworkServiceProvider.select(
        (network) => network.shouldLoadImages(dataSaver: dataSaver),
      ),
    );
    final int adaptiveWidth = ref.watch(
      appNetworkServiceProvider.select(
        (network) => network.getImageCacheWidth(dataSaver: dataSaver),
      ),
    );
    final int adaptiveHeight = adaptiveWidth;

    if (!allowImages) {
      return _buildError(context);
    }

    int? safeDimension(double? value, int fallback) {
      if (value == null || value.isNaN || value.isInfinite) return fallback;
      return value.clamp(1, double.maxFinite).toInt();
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: perf.reduceMotion
          ? const Duration()
          : const Duration(milliseconds: 150),
      fadeOutDuration: perf.reduceMotion
          ? const Duration()
          : const Duration(milliseconds: 80),
      memCacheHeight: safeDimension(height, adaptiveHeight),
      memCacheWidth: safeDimension(width, adaptiveWidth),
      // Adaptive disk cache: match network-aware image width, capped sensibly.
      // On poor network / data-saver, store compact thumbnails only.
      maxWidthDiskCache: dataSaver ? 640 : (adaptiveWidth * 2).clamp(320, 900),
      maxHeightDiskCache: dataSaver
          ? 360
          : (adaptiveHeight * 2).clamp(240, 450),
      placeholder: (context, url) => _shouldAnimatePlaceholder(perf)
          ? _buildShimmer(context)
          : _buildPlaceholder(context),
      errorWidget: (context, url, error) => errorWidget ?? _buildError(context),
    );

    final wrapped = Semantics(
      label: semanticLabel ?? 'Network image',
      image: true,
      child: imageWidget,
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: wrapped);
    }

    return wrapped;
  }

  static bool _shouldAnimatePlaceholder(PerformanceConfig perf) {
    return !perf.reduceEffects &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        perf.performanceTier == DevicePerformanceTier.flagship;
  }

  static String _normalizeCacheKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasQuery) return url;

    final filteredEntries =
        uri.queryParameters.entries
            .where(
              (entry) =>
                  !_volatileQueryParams.contains(entry.key.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    if (filteredEntries.isEmpty) {
      return uri.replace(queryParameters: const <String, String>{}).toString();
    }

    return uri
        .replace(
          queryParameters: <String, String>{
            for (final entry in filteredEntries) entry.key: entry.value,
          },
        )
        .toString();
  }

  Widget _buildShimmer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Shimmer.fromColors(
      baseColor: colorScheme.surface,
      highlightColor: colorScheme.surfaceVariant,
      child: Container(
        width: width,
        height: height,
        color: colorScheme.surface,
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      color: colorScheme.errorContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: colorScheme.onErrorContainer,
        size: 48,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceVariant,
    );
  }
}

/// Circular cached image for avatars
class CircularCachedImage extends ConsumerWidget {
  const CircularCachedImage({
    required this.imageUrl,
    super.key,
    this.radius = 40,
  });
  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool dataSaver = ref.watch(dataSaverProvider);
    final perf = PerformanceConfig.of(context);
    final cacheKey = OptimizedCachedImage._normalizeCacheKey(imageUrl);
    final bool allowImages = ref.watch(
      appNetworkServiceProvider.select(
        (network) => network.shouldLoadImages(dataSaver: dataSaver),
      ),
    );
    final size = radius * 2;
    final colorScheme = Theme.of(context).colorScheme;

    if (!allowImages) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surfaceVariant,
        child: Icon(
          Icons.person,
          size: radius,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.surfaceVariant,
      child: ClipOval(
        child: Semantics(
          label: 'User avatar',
          image: true,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            cacheKey: cacheKey,
            width: size,
            height: size,
            fit: BoxFit.cover,
            fadeInDuration: perf.reduceMotion
                ? const Duration()
                : const Duration(milliseconds: 120),
            memCacheHeight: size.toInt(),
            memCacheWidth: size.toInt(),
            placeholder: (context, url) =>
                OptimizedCachedImage._shouldAnimatePlaceholder(perf)
                ? Shimmer.fromColors(
                    baseColor: colorScheme.surface,
                    highlightColor: colorScheme.surfaceVariant,
                    child: Container(
                      width: size,
                      height: size,
                      color: colorScheme.surface,
                    ),
                  )
                : Container(
                    width: size,
                    height: size,
                    color: colorScheme.surfaceVariant,
                  ),
            errorWidget: (context, url, error) => Icon(
              Icons.person,
              size: radius,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Clear all cached images.
Future<void> clearImageCacheStore() async {
  await CachedNetworkImage.evictFromCache('');
}

/// Clear a specific image from cache.
Future<void> clearCachedImage(String url) async {
  if (url.isEmpty) return;
  await CachedNetworkImage.evictFromCache(url);
}

/// Precache image for faster loading.
Future<void> precacheCachedNetworkImage(
  String url,
  BuildContext context,
) async {
  if (url.isEmpty) return;

  final provider = CachedNetworkImageProvider(url);
  await ffw.precacheImage(provider, context);
}
