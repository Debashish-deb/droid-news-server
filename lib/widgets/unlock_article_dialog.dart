import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/premium_providers.dart';
import '../data/services/rewarded_ad_service.dart';

/// Dialog to show when user tries to access premium content
class UnlockArticleDialog extends ConsumerStatefulWidget {
  const UnlockArticleDialog({
    required this.articleUrl,
    required this.articleTitle,
    super.key,
  });

  final String articleUrl;
  final String articleTitle;

  @override
  ConsumerState<UnlockArticleDialog> createState() =>
      _UnlockArticleDialogState();
}

class _UnlockArticleDialogState extends ConsumerState<UnlockArticleDialog> {
  bool _isLoading = false;
  bool _adNotReady = false;

  @override
  Widget build(BuildContext context) {
    // Use Riverpod provider for premium status
    final bool isPremium = ref.watch(isPremiumProvider);
    final bool isUnlocked = RewardedAdService().isArticleUnlocked(
      widget.articleUrl,
    );
    final bool adReady = RewardedAdService().isAdReady;

    // If already unlocked or premium, close dialog
    if (isPremium || isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    }

    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.lock, color: Colors.amber),
          SizedBox(width: 8),
          Text('Premium Article'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'This is a premium article',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          const Text('Choose an option to unlock:'),
          const SizedBox(height: 16),

          // Watch ad option
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(
                Icons.play_circle_outline,
                color: Colors.green,
              ),
              title: const Text('Watch Ad (FREE)'),
              subtitle: const Text('Unlock for this session'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: adReady && !_isLoading ? _showRewardedAd : null,
            ),
          ),

          if (_adNotReady)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Ad is loading, please wait...',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),

          const SizedBox(height: 8),

          // Upgrade to premium option
          Card(
            color: Colors.blue.shade50,
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.blue),
              title: const Text('Go Premium'),
              subtitle: const Text('Unlock all articles + No ads'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _goToPremium,
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _showRewardedAd() async {
    setState(() {
      _isLoading = true;
      _adNotReady = false;
    });

    final bool success = await RewardedAdService().showAdToUnlockArticle(
      widget.articleUrl,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      //Ad watched successfully, close dialog and allow access
      if (!mounted) return;
      Navigator.of(context).pop(true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Article unlocked! Enjoy reading.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Ad isn't ready yet
      setState(() => _adNotReady = true);

      // Try to load ad manually
      await RewardedAdService().loadAdManually();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad is not ready yet. Please try again in a moment.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _goToPremium() {
    Navigator.of(context).pop(false);
    // Navigate to subscription management screen
    Navigator.of(context).pushNamed('/subscription');
  }
}

/// Helper function to show unlock dialog
Future<bool> showUnlockDialog(
  BuildContext context,
  String articleUrl,
  String articleTitle,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder:
        (context) => UnlockArticleDialog(
          articleUrl: articleUrl,
          articleTitle: articleTitle,
        ),
  );
  return result ?? false;
}
