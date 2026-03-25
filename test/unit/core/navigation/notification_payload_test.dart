import 'package:bdnewsreader/core/navigation/app_paths.dart';
import 'package:bdnewsreader/core/navigation/notification_payload.dart';
import 'package:bdnewsreader/presentation/features/common/webview_args.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe article payload opens in-app webview', () {
    final target = NotificationPayloadParser.parse(<String, dynamic>{
      'article_url': 'https://example.com/news/1',
      'title': 'Top story',
    });

    expect(target, isNotNull);
    expect(target!.location, AppPaths.webview);

    final args = target.extra as WebViewArgs;
    expect(args.url.toString(), 'https://example.com/news/1');
    expect(args.title, 'Top story');
    expect(args.origin, WebViewOrigin.notification);
  });

  test('unsafe payloads are rejected', () {
    final target = NotificationPayloadParser.parse(<String, dynamic>{
      'url': 'javascript:alert(1)',
      'title': 'Bad payload',
    });

    expect(target, isNull);
  });

  test('payload without article url is ignored', () {
    final target = NotificationPayloadParser.parse(<String, dynamic>{
      'title': 'No route',
    });

    expect(target, isNull);
  });
}
