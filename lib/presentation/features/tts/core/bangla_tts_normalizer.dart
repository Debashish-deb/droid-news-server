// ignore_for_file: avoid_classes_with_only_static_members

/// Bangla-focused text shaping for device TTS engines.
///
/// Flutter/device TTS voices tend to perform best when Bengali text keeps
/// Bengali sentence punctuation, numbers are expanded in Bangla words, and
/// common news acronyms are made pronounceable.
class BanglaTtsNormalizer {
  static final RegExp _banglaGlyph = RegExp(r'[\u0980-\u09FF]');
  static final RegExp _bnDigit = RegExp(r'[০-৯]');
  static final RegExp _latinAcronym = RegExp(r'\b[A-Z]{2,8}\b');
  static final RegExp _numberPattern = RegExp(
    r'(?<![A-Za-z\u0980-\u09FF])([\u09E6-\u09EF0-9]+(?:,[\u09E6-\u09EF0-9]{2,3})*(?:\.[\u09E6-\u09EF0-9]+)?)(?![A-Za-z\u0980-\u09FF])',
  );

  static bool hasBangla(String text) => _banglaGlyph.hasMatch(text);

  static String normalize(String text, {bool ensureTerminal = false}) {
    if (text.trim().isEmpty || !hasBangla(text)) return text;

    var out = text;
    out = _normalizeUnicode(out);
    out = _expandBanglaAbbreviations(out);
    out = _expandCommonLatinAcronyms(out);
    out = _expandMeasurements(out);
    out = _expandPercentages(out);
    out = _expandCurrency(out);
    out = _expandStandaloneNumbers(out);
    out = _applyPronunciationHints(out);
    out = _shapeBanglaPunctuation(out);
    out = _insertBanglaBreathingCommas(out);
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (ensureTerminal && out.isNotEmpty && !RegExp(r'[।!?]$').hasMatch(out)) {
      out = '$out।';
    }
    return out;
  }

  static String withBanglaTerminal(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || RegExp(r'[।!?]$').hasMatch(trimmed)) {
      return trimmed;
    }
    return '$trimmed।';
  }

  static String _normalizeUnicode(String text) {
    return text
        .replaceAll('\u200d', '\u200D')
        .replaceAll('\u200c', '\u200C')
        .replaceAll('৷', '।')
        .replaceAll('‥', '…')
        .replaceAll('...', '…')
        .replaceAll('—', ', ')
        .replaceAll('–', ', ')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");
  }

  static String _expandBanglaAbbreviations(String text) {
    var out = text;
    const replacements = <String, String>{
      'ডা.': 'ডাক্তার ',
      'ডাঃ': 'ডাক্তার ',
      'ড.': 'ডক্টর ',
      'ডঃ': 'ডক্টর ',
      'প্রফ.': 'প্রফেসর ',
      'প্রফঃ': 'প্রফেসর ',
      'মো.': 'মোহাম্মদ ',
      'মোঃ': 'মোহাম্মদ ',
      'মোসা.': 'মোসাম্মৎ ',
      'মোসাঃ': 'মোসাম্মৎ ',
      'কি.মি.': 'কিলোমিটার ',
      'কিঃমিঃ': 'কিলোমিটার ',
      'সে.মি.': 'সেন্টিমিটার ',
      'মি.লি.': 'মিলিলিটার ',
      'মিসেস.': 'মিসেস ',
    };
    replacements.forEach((from, to) {
      out = out.replaceAll(from, to);
    });
    return out;
  }

  static String _expandCommonLatinAcronyms(String text) {
    var out = text;
    const exact = <String, String>{
      'AI': 'এ আই',
      'API': 'এ পি আই',
      'BBC': 'বি বি সি',
      'BGB': 'বি জি বি',
      'BNP': 'বি এন পি',
      'COVID': 'কোভিড',
      'DMP': 'ডি এম পি',
      'EU': 'ই ইউ',
      'FBI': 'এফ বি আই',
      'GDP': 'জি ডি পি',
      'ICC': 'আই সি সি',
      'ICT': 'আই সি টি',
      'IMF': 'আই এম এফ',
      'NASA': 'নাসা',
      'NATO': 'ন্যাটো',
      'NGO': 'এন জি ও',
      'PM': 'পি এম',
      'RAB': 'র‍্যাব',
      'UN': 'ইউ এন',
      'UNDP': 'ইউ এন ডি পি',
      'UNICEF': 'ইউনিসেফ',
      'USA': 'ইউ এস এ',
      'WHO': 'ডব্লিউ এইচ ও',
    };
    exact.forEach((from, to) {
      out = out.replaceAllMapped(RegExp('\\b$from\\b'), (_) => to);
    });
    out = out.replaceAllMapped(
      RegExp(r'\b([\u09E6-\u09EF0-9]+)\s*G\b', caseSensitive: false),
      (match) => '${_numberToBanglaWords(match.group(1) ?? '')} জি',
    );
    return out.replaceAllMapped(_latinAcronym, (match) {
      final value = match.group(0) ?? '';
      return value.split('').map(_latinLetterName).join(' ');
    });
  }

  static String _expandMeasurements(String text) {
    var out = text;
    const units = <String, String>{
      'km': 'কিলোমিটার',
      'kg': 'কেজি',
      'gm': 'গ্রাম',
      'cm': 'সেন্টিমিটার',
      'mm': 'মিলিমিটার',
      'mb': 'মেগাবাইট',
      'gb': 'গিগাবাইট',
    };
    units.forEach((unit, spoken) {
      out = out.replaceAllMapped(
        RegExp(
          '([\u09E6-\u09EF0-9]+(?:\\.[\u09E6-\u09EF0-9]+)?)\\s*$unit\\b',
          caseSensitive: false,
        ),
        (match) => '${_numberToBanglaWords(match.group(1) ?? '')} $spoken',
      );
    });
    return out;
  }

  static String _expandPercentages(String text) {
    return text.replaceAllMapped(
      RegExp(
        r'([\u09E6-\u09EF0-9]+(?:\.[\u09E6-\u09EF0-9]+)?)\s*(?:%|শতাংশ|পার্সেন্ট)',
      ),
      (match) => '${_numberToBanglaWords(match.group(1) ?? '')} শতাংশ',
    );
  }

  static String _expandCurrency(String text) {
    var out = text.replaceAllMapped(
      RegExp(
        r'(?:৳|Tk\.?|BDT)\s*([\u09E6-\u09EF0-9]+(?:,[\u09E6-\u09EF0-9]{2,3})*)',
        caseSensitive: false,
      ),
      (match) => '${_numberToBanglaWords(match.group(1) ?? '')} টাকা',
    );
    out = out.replaceAllMapped(
      RegExp(
        r'\$\s*([\u09E6-\u09EF0-9]+(?:,[\u09E6-\u09EF0-9]{2,3})*(?:\.[\u09E6-\u09EF0-9]+)?)',
      ),
      (match) => '${_numberToBanglaWords(match.group(1) ?? '')} ডলার',
    );
    return out;
  }

  static String _expandStandaloneNumbers(String text) {
    return text.replaceAllMapped(
      _numberPattern,
      (match) => _numberToBanglaWords(match.group(1) ?? ''),
    );
  }

  static String _applyPronunciationHints(String text) {
    return text
        .replaceAll('মার্কিন', 'মারকিন')
        .replaceAll('র্যাব', 'র‍্যাব')
        .replaceAll('র‌্যাব', 'র‍্যাব')
        .replaceAll('কোভিড-১৯', 'কোভিড উনিশ')
        .replaceAll('করোনা ভাইরাস', 'করোনাভাইরাস');
  }

  static String _shapeBanglaPunctuation(String text) {
    var out = text;
    out = out.replaceAllMapped(
      RegExp(r'(?<![\u09E6-\u09EF0-9])\.(?![\u09E6-\u09EF0-9])'),
      (_) => '।',
    );
    out = out.replaceAllMapped(
      RegExp(r'\s+([,;:।!?])'),
      (match) => match.group(1) ?? '',
    );
    out = out.replaceAllMapped(
      RegExp(r'([,;:।!?])(?=\S)'),
      (match) => '${match.group(1)} ',
    );
    out = out
        .replaceAll(RegExp(r'।{2,}'), '।')
        .replaceAll(RegExp(r'!{2,}'), '!')
        .replaceAll(RegExp(r'\?{2,}'), '?')
        .replaceAll(RegExp(r',\s*,'), ',');
    return out;
  }

  static String _insertBanglaBreathingCommas(String text) {
    final parts = RegExp(r'[^।!?]+[।!?]?').allMatches(text);
    final shaped = <String>[];
    for (final match in parts) {
      var segment = (match.group(0) ?? '').trim();
      if (segment.isEmpty) continue;
      var terminal = '';
      if (RegExp(r'[।!?]$').hasMatch(segment)) {
        terminal = segment.substring(segment.length - 1);
        segment = segment.substring(0, segment.length - 1).trim();
      }
      if (!segment.contains(',') && segment.split(RegExp(r'\s+')).length > 18) {
        segment = _insertCommaBeforeConnector(segment);
      }
      shaped.add(terminal.isEmpty ? segment : '$segment$terminal');
    }
    return shaped.isEmpty ? text : shaped.join(' ');
  }

  static String _insertCommaBeforeConnector(String segment) {
    const connectors = <String>[
      ' কিন্তু ',
      ' তবে ',
      ' কারণ ',
      ' যদিও ',
      ' যেখানে ',
      ' যখন ',
      ' যাতে ',
      ' ফলে ',
      ' বলে ',
      ' এবং ',
    ];
    for (final connector in connectors) {
      final index = segment.indexOf(connector);
      if (index > 18 && index < segment.length - 18) {
        return '${segment.substring(0, index)},${segment.substring(index)}';
      }
    }
    return segment;
  }

  static String _numberToBanglaWords(String raw) {
    final sanitized = _normalizeDigits(raw).replaceAll(',', '').trim();
    if (sanitized.isEmpty) return raw;
    if (sanitized.contains('.')) {
      final parts = sanitized.split('.');
      final whole = int.tryParse(parts.first);
      if (whole == null) return raw;
      final fraction = parts.length > 1 ? parts[1] : '';
      final fractionWords = fraction
          .split('')
          .where((digit) => digit.isNotEmpty)
          .map((digit) => _digitWord(int.tryParse(digit) ?? 0))
          .join(' ');
      if (fractionWords.isEmpty) return _integerToBanglaWords(whole);
      return '${_integerToBanglaWords(whole)} দশমিক $fractionWords';
    }
    final value = int.tryParse(sanitized);
    if (value == null) return raw;
    return _integerToBanglaWords(value);
  }

  static String _normalizeDigits(String raw) {
    return raw.replaceAllMapped(_bnDigit, (match) {
      const digits = '০১২৩৪৫৬৭৮৯';
      return digits.indexOf(match.group(0) ?? '').toString();
    });
  }

  static String _integerToBanglaWords(int value) {
    if (value < 0) return 'ঋণাত্মক ${_integerToBanglaWords(-value)}';
    if (value < 100) return _underHundred[value];
    if (value >= 1000000000) {
      return value.toString();
    }
    if (value < 1000) {
      final hundreds = value ~/ 100;
      final rem = value % 100;
      final tail = rem == 0 ? '' : ' ${_integerToBanglaWords(rem)}';
      return '${_underHundred[hundreds]} শত$tail';
    }
    if (value < 100000) {
      return _unitWords(value, 1000, 'হাজার');
    }
    if (value < 10000000) {
      return _unitWords(value, 100000, 'লাখ');
    }
    return _unitWords(value, 10000000, 'কোটি');
  }

  static String _unitWords(int value, int unit, String label) {
    final head = value ~/ unit;
    final rem = value % unit;
    final tail = rem == 0 ? '' : ' ${_integerToBanglaWords(rem)}';
    return '${_integerToBanglaWords(head)} $label$tail';
  }

  static String _digitWord(int digit) => _underHundred[digit.clamp(0, 9)];

  static String _latinLetterName(String letter) {
    const names = <String, String>{
      'A': 'এ',
      'B': 'বি',
      'C': 'সি',
      'D': 'ডি',
      'E': 'ই',
      'F': 'এফ',
      'G': 'জি',
      'H': 'এইচ',
      'I': 'আই',
      'J': 'জে',
      'K': 'কে',
      'L': 'এল',
      'M': 'এম',
      'N': 'এন',
      'O': 'ও',
      'P': 'পি',
      'Q': 'কিউ',
      'R': 'আর',
      'S': 'এস',
      'T': 'টি',
      'U': 'ইউ',
      'V': 'ভি',
      'W': 'ডব্লিউ',
      'X': 'এক্স',
      'Y': 'ওয়াই',
      'Z': 'জেড',
    };
    return names[letter.toUpperCase()] ?? letter;
  }

  static const List<String> _underHundred = <String>[
    'শূন্য',
    'এক',
    'দুই',
    'তিন',
    'চার',
    'পাঁচ',
    'ছয়',
    'সাত',
    'আট',
    'নয়',
    'দশ',
    'এগারো',
    'বারো',
    'তেরো',
    'চৌদ্দ',
    'পনেরো',
    'ষোলো',
    'সতেরো',
    'আঠারো',
    'উনিশ',
    'বিশ',
    'একুশ',
    'বাইশ',
    'তেইশ',
    'চব্বিশ',
    'পঁচিশ',
    'ছাব্বিশ',
    'সাতাশ',
    'আটাশ',
    'ঊনত্রিশ',
    'ত্রিশ',
    'একত্রিশ',
    'বত্রিশ',
    'তেত্রিশ',
    'চৌত্রিশ',
    'পঁয়ত্রিশ',
    'ছত্রিশ',
    'সাঁইত্রিশ',
    'আটত্রিশ',
    'ঊনচল্লিশ',
    'চল্লিশ',
    'একচল্লিশ',
    'বিয়াল্লিশ',
    'তেতাল্লিশ',
    'চুয়াল্লিশ',
    'পঁয়তাল্লিশ',
    'ছেচল্লিশ',
    'সাতচল্লিশ',
    'আটচল্লিশ',
    'ঊনপঞ্চাশ',
    'পঞ্চাশ',
    'একান্ন',
    'বায়ান্ন',
    'তিপ্পান্ন',
    'চুয়ান্ন',
    'পঞ্চান্ন',
    'ছাপ্পান্ন',
    'সাতান্ন',
    'আটান্ন',
    'ঊনষাট',
    'ষাট',
    'একষট্টি',
    'বাষট্টি',
    'তেষট্টি',
    'চৌষট্টি',
    'পঁয়ষট্টি',
    'ছেষট্টি',
    'সাতষট্টি',
    'আটষট্টি',
    'ঊনসত্তর',
    'সত্তর',
    'একাত্তর',
    'বাহাত্তর',
    'তিয়াত্তর',
    'চুয়াত্তর',
    'পঁচাত্তর',
    'ছিয়াত্তর',
    'সাতাত্তর',
    'আটাত্তর',
    'ঊনআশি',
    'আশি',
    'একাশি',
    'বিরাশি',
    'তিরাশি',
    'চুরাশি',
    'পঁচাশি',
    'ছিয়াশি',
    'সাতাশি',
    'আটাশি',
    'ঊননব্বই',
    'নব্বই',
    'একানব্বই',
    'বিরানব্বই',
    'তিরানব্বই',
    'চুরানব্বই',
    'পঁচানব্বই',
    'ছিয়ানব্বই',
    'সাতানব্বই',
    'আটানব্বই',
    'নিরানব্বই',
  ];
}
