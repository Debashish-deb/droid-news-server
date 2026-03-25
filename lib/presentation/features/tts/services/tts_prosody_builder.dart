import '../domain/models/speech_chunk.dart';

enum ChunkTone { statement, question, exclamation, reflective, listing, quote }

enum ChunkRole { lead, context, pivot, attribution, closing }

enum TtsPreset { anchor, natural, story }

class ChunkProsody {
  const ChunkProsody({
    required this.text,
    required this.rate,
    required this.pitch,
    required this.tone,
    required this.role,
    required this.isBangla,
    required this.isUrgent,
    required this.isSolemn,
  });

  final String text;
  final double rate;
  final double pitch;
  final ChunkTone tone;
  final ChunkRole role;
  final bool isBangla;
  final bool isUrgent;
  final bool isSolemn;
}

class TtsProsodyBuilder {
  static final RegExp _quotePattern = RegExp(r'["“][^"”]+["”]');
  static final RegExp _pivotCuePattern = RegExp(
    r'^(however|meanwhile|in a related development|in other news|separately|turning to|on the other hand)\b',
    caseSensitive: false,
  );
  static final RegExp _attributionPattern = RegExp(
    r'^(according to|sources (say|said)|officials (say|said)|the (president|minister|spokesperson|department|agency) (said|stated)|police said)\b',
    caseSensitive: false,
  );
  static final RegExp _closingCuePattern = RegExp(
    r'(details to follow|more updates|that is the latest|stay with us|back to you)\.?$',
    caseSensitive: false,
  );

  static ChunkProsody buildChunkProsody({
    required SpeechChunk chunk,
    required double baseSynthesisRate,
    required double baseSynthesisPitch,
    TtsPreset preset = TtsPreset.natural,
  }) {
    final raw = chunk.text.trim();
    final hasBanglaGlyph = RegExp(r'[\u0980-\u09FF]').hasMatch(raw);
    final isBangla = chunk.language.startsWith('bn') || hasBanglaGlyph;
    final normalized = _normalizeChunkText(raw, isBangla: isBangla);
    final tone = _detectTone(normalized, isBangla: isBangla);
    final role = _detectRole(normalized, chunkId: chunk.id);
    final isUrgent = _isUrgentTopic(normalized, isBangla: isBangla);
    final isSolemn = _isSolemnTopic(normalized, isBangla: isBangla);

    var rate = baseSynthesisRate;
    var pitch = baseSynthesisPitch;

    // Apply style-based multipliers
    final rateStyleMult = switch (preset) {
      TtsPreset.anchor => 1.02,   // Authoritative, brisk
      TtsPreset.natural => 1.0,   // Balanced
      TtsPreset.story => 0.94,    // Deliberate, narratory
    };
    final pitchStyleMult = switch (preset) {
      TtsPreset.anchor => 0.94,   // Solemn, authoritative
      TtsPreset.natural => 1.0,   // Default
      TtsPreset.story => 1.08,    // Expressive, emotive
    };

    rate *= rateStyleMult;
    pitch *= pitchStyleMult;

    switch (role) {
      case ChunkRole.lead:
        rate -= 0.04;
        pitch -= 0.01;
        break;
      case ChunkRole.pivot:
        rate -= 0.02;
        break;
      case ChunkRole.attribution:
        rate -= 0.02;
        pitch -= 0.02;
        break;
      case ChunkRole.closing:
        rate -= 0.03;
        pitch -= 0.01;
        break;
      case ChunkRole.context:
        break;
    }

    switch (tone) {
      case ChunkTone.question:
        rate -= 0.02;
        pitch += isBangla ? 0.07 : 0.04;
        break;
      case ChunkTone.exclamation:
        rate += 0.02;
        pitch += 0.06;
        break;
      case ChunkTone.reflective:
        rate -= 0.04;
        pitch -= 0.03;
        break;
      case ChunkTone.listing:
        rate -= 0.015;
        pitch += 0.01;
        break;
      case ChunkTone.quote:
        rate -= 0.03;
        pitch -= 0.04;
        break;
      case ChunkTone.statement:
        break;
    }

    // Style-specific variances
    if (preset == TtsPreset.story) {
      if (tone == ChunkTone.quote || tone == ChunkTone.exclamation) {
        pitch += 0.02;
      }
    } else if (preset == TtsPreset.anchor) {
      pitch = (pitch * 0.92 + baseSynthesisPitch * 0.08);
    }

    if (isUrgent && !isSolemn) {
      rate += 0.01;
      pitch += 0.02;
    }
    if (isSolemn) {
      rate -= 0.05;
      pitch -= 0.04;
    }

    if (normalized.length > 260) {
      rate -= 0.02;
    } else if (normalized.length < 70) {
      rate += 0.012;
    }

    if (_containsLongClause(normalized, isBangla: isBangla)) {
      rate -= 0.01;
    }

    if (isBangla) {
      pitch += 0.015;
      rate -= 0.008;
    }

    final shapedText = _injectPauseHints(
      normalized,
      isBangla: isBangla,
      tone: tone,
      role: role,
      isUrgent: isUrgent,
      isSolemn: isSolemn,
      preset: preset,
    );

    return ChunkProsody(
      text: shapedText,
      rate: rate.clamp(0.35, 0.65),
      pitch: pitch.clamp(0.78, 1.22),
      tone: tone,
      role: role,
      isBangla: isBangla,
      isUrgent: isUrgent,
      isSolemn: isSolemn,
    );
  }

  static ChunkTone _detectTone(String text, {required bool isBangla}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return ChunkTone.statement;

    if (RegExp('\\?\\s*[\'"”]?\$').hasMatch(trimmed)) {
      return ChunkTone.question;
    }
    if (RegExp('!\\s*[\'"”]?\$').hasMatch(trimmed)) {
      return ChunkTone.exclamation;
    }
    if (_quotePattern.hasMatch(trimmed) ||
        _attributionPattern.hasMatch(trimmed)) {
      return ChunkTone.quote;
    }
    if (trimmed.contains('...') || trimmed.contains('…')) {
      return ChunkTone.reflective;
    }

    final punctuationCount = RegExp(r'[,;:]').allMatches(trimmed).length;
    if (punctuationCount >= 3) return ChunkTone.listing;

    if (isBangla &&
        RegExp(
          r'(কি|কী|কেন|কোথায়|কোথায়|কিভাবে|কীভাবে|কখন)\s*$',
          caseSensitive: false,
        ).hasMatch(trimmed)) {
      return ChunkTone.question;
    }
    return ChunkTone.statement;
  }

  static ChunkRole _detectRole(String text, {required int chunkId}) {
    final trimmed = text.trim();
    if (chunkId == 0) return ChunkRole.lead;
    if (_pivotCuePattern.hasMatch(trimmed)) return ChunkRole.pivot;
    if (_attributionPattern.hasMatch(trimmed) ||
        _quotePattern.hasMatch(trimmed)) {
      return ChunkRole.attribution;
    }
    if (_closingCuePattern.hasMatch(trimmed)) return ChunkRole.closing;
    return ChunkRole.context;
  }

  static bool _isUrgentTopic(String text, {required bool isBangla}) {
    final lower = text.toLowerCase();
    final englishMatch = RegExp(
      r'\b(breaking|urgent|just in|alert|confirmed|immediately)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (!isBangla) return englishMatch;
    final banglaMatch = RegExp(
      r'(ব্রেকিং|জরুরি|তাৎক্ষণিক|নিশ্চিত|অবিলম্বে)',
      caseSensitive: false,
    ).hasMatch(text);
    return englishMatch || banglaMatch;
  }

  static bool _isSolemnTopic(String text, {required bool isBangla}) {
    final lower = text.toLowerCase();
    final englishMatch = RegExp(
      r'\b(death|killed|injured|tragedy|mourning|disaster|critical|hospitalized)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (!isBangla) return englishMatch;
    final banglaMatch = RegExp(
      r'(মৃত্যু|নিহত|আহত|দুর্ঘটনা|শোক|বিপর্যয়|সংকটাপন্ন)',
      caseSensitive: false,
    ).hasMatch(text);
    return englishMatch || banglaMatch;
  }

  static bool _containsLongClause(String text, {required bool isBangla}) {
    final punctuation = isBangla ? RegExp(r'[,;:।!?]') : RegExp(r'[,;:!?]');
    if (punctuation.hasMatch(text)) return false;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return words > 20;
  }

  static String _normalizeChunkText(String text, {required bool isBangla}) {
    var out = text
        .replaceAllMapped(
          RegExp(r'\[PAUSE\s+(\d+(?:\.\d+)?)s\]', caseSensitive: false),
          (match) {
            final seconds = double.tryParse(match.group(1) ?? '0') ?? 0;
            return _pauseFromMilliseconds((seconds * 1000).round());
          },
        )
        .replaceAll(RegExp(r'\[(?:BREATH|BREAK)\]', caseSensitive: false), ', ')
        .replaceAll(
          RegExp(
            r'\[(?:EMPHASIS\s+\w+|PITCH\s+[^\]]+|RATE\s+[^\]]+|WHISPER|NEUTRAL|LEAD[^\]]*|BODY[^\]]*|QUOTE[^\]]*|OUTRO[^\]]*|NEWS\s+TONE:[^\]]+)\]',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAllMapped(
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
        )
        .replaceAll(
          RegExp(r'</?(?:speak|prosody|emphasis)[^>]*>', caseSensitive: false),
          ' ',
        )
        .replaceAllMapped(
          RegExp(r'\*([^\*]+)\*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{2,}'), isBangla ? '। ' : '. ')
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r'([,;:।!?])(?=\S)'), r'$1 ')
        .replaceAll(RegExp(r'\.{4,}'), '...')
        .replaceAll(RegExp(r'\s+"'), ' "')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (!isBangla) {
      out = _normalizeBroadcastNumbers(out);
    }

    out = _insertBreathingCommaForLongClauses(
      out,
      isBangla: isBangla,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();

    if (out.isEmpty) return out;

    final terminal = isBangla ? RegExp(r'[।!?]$') : RegExp(r'[.!?]$');
    if (!terminal.hasMatch(out)) {
      out = isBangla ? '$out। ' : '$out. ';
    }
    return out;
  }

  static String _pauseFromMilliseconds(int millis) {
    if (millis >= 1000) return '. ';
    if (millis >= 500) return '. ';
    if (millis >= 150) return ', ';
    return ' ';
  }

  static String _normalizeBroadcastNumbers(String text) {
    var out = text;

    out = out.replaceAllMapped(
      RegExp(r'\$([0-9]+(?:\.[0-9]+)?)\s*([kmb])\b', caseSensitive: false),
      (match) {
        final number = match.group(1) ?? '';
        final suffix = (match.group(2) ?? '').toLowerCase();
        final suffixWord = switch (suffix) {
          'k' => 'thousand',
          'm' => 'million',
          'b' => 'billion',
          _ => '',
        };
        return '${_numberToWords(number)} $suffixWord dollars';
      },
    );

    out = out.replaceAllMapped(
      RegExp(r'\$([0-9]+(?:\.[0-9]+)?)\b'),
      (match) => '${_numberToWords(match.group(1) ?? '')} dollars',
    );

    out = out.replaceAllMapped(
      RegExp(r'\b([0-9]+(?:\.[0-9]+)?)%'),
      (match) => '${_numberToWords(match.group(1) ?? '')} percent',
    );

    out = out.replaceAllMapped(RegExp(r'\b([0-9]{1,3}(?:,[0-9]{3})+)\b'), (
      match,
    ) {
      final compact = (match.group(1) ?? '').replaceAll(',', '');
      return _numberToWords(compact);
    });

    out = out.replaceAllMapped(
      RegExp(r'(?<![\w.])([0-9]{1,4})(?![\w.])'),
      (match) => _numberToWords(match.group(1) ?? ''),
    );

    return out;
  }

  static String _numberToWords(String raw) {
    final sanitized = raw.trim();
    if (sanitized.isEmpty) return raw;
    if (sanitized.contains('.')) {
      final parts = sanitized.split('.');
      final whole = int.tryParse(parts.first);
      if (whole == null) return raw;
      final fraction = parts.length > 1
          ? parts[1].replaceAll(RegExp(r'0+$'), '')
          : '';
      if (fraction.isEmpty) return _integerToWords(whole);
      final fractionWords = fraction
          .split('')
          .map((digit) => _digitToWord(int.tryParse(digit) ?? 0))
          .join(' ');
      return '${_integerToWords(whole)} point $fractionWords';
    }
    final value = int.tryParse(sanitized);
    if (value == null) return raw;
    return _integerToWords(value);
  }

  static String _digitToWord(int digit) {
    const words = <String>[
      'zero',
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
    return words[digit.clamp(0, 9)];
  }

  static String _integerToWords(int value) {
    if (value < 0) return 'minus ${_integerToWords(-value)}';
    if (value == 0) return 'zero';
    if (value >= 1000000000) return value.toString();

    if (value < 1000) return _underThousandToWords(value);
    if (value < 1000000) {
      final thousands = value ~/ 1000;
      final rem = value % 1000;
      final suffix = rem == 0 ? '' : ' ${_underThousandToWords(rem)}';
      return '${_underThousandToWords(thousands)} thousand$suffix';
    }

    final millions = value ~/ 1000000;
    final rem = value % 1000000;
    if (rem == 0) return '${_underThousandToWords(millions)} million';
    if (rem < 1000) {
      return '${_underThousandToWords(millions)} million ${_underThousandToWords(rem)}';
    }
    final remThousands = rem ~/ 1000;
    final remTail = rem % 1000;
    final tail = remTail == 0 ? '' : ' ${_underThousandToWords(remTail)}';
    return '${_underThousandToWords(millions)} million ${_underThousandToWords(remThousands)} thousand$tail';
  }

  static String _underThousandToWords(int value) {
    const ones = <String>[
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
    const teens = <String>[
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
    const tens = <String>[
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

    if (value < 10) return ones[value];
    if (value < 20) return teens[value - 10];
    if (value < 100) {
      final rem = value % 10;
      return rem == 0 ? tens[value ~/ 10] : '${tens[value ~/ 10]} ${ones[rem]}';
    }
    final rem = value % 100;
    if (rem == 0) return '${ones[value ~/ 100]} hundred';
    return '${ones[value ~/ 100]} hundred ${_underThousandToWords(rem)}';
  }

  static String _insertBreathingCommaForLongClauses(
    String text, {
    required bool isBangla,
  }) {
    if (isBangla) return text;

    final segments = <String>[];
    final matches = RegExp(r'[^.!?]+[.!?]?').allMatches(text);
    for (final match in matches) {
      final rawSegment = match.group(0) ?? '';
      var segment = rawSegment.trim();
      if (segment.isEmpty) continue;

      var terminal = '';
      if (RegExp(r'[.!?]$').hasMatch(segment)) {
        terminal = segment[segment.length - 1];
        segment = segment.substring(0, segment.length - 1).trim();
      }

      final words = segment
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.length > 20 && !segment.contains(RegExp(r'[,;:]'))) {
        final pivot = _findBreathPivot(words);
        if (pivot > 2 && pivot < words.length - 2) {
          words[pivot - 1] = '${words[pivot - 1]},';
          segment = words.join(' ');
        }
      }

      final rebuilt = terminal.isEmpty ? segment : '$segment$terminal';
      segments.add(rebuilt);
    }

    if (segments.isEmpty) return text;
    return segments.join(' ');
  }

  static int _findBreathPivot(List<String> words) {
    const connectors = <String>{
      'and',
      'but',
      'while',
      'because',
      'although',
      'however',
      'meanwhile',
      'which',
      'that',
      'whereas',
      'since',
      'when',
      'after',
      'before',
    };

    final mid = words.length ~/ 2;
    for (int delta = 0; delta < words.length; delta++) {
      final right = mid + delta;
      if (right < words.length) {
        final token = words[right].toLowerCase().replaceAll(
          RegExp(r'[^a-z]'),
          '',
        );
        if (connectors.contains(token)) return right;
      }
      final left = mid - delta;
      if (left >= 0) {
        final token = words[left].toLowerCase().replaceAll(
          RegExp(r'[^a-z]'),
          '',
        );
        if (connectors.contains(token)) return left;
      }
    }
    return -1;
  }

  static String _injectPauseHints(
    String text, {
    required bool isBangla,
    required ChunkTone tone,
    required ChunkRole role,
    required bool isUrgent,
    required bool isSolemn,
    TtsPreset preset = TtsPreset.natural,
  }) {
    var out = text
        .replaceAll('—', ', ')
        .replaceAll('–', ', ')
        .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '')
        .replaceAll(RegExp(r'([,;:])\s*'), r'$1 ');

    final isFastStyle = preset == TtsPreset.anchor || preset == TtsPreset.natural;

    if (role == ChunkRole.pivot &&
        _pivotCuePattern.hasMatch(out) &&
        !RegExp(r'^[^,]+,').hasMatch(out)) {
      out = out.replaceFirstMapped(
        _pivotCuePattern,
        (match) => '${match.group(0)}${isFastStyle ? "" : ","}',
      );
    }

    if ((role == ChunkRole.attribution || tone == ChunkTone.quote) &&
        RegExp(r'^[^,]{16,}["“]').hasMatch(out)) {
      out = out.replaceFirstMapped(
        RegExp(r'([A-Za-z0-9])\s*["“]'),
        (match) => isFastStyle ? '${match.group(1)} "' : '${match.group(1)}, "',
      );
    }

    if (isBangla && tone == ChunkTone.listing) {
      out = out.replaceAll(' এবং ', isFastStyle ? ' এবং ' : ', এবং ');
    }

    if (tone == ChunkTone.reflective &&
        !out.endsWith('...') &&
        !out.endsWith('…')) {
      out = isFastStyle ? '$out.' : '$out ...';
    }

    if (role == ChunkRole.closing &&
        !out.endsWith('...') &&
        !out.endsWith('…')) {
      out = isFastStyle ? '$out.' : '$out ...';
    }

    if (isUrgent && !isSolemn) {
      out = out.replaceAllMapped(
        RegExp(r'\b(breaking news|urgent update)\b', caseSensitive: false),
        (match) => isFastStyle ? match.group(0)! : '${match.group(0)},',
      );
    }

    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
