import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/material.dart';
import '../../../../core/theme/theme_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/generated/app_localizations.dart'; // Fixed import
import '../../../providers/premium_providers.dart';
import '../../../../core/navigation/navigation_helper.dart';

class PaywallGuard extends ConsumerStatefulWidget {
  const PaywallGuard({
    required this.child,
    this.isPremiumContent = false,
    super.key,
  });
  final Widget child;
  final bool isPremiumContent;

  static int _manualFreeViewsForTesting = -1;

  @visibleForTesting
  static void resetForTesting() {
    _manualFreeViewsForTesting = -1;
  }

  @visibleForTesting
  static void setFreeViewsUsedForTesting(int count) {
    _manualFreeViewsForTesting = count;
  }

  @override
  ConsumerState<PaywallGuard> createState() => _PaywallGuardState();
}

class _PaywallGuardState extends ConsumerState<PaywallGuard> {
  static const int _maxFreeViews = 3;
  bool _unlockedLocally = false;
  bool _hasChecked = false;
  bool _isCheckingAccess = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleAccessCheck();
  }

  @override
  void didUpdateWidget(covariant PaywallGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPremiumContent != oldWidget.isPremiumContent) {
      _scheduleAccessCheck(force: true);
    }
  }

  void _scheduleAccessCheck({bool force = false}) {
    if (!widget.isPremiumContent ||
        PaywallGuard._manualFreeViewsForTesting != -1) {
      return;
    }
    if ((_hasChecked || _isCheckingAccess || _checkScheduled) && !force) {
      return;
    }
    if (force) {
      _unlockedLocally = false;
      _hasChecked = false;
      _isCheckingAccess = false;
    }

    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) {
        _consumeFreeViewAccess();
      }
    });
  }

  Future<void> _consumeFreeViewAccess() async {
    if (_hasChecked || _isCheckingAccess || !widget.isPremiumContent) {
      return;
    }

    _isCheckingAccess = true;
    try {
      final granted = await ref
          .read(freeViewsProvider.notifier)
          .tryConsumeIfAvailable(maxFreeViews: _maxFreeViews);

      if (!mounted) return;
      setState(() {
        _unlockedLocally = granted;
        _hasChecked = true;
      });
    } finally {
      _isCheckingAccess = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUserPremium = ref.watch(isPremiumStateProvider);

    if (!widget.isPremiumContent || isUserPremium || _unlockedLocally) {
      return widget.child;
    }

    if (PaywallGuard._manualFreeViewsForTesting != -1) {
      if (!_hasChecked) {
        if (PaywallGuard._manualFreeViewsForTesting < _maxFreeViews) {
          _unlockedLocally = true;
        }
        _hasChecked = true;
      }
      if (_unlockedLocally) return widget.child;
      return _buildLockOverlay(context, loc);
    }

    ref.watch(freeViewsProvider);
    if (!_hasChecked) {
      _scheduleAccessCheck();
      return const Center(child: CircularProgressIndicator());
    }

    if (_unlockedLocally) {
      return widget.child;
    }
    return _buildLockOverlay(context, loc);
  }

  Widget _buildLockOverlay(BuildContext context, AppLocalizations loc) {
    return Stack(
      children: [
        // Blurred background content
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: IgnorePointer(
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                  stops: [0.4, 0.9],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: widget.child,
            ),
          ),
        ),

        // Lock UI overlay
        Positioned.fill(
          child: Center(
            child: Container(
              padding: ThemeSkeleton.shared.insetsAll(24),
              margin: ThemeSkeleton.shared.insetsAll(24),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: ThemeSkeleton.shared.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: ThemeSkeleton.shared.insetsAll(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      size: 40,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: ThemeSkeleton.size16),
                  Text(
                    loc.exclusiveContent,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: ThemeSkeleton.size12),
                  Text(
                    loc.droidPlusDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: ThemeSkeleton.size28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        NavigationHelper.openSubscriptionManagement<void>(
                          context,
                        );
                      },
                      icon: const Icon(Icons.star_rounded),
                      label: Text(loc.upgradeDroidPlus),
                      style: FilledButton.styleFrom(
                        padding: ThemeSkeleton.shared.insetsSymmetric(
                          vertical: 16,
                        ),
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: ThemeSkeleton.shared.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
