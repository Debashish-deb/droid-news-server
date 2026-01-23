/// Domain entity representing a user profile.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.createdAt,
    this.displayName,
    this.photoUrl,
    this.lastLoginAt,
    this.preferences = const {},
  });
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic> preferences;

  /// Returns the user's display name or a fallback.
  String get nameOrEmail => displayName ?? email.split('@').first;

  /// Returns true if the user has a profile photo.
  bool get hasProfilePhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// Gets a preference value by key with optional default.
  T? getPreference<T>(String key, [T? defaultValue]) {
    final value = preferences[key];
    return value is T ? value : defaultValue;
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? preferences,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserProfile(id: $id, email: $email)';
}
