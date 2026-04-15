// lib/infrastructure/repositories/premium_repository_impl.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../domain/entities/subscription.dart' show SubscriptionTier;
import '../../core/security/secure_prefs.dart';
import '../../core/telemetry/structured_logger.dart';

class PremiumRepositoryImpl implements PremiumRepository {
  PremiumRepositoryImpl(
    this._securePrefs,
    this._prefs,
    this._firestore,
    this._logger,
  ) {
    if (_prefs != null) {
      // 1. Initial sync check for zero-flicker startup
      _lastKnownStatus = _isPremiumFromPrefsSnapshot();
      _lastKnownTier = _extractTierFromPrefs(
        assumePremiumIfMissing: _lastKnownStatus,
      );
      final hasMarker = _hasLocalStatusMarker();
      // Fail-safe for tier gating:
      // - cached premium can be trusted immediately (never show ads to premium)
      // - cached free is not trusted until refreshStatus() confirms server state
      _statusResolved = hasMarker && _lastKnownStatus;
    }

    _snapshot = EntitlementSnapshot(
      isPremium: _lastKnownStatus,
      tier: _coerceTierForPremium(_lastKnownTier, isPremium: _lastKnownStatus),
      resolved: _statusResolved,
      source: _statusResolved ? 'cache' : 'bootstrap',
      updatedAt: DateTime.now(),
    );

    // Proactive broadcast to any early listeners to avoid a frame of 'false'
    if (_statusResolved) {
      _statusController.add(_lastKnownStatus);
      _snapshotController.add(_snapshot);
    }

    // Don't eagerly hit Firestore here. Let AuthService.init() trigger
    // refreshStatus() after Firebase is fully ready.
  }

  final SecurePrefs _securePrefs;
  final SharedPreferences? _prefs;
  final FirebaseFirestore _firestore;
  final StructuredLogger _logger;

  static const String _kPremiumKey = 'is_premium';
  static const String _kCurrentTierKey = 'current_subscription_tier';

  final _statusController = StreamController<bool>.broadcast();
  final _snapshotController = StreamController<EntitlementSnapshot>.broadcast();
  bool _lastKnownStatus = false;
  SubscriptionTier _lastKnownTier = SubscriptionTier.free;
  late EntitlementSnapshot _snapshot;
  bool _statusResolved = false;
  Future<void>? _refreshInFlight;
  DateTime? _lastRefreshAt;
  String? _lastRefreshUserId;

  static const Duration _minRefreshInterval = Duration(seconds: 20);

  @override
  Stream<bool> get premiumStatusStream async* {
    if (_statusResolved) {
      yield _lastKnownStatus;
    }
    yield* _statusController.stream;
  }

  @override
  Stream<EntitlementSnapshot> get entitlementSnapshotStream async* {
    yield _snapshot;
    yield* _snapshotController.stream;
  }

  @override
  bool get isPremium => _lastKnownStatus;

  @override
  SubscriptionTier get tier => _lastKnownTier;

  @override
  EntitlementSnapshot get entitlementSnapshot => _snapshot;

  @override
  bool get isStatusResolved => _statusResolved;

  @override
  bool get shouldShowAds => !_lastKnownStatus;

  @override
  Future<void> refreshStatus() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final now = DateTime.now();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final authContextChanged = currentUid != _lastRefreshUserId;
    if (_statusResolved &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < _minRefreshInterval &&
        !authContextChanged) {
      return;
    }

    final future = _refreshStatusInternal();
    _refreshInFlight = future;
    try {
      await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _refreshStatusInternal() async {
    // 1. Check local persistence first (offline-safe and race-safe).
    final localPrefsStatus = _isPremiumFromPrefsSnapshot();
    final secureStatus = await _securePrefs.getString(_kPremiumKey);
    final localSecureStatus = secureStatus == 'true';
    final localEntitlement = localSecureStatus || localPrefsStatus;
    bool status = localEntitlement;
    var source = localEntitlement ? 'cache' : 'unknown';

    // Fast-path: publish trusted local premium immediately so slow network/server
    // refresh cannot momentarily downgrade the UI to free.
    if (localEntitlement && (!_statusResolved || !_lastKnownStatus)) {
      _statusResolved = true;
      _lastKnownStatus = true;
      _lastKnownTier = _extractTierFromPrefs(assumePremiumIfMissing: true);
      _publishEntitlement(
        source: 'cache_fastpath',
        emitStatus: true,
        forceSnapshotEmit: true,
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Fetch premium status from Firestore with high priority
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          final isPremium = _isPremiumFromFirestore(data);
          final hasExplicitServerEntitlement = _hasExplicitEntitlementState(
            data,
          );

          if (isPremium) {
            status = true;
            final serverTier = _extractTierFromFirestore(data);
            final tierStr = _normalizeTier(serverTier, isPremium: true);
            source = 'server';

            // Sync immediately to local cache
            await _persistLocalEntitlement(true, tier: tierStr);

            // Update mid-refresh state to prevent "flicker back to free"
            final wasPremium = _lastKnownStatus;
            _lastKnownStatus = true;
            _lastKnownTier = _mapToTierEnum(tierStr);
            _statusResolved = true;

            if (!wasPremium) {
              _logger.info(
                '👑 Premium granted via Firestore for: ${user.email}',
              );
            }
          } else if (hasExplicitServerEntitlement) {
            // Revoke only when server explicitly provides non-premium state.
            // Missing entitlement fields are treated as "unknown", not "false".
            status = false;
            source = 'server_explicit';
            await _persistLocalEntitlement(false);
            _logger.info(
              'Premium sync: Revoked access for user based on explicit server entitlement.',
            );
          } else {
            status = localEntitlement;
            source = status ? 'grace_cache' : 'grace_unknown';
            _logger.warning(
              'Premium sync: user document missing entitlement fields; preserving local entitlement state.',
            );
          }
        } else if (localEntitlement) {
          source = 'cache_no_doc';
          await _persistLocalEntitlement(true);
        }
      } catch (e) {
        source = status ? 'error_grace' : 'error_unknown';
        _logger.error('Failed to fetch premium status from Firestore', e);
      }
    } else if (localEntitlement) {
      source = 'cache_signed_out';
      await _persistLocalEntitlement(true);
    }

    final changed = !_statusResolved || _lastKnownStatus != status;
    final previousTier = _lastKnownTier;
    _statusResolved = true;
    _lastKnownStatus = status;
    _lastKnownTier = status
        ? _extractTierFromPrefs(assumePremiumIfMissing: true)
        : SubscriptionTier.free;
    _lastRefreshAt = DateTime.now();
    _lastRefreshUserId = user?.uid;
    final tierChanged = previousTier != _lastKnownTier;
    _publishEntitlement(
      source: source,
      emitStatus: changed,
      forceSnapshotEmit: tierChanged,
    );
  }

  @override
  Future<void> setPremium(bool value) async {
    await _persistLocalEntitlement(value);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(<String, dynamic>{
              _kPremiumKey: value,
              _kCurrentTierKey: value
                  ? _normalizeTier(
                      _prefs?.getString(_kCurrentTierKey),
                      isPremium: true,
                    )
                  : 'free',
              'entitlement_updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e, stack) {
        _logger.warning('Failed to sync premium status to Firestore', e, stack);
      }
    }

    _statusResolved = true;
    _lastKnownStatus = value;
    _lastKnownTier = value
        ? _extractTierFromPrefs(assumePremiumIfMissing: true)
        : SubscriptionTier.free;
    _lastRefreshAt = DateTime.now();
    _publishEntitlement(source: 'local_set', emitStatus: true);
  }

  bool _hasLocalStatusMarker() {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.containsKey(_kPremiumKey) ||
        prefs.containsKey(_kCurrentTierKey);
  }

  bool _isPremiumFromPrefsSnapshot() {
    final prefs = _prefs;
    if (prefs == null) return false;
    if (prefs.getBool(_kPremiumKey) == true) {
      return true;
    }
    return _isPremiumTier(prefs.getString(_kCurrentTierKey));
  }

  bool _isPremiumFromFirestore(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data[_kPremiumKey] == true || data['isPremium'] == true) {
      return true;
    }
    return _isPremiumTier(_extractTierFromFirestore(data));
  }

  bool _hasExplicitEntitlementState(Map<String, dynamic>? data) {
    if (data == null) return false;
    final premiumRaw = data[_kPremiumKey] ?? data['isPremium'];
    if (premiumRaw is bool) return true;

    final tierRaw =
        data[_kCurrentTierKey] ?? data['subscription_tier'] ?? data['tier'];
    if (tierRaw is String && tierRaw.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  String? _extractTierFromFirestore(Map<String, dynamic>? data) {
    final rawTier =
        data?[_kCurrentTierKey] ?? data?['subscription_tier'] ?? data?['tier'];
    if (rawTier is! String) return null;
    final normalized = rawTier.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  SubscriptionTier _mapToTierEnum(String? raw) {
    if (raw == null) return SubscriptionTier.free;
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    if (normalized.contains('pro') ||
        normalized.contains('premium') ||
        normalized.contains('paid') ||
        normalized.contains('yearly')) {
      return SubscriptionTier.pro;
    }
    return SubscriptionTier.free;
  }

  bool _isPremiumTier(String? tier) {
    if (tier == null) return false;
    final normalized = tier
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    return normalized.contains('pro') ||
        normalized.contains('premium') ||
        normalized.contains('paid') ||
        normalized.contains('yearly');
  }

  String _normalizeTier(String? tier, {required bool isPremium}) {
    if (!isPremium) return 'free';

    final normalized = (tier ?? '').trim().toLowerCase();
    if (_isPremiumTier(normalized)) {
      return 'pro';
    }

    final existing = _prefs?.getString(_kCurrentTierKey);
    if (_isPremiumTier(existing)) {
      return _normalizeTier(existing, isPremium: true);
    }
    return 'pro';
  }

  SubscriptionTier _extractTierFromPrefs({
    bool assumePremiumIfMissing = false,
  }) {
    final raw =
        _prefs?.getString(_kCurrentTierKey) ??
        _prefs?.getString('premium_tier') ?? // Legacy fallback
        'free';
    final mapped = _mapToTierEnum(raw);
    return _coerceTierForPremium(mapped, isPremium: assumePremiumIfMissing);
  }

  Future<void> _persistLocalEntitlement(bool isPremium, {String? tier}) async {
    final prefs = _prefs;
    final normalizedTier = _normalizeTier(tier, isPremium: isPremium);

    // Memory sync
    _lastKnownStatus = isPremium;
    _lastKnownTier = _coerceTierForPremium(
      _mapToTierEnum(normalizedTier),
      isPremium: isPremium,
    );
    _statusResolved = true;

    await Future.wait<dynamic>([
      _securePrefs.setString(_kPremiumKey, isPremium ? 'true' : 'false'),
      if (prefs != null) ...[
        prefs.setBool(_kPremiumKey, isPremium),
        prefs.setString(_kCurrentTierKey, normalizedTier),
      ],
    ]);
  }

  SubscriptionTier _coerceTierForPremium(
    SubscriptionTier tier, {
    required bool isPremium,
  }) {
    if (!isPremium) return SubscriptionTier.free;
    if (tier == SubscriptionTier.free) {
      return SubscriptionTier.pro;
    }
    return tier;
  }

  void _publishEntitlement({
    required String source,
    required bool emitStatus,
    bool forceSnapshotEmit = false,
  }) {
    _lastKnownTier = _coerceTierForPremium(
      _lastKnownTier,
      isPremium: _lastKnownStatus,
    );
    final next = EntitlementSnapshot(
      isPremium: _lastKnownStatus,
      tier: _lastKnownTier,
      resolved: _statusResolved,
      source: source,
      updatedAt: DateTime.now(),
    );
    final changed = forceSnapshotEmit || next != _snapshot;
    _snapshot = next;
    if (changed && !_snapshotController.isClosed) {
      _snapshotController.add(_snapshot);
    }
    if (emitStatus && !_statusController.isClosed) {
      _statusController.add(_lastKnownStatus);
    }
  }
}

class StubPremiumRepository implements PremiumRepository {
  StubPremiumRepository(this._prefs) {
    if (_prefs != null) {
      final tierStr = _prefs.getString('current_subscription_tier');
      _isPremium =
          (_prefs.getBool('is_premium') ?? false) || _isPremiumTier(tierStr);
      _tier = _coerceTierForPremium(
        _mapToTierEnum(tierStr),
        isPremium: _isPremium,
      );
      _isStatusResolved =
          _prefs.containsKey('is_premium') ||
          _prefs.containsKey('current_subscription_tier');
    }
    _snapshot = EntitlementSnapshot(
      isPremium: _isPremium,
      tier: _coerceTierForPremium(_tier, isPremium: _isPremium),
      resolved: _isStatusResolved,
      source: _isStatusResolved ? 'stub_cache' : 'stub_bootstrap',
      updatedAt: DateTime.now(),
    );
  }

  final SharedPreferences? _prefs;
  final _snapshotController = StreamController<EntitlementSnapshot>.broadcast();
  bool _isPremium = false;
  SubscriptionTier _tier = SubscriptionTier.free;
  bool _isStatusResolved = false;
  late EntitlementSnapshot _snapshot;

  bool _isPremiumTier(String? tier) {
    if (tier == null) return false;
    final normalized = tier
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    return normalized.contains('pro') ||
        normalized.contains('premium') ||
        normalized.contains('paid') ||
        normalized.contains('yearly');
  }

  SubscriptionTier _mapToTierEnum(String? raw) {
    if (raw == null) return SubscriptionTier.free;
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    if (normalized.contains('pro') ||
        normalized.contains('premium') ||
        normalized.contains('paid') ||
        normalized.contains('yearly')) {
      return SubscriptionTier.pro;
    }
    return SubscriptionTier.free;
  }

  SubscriptionTier _coerceTierForPremium(
    SubscriptionTier tier, {
    required bool isPremium,
  }) {
    if (!isPremium) return SubscriptionTier.free;
    if (tier == SubscriptionTier.free) return SubscriptionTier.pro;
    return tier;
  }

  @override
  bool get isPremium => _isPremium;

  @override
  SubscriptionTier get tier => _tier;

  @override
  EntitlementSnapshot get entitlementSnapshot => _snapshot;

  @override
  bool get isStatusResolved => _isStatusResolved;

  @override
  Stream<bool> get premiumStatusStream =>
      _isStatusResolved ? Stream.value(_isPremium) : const Stream.empty();

  @override
  Stream<EntitlementSnapshot> get entitlementSnapshotStream async* {
    yield _snapshot;
    yield* _snapshotController.stream;
  }

  @override
  bool get shouldShowAds => !_isPremium;

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<void> setPremium(bool value) async {
    _isPremium = value;
    _tier = value
        ? _coerceTierForPremium(_tier, isPremium: true)
        : SubscriptionTier.free;
    _isStatusResolved = true;
    _snapshot = EntitlementSnapshot(
      isPremium: _isPremium,
      tier: _tier,
      resolved: _isStatusResolved,
      source: 'stub_local_set',
      updatedAt: DateTime.now(),
    );
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_snapshot);
    }
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool('is_premium', value);
      await prefs.setString(
        'current_subscription_tier',
        value ? 'pro' : 'free',
      );
    }
  }
}
