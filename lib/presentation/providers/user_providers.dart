import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feature_providers.dart';

// Provides the user profile and caches it to avoid re-fetching on every build
final userProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return authService.getProfile();
});
