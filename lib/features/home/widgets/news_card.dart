import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/core/utils/source_logos.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/news_article.dart';
import '../../../data/services/ml/ml_categorizer.dart';
import '../../../widgets/category_badge.dart';
import '../../../data/services/ml/ml_sentiment_analyzer.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({
    required this.article,
    super.key,
    this.onTap,
    this.highlight = true,
  });
  final NewsArticle article;
  final VoidCallback? onTap;
  final bool highlight;

  bool get isLive => article.isLive;
  bool get isBreaking =>
      DateTime.now().difference(article.publishedAt) < const Duration(hours: 6);
  bool get isFresh =>
      DateTime.now().difference(article.publishedAt) <
      const Duration(minutes: 30);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final logoPath =
        SourceLogos.logos[article.sourceOverride ?? article.source];
    
    // Safely format date
    String timestamp = '';
    try {
      timestamp = DateFormat('h:mm a').format(article.publishedAt);
    } catch (_) {
      timestamp = 'Recently';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark 
              ? const Color(0xFF1C1C1E) 
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section - Safe check
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                _buildImage(article.imageUrl!, isDark),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Source + Tags
                    Row(
                      children: [
                        if (logoPath != null)
                          _buildSourceLogo(logoPath)
                        else
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.public,
                              size: 14,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            article.sourceOverride ?? article.source,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: isDark 
                                  ? const Color(0xFF8E8E93)
                                  : const Color(0xFF6E6E73),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLive) 
                          _modernTag("LIVE", const Color(0xFFFF3B30), Icons.circle)
                        else if (isBreaking)
                          _modernTag("NEW", const Color(0xFFFF9500), Icons.bolt)
                        else if (isFresh)
                          _modernTag("Fresh", const Color(0xFF34C759), Icons.access_time),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Title
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Footer: Category + Time + Actions
                    Row(
                      children: [
                        // ML Category Badge (compact)
                        Flexible(
                          child: FutureBuilder<String>(
                            future: MLCategorizer.instance.categorizeArticle(
                              article.title,
                              article.snippet,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox.shrink();
                              final categoryId = snapshot.data!;
                              final categoryInfo = MLCategorizer.instance
                                  .getCategoryInfo(categoryId);
                              
                              if (categoryInfo == null) return const SizedBox.shrink();
                              
                              final colorStr = categoryInfo['color'] as String?;
                              final emoji = categoryInfo['emoji'] as String?;
                              final label = categoryInfo['label'] as String?;
                              
                              if (colorStr == null || emoji == null || label == null) {
                                return const SizedBox.shrink();
                              }
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(int.parse(
                                    colorStr.replaceFirst('#', '0xFF'),
                                  )).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        label.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                          color: Color(int.parse(
                                            colorStr.replaceFirst('#', '0xFF'),
                                          )),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(width: 8),

                        // Sentiment Emoji
                        FutureBuilder<double>(
                          future: MLSentimentAnalyzer.instance.analyzeSentiment(
                            '${article.title} ${article.snippet}',
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox.shrink();
                            final sentiment = snapshot.data!;
                            final emoji = MLSentimentAnalyzer.instance
                                .getSentimentEmoji(sentiment);
                            return Text(
                              emoji,
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),

                        const Spacer(),

                        // Time
                        Text(
                          timestamp,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark 
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF6E6E73),
                          ),
                        ),

                        // Actions
                        const SizedBox(width: 8),
                        _iconButton(
                          Icons.bookmark_border_rounded,
                          isDark,
                          () {},
                        ),
                        const SizedBox(width: 4),
                        _iconButton(
                          Icons.share_outlined,
                          isDark,
                          () async {
                            await Share.share(
                              '${article.title}\n\n${article.url}',
                              subject: article.title,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl, bool isDark) {
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          memCacheHeight: 240,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF2C2C2E),
                        const Color(0xFF1C1C1E),
                      ]
                    : [
                        const Color(0xFFF2F2F7),
                        const Color(0xFFE5E5EA),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 160,
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 32,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFFAEAEB2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceLogo(String path) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.asset(path, fit: BoxFit.contain),
      ),
    );
  }

  Widget _modernTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, bool isDark, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73),
        ),
      ),
    );
  }
}
