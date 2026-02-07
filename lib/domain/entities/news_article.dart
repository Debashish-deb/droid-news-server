/// Domain entity representing a news article.
class NewsArticle {

  const NewsArticle({
    required this.title,
    required this.url, required this.source, required this.publishedAt, this.description = '',
    this.imageUrl,
    this.language = 'en',
    this.snippet = '',
    this.fullContent = '',
    this.author = '',
    this.isLive = false,
    this.sourceOverride,
    this.sourceLogo,
    this.fromCache = false,
    this.category = 'general',
    this.tags,
  });

  factory NewsArticle.fromMap(Map<String, dynamic> map) => NewsArticle(
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        url: map['url'] ?? '',
        source: map['source'] ?? '',
        imageUrl: map['imageUrl'],
        language: map['language'] ?? 'en',
        snippet: map['snippet'] ?? '',
        fullContent: map['fullContent'] ?? '',
        publishedAt: DateTime.tryParse(map['publishedAt'] ?? '') ?? DateTime.now(),
        isLive: map['isLive'] ?? false,
        sourceOverride: map['sourceOverride'],
        sourceLogo: map['sourceLogo'],
        fromCache: map['fromCache'] ?? false,
        category: map['category'] ?? 'general',
        tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
        author: map['author'] ?? '',
      );
  final String title;
  final String description;
  final String url;
  final String source;
  final String? imageUrl;
  final String language;
  final String snippet;
  final String fullContent;
  final DateTime publishedAt;
  final String author;
  final bool isLive;
  final String? sourceOverride;
  final String? sourceLogo;
  final bool fromCache;
  final String category;
  final List<String>? tags;

  NewsArticle copyWith({
    String? title,
    String? description,
    String? url,
    String? source,
    String? imageUrl,
    String? language,
    String? snippet,
    String? fullContent,
    DateTime? publishedAt,
    bool? isLive,
    String? sourceOverride,
    String? sourceLogo,
    bool? fromCache,
    String? category,
    List<String>? tags,
    String? author,
  }) {
    return NewsArticle(
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      source: source ?? this.source,
      imageUrl: imageUrl ?? this.imageUrl,
      language: language ?? this.language,
      snippet: snippet ?? this.snippet,
      fullContent: fullContent ?? this.fullContent,
      publishedAt: publishedAt ?? this.publishedAt,
      isLive: isLive ?? this.isLive,
      sourceOverride: sourceOverride ?? this.sourceOverride,
      sourceLogo: sourceLogo ?? this.sourceLogo,
      fromCache: fromCache ?? this.fromCache,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      author: author ?? this.author,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'url': url,
        'source': source,
        'imageUrl': imageUrl,
        'language': language,
        'snippet': snippet,
        'fullContent': fullContent,
        'publishedAt': publishedAt.toIso8601String(),
        'isLive': isLive,
        'sourceOverride': sourceOverride,
        'sourceLogo': sourceLogo,
        'fromCache': fromCache,
        'category': category,
        'tags': tags,
        'author': author,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsArticle &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}
