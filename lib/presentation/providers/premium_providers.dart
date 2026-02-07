import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/premium_service.dart';
import '../../core/providers.dart';

// Provides the current premium status, listening to the underlying service
// Provides the current premium status
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumNotifierProvider).isPremium;
});

// Provides access to the PremiumService as a ChangeNotifier
final premiumNotifierProvider = ChangeNotifierProvider<PremiumService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PremiumService(prefs: prefs);
});

