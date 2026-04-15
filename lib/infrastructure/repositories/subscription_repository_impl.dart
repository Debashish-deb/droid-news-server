import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/identity/entitlement_policy.dart';
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/config/premium_plans.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/tts_quota_status.dart';
import '../../domain/facades/auth_facade.dart';
import '../../domain/interfaces/subscription_repository.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../core/utils/url_identity.dart';
import '../services/payment/payment_service.dart';
import '../services/payment/receipt_verification_service.dart'
    show ReceiptVerificationResult;

/// Implementation of SubscriptionRepository using in_app_purchase.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(
    this._prefs,
    this._paymentService,
    this._authService,
    this._premiumRepository,
  );

  final SharedPreferences? _prefs;
  final PaymentService _paymentService;
  final AuthFacade _authService;
  final PremiumRepository _premiumRepository;

  static const String _currentTierKey = 'current_subscription_tier';
  static const String _subscriptionIdKey = 'subscription_id';
  static const String _startDateKey = 'subscription_start_date';
  static const String _endDateKey = 'subscription_end_date';
  static const String _isPremiumKey = 'is_premium';
  static const String _ttsDayKey = 'tts_usage_day';
  static const String _ttsMonthKey = 'tts_usage_month';
  static const String _ttsDailyArticlesKey = 'tts_usage_daily_articles';
  static const String _ttsMonthlyArticlesKey = 'tts_usage_monthly_articles';
  static const String _trialSubscriptionId = 'trial_sub';

  @override
  Future<Either<AppFailure, Subscription>> getCurrentSubscription() async {
    try {
      await _syncPremiumFromTrialState();
      await _premiumRepository.refreshStatus();

      final cached = _getCachedSubscription();
      return await cached.fold((failure) async => Left(failure), (
        subscription,
      ) async {
        final userId = _authService.currentUser?.uid ?? 'anonymous';
        final isPremium = _premiumRepository.isPremium;

        if (!isPremium) {
          // Only wipe if we are absolutely sure (not just during initial bootstrap)
          if (subscription.tier.isPremium &&
              _premiumRepository.isStatusResolved) {
            // await _persistFreeState(); // Removed aggressive wiping
          }
          return Right(_createFreeSubscription(userId: userId));
        }

        final effectiveTier = subscription.tier.isPremium
            ? subscription.tier
            : SubscriptionTier.pro;

        if (!subscription.tier.isPremium) {
          await _persistPremiumTierIfPossible(effectiveTier);
        }

        return Right(
          subscription.copyWith(
            userId: userId,
            tier: effectiveTier,
            status: SubscriptionStatus.active,
            features: _getFeaturesForTier(effectiveTier),
          ),
        );
      });
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('Error getting current subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Map<SubscriptionTier, List<String>>>>
  getAvailableTiers() async {
    try {
      final tiers = <SubscriptionTier, List<String>>{
        SubscriptionTier.free: [
          'All articles and sources',
          'Reader mode',
          'TTS on 5 articles per week',
          'Auto and Dark themes',
          'Ads enabled',
        ],
        SubscriptionTier.pro: [
          'Ad-free experience',
          'All articles and sources',
          'Unlimited TTS',
          'Offline saving',
          'Light, AMOLED, and Desh themes',
          'Lifetime and yearly billing options',
        ],
      };

      return Right(tiers);
    } catch (e, stackTrace) {
      debugPrint('Error getting available tiers: $e');
      return Left(NetworkFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, bool>> canAccessFeature(String featureId) async {
    try {
      final subscriptionResult = await getCurrentSubscription();

      return subscriptionResult.fold(
        (failure) => Left(failure),
        (subscription) => Right(subscription.canAccessFeature(featureId)),
      );
    } catch (e, stackTrace) {
      debugPrint('Error checking feature access: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> upgradeSubscription(
    SubscriptionTier newTier,
  ) async {
    final productId = _getProductIdForTier(newTier);
    if (productId == null) {
      return Left(
        SubscriptionFailure('No purchasable product is mapped for $newTier'),
      );
    }
    return purchasePremiumProduct(productId);
  }

  @override
  Future<Either<AppFailure, Subscription>> purchasePremiumProduct(
    String productId,
  ) async {
    try {
      if (!_paymentService.isPurchaseActivationAvailable) {
        return const Left(
          StoreNotAvailableFailure(
            'Premium purchases are temporarily unavailable while verification backend is offline.',
          ),
        );
      }

      final isAvailable = await _paymentService.isAvailable();
      if (!isAvailable) {
        return const Left(StoreNotAvailableFailure());
      }

      final tier = _getTierFromProductId(productId);
      if (!tier.isPremium) {
        return Left(PurchaseFailure('Unknown product "$productId".'));
      }

      final productResponse = await _paymentService.queryProductDetails({
        productId,
      });

      if (productResponse.productDetails.isEmpty) {
        return Left(
          PurchaseFailure(
            'Product "$productId" is not available in Play Console for this build.',
          ),
        );
      }

      final product = productResponse.productDetails.firstWhere(
        (p) => p.id == productId,
        orElse: () => productResponse.productDetails.first,
      );

      final success = await _paymentService.buyNonConsumable(product);
      if (!success) {
        return const Left(PurchaseFailure('Failed to initiate purchase'));
      }

      return Right(
        _createPendingSubscription(
          tier,
          userId: _authService.currentUser?.uid ?? 'anonymous',
        ),
      );
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('Error upgrading subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> cancelSubscription() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final uri = Uri.https('play.google.com', '/store/account/subscriptions', {
        if (packageInfo.packageName.trim().isNotEmpty)
          'package': packageInfo.packageName.trim(),
      });

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return const Left(
          StoreNotAvailableFailure(
            'Unable to open Play Store subscription management.',
          ),
        );
      }

      return getCurrentSubscription();
    } catch (e, stackTrace) {
      debugPrint('Error cancelling subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> restoreSubscription() async {
    try {
      final isAvailable = await _paymentService.isAvailable();
      if (isAvailable) {
        await _paymentService.restorePurchases();
      }
      await _premiumRepository.refreshStatus();
      return getCurrentSubscription();
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('Error restoring subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>>
  validateAndRefreshSubscription() async {
    try {
      final isAvailable = await _paymentService.isAvailable();
      if (isAvailable) {
        await _paymentService.restorePurchases();
      }
      await _premiumRepository.refreshStatus();
      return getCurrentSubscription();
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('Error validating subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> processStorePurchase(
    PurchaseDetails purchase,
  ) async {
    try {
      if (purchase.status == PurchaseStatus.pending) {
        return Right(
          _createPendingSubscription(
            _getTierFromProductId(purchase.productID),
            userId: _authService.currentUser?.uid ?? 'anonymous',
          ),
        );
      }

      if (purchase.status == PurchaseStatus.canceled) {
        return const Left(PurchaseCancelledFailure());
      }

      if (purchase.status == PurchaseStatus.error) {
        final err = purchase.error;
        return Left(
          PurchaseFailure(err?.message ?? 'Purchase failed.', err?.code),
        );
      }

      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        return const Left(PurchaseFailure('Purchase state not completed'));
      }

      final tier = _getTierFromProductId(purchase.productID);
      if (!tier.isPremium) {
        return Left(PurchaseFailure('Unknown product: ${purchase.productID}'));
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final userId = _authService.currentUser?.uid ?? 'anonymous';
        final verification = await _paymentService.verifyPurchase(
          purchase,
          userId,
        );

        if (verification == ReceiptVerificationResult.backendUnavailable) {
          final alreadyEntitled =
              _premiumRepository.isPremium || _hasLocallyEntitledTier();
          if (purchase.status == PurchaseStatus.restored && alreadyEntitled) {
            // Grace path: preserve existing entitlement without granting new one.
            await _completePendingPurchaseIfNeeded(
              purchase,
              swallowErrors: true,
            );
            return getCurrentSubscription();
          }
          return const Left(
            StoreNotAvailableFailure(
              'Purchase verification service is temporarily unavailable. Please try again later.',
            ),
          );
        }

        if (verification == ReceiptVerificationResult.invalid) {
          return const Left(
            ReceiptValidationFailure('Purchase receipt is invalid.'),
          );
        }
        if (verification == ReceiptVerificationResult.error) {
          return const Left(
            ReceiptValidationFailure(
              'Purchase verification failed due to a backend error.',
            ),
          );
        }
      }

      await _completePendingPurchaseIfNeeded(purchase);

      final prefs = _prefs;
      if (prefs != null) {
        await prefs.setString(_currentTierKey, tier.name);
        await prefs.setBool(_isPremiumKey, true);
        await prefs.setString(
          _subscriptionIdKey,
          purchase.purchaseID ?? purchase.productID,
        );
        await prefs.setString(_startDateKey, DateTime.now().toIso8601String());
        await prefs.remove(_endDateKey);
      }

      await _premiumRepository.setPremium(true);

      return getCurrentSubscription();
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('Error processing purchase: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  Either<AppFailure, Subscription> _getCachedSubscription() {
    try {
      final tierString = _prefs?.getString(_currentTierKey) ?? 'free';
      var tier = _parseTier(tierString);
      final subscriptionId =
          _prefs?.getString(_subscriptionIdKey) ?? 'free_sub';
      final startDateRaw = _prefs?.getString(_startDateKey);
      final endDateRaw = _prefs?.getString(_endDateKey);

      final startDate = DateTime.tryParse(startDateRaw ?? '') ?? DateTime.now();
      final endDate = DateTime.tryParse(endDateRaw ?? '');

      var status = SubscriptionStatus.active;
      if (endDate != null && DateTime.now().isAfter(endDate)) {
        status = SubscriptionStatus.expired;
        if (subscriptionId == _trialSubscriptionId && tier.isPremium) {
          tier = SubscriptionTier.free;
        }
      }

      final subscription = Subscription(
        id: subscriptionId,
        userId: _authService.currentUser?.uid ?? 'anonymous',
        tier: tier,
        status: status,
        startDate: startDate,
        endDate: endDate,
        features: _getFeaturesForTier(tier),
      );

      return Right(subscription);
    } catch (e, stackTrace) {
      debugPrint('Error getting cached subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  Subscription _createFreeSubscription({required String userId}) {
    return Subscription(
      id: 'free_sub',
      userId: userId,
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
      features: _getFeaturesForTier(SubscriptionTier.free),
    );
  }

  Subscription _createPendingSubscription(
    SubscriptionTier tier, {
    required String userId,
  }) {
    return Subscription(
      id: 'pending_${tier.name}',
      userId: userId,
      tier: tier,
      status: SubscriptionStatus.pending,
      startDate: DateTime.now(),
      features: _getFeaturesForTier(tier),
    );
  }

  SubscriptionTier _parseTier(String tierString) {
    final normalized = tierString
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    switch (normalized) {
      case 'pro':
      case 'premium':
      case 'paid':
      case 'yearly':
        return SubscriptionTier.pro;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }

  Future<void> _completePendingPurchaseIfNeeded(
    PurchaseDetails purchase, {
    bool swallowErrors = false,
  }) async {
    if (!purchase.pendingCompletePurchase) {
      return;
    }

    try {
      await _paymentService.completePurchase(purchase);
    } catch (e, stackTrace) {
      if (swallowErrors) {
        debugPrint('Non-fatal purchase completion failure: $e');
        return;
      }
      throw PurchaseFailure(
        'Failed to acknowledge purchase with the store.',
        null,
        stackTrace,
      );
    }
  }

  String? _getProductIdForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.pro:
        return PremiumPlanConfig.proLifetimeProductId;
      case SubscriptionTier.free:
        return null;
    }
  }

  SubscriptionTier _getTierFromProductId(String productId) {
    if (PremiumPlanConfig.primaryProductIds.contains(productId) ||
        PremiumPlanConfig.retiredPremiumProductIds.contains(productId)) {
      return SubscriptionTier.pro;
    }
    return SubscriptionTier.free;
  }

  List<String> _getFeaturesForTier(SubscriptionTier tier) {
    return EntitlementPolicy.featuresForTier(tier);
  }

  @override
  Future<Either<AppFailure, bool>> isTrialEligible() async {
    try {
      if (_authService.currentUser == null) {
        return const Right(false);
      }
      final hasUsed = await _authService.hasUsedTrial();
      return Right(!hasUsed);
    } catch (e, stackTrace) {
      debugPrint('Error checking trial eligibility: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> startTrial() async {
    try {
      if (_authService.currentUser == null) {
        return const Left(
          SubscriptionFailure('Please sign in to start your free trial.'),
        );
      }
      final hasUsedTrial = await _authService.hasUsedTrial();
      if (hasUsedTrial) {
        return const Left(SubscriptionFailure('Trial already used.'));
      }

      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 3));
      await _authService.markTrialUsed(startedAt: startDate, endsAt: endDate);
      final prefs = _prefs;
      if (prefs != null) {
        await prefs.setString(_currentTierKey, 'pro');
        await prefs.setBool(_isPremiumKey, true);
        await prefs.setString(_subscriptionIdKey, _trialSubscriptionId);
        await prefs.setString(_startDateKey, startDate.toIso8601String());
        await prefs.setString(_endDateKey, endDate.toIso8601String());
      }

      await _premiumRepository.setPremium(true);
      return getCurrentSubscription();
    } on StateError catch (e, stackTrace) {
      return Left(SubscriptionFailure(e.message.toString(), stackTrace));
    } catch (e, stackTrace) {
      debugPrint('Error starting trial: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, int>> getTtsUsageMonth() async {
    final quota = await getTtsQuotaStatus();
    return quota.fold(
      (failure) => Left(failure),
      (status) => Right(status.usedMonthlyUniqueArticles),
    );
  }

  @override
  Future<Either<AppFailure, void>> incrementTtsUsage() async {
    return const Right(null);
  }

  @override
  Future<Either<AppFailure, bool>> canUseTts() async {
    final quota = await getTtsQuotaStatus();
    return quota.fold(
      (failure) => Left(failure),
      (status) => Right(status.canStartTts),
    );
  }

  @override
  Future<Either<AppFailure, TtsQuotaStatus>> getTtsQuotaStatus({
    String? articleUrl,
  }) async {
    try {
      final subscriptionResult = await getCurrentSubscription();
      return await subscriptionResult.fold((failure) async => Left(failure), (
        subscription,
      ) async {
        final canonicalArticleId = _canonicalArticleId(articleUrl);
        final usage = await _loadTtsUsage();
        final articleAlreadyCounted =
            canonicalArticleId.isNotEmpty &&
            (usage.dailyArticleIds.contains(canonicalArticleId) ||
                usage.monthlyArticleIds.contains(canonicalArticleId));
        return Right(
          TtsQuotaStatus(
            dayKey: usage.dayKey,
            monthKey: usage.monthKey,
            usedDailyUniqueArticles: usage.dailyArticleIds.length,
            usedMonthlyUniqueArticles: usage.monthlyArticleIds.length,
            dailyLimit: EntitlementPolicy.freeTtsDailyArticleLimit,
            monthlyLimit: EntitlementPolicy.freeTtsMonthlyArticleLimit,
            isPremium: subscription.tier.isPremium,
            articleAlreadyCounted: articleAlreadyCounted,
          ),
        );
      });
    } catch (e, stackTrace) {
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, void>> recordTtsArticleUsage(
    String articleUrl,
  ) async {
    try {
      final quotaResult = await getTtsQuotaStatus(articleUrl: articleUrl);
      return await quotaResult.fold((failure) async => Left(failure), (
        status,
      ) async {
        if (status.isPremium || status.articleAlreadyCounted) {
          return const Right(null);
        }
        if (!status.canStartTts) {
          return const Left(
            SubscriptionFailure(
              'Free TTS limit reached for today or this month.',
            ),
          );
        }
        final canonicalArticleId = _canonicalArticleId(articleUrl);
        await _persistTtsArticleId(
          dayKey: status.dayKey,
          monthKey: status.monthKey,
          canonicalArticleId: canonicalArticleId,
        );
        return const Right(null);
      });
    } catch (e, stackTrace) {
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  Future<
    ({
      String dayKey,
      String monthKey,
      Set<String> dailyArticleIds,
      Set<String> monthlyArticleIds,
    })
  >
  _loadTtsUsage() async {
    final now = DateTime.now();
    final dayKey = _dayKey(now);
    final monthKey = _monthKey(now);
    final user = _authService.currentUser;

    if (user != null && !user.isAnonymous) {
      final doc = await FirebaseFirestore.instance
          .collection('user_usage')
          .doc(user.uid)
          .get();
      if (!doc.exists) {
        return (
          dayKey: dayKey,
          monthKey: monthKey,
          dailyArticleIds: <String>{},
          monthlyArticleIds: <String>{},
        );
      }
      final data = doc.data() ?? const <String, dynamic>{};
      final storedDay = (data['ttsDay'] as String?) ?? '';
      final storedMonth = (data['ttsMonth'] as String?) ?? '';
      final dailyArticles = storedDay == dayKey
          ? _stringSetFromDynamicList(data['ttsDailyArticleIds'])
          : <String>{};
      final monthlyArticles = storedMonth == monthKey
          ? _stringSetFromDynamicList(data['ttsMonthlyArticleIds'])
          : <String>{};
      return (
        dayKey: dayKey,
        monthKey: monthKey,
        dailyArticleIds: dailyArticles,
        monthlyArticleIds: monthlyArticles,
      );
    }

    final prefs = _prefs;
    if (prefs == null) {
      return (
        dayKey: dayKey,
        monthKey: monthKey,
        dailyArticleIds: <String>{},
        monthlyArticleIds: <String>{},
      );
    }

    final storedDay = prefs.getString(_ttsDayKey);
    final storedMonth = prefs.getString(_ttsMonthKey);
    if (storedDay != dayKey) {
      await prefs.setString(_ttsDayKey, dayKey);
      await prefs.setStringList(_ttsDailyArticlesKey, const <String>[]);
    }
    if (storedMonth != monthKey) {
      await prefs.setString(_ttsMonthKey, monthKey);
      await prefs.setStringList(_ttsMonthlyArticlesKey, const <String>[]);
    }

    final dailyArticles = storedDay == dayKey
        ? _stringSetFromList(prefs.getStringList(_ttsDailyArticlesKey))
        : <String>{};
    final monthlyArticles = storedMonth == monthKey
        ? _stringSetFromList(prefs.getStringList(_ttsMonthlyArticlesKey))
        : <String>{};
    return (
      dayKey: dayKey,
      monthKey: monthKey,
      dailyArticleIds: dailyArticles,
      monthlyArticleIds: monthlyArticles,
    );
  }

  Future<void> _persistTtsArticleId({
    required String dayKey,
    required String monthKey,
    required String canonicalArticleId,
  }) async {
    if (canonicalArticleId.isEmpty) {
      return;
    }

    final user = _authService.currentUser;
    if (user != null && !user.isAnonymous) {
      final docRef = FirebaseFirestore.instance
          .collection('user_usage')
          .doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        final data = snapshot.data() ?? const <String, dynamic>{};
        final storedDay = (data['ttsDay'] as String?) ?? '';
        final storedMonth = (data['ttsMonth'] as String?) ?? '';
        final dailyIds = storedDay == dayKey
            ? _stringSetFromDynamicList(data['ttsDailyArticleIds'])
            : <String>{};
        final monthlyIds = storedMonth == monthKey
            ? _stringSetFromDynamicList(data['ttsMonthlyArticleIds'])
            : <String>{};
        dailyIds.add(canonicalArticleId);
        monthlyIds.add(canonicalArticleId);
        tx.set(docRef, <String, dynamic>{
          'ttsDay': dayKey,
          'ttsMonth': monthKey,
          'ttsDailyArticleIds': dailyIds.toList(),
          'ttsMonthlyArticleIds': monthlyIds.toList(),
        }, SetOptions(merge: true));
      });
      return;
    }

    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final usage = await _loadTtsUsage();
    final nextDailyIds = Set<String>.from(usage.dailyArticleIds)
      ..add(canonicalArticleId);
    final nextMonthlyIds = Set<String>.from(usage.monthlyArticleIds)
      ..add(canonicalArticleId);
    await prefs.setString(_ttsDayKey, dayKey);
    await prefs.setString(_ttsMonthKey, monthKey);
    await prefs.setStringList(_ttsDailyArticlesKey, nextDailyIds.toList());
    await prefs.setStringList(_ttsMonthlyArticlesKey, nextMonthlyIds.toList());
  }

  String _canonicalArticleId(String? articleUrl) {
    final normalized = UrlIdentity.canonicalize(articleUrl ?? '');
    return normalized.isEmpty ? '' : normalized;
  }

  Set<String> _stringSetFromDynamicList(Object? rawList) {
    return (rawList as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Set<String> _stringSetFromList(List<String>? rawList) {
    return (rawList ?? const <String>[])
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  String _dayKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _monthKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}';
  }

  Future<void> _syncPremiumFromTrialState() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final subscriptionId = prefs.getString(_subscriptionIdKey);
    if (subscriptionId != _trialSubscriptionId) return;

    final trialEndRaw = prefs.getString(_endDateKey);
    final trialEnd = DateTime.tryParse(trialEndRaw ?? '');
    if (trialEnd == null) return;

    if (DateTime.now().isAfter(trialEnd)) {
      await _persistFreeState();
      await _premiumRepository.setPremium(false);
    }
  }

  Future<void> _persistPremiumTierIfPossible(SubscriptionTier tier) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_currentTierKey, tier.name);
    await prefs.setBool(_isPremiumKey, true);
  }

  Future<void> _persistFreeState() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_currentTierKey, 'free');
    await prefs.setBool(_isPremiumKey, false);
    await prefs.remove(_subscriptionIdKey);
    await prefs.remove(_startDateKey);
    await prefs.remove(_endDateKey);
  }

  bool _hasLocallyEntitledTier() {
    final prefs = _prefs;
    if (prefs == null) return false;
    final tier = prefs.getString(_currentTierKey) ?? '';
    final normalized = tier
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    return (prefs.getBool(_isPremiumKey) ?? false) ||
        normalized.contains('pro') ||
        normalized.contains('premium') ||
        normalized.contains('paid') ||
        normalized.contains('yearly');
  }

  /// Dispose resources
  void dispose() {
    _paymentService.dispose();
  }
}
