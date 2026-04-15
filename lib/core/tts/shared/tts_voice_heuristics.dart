// ignore_for_file: avoid_classes_with_only_static_members

import '../domain/entities/voice_profile.dart';

class TtsVoiceCandidate {
  const TtsVoiceCandidate({
    required this.name,
    required this.locale,
    this.gender = 'unknown',
    this.isNetworkVoice = false,
  });

  factory TtsVoiceCandidate.fromRawMap(Map<dynamic, dynamic> raw) {
    final name = (raw['name'] ?? raw['voice'] ?? '').toString().trim();
    final locale = (raw['locale'] ?? raw['language'] ?? '').toString().trim();
    final gender = (raw['gender'] ?? 'unknown').toString().trim();
    final isNetworkVoice = _readBool(
      raw['network_required'] ??
          raw['networkRequired'] ??
          raw['isNetworkVoice'] ??
          raw['network'],
    );

    return TtsVoiceCandidate(
      name: name,
      locale: locale,
      gender: gender.isEmpty ? 'unknown' : gender,
      isNetworkVoice: isNetworkVoice,
    );
  }

  final String name;
  final String locale;
  final String gender;
  final bool isNetworkVoice;

  VoiceProfile toVoiceProfile() => VoiceProfile(
    name: name,
    locale: locale,
    gender: gender,
    isNetworkVoice: isNetworkVoice,
  );

  Map<String, String> toUiMap() => <String, String>{
    'name': name,
    'locale': locale,
  };

  static bool _readBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final value = raw?.toString().trim().toLowerCase();
    return value == 'true' || value == '1' || value == 'yes';
  }
}

class TtsVoiceHeuristics {
  static final RegExp _blockedVoiceNamePattern = RegExp(
    r'\b(echo|electro|robot|synthetic|synth|vocoder|chipmunk|helium|monster)\b',
    caseSensitive: false,
  );

  static final RegExp _preferredVoiceNamePattern = RegExp(
    r'\b(neural|wavenet|studio|natural|clear|premium|enhanced)\b',
    caseSensitive: false,
  );

  static final RegExp _lowerPriorityVoiceNamePattern = RegExp(
    r'\b(legacy|compact|demo|experimental|sample)\b',
    caseSensitive: false,
  );

  static List<TtsVoiceCandidate> sanitizeCandidates(
    Iterable<TtsVoiceCandidate> candidates,
  ) {
    final valid = candidates
        .where((candidate) => candidate.name.isNotEmpty && candidate.locale.isNotEmpty)
        .toList(growable: false);
    if (valid.isEmpty) return const <TtsVoiceCandidate>[];

    final filtered = valid
        .where((candidate) => !_blockedVoiceNamePattern.hasMatch(candidate.name))
        .toList(growable: false);
    return filtered.isNotEmpty ? filtered : valid;
  }

  static List<TtsVoiceCandidate> sortCandidates(
    Iterable<TtsVoiceCandidate> candidates, {
    String? preferredLanguageCode,
  }) {
    final sorted = List<TtsVoiceCandidate>.from(sanitizeCandidates(candidates));
    sorted.sort(
      (a, b) => compareCandidates(
        a,
        b,
        preferredLanguageCode: preferredLanguageCode,
      ),
    );
    return sorted;
  }

  static TtsVoiceCandidate? pickBestCandidate(
    Iterable<TtsVoiceCandidate> candidates, {
    String? preferredLanguageCode,
  }) {
    final sorted = sortCandidates(
      candidates,
      preferredLanguageCode: preferredLanguageCode,
    );
    return sorted.isEmpty ? null : sorted.first;
  }

  static List<Map<String, String>> sortVoiceMaps(
    Iterable<Map<String, String>> voices, {
    String? preferredLanguageCode,
  }) {
    final candidates = voices
        .map(
          (voice) => TtsVoiceCandidate(
            name: (voice['name'] ?? '').trim(),
            locale: (voice['locale'] ?? '').trim(),
          ),
        )
        .toList(growable: false);
    return sortCandidates(
      candidates,
      preferredLanguageCode: preferredLanguageCode,
    ).map((candidate) => candidate.toUiMap()).toList(growable: false);
  }

  static Map<String, String>? pickBestVoiceMap(
    Iterable<Map<String, String>> voices, {
    String? preferredLanguageCode,
  }) {
    final sorted = sortVoiceMaps(
      voices,
      preferredLanguageCode: preferredLanguageCode,
    );
    return sorted.isEmpty ? null : sorted.first;
  }

  static VoiceProfile? pickBestVoiceProfile(
    Iterable<VoiceProfile> voices, {
    String? preferredLanguageCode,
  }) {
    final candidate = pickBestCandidate(
      voices
          .map(
            (voice) => TtsVoiceCandidate(
              name: voice.name,
              locale: voice.locale,
              gender: voice.gender,
              isNetworkVoice: voice.isNetworkVoice,
            ),
          )
          .toList(growable: false),
      preferredLanguageCode: preferredLanguageCode,
    );
    return candidate?.toVoiceProfile();
  }

  static bool matchesLanguage(String locale, String preferredLanguageCode) {
    final normalizedLocale = normalizeLanguageCode(locale);
    final normalizedPreferred = normalizeLanguageCode(preferredLanguageCode);
    if (normalizedLocale.isEmpty || normalizedPreferred.isEmpty) return false;
    if (normalizedLocale == normalizedPreferred) return true;
    return normalizedLocale.split('-').first ==
        normalizedPreferred.split('-').first;
  }

  static String normalizeLanguageCode(String raw) {
    final code = raw.trim().replaceAll('_', '-');
    if (code.isEmpty) return '';
    switch (code.toLowerCase()) {
      case 'en':
        return 'en-US';
      case 'bn':
        return 'bn-BD';
      case 'hi':
        return 'hi-IN';
      default:
        return code;
    }
  }

  static int compareCandidates(
    TtsVoiceCandidate a,
    TtsVoiceCandidate b, {
    String? preferredLanguageCode,
  }) {
    final scoreA = _scoreCandidate(
      a,
      preferredLanguageCode: preferredLanguageCode,
    );
    final scoreB = _scoreCandidate(
      b,
      preferredLanguageCode: preferredLanguageCode,
    );
    if (scoreA != scoreB) return scoreB.compareTo(scoreA);

    final localeCompare = a.locale.compareTo(b.locale);
    if (localeCompare != 0) return localeCompare;
    return a.name.compareTo(b.name);
  }

  static int _scoreCandidate(
    TtsVoiceCandidate candidate, {
    String? preferredLanguageCode,
  }) {
    var score = 0;
    final normalizedName = candidate.name.toLowerCase();
    final normalizedLocale = normalizeLanguageCode(candidate.locale);
    final normalizedPreferred = normalizeLanguageCode(preferredLanguageCode ?? '');

    if (normalizedPreferred.isNotEmpty) {
      if (normalizedLocale == normalizedPreferred) {
        score += 120;
      } else if (matchesLanguage(normalizedLocale, normalizedPreferred)) {
        score += 80;
      } else {
        score -= 30;
      }
    }

    if (candidate.isNetworkVoice) {
      score += 18;
    }
    if (_preferredVoiceNamePattern.hasMatch(normalizedName)) {
      score += 12;
    }
    if (_lowerPriorityVoiceNamePattern.hasMatch(normalizedName)) {
      score -= 10;
    }
    if (normalizedName.contains('local')) {
      score -= 3;
    }
    if (normalizedName.contains('google')) {
      score += 4;
    }
    if (normalizedName.contains('samsung')) {
      score += 2;
    }

    return score;
  }
}
