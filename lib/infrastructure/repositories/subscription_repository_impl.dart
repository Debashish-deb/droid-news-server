import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/config/premium_plans.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/facades/auth_facade.dart';
import '../../domain/interfaces/subscription_repository.dart';
import '../../domain/repositories/premium_repository.dart';
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
  static const String _ttsUsageKey = 'tts_usage_count';
  static const String _ttsMonthKey = 'tts_usage_month';
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
          if (subscription.tier.isPremium && _premiumRepository.isStatusResolved) {
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
          'Basic news feed',
          'Limited articles',
          'TTS (5/month)',
        ],
        SubscriptionTier.pro: [
          'Ad-free experience',
          'Unlimited articles',
          'Unlimited TTS',
          'Offline reading',
          'Dark mode themes',
          'Premium sources',
          'One-time purchase',
        ],
        SubscriptionTier.proPlus: [
          'Ad-free experience',
          'Unlimited articles',
          'Unlimited TTS',
          'Offline reading',
          'Dark mode themes',
          'Premium sources',
          'AI summaries',
          'Priority support',
          'Yearly plan',
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

      final productId = _getProductIdForTier(newTier);
      if (productId == null) {
        return Left(
          SubscriptionFailure('No purchasable product is mapped for $newTier'),
        );
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
          newTier,
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
  Future<Either<AppFailure, void>> upgradeWithGooglePay({
    required SubscriptionTier tier,
    required String paymentToken,
  }) async {
    try {
      if (!_paymentService.isPurchaseActivationAvailable) {
        return const Left(
          StoreNotAvailableFailure(
            'Premium purchases are temporarily unavailable while verification backend is offline.',
          ),
        );
      }
      final user = _authService.currentUser;
      if (user == null) {
        return const Left(AuthFailure('User not authenticated'));
      }

      await _paymentService.processGooglePayPayment(
        psp: 'stripe',
        total: tier == SubscriptionTier.proPlus ? 1.99 : 6.99,
        currency: 'EUR',
        paymentToken: paymentToken,
        userId: user.uid,
      );

      final prefs = _prefs;
      if (prefs != null) {
        await prefs.setString(_currentTierKey, tier.name);
        await prefs.setBool(_isPremiumKey, true); // Changed from false to true
        await prefs.setString(
          _subscriptionIdKey,
          'gpay_pending_${DateTime.now().millisecondsSinceEpoch}',
        );
        await prefs.setString(_startDateKey, DateTime.now().toIso8601String());
        await prefs.remove(_endDateKey);
      }
      // Fixed: Actually set to true in Firestore instead of refreshing and getting back 'false'
      await _premiumRepository.setPremium(true);

      return const Right(null);
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('Error upgrading with Google Pay: $e');
      return Left(PurchaseFailure(e.toString(), null, stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> cancelSubscription() async {
    try {
      await _persistFreeState();
      await _premiumRepository.setPremium(false);
      return Right(
        _createFreeSubscription(
          userId: _authService.currentUser?.uid ?? 'anonymous',
        ),
      );
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

      if (purchase.pendingCompletePurchase) {
        await _paymentService.completePurchase(purchase);
      }

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
    final normalized = tierString.trim().toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    if (normalized.contains('proplus') || normalized.contains('yearly')) {
      return SubscriptionTier.proPlus;
    }
    if (normalized.contains('pro') || normalized.contains('premium') || normalized.contains('paid')) {
      return SubscriptionTier.pro;
    }
    return SubscriptionTier.free;
  }

  String? _getProductIdForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.pro:
        return PremiumPlanConfig.proLifetimeProductId;
      case SubscriptionTier.proPlus:
        return PremiumPlanConfig.proYearlyProductId;
      case SubscriptionTier.free:
        return null;
    }
  }

  SubscriptionTier _getTierFromProductId(String productId) {
    switch (productId) {
      case PremiumPlanConfig.proLifetimeProductId:
      case PremiumPlanConfig.legacyRemoveAdsProductId:
      case PremiumPlanConfig.legacyProProductId:
        return SubscriptionTier.pro;
      case PremiumPlanConfig.proYearlyProductId:
      case PremiumPlanConfig.legacyProPlusProductId:
        return SubscriptionTier.proPlus;
      default:
        return SubscriptionTier.free;
    }
  }

  List<String> _getFeaturesForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return ['basic_feed', 'limited_articles', 'tts_limit_5'];
      case SubscriptionTier.pro:
        return [
          'ad_free',
          'offline_reading',
          'unlimited_articles',
          'unlimited_tts',
          'premium_sources',
        ];
      case SubscriptionTier.proPlus:
        return [
          'ad_free',
          'offline_reading',
          'unlimited_articles',
          'unlimited_tts',
          'premium_sources',
          'ai_summaries',
          'bulk_export',
        ];
    }
  }

  @override
  Future<Either<AppFailure, bool>> isTrialEligible() async {
    try {
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
      final hasUsedTrial = await _authService.hasUsedTrial();
      if (hasUsedTrial) {
        return const Left(SubscriptionFailure('Trial already used'));
      }

      await _authService.markTrialUsed();

      final startDate = DateTime.now();
      final endDate = startDate.add(const Duration(days: 3));
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
    } catch (e, stackTrace) {
      debugPrint('Error starting trial: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, int>> getTtsUsageMonth() async {
    try {
      final user = _authService.currentUser;
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      if (user != null && !user.isAnonymous) {
        final doc = await FirebaseFirestore.instance.collection('user_usage').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data['ttsMonth'] == currentMonth) {
             return Right((data['ttsUsage'] as num?)?.toInt() ?? 0);
          }
        }
        return const Right(0);
      }

      final prefs = _prefs;
      if (prefs == null) return const Right(0);
      final storedMonth = prefs.getString(_ttsMonthKey);

      if (storedMonth != currentMonth) {
        await prefs.setString(_ttsMonthKey, currentMonth);
        await prefs.setInt(_ttsUsageKey, 0);
        return const Right(0);
      }

      return Right(prefs.getInt(_ttsUsageKey) ?? 0);
    } catch (e, stackTrace) {
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, void>> incrementTtsUsage() async {
    try {
      final user = _authService.currentUser;
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      if (user != null && !user.isAnonymous) {
         final docRef = FirebaseFirestore.instance.collection('user_usage').doc(user.uid);
         await FirebaseFirestore.instance.runTransaction((tx) async {
           final doc = await tx.get(docRef);
           if (doc.exists && doc.data()?['ttsMonth'] == currentMonth) {
             final currentUsage = (doc.data()?['ttsUsage'] as num?)?.toInt() ?? 0;
             tx.update(docRef, {'ttsUsage': currentUsage + 1});
           } else {
             tx.set(docRef, {'ttsMonth': currentMonth, 'ttsUsage': 1});
           }
         });
         return const Right(null);
      }

      final prefs = _prefs;
      if (prefs == null) return const Right(null);
      final usageResult = await getTtsUsageMonth();
      final usage = usageResult.fold((_) => 0, (r) => r);
      await prefs.setInt(_ttsUsageKey, usage + 1);
      return const Right(null);
    } catch (e, stackTrace) {
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, bool>> canUseTts() async {
    try {
      final subResult = await getCurrentSubscription();

      return subResult.fold((l) => Left(l), (sub) async {
        if (sub.features.contains('unlimited_tts')) {
          return const Right(true);
        }

        final usageResult = await getTtsUsageMonth();
        return usageResult.fold((l) => Left(l), (usage) => Right(usage < 5));
      });
    } catch (e, stackTrace) {
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
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
