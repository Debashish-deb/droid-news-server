/// Domain entity representing notification preferences.
class NotificationSettings {
  const NotificationSettings({
    required this.userId,
    required this.updatedAt,
    this.pushNotificationsEnabled = true,
    this.newsUpdatesEnabled = true,
    this.magazineUpdatesEnabled = true,
    this.historicalEventsEnabled = true,
    this.promotionalNotificationsEnabled = false,
    this.categoryNotifications = const {},
  });
  final String userId;
  final bool pushNotificationsEnabled;
  final bool newsUpdatesEnabled;
  final bool magazineUpdatesEnabled;
  final bool historicalEventsEnabled;
  final bool promotionalNotificationsEnabled;
  final Map<String, bool> categoryNotifications;
  final DateTime updatedAt;

  /// Returns true if any notifications are enabled.
  bool get hasAnyNotificationsEnabled {
    return pushNotificationsEnabled &&
        (newsUpdatesEnabled ||
            magazineUpdatesEnabled ||
            historicalEventsEnabled ||
            promotionalNotificationsEnabled);
  }

  /// Checks if notifications are enabled for a specific category.
  bool isCategoryEnabled(String category) {
    return categoryNotifications[category] ?? true;
  }

  NotificationSettings copyWith({
    String? userId,
    bool? pushNotificationsEnabled,
    bool? newsUpdatesEnabled,
    bool? magazineUpdatesEnabled,
    bool? historicalEventsEnabled,
    bool? promotionalNotificationsEnabled,
    Map<String, bool>? categoryNotifications,
    DateTime? updatedAt,
  }) {
    return NotificationSettings(
      userId: userId ?? this.userId,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      newsUpdatesEnabled: newsUpdatesEnabled ?? this.newsUpdatesEnabled,
      magazineUpdatesEnabled:
          magazineUpdatesEnabled ?? this.magazineUpdatesEnabled,
      historicalEventsEnabled:
          historicalEventsEnabled ?? this.historicalEventsEnabled,
      promotionalNotificationsEnabled:
          promotionalNotificationsEnabled ??
          this.promotionalNotificationsEnabled,
      categoryNotifications:
          categoryNotifications ?? this.categoryNotifications,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettings &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      'NotificationSettings(userId: $userId, pushEnabled: $pushNotificationsEnabled)';
}
