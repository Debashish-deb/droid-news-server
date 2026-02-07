import 'package:flutter/material.dart';
import '../../../../domain/entities/news_thread.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NewsThreadCard extends StatefulWidget {

  const NewsThreadCard({
    required this.thread,
    required this.onTap,
    super.key,
  });
  final NewsThread thread;
  final VoidCallback onTap;

  @override
  State<NewsThreadCard> createState() => _NewsThreadCardState();
}

class _NewsThreadCardState extends State<NewsThreadCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.thread.mainArticle;
    final hasRelated = widget.thread.relatedArticles.isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    
    final List<BoxShadow> shadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              offset: const Offset(6, 6),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.05),
              offset: const Offset(-2, -2),
              blurRadius: 6,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.grey.shade400,
              offset: const Offset(8, 8),
              blurRadius: 16,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ];

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(24),
            boxShadow: _isPressed 
              ? [] 
              : shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark 
                        ? [Colors.white.withOpacity(0.05), Colors.black.withOpacity(0.2)]
                        : [Colors.white.withOpacity(0.8), Colors.grey.withOpacity(0.1)],
                    ),
                  ),
                ),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.imageUrl != null)
                      Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: article.imageUrl!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.grey[800]),
                            errorWidget: (_, __, ___) => const SizedBox(height: 220),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                  stops: const [0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                       
                           if (widget.thread.relatedArticles.isNotEmpty)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                  backgroundBlendMode: BlendMode.overlay,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.layers_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${widget.thread.relatedArticles.length + 1} Coverage',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
          
                
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                   
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent,
                                ),
                                child: const Icon(Icons.newspaper, size: 12, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                article.source.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _timeAgo(article.publishedAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                        
                          Text(
                            article.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              fontSize: 20,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          if (hasRelated)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.white60,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MORE PERSPECTIVES',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...widget.thread.relatedArticles.take(2).map((rel) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Icon(Icons.subdirectory_arrow_right_rounded, 
                                          size: 14, 
                                          color: isDark ? Colors.grey : Colors.grey[800]
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            rel.source,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {

    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
