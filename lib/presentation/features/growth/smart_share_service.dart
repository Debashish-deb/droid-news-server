import 'package:share_plus/share_plus.dart';
import '../../../domain/entities/news_article.dart';

class SmartShareService {
static Future<void> shareArticle(NewsArticle article) async {
    final buffer = StringBuffer();
    buffer.writeln('📰 ${article.title}');
    buffer.writeln();
    buffer.writeln(article.description.length > 100 
      ? '${article.description.substring(0, 100)}...' 
      : article.description
    );
    buffer.writeln();
    
    final shortLink = 'https://bdnews.app/read/${article.url.hashCode}';
    buffer.write('Read more: $shortLink');

    await Share.share(
      buffer.toString(),
      subject: article.title,
    );
  }
}
