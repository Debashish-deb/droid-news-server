class TtsQuotaStatus {
  const TtsQuotaStatus({
    required this.dayKey,
    required this.monthKey,
    required this.usedDailyUniqueArticles,
    required this.usedMonthlyUniqueArticles,
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.isPremium,
    this.articleAlreadyCounted = false,
  });

  final String dayKey;
  final String monthKey;
  final int usedDailyUniqueArticles;
  final int usedMonthlyUniqueArticles;
  final int dailyLimit;
  final int monthlyLimit;
  final bool isPremium;
  final bool articleAlreadyCounted;

  int get remainingDailyArticles {
    if (isPremium) {
      return dailyLimit;
    }
    final remaining = dailyLimit - usedDailyUniqueArticles;
    return remaining < 0 ? 0 : remaining;
  }

  int get remainingMonthlyArticles {
    if (isPremium) {
      return monthlyLimit;
    }
    final remaining = monthlyLimit - usedMonthlyUniqueArticles;
    return remaining < 0 ? 0 : remaining;
  }

  int get remainingArticles {
    if (isPremium) {
      return monthlyLimit;
    }
    final remaining = remainingDailyArticles < remainingMonthlyArticles
        ? remainingDailyArticles
        : remainingMonthlyArticles;
    return remaining < 0 ? 0 : remaining;
  }

  bool get canStartTts {
    return isPremium ||
        articleAlreadyCounted ||
        (usedDailyUniqueArticles < dailyLimit &&
            usedMonthlyUniqueArticles < monthlyLimit);
  }
}
