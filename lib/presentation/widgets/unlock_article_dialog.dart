import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../infrastructure/services/rewarded_ad_service.dart';

import '../providers/subscription_providers.dart' show isPremiumProvider;

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
    final loc = AppLocalizations.of(context);
    final bool isPremium = ref.watch(isPremiumProvider);
    final bool isUnlocked = RewardedAdService().isArticleUnlocked(
      widget.articleUrl,
    );
    final bool adReady = RewardedAdService().isAdReady;

    if (isPremium || isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    }

    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.lock, color: Colors.amber),
          const SizedBox(width: 8),
          Text(loc.premiumArticle),
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
          Text(loc.chooseUnlockOption),
          const SizedBox(height: 16),

          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(
                Icons.play_circle_outline,
                color: Colors.green,
              ),
              title: Text(loc.watchAdFree),
              subtitle: Text(loc.unlockForSession),
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

          Card(
            color: Colors.blue.shade50,
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.blue),
              title: Text(loc.goPremium),
              subtitle: Text(loc.unlockAllArticles),
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
          child: Text(loc.cancel),
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

    final loc = AppLocalizations.of(context);
    if (success) {
      //Ad watched successfully, close dialog and allow access
      if (!mounted) return;
      Navigator.of(context).pop(true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.articleUnlocked),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _adNotReady = true);

      await RewardedAdService().loadAdManually();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.adNotReady),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _goToPremium() {
    Navigator.of(context).pop(false);
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
