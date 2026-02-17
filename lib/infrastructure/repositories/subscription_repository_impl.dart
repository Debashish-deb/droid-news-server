// lib/infrastructure/repositories/subscription_repository_impl.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/interfaces/subscription_repository.dart' show SubscriptionRepository;
import '../../domain/interfaces/subscription_repository.dart';
import '../services/payment_service.dart';
import '../../domain/facades/auth_facade.dart';

/// Implementation of SubscriptionRepository using in_app_purchase.

class SubscriptionRepositoryImpl implements SubscriptionRepository {

  SubscriptionRepositoryImpl(
    this._prefs,
    this._paymentService,
    this._authService,
  );
  final SharedPreferences _prefs;
  final PaymentService _paymentService;
  final AuthFacade _authService;

  static const String _removeAdsProductId = 'remove_ads';
  static const String _proProductId = 'pro_subscription';
  static const String _proPlusProductId = 'pro_plus_subscription';

  static const String _currentTierKey = 'current_subscription_tier';
  static const String _subscriptionIdKey = 'subscription_id';
  static const String _startDateKey = 'subscription_start_date';
  static const String _endDateKey = 'subscription_end_date';
  static const String _isPremiumKey = 'is_premium';

  @override
  Future<Either<AppFailure, Subscription>> getCurrentSubscription() async {
    try {
      final isAvailable = await _paymentService.isAvailable();
      if (!isAvailable) {
        return const Left(StoreNotAvailableFailure());
      }

      final isPremium = _prefs.getBool(_isPremiumKey) ?? false;

      if (isPremium) {
        final validationResult = await validateAndRefreshSubscription();
        return validationResult;
      }

      return Right(_createFreeSubscription());
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting current subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
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
      debugPrint('❌ Error checking feature access: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> upgradeSubscription(
    SubscriptionTier newTier,
  ) async {
    try {
      final isAvailable = await _paymentService.isAvailable();
      if (!isAvailable) {
        return const Left(StoreNotAvailableFailure());
      }

      final productId = _getProductIdForTier(newTier);
      if (productId == null) {
        return Left(
          SubscriptionFailure('No product available for tier: $newTier'),
        );
      }

      final productResponse = await _paymentService.queryProductDetails({
        productId,
      });

      if (productResponse.productDetails.isEmpty) {
        return Left(SubscriptionFailure('Product not found: $productId'));
      }

      final product = productResponse.productDetails.first;

      final success = await _paymentService.buyNonConsumable(product);

      if (!success) {
        return const Left(PurchaseFailure('Failed to initiate purchase'));
      }

      return Right(_createPendingSubscription(newTier));
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('❌ Error upgrading subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> cancelSubscription() async {
    try {

      await _prefs.setString(_currentTierKey, 'free');
      await _prefs.setBool(_isPremiumKey, false);

      return Right(_createFreeSubscription());
    } catch (e, stackTrace) {
      debugPrint('❌ Error cancelling subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> restoreSubscription() async {
    try {
      final isAvailable = await _paymentService.isAvailable();
      if (!isAvailable) {
        return const Left(StoreNotAvailableFailure());
      }

      await _paymentService.restorePurchases();

      return await getCurrentSubscription();
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('❌ Error restoring subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Map<SubscriptionTier, List<String>>>>
  getAvailableTiers() async {
    try {
      final Map<SubscriptionTier, List<String>> tiers = {
        SubscriptionTier.free: ['Basic news feed', 'Limited articles'],
        SubscriptionTier.pro: [
          'Ad-free experience',
          'Offline reading',
          'Unlimited articles',
          'Dark mode themes',
        ],
        SubscriptionTier.proPlus: [
          'Everything in Pro',
          'Premium sources',
          'AI summaries',
          'Priority support',
          'Early access features',
        ],
      };

      return Right(tiers);
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting available tiers: $e');
      return Left(NetworkFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>>
  validateAndRefreshSubscription() async {
    try {
      final isAvailable = await _paymentService.isAvailable();
      if (!isAvailable) {
        return _getCachedSubscription();
      }

      await _paymentService.restorePurchases();

      return _getCachedSubscription();
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('❌ Error validating subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  /// Process purchase details and update subscription
  Future<Either<AppFailure, Subscription>> processPurchase(
    PurchaseDetails purchase,
  ) async {
    try {
      final userId = _authService.currentUser?.uid ?? 'anonymous';
      final isValid = await _paymentService.verifyPurchase(purchase, userId);
      if (!isValid) {
        return const Left(ReceiptValidationFailure('Purchase verification failed'));
      }

      final tier = _getTierFromProductId(purchase.productID);

      await _prefs.setString(_currentTierKey, tier.name);
      await _prefs.setBool(_isPremiumKey, tier.isPremium);
      await _prefs.setString(_subscriptionIdKey, purchase.purchaseID ?? '');
      await _prefs.setString(_startDateKey, DateTime.now().toIso8601String());

      if (purchase.pendingCompletePurchase) {
        await _paymentService.completePurchase(purchase);
      }

      return _getCachedSubscription();
    } on AppFailure catch (e) {
      return Left(e);
    } catch (e, stackTrace) {
      debugPrint('❌ Error processing purchase: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  /// Helper: Get cached subscription from SharedPreferences
  Either<AppFailure, Subscription> _getCachedSubscription() {
    try {
      final tierString = _prefs.getString(_currentTierKey) ?? 'free';
      final tier = _parseTier(tierString);
      final subscriptionId = _prefs.getString(_subscriptionIdKey) ?? 'free_sub';
      final startDateString = _prefs.getString(_startDateKey);
      final startDate =
          startDateString != null
              ? DateTime.parse(startDateString)
              : DateTime.now();

      final subscription = Subscription(
        id: subscriptionId,
        userId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
        tier: tier,
        status: SubscriptionStatus.active,
        startDate: startDate,
        features: _getFeaturesForTier(tier),
      );

      return Right(subscription);
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting cached subscription: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  /// Helper: Create free subscription
  Subscription _createFreeSubscription() {
    return Subscription(
      id: 'free_sub',
      userId: 'current_user',
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
      features: _getFeaturesForTier(SubscriptionTier.free),
    );
  }

  /// Helper: Create pending subscription
  Subscription _createPendingSubscription(SubscriptionTier tier) {
    return Subscription(
      id: 'pending_${tier.name}',
      userId: 'current_user',
      tier: tier,
      status: SubscriptionStatus.pending,
      startDate: DateTime.now(),
      features: _getFeaturesForTier(tier),
    );
  }

  /// Helper: Parse tier from string
  SubscriptionTier _parseTier(String tierString) {
    switch (tierString.toLowerCase()) {
      case 'pro':
        return SubscriptionTier.pro;
      case 'proplus':
      case 'pro_plus':
        return SubscriptionTier.proPlus;
      default:
        return SubscriptionTier.free;
    }
  }

  /// Helper: Get product ID for tier
  String? _getProductIdForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.pro:
        return _removeAdsProductId; 
      case SubscriptionTier.proPlus:
        return _proPlusProductId;
      case SubscriptionTier.free:
        return null;
    }
  }

  /// Helper: Get tier from product ID
  SubscriptionTier _getTierFromProductId(String productId) {
    switch (productId) {
      case _removeAdsProductId:
      case _proProductId:
        return SubscriptionTier.pro;
      case _proPlusProductId:
        return SubscriptionTier.proPlus;
      default:
        return SubscriptionTier.free;
    }
  }

  /// Helper: Get features for tier
  List<String> _getFeaturesForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return ['basic_feed', 'limited_articles'];
      case SubscriptionTier.pro:
        return [
          'ad_free',
          'offline_reading',
          'unlimited_articles',
          'dark_mode',
        ];
      case SubscriptionTier.proPlus:
        return [
          'ad_free',
          'offline_reading',
          'unlimited_articles',
          'dark_mode',
          'premium_sources',
          'ai_summaries',
          'priority_support',
        ];
    }
  }

  @override
  Future<Either<AppFailure, bool>> isTrialEligible() async {
    try {
      final hasUsed = await _authService.hasUsedTrial() ?? false;
      return Right(!hasUsed);
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking trial eligibility: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  @override
  Future<Either<AppFailure, Subscription>> startTrial() async {
    try {
      final eligible = !(await _authService.hasUsedTrial() ?? true);
      if (eligible) {
         return const Left(SubscriptionFailure('Trial already used'));
      }

      await _authService.markTrialUsed();

      final startDate = DateTime.now();
      await _prefs.setString(_currentTierKey, 'pro');
      await _prefs.setBool(_isPremiumKey, true);
      await _prefs.setString(_subscriptionIdKey, 'trial_sub');
      await _prefs.setString(_startDateKey, startDate.toIso8601String());
      await _prefs.setString(_endDateKey, startDate.add(const Duration(days: 3)).toIso8601String());

      return _getCachedSubscription();
    } catch (e, stackTrace) {
      debugPrint('❌ Error starting trial: $e');
      return Left(SubscriptionFailure(e.toString(), stackTrace));
    }
  }

  /// Dispose resources
  void dispose() {
    _paymentService.dispose();
  }
}