import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// Optimized cached image widget with consistent configuration
class OptimizedCachedImage extends StatelessWidget {

  const OptimizedCachedImage({
    required this.imageUrl, super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
  });
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;

  /// Memory cache limits for optimization
  static const int memCacheHeight = 400;
  static const int memCacheWidth = 800;

  @override
  Widget build(BuildContext context) {
    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: imageUrl, // stable caching
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 150),
      memCacheHeight: memCacheHeight,
      memCacheWidth: memCacheWidth,
      maxHeightDiskCache: 800,
      maxWidthDiskCache: 1600,
      placeholder: (context, url) => _buildShimmer(context),
      errorWidget: (context, url, error) => errorWidget ?? _buildError(context),
    );

    final wrapped = Semantics(
      label: 'Network image',
      image: true,
      child: imageWidget,
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: wrapped);
    }

    return wrapped;
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
}

/// Circular cached image for avatars
class CircularCachedImage extends StatelessWidget {

  const CircularCachedImage({
    required this.imageUrl, super.key,
    this.radius = 40,
  });
  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final colorScheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.surfaceVariant,
      child: ClipOval(
        child: Semantics(
          label: 'User avatar',
          image: true,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            cacheKey: imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            memCacheHeight: size.toInt(),
            memCacheWidth: size.toInt(),
            placeholder:
                (context, url) => Shimmer.fromColors(
                  baseColor: colorScheme.surface,
                  highlightColor: colorScheme.surfaceVariant,
                  child: Container(
                    width: size,
                    height: size,
                    color: colorScheme.surface,
                  ),
                ),
            errorWidget:
                (context, url, error) => Icon(
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

/// Image cache manager helper
class ImageCacheHelper {
  /// Clear all cached images
  static Future<void> clearCache() async {
    await CachedNetworkImage.evictFromCache('');
  }

  /// Clear specific image from cache
  static Future<void> clearImageCache(String url) async {
    if (url.isEmpty) return;
    await CachedNetworkImage.evictFromCache(url);
  }

  /// Precache image for faster loading
  static Future<void> precacheImage(String url, BuildContext context) async {
    if (url.isEmpty) return;

    final provider = CachedNetworkImageProvider(url);
    await precacheImageFromProvider(provider, context);
  }

  /// Internal helper to avoid name collision with Flutter precacheImage()
  static Future<void> precacheImageFromProvider(
    ImageProvider provider,
    BuildContext context,
  ) async {
    await precacheImage(provider as String, context);
  }
}
