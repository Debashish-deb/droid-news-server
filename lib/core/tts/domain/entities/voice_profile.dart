import 'package:flutter/foundation.dart';

/// Represents a single TTS voice available on the device or network.
@immutable
class VoiceProfile {

  /// Restores a [VoiceProfile] serialised with [toJson].
  factory VoiceProfile.fromJson(Map<String, dynamic> json) {
    return VoiceProfile(
      name: (json['name'] as String? ?? '').trim(),
      locale: (json['locale'] as String? ?? '').trim(),
      gender: (json['gender'] as String? ?? 'unknown').trim(),
      isNetworkVoice: json['isNetworkVoice'] as bool? ?? false,
      quality: VoiceQuality.values.firstWhere(
        (q) => q.name == json['quality'],
        orElse: () => VoiceQuality.standard,
      ),
    );
  }
  const VoiceProfile({
    required this.name,
    required this.locale,
    this.gender = 'unknown',
    this.isNetworkVoice = false,
    this.quality = VoiceQuality.standard,
  });

  // ─── Factories ─────────────────────────────────────────────────────────────

  /// A sentinel profile used when no voice is selected or available.
  static const VoiceProfile unknown = VoiceProfile(name: '', locale: '');

  // ─── Fields ────────────────────────────────────────────────────────────────

  final String name;
  final String locale;
  final String gender;
  final bool isNetworkVoice;

  /// Subjective quality tier inferred from the voice name.
  final VoiceQuality quality;

  // ─── Computed ──────────────────────────────────────────────────────────────

  /// Whether this is the sentinel "no voice selected" profile.
  bool get isUnknown => name.isEmpty || locale.isEmpty;

  /// Inverse of [isNetworkVoice].
  bool get isLocal => !isNetworkVoice;

  /// BCP-47 language subtag (e.g. `"en"` from `"en-US"`).
  String get languageCode {
    final parts = locale.split(RegExp(r'[-_]'));
    return parts.isNotEmpty ? parts.first.toLowerCase() : '';
  }

  /// Region subtag (e.g. `"US"` from `"en-US"`), or empty string.
  String get regionCode {
    final parts = locale.split(RegExp(r'[-_]'));
    return parts.length >= 2 ? parts[1].toUpperCase() : '';
  }

  /// Human-readable label: voice name, or `"Unknown"` for the sentinel.
  String get displayName => isUnknown ? 'Unknown' : name;

  /// Whether this voice can speak Bengali content.
  bool get supportsBengali => locale.toLowerCase().startsWith('bn');

  /// Whether this voice can speak English content.
  bool get supportsEnglish => locale.toLowerCase().startsWith('en');

  /// `true` when [gender] is `"female"` (case-insensitive).
  bool get isFemale => gender.toLowerCase() == 'female';

  /// `true` when [gender] is `"male"` (case-insensitive).
  bool get isMale => gender.toLowerCase() == 'male';

  // ─── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'locale': locale,
    'gender': gender,
    'isNetworkVoice': isNetworkVoice,
    'quality': quality.name,
  };

  // ─── copyWith ──────────────────────────────────────────────────────────────

  VoiceProfile copyWith({
    String? name,
    String? locale,
    String? gender,
    bool? isNetworkVoice,
    VoiceQuality? quality,
  }) => VoiceProfile(
    name: name ?? this.name,
    locale: locale ?? this.locale,
    gender: gender ?? this.gender,
    isNetworkVoice: isNetworkVoice ?? this.isNetworkVoice,
    quality: quality ?? this.quality,
  );

  // ─── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceProfile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          locale == other.locale;

  @override
  int get hashCode => Object.hash(name, locale);

  @override
  String toString() =>
      'VoiceProfile(name: $name, locale: $locale, '
      'gender: $gender, network: $isNetworkVoice, quality: ${quality.name})';
}

// ─── Supporting enums ─────────────────────────────────────────────────────────

/// Subjective quality tier for a [VoiceProfile].
enum VoiceQuality {
  /// Basic on-device voice; fast but often robotic.
  compact,

  /// Default on-device voice — good balance of quality and speed.
  standard,

  /// Enhanced neural / WaveNet voice; highest quality.
  premium,
}
