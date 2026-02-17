import 'package:html/parser.dart' as html_parser;

// Industrial-grade text cleaning for TTS
// 
// Handles HTML stripping, emoji conversion, number normalization,
// and content sanitization to produce clean, speakable text.
class TextCleaner {
    static String clean(String rawText) {
    if (rawText.isEmpty) return '';
    
    String text = rawText;
    
 
    text = _stripHtml(text);
    

    text = _convertEmojis(text);
    
   
    text = _normalizeNumbers(text);
    text = _normalizeBengaliNumbers(text); 
    text = _cleanPunctuation(text);
    text = _removeUrls(text);
    text = _removeAdMarkers(text);
    text = _fixFormatting(text);
    text = _applyPhoneticFixes(text);
    return text.trim();
  }

  static String _applyPhoneticFixes(String text) {
    // Reverting broad replacement as it causes issues like Sujit -> Chujit.
    // Need more specific contextual rules if specific corrections are required.
    return text;
  }
  
  static String _stripHtml(String text) {
    try {
      final document = html_parser.parse(text);
      
      document.querySelectorAll('script, style').forEach((element) {
        element.remove();
      });
      
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
    final String result = text
        .replaceAll('।', '. ')  
        .replaceAll('ঃ', ':')   
        .replaceAll('—', ', ')   
        .replaceAll('–', ', '); 

    return result;
  }
  

  static String _normalizeNumbers(String text) {
    
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,3})(,\d{3})+\b'),
      (match) {
        final numberStr = match.group(0)!.replaceAll(',', '');
        final number = int.tryParse(numberStr);
        if (number != null && number < 10000) {
          return _numberToWords(number);
        }
        return numberStr;
      },
    );
    
    text = text.replaceAllMapped(
      RegExp(r'\b(\d+)%\b'),
      (match) {
        final number = int.tryParse(match.group(1)!);
        if (number != null && number <= 100) {
          return '${_numberToWords(number)} percent';
        }
        return match.group(0)!;
      },
    );
    
    text = text.replaceAllMapped(
      RegExp(r'\$(\d+)'),
      (match) {
        final number = int.tryParse(match.group(1)!);
        if (number != null && number < 1000) {
          return '${_numberToWords(number)} dollars';
        }
        return match.group(0)!;
      },
    );
    
    return text;
  }
  
  static String _numberToWords(int number) {
    if (number == 0) return 'zero';
    if (number < 0) return 'negative ${_numberToWords(-number)}';
    if (number >= 10000) return number.toString();
    
    final ones = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'];
    final teens = ['ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 
                   'sixteen', 'seventeen', 'eighteen', 'nineteen'];
    final tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
    
    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      return tens[number ~/ 10] + (number % 10 > 0 ? ' ${ones[number % 10]}' : '');
    }
    if (number < 1000) {
      return '${ones[number ~/ 100]} hundred${number % 100 > 0 ? ' ${_numberToWords(number % 100)}' : ''}';
    }

    return '${ones[number ~/ 1000]} thousand${number % 1000 > 0 ? ' ${_numberToWords(number % 1000)}' : ''}';
  }
  

  static String _cleanPunctuation(String text) {
    
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAllMapped(
      RegExp(r'\s+([.,!?;:])'),
      (match) => match.group(1)!,
    );
    text = text.replaceAllMapped(
      RegExp(r'([.,!?;:])\s*'),
      (match) => '${match.group(1)} ',
    );
    
    text = text.replaceAll(RegExp(r'\.{4,}'), '...');
    text = text.replaceAll(RegExp(r'!{2,}'), '!');
    text = text.replaceAll(RegExp(r'\?{2,}'), '?');
    
    return text;
  }
  
  static String _removeUrls(String text) {

    text = text.replaceAll(
      RegExp(r'https?://\S+|www\.\S+'),
      '',
    );
    
  
    text = text.replaceAll(
      RegExp(r'\S+@\S+\.\S+'),
      '',
    );
    
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
  
 
  static String _fixFormatting(String text) {
    text = text.replaceAll(RegExp(r'([a-z,])\n([a-z])'), r'\1 \2');
    

    text = text.replaceAll('\n', ' ');
    text = text.replaceAll('\r', ' ');
    text = text.replaceAll('\t', ' ');
 
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    
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
