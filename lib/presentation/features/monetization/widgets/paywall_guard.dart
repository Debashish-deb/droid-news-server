import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdnewsreader/l10n/generated/app_localizations.dart'; // Fixed import
import '../../../providers/premium_providers.dart';

class PaywallGuard extends ConsumerStatefulWidget {

  const PaywallGuard({
    required this.child,
    this.isPremiumContent = false,
    super.key,
  });
  final Widget child;
  final bool isPremiumContent;

  @visibleForTesting
  static void resetForTesting() {
    _PaywallGuardState.resetForTesting();
  }

  @override
  ConsumerState<PaywallGuard> createState() => _PaywallGuardState();
}

class _PaywallGuardState extends ConsumerState<PaywallGuard> {
  static int _freeViewsUsed = 0;
  static const int _maxFreeViews = 3; // Increased slightly for user experience
  bool _unlockedLocally = false;

  @visibleForTesting
  static void resetForTesting() {
    _freeViewsUsed = 0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.isPremiumContent && _freeViewsUsed < _maxFreeViews) {
      _freeViewsUsed++;
      _unlockedLocally = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUserPremium = ref.watch(isPremiumProvider);

    // If content is free, or user is premium, or user still has free views left for this session
    if (!widget.isPremiumContent || (isUserPremium.valueOrNull ?? false) || _unlockedLocally) {
      return widget.child;
    }

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
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_person_rounded, size: 40, color: Colors.amber),
                  ),
                  const SizedBox(height: 16),
                    Text(
                      loc.exclusiveContent,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.droidPlusDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc.navigatingToPremium)),
                        );
                      },
                      icon: const Icon(Icons.star_rounded),
                      label: Text(loc.upgradeDroidPlus),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
