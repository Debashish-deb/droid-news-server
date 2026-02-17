import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/domain/entities/subscription.dart';
import 'package:bdnewsreader/presentation/providers/subscription_providers.dart';
import 'package:bdnewsreader/presentation/widgets/error_widget.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart';

import 'package:bdnewsreader/presentation/features/common/app_bar.dart';

/// Enhanced Remove Ads screen with unified error handling
class RemoveAdsScreen extends ConsumerStatefulWidget {
  const RemoveAdsScreen({super.key});

  @override
  ConsumerState<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends ConsumerState<RemoveAdsScreen> {
  bool _isLoading = true;
  bool _isPurchased = false;
  AppFailure? _error;
  ProductDetails? _product;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    _initializeStore();
    _listenToPurchases();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeStore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(subscriptionRepositoryProvider);

      final subscriptionResult = await repository.getCurrentSubscription();

      subscriptionResult.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _error = failure;
              _isLoading = false;
            });
          }
        },
        (subscription) async {
          if (subscription.tier.isPremium) {
            if (mounted) {
              setState(() {
                _isPurchased = true;
                _isLoading = false;
              });
            }
            return;
          }

          final tiersResult = await repository.getAvailableTiers();

          tiersResult.fold(
            (failure) {
              if (mounted) {
                setState(() {
                  _error = failure;
                  _isLoading = false;
                });
              }
            },
            (tiers) {
            
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UnknownFailure(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  void _listenToPurchases() {
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = PurchaseFailure(error.toString());
          });
        }
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
      
        final repository = ref.read(subscriptionRepositoryProvider);
        final result = await repository.validateAndRefreshSubscription();

        result.fold(
          (failure) {
            if (mounted) {
              setState(() => _error = failure);
            }
          },
          (subscription) {
            if (mounted) {
              setState(() {
                _isPurchased = subscription.tier.isPremium;
              });

              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).purchaseSuccess),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        );

      
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          final iapError = purchase.error;
          setState(() {
            _error =
                iapError != null
                    ? _mapIAPError(iapError)
                    : PurchaseFailure(AppLocalizations.of(context).loadFailed);
          });
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() {
            _error = const PurchaseCancelledFailure();
          });
        }
      }
    }
  }

  AppFailure _mapIAPError(IAPError error) {
    switch (error.code) {
      case 'user_cancelled':
        return const PurchaseCancelledFailure();
      case 'purchase_already_owned':
        return const PurchaseAlreadyOwnedFailure();
      case 'network_error':
        return NetworkFailure(error.message);
      default:
        return PurchaseFailure(error.message, error.code);
    }
  }

  Future<void> _buyPremium() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(subscriptionRepositoryProvider);
      final result = await repository.upgradeSubscription(SubscriptionTier.pro);

      result.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _error = failure;
              _isLoading = false;
            });
          }
        },
        (subscription) {
  
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UnknownFailure(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repository = ref.read(subscriptionRepositoryProvider);
      final result = await repository.restoreSubscription();

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
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        (subscription) {
          if (mounted) {
            setState(() {
              _isPurchased = subscription.tier.isPremium;
              _isLoading = false;
            });

            if (subscription.tier.isPremium) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).purchaseRestored),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).noPreviousPurchases)),
              );
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UnknownFailure(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: AppBarTitle(AppLocalizations.of(context).removeAds),
        centerTitle: true,
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return ErrorDisplay(error: _error!, onRetry: _initializeStore);
    }

    if (_isPurchased) {
      return _buildSuccessState(theme);
    }

    return _buildPurchaseState(theme);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(AppLocalizations.of(context).loading),
        ],
      ),
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).adsRemovedWithTick,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).thankYouSupport,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseState(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
         
          _buildBenefitsCard(theme),

          const SizedBox(height: 32),

       
          ElevatedButton.icon(
            onPressed: _buyPremium,
            icon: const Icon(Icons.shopping_cart),
            label: Text(AppLocalizations.of(context).removeAdsOneTime),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

    
          TextButton.icon(
            onPressed: _restorePurchases,
            icon: const Icon(Icons.restore),
            label: Text(AppLocalizations.of(context).restorePurchase),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard(ThemeData theme) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: theme.colorScheme.primary, size: 32),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).premiumBenefits,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildBenefitItem('✓', AppLocalizations.of(context).adFreeExperienceBenefit, theme),
            _buildBenefitItem('✓', AppLocalizations.of(context).supportAppDevelopmentBenefit, theme),
            _buildBenefitItem('✓', AppLocalizations.of(context).oneTimePaymentBenefit, theme),
            _buildBenefitItem('✓', AppLocalizations.of(context).prioritySupportBenefit, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
