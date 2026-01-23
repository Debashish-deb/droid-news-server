import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/architecture/failure.dart';
import '../../domain/entities/subscription.dart';
import '../../presentation/providers/subscription_providers.dart';
import '../../widgets/error_widget.dart';

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
      // Get subscription repository
      final repository = ref.read(subscriptionRepositoryProvider);

      // Check current subscription status
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
          // Check if user is already premium
          if (subscription.tier.isPremium) {
            if (mounted) {
              setState(() {
                _isPurchased = true;
                _isLoading = false;
              });
            }
            return;
          }

          // Query available products
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
              // For now, we have products loaded
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
        // Process successful purchase
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

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Purchase successful! Ads removed.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        );

        // Complete the purchase
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
                    : const PurchaseFailure('Purchase failed');
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
          // Purchase initiated, wait for stream updates
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
                const SnackBar(
                  content: Text('✅ Purchase restored successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No previous purchases found.')),
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
      appBar: AppBar(title: const Text('Remove Ads'), centerTitle: true),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading...'),
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
              '✅ Ads Removed!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Thank you for supporting our app!',
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
          // Premium benefits
          _buildBenefitsCard(theme),

          const SizedBox(height: 32),

          // Purchase button
          ElevatedButton.icon(
            onPressed: _buyPremium,
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Remove Ads - One-time Purchase'),
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

          // Restore button
          TextButton.icon(
            onPressed: _restorePurchases,
            icon: const Icon(Icons.restore),
            label: const Text('Restore Previous Purchase'),
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
                  'Premium Benefits',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildBenefitItem('✓', 'Ad-free experience', theme),
            _buildBenefitItem('✓', 'Support app development', theme),
            _buildBenefitItem('✓', 'One-time payment, lifetime access', theme),
            _buildBenefitItem('✓', 'Priority customer support', theme),
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
