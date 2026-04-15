// ignore_for_file: avoid_classes_with_only_static_members

import 'package:html/parser.dart' as html_parser;

import 'bangla_tts_normalizer.dart';

// Industrial-grade text cleaning for TTS
//
// Handles HTML stripping, emoji conversion, number normalization,
// and content sanitization to produce clean, speakable text.
class TextCleaner {
  static String clean(String rawText) {
    if (rawText.isEmpty) return '';

    String text = rawText;

    text = _normalizeTtsMarkup(text);
    text = _stripHtml(text);
    text = _normalizeLineBreaks(text);
    text = _convertEmojis(text);
    text = _removeNoisyLines(text);
    text = _deduplicateLines(text);
    text = _removeImageCredits(text);

    if (BanglaTtsNormalizer.hasBangla(text)) {
      text = _normalizeBengaliNumbers(text);
    } else {
      text = _normalizeNumbers(text);
    }
    text = _cleanPunctuation(text);
    text = _removeUrls(text);
    text = _removeAdMarkers(text);
    text = _removeBoilerplateSections(text);
    text = _fixFormatting(text);
    text = _applyPhoneticFixes(text);
    return _normalizeFinalWhitespace(text);
  }

  static String _applyPhoneticFixes(String text) {
    return BanglaTtsNormalizer.normalize(text);
  }

  static String _normalizeTtsMarkup(String text) {
    var out = text;

    out = out.replaceAllMapped(
      RegExp(
        r'<break\s+[^>]*time\s*=\s*"?(\\d+(?:\\.\\d+)?)(ms|s)"?[^>]*/?>',
        caseSensitive: false,
      ),
      (match) {
        final value = double.tryParse(match.group(1) ?? '0') ?? 0;
        final unit = (match.group(2) ?? '').toLowerCase();
        final millis = unit == 's' ? (value * 1000).round() : value.round();
        return _pauseFromMilliseconds(millis);
      },
    );

    out = out.replaceAllMapped(
      RegExp(
        r'<break\s+[^>]*strength\s*=\s*"?(none|x-weak|weak|medium|strong|x-strong)"?[^>]*/?>',
        caseSensitive: false,
      ),
      (match) {
        final strength = (match.group(1) ?? '').toLowerCase();
        switch (strength) {
          case 'strong':
          case 'x-strong':
            return '. ';
          case 'medium':
            return ', ';
          case 'weak':
          case 'x-weak':
            return ' ';
          case 'none':
            return ' ';
          default:
            return ', ';
        }
      },
    );

    out = out.replaceAll(
      RegExp(r'</?(?:speak|prosody|emphasis)[^>]*>', caseSensitive: false),
      ' ',
    );

    out = out.replaceAllMapped(
      RegExp(r'\[PAUSE\s+(\d+(?:\.\d+)?)s\]', caseSensitive: false),
      (match) {
        final seconds = double.tryParse(match.group(1) ?? '0') ?? 0;
        return _pauseFromMilliseconds((seconds * 1000).round());
      },
    );

    out = out.replaceAll(
      RegExp(r'\[(?:BREATH|BREAK)\]', caseSensitive: false),
      ', ',
    );

    out = out.replaceAll(
      RegExp(
        r'\[(?:EMPHASIS\s+\w+|PITCH\s+[^\]]+|RATE\s+[^\]]+|WHISPER|NEUTRAL|LEAD[^\]]*|BODY[^\]]*|QUOTE[^\]]*|OUTRO[^\]]*|NEWS\s+TONE:[^\]]+)\]',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove markdown emphasis markers while preserving the emphasized word.
    out = out.replaceAllMapped(
      RegExp(r'\*([^\*]+)\*'),
      (match) => match.group(1) ?? '',
    );

    return out;
  }

  static String _pauseFromMilliseconds(int millis) {
    if (millis >= 1000) return '\n\n';
    if (millis >= 700) return '. ';
    if (millis >= 250) return ', ';
    return ' ';
  }

  static String _normalizeFinalWhitespace(String text) {
    var out = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    const paragraphSentinel = '\u0001';
    out = out.replaceAll('\n\n', paragraphSentinel);
    out = out.replaceAll('\n', ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    out = out.replaceAll(paragraphSentinel, '\n\n');
    return out.trim();
  }

  static String _stripHtml(String text) {
    try {
      final document = html_parser.parse(text);

      document
          .querySelectorAll(
            'script,style,noscript,iframe,nav,aside,footer,form,button',
          )
          .forEach((element) {
            element.remove();
          });

      const noiseTokens = <String>[
        'related',
        'recommend',
        'recommended',
        'trending',
        'popular',
        'newsletter',
        'subscribe',
        'comment',
        'share',
        'social',
        'sponsored',
        'advert',
        'read-more',
        'also-read',
        'more-news',
        'more-from',
        'you-may-like',
        'আরও-পড়ুন',
        'আরও-সংবাদ',
        'সম্পর্কিত',
        'সংশ্লিষ্ট',
        'জনপ্রিয়',
        'ট্রেন্ডিং',
      ];
      final allElements = List.from(document.querySelectorAll('*'));
      for (final element in allElements) {
        final marker =
            '${element.className.toString().toLowerCase()} '
            '${element.id.toLowerCase()}';
        if (noiseTokens.any(marker.contains)) {
          element.remove();
        }
      }

      String cleaned = document.body?.text ?? text;

      cleaned = _decodeHtmlEntities(cleaned);

      return cleaned;
    } catch (e) {
      return text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    }
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '...')
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"');
  }

  static String _convertEmojis(String text) {
    final emojiMap = {
      '👍': ' thumbs up ',
      '👎': ' thumbs down ',
      '❤️': ' heart ',
      '😀': ' smile ',
      '😂': ' laughing ',
      '😊': ' happy ',
      '😢': ' sad ',
      '😡': ' angry ',
      '🔥': ' fire ',
      '💯': ' hundred ',
      '✅': ' checkmark ',
      '❌': ' cross ',
      '⚠️': ' warning ',
      '📌': ' pin ',
      '🎉': ' celebration ',
      '🚀': ' rocket ',
      '💡': ' idea ',
      '📱': ' phone ',
      '💻': ' computer ',
      '📧': ' email ',
      '🌍': ' world ',
      '🏆': ' trophy ',
      '⭐': ' star ',
      '🎯': ' target ',
    };

    String result = text;
    emojiMap.forEach((emoji, replacement) {
      result = result.replaceAll(emoji, replacement);
    });

    result = result.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
        unicode: true,
      ),
      '',
    );

    return result;
  }

  static String _normalizeBengaliNumbers(String text) {
    return BanglaTtsNormalizer.normalize(text);
  }

  static String _normalizeNumbers(String text) {
    text = text.replaceAllMapped(RegExp(r'(?<!\$)\b(\d{1,3})(,\d{3})+\b'), (
      match,
    ) {
      final numberStr = match.group(0)!.replaceAll(',', '');
      final number = int.tryParse(numberStr);
      if (number != null && number < 10000) {
        return _numberToWords(number);
      }
      return numberStr;
    });

    text = text.replaceAllMapped(RegExp(r'\b(\d+)%'), (match) {
      final number = int.tryParse(match.group(1)!);
      if (number != null && number <= 100) {
        return '${_numberToWords(number)} percent';
      }
      return match.group(0)!;
    });

    return text;
  }

  static String _numberToWords(int number) {
    if (number == 0) return 'zero';
    if (number < 0) return 'negative ${_numberToWords(-number)}';
    if (number >= 10000) return number.toString();

    final ones = [
      '',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
    ];
    final teens = [
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    final tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];

    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      return tens[number ~/ 10] +
          (number % 10 > 0 ? ' ${ones[number % 10]}' : '');
    }
    if (number < 1000) {
      return '${ones[number ~/ 100]} hundred${number % 100 > 0 ? ' ${_numberToWords(number % 100)}' : ''}';
    }

    return '${ones[number ~/ 1000]} thousand${number % 1000 > 0 ? ' ${_numberToWords(number % 1000)}' : ''}';
  }

  static String _cleanPunctuation(String text) {
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAllMapped(
      RegExp(r'[ \t]+([!?;:])'),
      (match) => match.group(1)!,
    );
    text = text.replaceAllMapped(
      RegExp(r'[ \t]+([.,])(?!\d)'),
      (match) => match.group(1)!,
    );
    text = text.replaceAllMapped(
      RegExp(r'([!?;:])[ \t]*'),
      (match) => '${match.group(1)} ',
    );
    text = text.replaceAllMapped(
      RegExp(r'([.,])(?!\d)[ \t]*'),
      (match) => '${match.group(1)} ',
    );
    text = text.replaceAll(RegExp(r' *\n *'), '\n');

    text = text.replaceAll(RegExp(r'\.{4,}'), '...');
    text = text.replaceAll(RegExp(r'!{2,}'), '!');
    text = text.replaceAll(RegExp(r'\?{2,}'), '?');

    return text;
  }

  static String _removeUrls(String text) {
    text = text.replaceAll(RegExp(r'https?://\S+|www\.\S+'), '');

    text = text.replaceAll(RegExp(r'\S+@\S+\.\S+'), '');

    return text;
  }

  static String _removeAdMarkers(String text) {
    final adPatterns = [
      RegExp(r'\[Ad\]', caseSensitive: false),
      RegExp(r'\[Sponsored\]', caseSensitive: false),
      RegExp(r'\[Advertisement\]', caseSensitive: false),
      RegExp(r'Click here to.*', caseSensitive: false),
      RegExp(r'Subscribe to.*newsletter', caseSensitive: false),
      RegExp(r'Follow us on.*', caseSensitive: false),
    ];

    String result = text;
    for (final pattern in adPatterns) {
      result = result.replaceAll(pattern, '');
    }

    return result;
  }

  static String _removeImageCredits(String text) {
    // Matches "Image credit:", "Photo:", "ছবি:" and removes the rest of the sentence.
    return text.replaceAll(
      RegExp(
        r'(?:Image\s*credit|Photo|ছবি)\s*:\s*[^\n.]+[.\n]?',
        caseSensitive: false,
      ),
      ' ',
    );
  }

  static String _removeBoilerplateSections(String text) {
    const markers = <String>[
      'read more',
      'also read',
      'related news',
      'related stories',
      'related articles',
      'you may also like',
      'recommended for you',
      'trending now',
      'more from',
      'more news',
      'latest news',
      'popular news',
      'follow us',
      'subscribe',
      'comments',
      'advertisement',
      'sponsored content',
      'আরও পড়ুন',
      'আরও দেখুন',
      'সম্পর্কিত খবর',
      'সংশ্লিষ্ট খবর',
      'আরও সংবাদ',
      'জনপ্রিয় সংবাদ',
      'ট্রেন্ডিং',
    ];

    final lower = text.toLowerCase();
    int cutIndex = lower.length;
    for (final marker in markers) {
      final idx = lower.indexOf(marker);
      // Only truncate on markers that appear after the opening body.
      if (idx > 0 && idx > (lower.length * 0.35).floor() && idx < cutIndex) {
        cutIndex = idx;
      }
    }

    if (cutIndex < lower.length) {
      return text.substring(0, cutIndex).trim();
    }
    return text;
  }

  static String _normalizeLineBreaks(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static String _removeNoisyLines(String text) {
    final lines = text.split('\n');
    final kept = <String>[];
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (kept.isNotEmpty && kept.last.isNotEmpty) {
          kept.add('');
        }
        continue;
      }
      if (_isNoisyLine(line)) continue;
      kept.add(line);
    }
    return kept.join('\n');
  }

  static String _deduplicateLines(String text) {
    final seen = <String, int>{};
    final kept = <String>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (kept.isNotEmpty && kept.last.isNotEmpty) {
          kept.add('');
        }
        continue;
      }
      final key = line.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9\u0980-\u09ff]+'),
        '',
      );
      if (key.length < 5) continue;
      final count = (seen[key] ?? 0) + 1;
      seen[key] = count;
      if (count > 1 && line.length < 180) continue;
      kept.add(line);
    }
    return kept.join('\n');
  }

  static bool _isNoisyLine(String line) {
    final lower = line.toLowerCase();
    const markers = <String>[
      'read more',
      'also read',
      'related',
      'recommended',
      'trending',
      'most read',
      'most popular',
      'follow us',
      'subscribe',
      'subscribe to newsletter',
      'share this',
      'advertisement',
      'sponsored by',
      'sponsored post',
      'cookie',
      'privacy policy',
      'terms of use',
      'আরও পড়ুন',
      'আরও দেখুন',
      'সম্পর্কিত',
      'সংশ্লিষ্ট',
      'জনপ্রিয়',
      'ট্রেন্ডিং',
    ];

    if (RegExp(r'https?://\S+|www\.\S+', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    if (RegExp(
      r'^(by|source|published|updated|category|tag|author)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }

    if (markers.any(lower.contains) && line.length < 220 && line.length >= 24) {
      return true;
    }

    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words <= 3 && line.length < 24 && !line.contains(RegExp(r'[A-Za-z]'))) {
      return true;
    }
    if (RegExp(r'^[A-Z0-9\s|:/_-]{2,}$').hasMatch(line) && line.length < 80) {
      return true;
    }
    return false;
  }

  static String _fixFormatting(String text) {
    text = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r' *\n *'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text;
  }

  static String? extractTitle(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length > 10 && trimmed.length < 200) {
        if (!trimmed.endsWith('.')) {
          return trimmed;
        }
      }
    }
    return null;
  }
}
