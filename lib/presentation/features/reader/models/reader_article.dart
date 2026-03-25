class ReaderArticle {

  const ReaderArticle({
    required this.title,
    required this.content,
    required this.textContent,
    this.excerpt,
    this.byline,
    this.siteName,
    this.length = 0,
  });

  factory ReaderArticle.fromJson(Map<String, dynamic> json) {
    return ReaderArticle(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      textContent: json['textContent'] as String? ?? '',
      excerpt: json['excerpt'] as String?,
      byline: json['byline'] as String?,
      siteName: json['siteName'] as String?,
      length: json['length'] as int? ?? 0,
    );
  }
  final String title;
  final String content;
  final String textContent;
  final String? excerpt;
  final String? byline;
  final String? siteName;
  final int length;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'textContent': textContent,
      'excerpt': excerpt,
      'byline': byline,
      'siteName': siteName,
      'length': length,
    };
  }
}
