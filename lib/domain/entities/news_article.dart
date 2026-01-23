/// Domain entity representing a news article.
///
/// This is a pure business object with no dependencies on data sources,
/// JSON serialization, or any infrastructure concerns.
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.publishedAt,
    required this.source,
    this.imageUrl,
    this.category,
    this.isBookmarked = false,
    this.isRead = false,
    this.tags = const [],
  });
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final DateTime publishedAt;
  final String source;
  final String? category;
  final bool isBookmarked;
  final bool isRead;
  final List<String> tags;

  /// Creates a copy of this article with the given fields replaced.
  NewsArticle copyWith({
    String? id,
    String? title,
    String? content,
    String? imageUrl,
    DateTime? publishedAt,
    String? source,
    String? category,
    bool? isBookmarked,
    bool? isRead,
    List<String>? tags,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      source: source ?? this.source,
      category: category ?? this.category,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isRead: isRead ?? this.isRead,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsArticle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NewsArticle(id: $id, title: $title)';
}
