import 'package:equatable/equatable.dart';

class NewsSource extends Equatable {
  const NewsSource({
    required this.id,
    required this.name,
    required this.url,
    required this.language,
    required this.category,
    this.logoUrl,
    this.isEnabled = true,
  });

  /// Unique identifier (could just be the URL)
  final String id;

  /// Display name of the source
  final String name;

  /// The RSS feed URL
  final String url;

  /// Language code ('en' or 'bn')
  final String language;

  /// Category it belongs to
  final String category;

  /// Optional logo asset path
  final String? logoUrl;

  /// Whether the user has enabled this source
  final bool isEnabled;

  NewsSource copyWith({
    String? id,
    String? name,
    String? url,
    String? language,
    String? category,
    String? logoUrl,
    bool? isEnabled,
  }) {
    return NewsSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      language: language ?? this.language,
      category: category ?? this.category,
      logoUrl: logoUrl ?? this.logoUrl,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        url,
        language,
        category,
        logoUrl,
        isEnabled,
      ];
}
