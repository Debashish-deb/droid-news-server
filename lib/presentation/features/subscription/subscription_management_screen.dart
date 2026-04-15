import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/config/premium_plans.dart';

import '../../../core/architecture/either.dart';
import '../../../core/architecture/failure.dart';
import '../../../domain/entities/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/error_widget.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/theme.dart';
import '../../widgets/premium_screen_header.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────

// ─── Design Tokens ──────────────────────────────────────────────────────────

extension _CtxColors on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}

class _TierColors {
  // Tier accents (Gradients not in main theme)
  static const freeStart = Color(0xFF3A3A52);
  static const freeEnd = Color(0xFF252538);
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class SubscriptionManagementScreen extends ConsumerStatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  ConsumerState<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends ConsumerState<SubscriptionManagementScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Subscription? _subscription;
  AppFailure? _error;
  Map<SubscriptionTier, List<String>>? _availableTiers;
  String _proLifetimePrice = PremiumPlanConfig.proLifetimeDisplayPrice;
  String _proYearlyPrice = PremiumPlanConfig.proYearlyDisplayPrice;
  bool _isTrialEligible = false;
  SubscriptionTier? _actionLoading;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  late final AnimationController _entryController;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );

    _loadSubscriptionInfo();
    _listenToPurchaseUpdates();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _entryController.reset();

    final repository = ref.read(subscriptionRepositoryProvider);
    final results = await Future.wait<dynamic>([
      repository.getCurrentSubscription(),
      repository.getAvailableTiers(),
      repository.isTrialEligible(),
      _resolvePlanPrices(),
    ]);

    final subResult = results[0] as Either<AppFailure, Subscription>;
    final tiersResult =
        results[1] as Either<AppFailure, Map<SubscriptionTier, List<String>>>;
    final trialResult = results[2] as Either<AppFailure, bool>;
    final planPrices = results[3] as ({String lifetime, String yearly});

    if (mounted) {
      setState(() {
        _isLoading = false;
        subResult.fold((f) => _error = f, (s) => _subscription = s);
        tiersResult.fold((f) => _error ??= f, (t) => _availableTiers = t);
        trialResult.fold((f) => null, (e) => _isTrialEligible = e);
        _proLifetimePrice = planPrices.lifetime;
        _proYearlyPrice = planPrices.yearly;
      });
      _entryController.forward();
    }
  }

  Future<({String lifetime, String yearly})> _resolvePlanPrices() async {
    var lifetime = PremiumPlanConfig.proLifetimeDisplayPrice;
    var yearly = PremiumPlanConfig.proYearlyDisplayPrice;

    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        return (lifetime: lifetime, yearly: yearly);
      }

      final response = await iap.queryProductDetails(
        PremiumPlanConfig.primaryProductIds,
      );
      for (final product in response.productDetails) {
        if (product.id == PremiumPlanConfig.proLifetimeProductId) {
          lifetime = product.price;
        } else if (product.id == PremiumPlanConfig.proYearlyProductId) {
          yearly = product.price;
        }
      }
    } catch (_) {
      // Keep deterministic fallback pricing labels when Store query fails.
    }

    return (lifetime: lifetime, yearly: yearly);
  }

  void _listenToPurchaseUpdates() {
    _purchaseSub?.cancel();
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      (purchases) async {
        var shouldReload = false;
        for (final purchase in purchases) {
          if (purchase.status == PurchaseStatus.pending) {
            shouldReload = true;
            continue;
          }

          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            shouldReload = true;
            continue;
          }

          if (purchase.status == PurchaseStatus.error) {
            final message =
                purchase.error?.message ?? 'Purchase could not be completed.';
            if (mounted) {
              _showSnack(message, isError: true);
            }
          }
        }

        if (mounted && shouldReload) {
          final purchaseSuccessMessage = AppLocalizations.of(
            context,
          ).purchaseSuccess;
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          await _loadSubscriptionInfo();
          if (_subscription?.tier.isPremium == true) {
            _showSnack(purchaseSuccessMessage);
          }
        }
      },
      onError: (e) {
        if (mounted) {
          _showSnack('Purchase stream error: $e', isError: true);
        }
      },
    );
  }

  Future<void> _buyPremiumProduct(String productId) async {
    setState(() => _actionLoading = SubscriptionTier.pro);
    final result = await ref
        .read(subscriptionRepositoryProvider)
        .purchasePremiumProduct(productId);
    if (!mounted) return;

    result.fold(
      (f) {
        setState(() => _actionLoading = null);
        _showSnack(f.userMessage, isError: true);
      },
      (s) {
        setState(() {
          _subscription = s;
          _actionLoading = null;
        });
        _showSnack(
          AppLocalizations.of(
            context,
          ).upgradeInitiated(SubscriptionTier.pro.displayName),
        );
      },
    );
  }

  Future<void> _startTrial() async {
    setState(() => _actionLoading = SubscriptionTier.pro);
    final result = await ref.read(subscriptionRepositoryProvider).startTrial();
    if (!mounted) return;

    result.fold(
      (f) {
        setState(() => _actionLoading = null);
        _showSnack(f.userMessage, isError: true);
      },
      (s) {
        setState(() {
          _subscription = s;
          _actionLoading = null;
          _isTrialEligible = false;
        });
        _showSnack(AppLocalizations.of(context).freeTrialStarted);
        _loadSubscriptionInfo();
      },
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final purchaseActivationAvailable = ref.watch(
      purchaseActivationAvailableProvider,
    );

    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: PremiumScreenHeader(title: loc.manageSubscription),
      body: _buildBody(loc, purchaseActivationAvailable),
    );
  }

  Widget _buildBody(AppLocalizations loc, bool purchaseActivationAvailable) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colors.goldStart,
          strokeWidth: 2,
        ),
      );
    }
    if (_error != null) {
      return SafeArea(
        child: ErrorDisplay(error: _error!, onRetry: _loadSubscriptionInfo),
      );
    }
    if (_subscription == null) {
      return Center(
        child: Text(
          loc.noSubscriptionInfo,
          style: TextStyle(color: context.colors.textSecondary),
        ),
      );
    }

    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: RefreshIndicator(
          color: context.colors.goldStart,
          backgroundColor: context.colors.card,
          onRefresh: _loadSubscriptionInfo,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // top spacing for app bar
              const SliverToBoxAdapter(child: SizedBox(height: 116)),

              // ── Current Plan Hero ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _CurrentPlanHero(subscription: _subscription!),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // ── Section Label ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _SectionLabel(
                    label: AppLocalizations.of(context).availablePlans,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (!purchaseActivationAvailable)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'Purchases are temporarily disabled until receipt verification backend is available.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),

              // ── Plan Cards ──
              if (_availableTiers != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((ctx, i) {
                      final entry = _availableTiers!.entries.elementAt(i);
                      return _PlanCard(
                        tier: entry.key,
                        features: entry.value,
                        priceLabel: entry.key == SubscriptionTier.pro
                            ? _proLifetimePrice
                            : '',
                        secondaryPriceLabel: entry.key == SubscriptionTier.pro
                            ? _proYearlyPrice
                            : null,
                        isCurrent: entry.key == _subscription!.tier,
                        isTrialEligible: _isTrialEligible,
                        isLoading: _actionLoading == entry.key,
                        purchaseActivationAvailable:
                            purchaseActivationAvailable,
                        onUpgrade: () => _buyPremiumProduct(
                          PremiumPlanConfig.proLifetimeProductId,
                        ),
                        onSecondaryUpgrade: () => _buyPremiumProduct(
                          PremiumPlanConfig.proYearlyProductId,
                        ),
                        onTrial: _startTrial,
                      );
                    }, childCount: _availableTiers!.length),
                  ),
                ),

              // ── Debug strip (debug only) ──
              if (kDebugMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        '⚙ ${FirebaseAuth.instance.currentUser?.email} · '
                        '${_subscription?.tier.name}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Current Plan Hero Card ───────────────────────────────────────────────────

class _CurrentPlanHero extends StatelessWidget {
  const _CurrentPlanHero({required this.subscription});
  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final tier = subscription.tier;
    final colors = _tierGradient(context, tier);
    final isPro = tier != SubscriptionTier.free;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: isPro
            ? [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Stack(
        children: [
          // Decorative shimmer circle
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _tierIcon(tier),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(isActive: subscription.isActive),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).currentPlan,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tier.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                if (subscription.features.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subscription.features
                        .take(4)
                        .map(
                          (f) => _FeaturePill(
                            label: _formatFeature(f),
                            light: true,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: context.colors.textHint,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.features,
    required this.priceLabel,
    required this.isCurrent,
    required this.isTrialEligible,
    required this.isLoading,
    required this.purchaseActivationAvailable,
    required this.onUpgrade,
    required this.onTrial,
    this.secondaryPriceLabel,
    this.onSecondaryUpgrade,
  });

  final SubscriptionTier tier;
  final List<String> features;
  final String priceLabel;
  final String? secondaryPriceLabel;
  final bool isCurrent;
  final bool isTrialEligible;
  final bool isLoading;
  final bool purchaseActivationAvailable;
  final VoidCallback onUpgrade;
  final VoidCallback? onSecondaryUpgrade;
  final VoidCallback onTrial;

  @override
  Widget build(BuildContext context) {
    final isPro = tier == SubscriptionTier.pro;
    final accent = isPro ? context.colors.proBlue : context.colors.textHint;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isCurrent
                ? accent.withValues(alpha: 0.5)
                : context.colors.cardBorder,
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_tierIcon(tier), color: accent, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tier.displayName,
                      style: TextStyle(
                        color: isCurrent ? accent : context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (tier.isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      child: Text(
                        priceLabel,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (isCurrent) _CurrentBadge(accent: accent),
                ],
              ),

              if (features.isNotEmpty) ...[
                const SizedBox(height: 16),
                // ── Features ── (compact grid of pills)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: features
                      .map(
                        (f) => _FeaturePill(
                          label: _formatFeature(f),
                          accent: accent,
                        ),
                      )
                      .toList(),
                ),
              ],

              // ── CTA ──
              if (!isCurrent && tier.isPremium) ...[
                const SizedBox(height: 16),
                _CTAButton(
                  label: 'Premium Lifetime · $priceLabel',
                  isLoading: isLoading,
                  accent: accent,
                  onTap: purchaseActivationAvailable ? onUpgrade : null,
                ),
                if (secondaryPriceLabel != null) ...[
                  const SizedBox(height: 8),
                  _CTAButton(
                    label: 'Premium Yearly · ${secondaryPriceLabel!}',
                    isLoading: isLoading,
                    accent: accent,
                    onTap: purchaseActivationAvailable
                        ? onSecondaryUpgrade
                        : null,
                  ),
                ],
                if (isTrialEligible && tier == SubscriptionTier.pro) ...[
                  const SizedBox(height: 8),
                  Align(
                    child: TextButton.icon(
                      onPressed: (!purchaseActivationAvailable || isLoading)
                          ? null
                          : onTrial,
                      icon: Icon(Icons.stars_rounded, size: 16, color: accent),
                      label: Text(
                        AppLocalizations.of(context).startFreeTrial,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CTA Button ──────────────────────────────────────────────────────────────

class _CTAButton extends StatelessWidget {
  const _CTAButton({
    required this.label,
    required this.isLoading,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: accent.withValues(alpha: 0.15),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: TextButton(
          onPressed: isLoading ? null : onTap,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Small Widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? context.colors.successGreen.withValues(alpha: 0.18)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(
          color: isActive
              ? context.colors.successGreen.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? context.colors.successGreen : Colors.grey,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? AppLocalizations.of(context).active : 'Inactive',
            style: TextStyle(
              color: isActive ? context.colors.successGreen : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        AppLocalizations.of(context).current,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label, this.accent, this.light = false});
  final String label;
  final Color? accent;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.12)
            : (accent ?? context.colors.textHint).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 12,
            color: light
                ? Colors.white.withValues(alpha: 0.8)
                : (accent ?? context.colors.textSecondary),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: light
                  ? Colors.white.withValues(alpha: 0.85)
                  : context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

List<Color> _tierGradient(BuildContext context, SubscriptionTier tier) {
  final colors = context.colors;
  final shadow = Theme.of(context).colorScheme.shadow;
  switch (tier) {
    case SubscriptionTier.pro:
      return [
        colors.proBlue,
        Color.alphaBlend(shadow.withValues(alpha: 0.58), colors.proBlue),
      ];
    case SubscriptionTier.free:
      return [_TierColors.freeStart, _TierColors.freeEnd];
  }
}

IconData _tierIcon(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.pro:
      return Icons.bolt_rounded;
    case SubscriptionTier.free:
      return Icons.person_outline_rounded;
  }
}

String _formatFeature(String id) => id
    .split('_')
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
