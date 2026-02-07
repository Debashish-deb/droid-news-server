import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/architecture/either.dart';
import '../../../core/architecture/failure.dart';
import '../../../domain/entities/subscription.dart'; 
import '../../providers/subscription_providers.dart';
import '../../widgets/error_widget.dart';
import '../../../l10n/generated/app_localizations.dart';


import '../common/app_bar.dart';

// Subscription Management Screen
// Shows current tier, billing info, and upgrade/downgrade options
class SubscriptionManagementScreen extends ConsumerStatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  ConsumerState<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends ConsumerState<SubscriptionManagementScreen> {
  bool _isLoading = true;
  Subscription? _subscription;
  AppFailure? _error;
  Map<SubscriptionTier, List<String>>? _availableTiers;
  bool _isTrialEligible = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionInfo();
  }

  Future<void> _loadSubscriptionInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repository = ref.read(subscriptionRepositoryProvider);

    final results = await Future.wait([
      repository.getCurrentSubscription(),
      repository.getAvailableTiers(),
      repository.isTrialEligible(),
    ]);

    final subResult = results[0] as Either<AppFailure, Subscription?>; 
    
    if (results[1] is! Either<AppFailure, Map<SubscriptionTier, List<String>>>) {
    }
    final tiersResult = results[1] as Either<AppFailure, Map<SubscriptionTier, List<String>>>;
    
    final trialResult = results[2] as Either<AppFailure, bool>;

    if (mounted) {
      setState(() {
        _isLoading = false;
        
        subResult.fold(
          (f) => _error = f,
          (s) => _subscription = s,
        );

        tiersResult.fold(
          (f) => _error = f, 
          (t) => _availableTiers = t,
        );

        trialResult.fold(
          (f) => null, 
          (eligible) => _isTrialEligible = eligible,
        );
      });
    }
  }

  Future<void> _upgradeTo(SubscriptionTier tier) async {
    setState(() => _isLoading = true);

    final repository = ref.read(subscriptionRepositoryProvider);
    final result = await repository.upgradeSubscription(tier);

    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _error = failure;
            _isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
        }
      },
      (subscription) {
        if (mounted) {
          setState(() {
            _subscription = subscription;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).upgradeInitiated(tier.displayName)),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  Future<void> _startTrial() async {
    setState(() => _isLoading = true);

    final repository = ref.read(subscriptionRepositoryProvider);
    final result = await repository.startTrial();

    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _error = failure;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.userMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (subscription) {
        if (mounted) {
          setState(() {
            _subscription = subscription;
            _isLoading = false;
            _isTrialEligible = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).freeTrialStarted),
              backgroundColor: Colors.green,
            ),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
             if (mounted) {
                 ref.read(premiumStatusProvider);
                }
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: AppBarTitle(loc.manageSubscription),
        centerTitle: true,
      ),
      body: _buildBody(theme, loc),
    );
  }

  Widget _buildBody(ThemeData theme, AppLocalizations loc) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorDisplay(error: _error!, onRetry: _loadSubscriptionInfo);
    }

    if (_subscription == null) {
      return Center(child: Text(loc.noSubscriptionInfo));
    }

    return RefreshIndicator(
      onRefresh: _loadSubscriptionInfo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCurrentPlanCard(theme, loc),
            const SizedBox(height: 24),
            _buildAvailablePlans(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(ThemeData theme, AppLocalizations loc) {
    final tier = _subscription!.tier;
    final isActive = _subscription!.isActive;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForTier(tier),
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.currentPlan,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tier.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      loc.active,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              loc.features,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._subscription!.features.map((feature) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_formatFeatureName(feature)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailablePlans(ThemeData theme) {
    if (_availableTiers == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).availablePlans,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._availableTiers!.entries.map((entry) {
          final tier = entry.key;
          final features = entry.value;
          final isCurrent = tier == _subscription!.tier;

          return _buildPlanCard(theme, tier, features, isCurrent);
        }),
      ],
    );
  }

  Widget _buildPlanCard(
    ThemeData theme,
    SubscriptionTier tier,
    List<String> features,
    bool isCurrent,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCurrent ? 8 : 2,
      child: Container(
        decoration:
            isCurrent
                ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                )
                : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getIconForTier(tier), color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tier.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Chip(
                      label: Text(AppLocalizations.of(context).current),
                      backgroundColor: Colors.green,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ...features.map((feature) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                );
              }),
              if (!isCurrent && tier.isPremium) ...[
                const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                       if (_isTrialEligible && tier == SubscriptionTier.pro) {
                         _startTrial();
                       } else {
                         _upgradeTo(tier);
                       }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      (_isTrialEligible && tier == SubscriptionTier.pro)
                          ? AppLocalizations.of(context).startFreeTrial
                          : AppLocalizations.of(context).upgradeToTier(tier.displayName),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return Icons.account_circle_outlined;
      case SubscriptionTier.pro:
        return Icons.star;
      case SubscriptionTier.proPlus:
        return Icons.diamond;
    }
  }

  String _formatFeatureName(String featureId) {
    return featureId
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
