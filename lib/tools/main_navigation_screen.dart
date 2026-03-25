import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/generated/app_localizations.dart';
import '../presentation/providers/tab_providers.dart';
import '../presentation/widgets/bottom_nav_bar.dart' show BottomNavBar;

/// Root shell screen that hosts the [StatefulNavigationShell].
///
/// Converted from [ConsumerWidget] to [ConsumerStatefulWidget] to fix a
/// critical bug: `lastBackPressed` must survive rebuilds as instance state.
/// Declaring it inside `build()` reset it to `null` on every rebuild, making
/// the double-back-press exit gesture permanently non-functional.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  /// Timestamp of the last back-press. Null until the first press occurs.
  ///
  /// Lives here as instance state so it survives widget rebuilds — the
  /// original had it inside build() which reset it to null on every rebuild.
  DateTime? _lastBackPressed;

  // ── Back-press handler ────────────────────────────────────────────────────

  /// Called by [PopScope] when the user attempts to pop the current route.
  ///
  /// - If on a non-home branch: navigate to home branch and block the pop.
  /// - If on the home branch: first press shows a snackbar; second press within
  ///   2 s allows the pop (exits the app).
  Future<bool> _onPopRequested() async {
    if (widget.navigationShell.currentIndex != 0) {
      // Not on home tab — jump to home, block the pop
      widget.navigationShell.goBranch(0);
      ref.read(tabProvider.notifier).setTab(0);
      return false; // block pop
    }

    final now = DateTime.now();
    final sinceLastPress = _lastBackPressed == null
        ? null
        : now.difference(_lastBackPressed!);

    if (sinceLastPress == null || sinceLastPress > const Duration(seconds: 2)) {
      // First press (or cooldown expired): show snackbar, block pop
      _lastBackPressed = now;
      _showExitSnackbar();
      return false;
    }

    // Second press within 2 s: allow the pop (app exits)
    return true;
  }

  void _showExitSnackbar() {
    if (!mounted) return;
    final loc = AppLocalizations.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('👋', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.pressBackToExit,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // `PopScope` is the modern replacement for deprecated `WillPopScope`.
    // `canPop: false` always intercepts the back gesture so our handler runs.
    // `onPopInvokedWithResult` fires after the pop decision; we use a custom
    // flow so we control navigation manually inside `_onPopRequested`.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return; // PopScope already handled it (canPop was true)
        final navigator = Navigator.of(context);
        final allow = await _onPopRequested();
        if (allow && mounted) {
          // Re-invoke the system back so the OS can exit the app
          navigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true, // content draws behind the translucent nav bar
        body: widget.navigationShell,
        bottomNavigationBar: BottomNavBar(
          navigationShell: widget.navigationShell,
        ),
      ),
    );
  }
}
