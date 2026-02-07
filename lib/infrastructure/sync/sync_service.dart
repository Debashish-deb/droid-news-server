import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import "../../domain/entities/news_article.dart";
import '../../core/premium_service.dart';
import '../../core/telemetry/observability_service.dart';
import '../../core/telemetry/structured_logger.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class SyncService {

  SyncService(
    this._premiumService,
    this._observability,
    this._logger,
  ) {
    _init();
  }
  final PremiumService _premiumService;
  final ObservabilityService _observability;
  final StructuredLogger _logger;
  
  bool _initialized = false;

  void _init() {
    if (_initialized) return;
    _initialized = true;
    _logger.info('SyncService initialized');
    _observability.measure('sync_init', () => _ensureLocalReady().then((_) => flushPending()));
  }

  PremiumService get premium => _premiumService;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get _canSync =>
      _initialized && _auth.currentUser != null && _premiumService.isPremium;

  String? get _uid => _auth.currentUser?.uid;

 static const int _schemaVersion = 2; 

  static const String _kDeviceIdKey = 'sync_device_id_v1';

  static const String _kPendingSettingsKey = 'sync_pending_settings_v1';

  static const String _kPendingFavoritesDeltaKey = 'sync_pending_fav_delta_v1';

  String get _kShadowSettingsKey => 'sync_shadow_settings_v1_${_uid ?? "anon"}';

  String get _kShadowFavoritesKey =>
      'sync_shadow_favorites_v2_${_uid ?? "anon"}';

  SharedPreferences? _prefs;
  String? _deviceId;
  bool _localReady = false;
  bool _flushing = false;

  Future<void> _ensureLocalReady() async {
    if (_localReady) return;
    _prefs ??= await SharedPreferences.getInstance();

    _deviceId ??= _prefs!.getString(_kDeviceIdKey);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = '${DateTime.now().microsecondsSinceEpoch}_${_rand32()}';
      await _prefs!.setString(_kDeviceIdKey, _deviceId!);
    }

    _localReady = true;
  }

  int _rand32() => DateTime.now().microsecondsSinceEpoch & 0x7fffffff;

  DocumentReference<Map<String, dynamic>> get _settingsRef => _firestore
      .collection('users')
      .doc(_uid)
      .collection('data')
      .doc('settings');

  DocumentReference<Map<String, dynamic>> get _favoritesRef => _firestore
      .collection('users')
      .doc(_uid)
      .collection('data')
      .doc('favorites');


  /// Push local favorites to Cloud (offline-first + delta-sync + tombstones)
  Future<void> pushFavorites({
    required List<NewsArticle> articles,
    required List<Map<String, dynamic>> magazines,
    required List<Map<String, dynamic>> newspapers,
  }) async {
    return _observability.measure('sync_push_favorites', () async {
      await _ensureLocalReady();

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final normalizedNow = _normalizeFavoritesState(
        articles: articles,
        magazines: magazines,
        newspapers: newspapers,
        baseTombstones:
            _readShadow(_kShadowFavoritesKey)?['tombstones']
                as Map<String, dynamic>?,
      );

      final prevShadow = _readShadow(_kShadowFavoritesKey);
      final prevNorm = _ensureFavoritesNormalized(prevShadow);

      final delta = _computeFavoritesDelta(
        previous: prevNorm,
        current: normalizedNow,
        nowMs: nowMs,
      );

      final shadowToStore = <String, dynamic>{
        'schemaVersion': _schemaVersion,
        'clientUpdatedAtMs': nowMs,
        'deviceId': _deviceId,
        ...normalizedNow,
      };
      await _writeShadow(_kShadowFavoritesKey, shadowToStore);

      if (_isEmptyDelta(delta)) {
        _log('favorites.push: no changes (delta empty)');
        return;
      }

      if (!_canSync || _uid == null) {
        await _enqueuePendingDelta(_kPendingFavoritesDeltaKey, delta);
        _log('favorites.push queued delta (offline/not-premium/not-auth)');
        return;
      }

      final ok = await _applyFavoritesDeltaTransaction(
        ref: _favoritesRef,
        delta: delta,
        tag: 'favorites.delta.push',
      );

      if (!ok) {
        await _enqueuePendingDelta(_kPendingFavoritesDeltaKey, delta);
        _log('favorites.push queued delta (cloud failed)');
      } else {
        await _clearPending(_kPendingFavoritesDeltaKey);
        _log('favorites.push delta applied');
      }
    });
  }

  /// Pull favorites from Cloud (offline-first: returns shadow if cannot sync)
  /// Returns legacy shape: { articles: [...], magazines: [...], newspapers: [...] }
  Future<Map<String, dynamic>?> pullFavorites() async {
    return _observability.measure('sync_pull_favorites', () async {
    await _ensureLocalReady();

    if (!_canSync || _uid == null) {
      final cached = _readShadow(_kShadowFavoritesKey);
      final legacy = _favoritesShadowToLegacy(cached);
      if (legacy != null) _log('favorites.pull from shadow (offline)');
      return legacy;
    }

    await flushPending();

    try {
      final doc = await _favoritesRef.get();
      final data = doc.data();

      if (doc.exists && data != null) {
        await _writeShadow(_kShadowFavoritesKey, data);

        final legacy = _favoritesServerToLegacy(data);
        _log('favorites.pull cloud success');
        return legacy;
      }
    } catch (e) {
      _log('favorites.pull failed: $e');
      final cached = _readShadow(_kShadowFavoritesKey);
      final legacy = _favoritesShadowToLegacy(cached);
      if (legacy != null) _log('favorites.pull fallback to shadow');
      return legacy;
    }

    final cached = _readShadow(_kShadowFavoritesKey);
    return _favoritesShadowToLegacy(cached);
    });
  }


  Future<void> pushSettings({
    required bool dataSaver,
    required bool pushNotif,
    required int themeMode,
    required String languageCode,
    required double readerLineHeight,
    required double readerContrast,
  }) async {
    await _ensureLocalReady();

    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'type': 'settings',
      'clientUpdatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'deviceId': _deviceId,
      'updatedAt': FieldValue.serverTimestamp(),
      'dataSaver': dataSaver,
      'pushNotif': pushNotif,
      'themeMode': themeMode,
      'languageCode': languageCode,
      'readerLineHeight': readerLineHeight,
      'readerContrast': readerContrast,
    };

    await _writeShadow(_kShadowSettingsKey, payload);

    if (!_canSync || _uid == null) {
      await _prefs!.setString(
        _kPendingSettingsKey,
        jsonEncode(_jsonSafe(payload)),
      );
      _log('settings.push queued');
      return;
    }

    final ok = await _conflictSafeUpsertSettings(payload, tag: 'settings.push');
    if (!ok) {
      await _prefs!.setString(
        _kPendingSettingsKey,
        jsonEncode(_jsonSafe(payload)),
      );
    } else {
      await _clearPending(_kPendingSettingsKey);
    }
  }

  Future<Map<String, dynamic>?> pullSettings() async {
    await _ensureLocalReady();

    if (!_canSync || _uid == null) {
      final cached = _readShadow(_kShadowSettingsKey);
      if (cached != null) _log('settings.pull from shadow (offline)');
      return cached;
    }

    await flushPending();

    try {
      final doc = await _settingsRef.get();
      final data = doc.data();
      if (doc.exists && data != null) {
        await _writeShadow(_kShadowSettingsKey, data);
        _log('settings.pull cloud success');
        return data;
      }
    } catch (e) {
      _log('settings.pull failed: $e');
      return _readShadow(_kShadowSettingsKey);
    }

    return _readShadow(_kShadowSettingsKey);
  }

  Stream<Map<String, dynamic>?>? settingsStream() {
    if (!_canSync || _uid == null) return null;
    flushPending();

    return _settingsRef.snapshots().map((doc) {
      final data = doc.data();
      if (data != null) _writeShadow(_kShadowSettingsKey, data);
      return data;
    });
  }

  Stream<Map<String, dynamic>?>? favoritesStream() {
    if (!_canSync || _uid == null) return null;
    flushPending();

    return _favoritesRef.snapshots().map((doc) {
      final data = doc.data();
      if (data != null) _writeShadow(_kShadowFavoritesKey, data);
      return data;
    });
  }


  Future<void> flushPending() async {
    if (_flushing) return;
    if (!_canSync || _uid == null) return;

    await _ensureLocalReady();
    _flushing = true;

    try {
      final pendingSettings = _prefs!.getString(_kPendingSettingsKey);
      if (pendingSettings != null && pendingSettings.isNotEmpty) {
        try {
          final v = jsonDecode(pendingSettings);
          if (v is Map) {
            final ok = await _conflictSafeUpsertSettings(
              v.cast<String, dynamic>(),
              tag: 'settings.flush',
            );
            if (ok) await _clearPending(_kPendingSettingsKey);
          }
        } catch (e) {
          _logger.error('Failed to flush pending settings', e);
        }
      }

      final pendingDelta = _readPendingDelta(_kPendingFavoritesDeltaKey);
      if (pendingDelta != null && !_isEmptyDelta(pendingDelta)) {
        final ok = await _applyFavoritesDeltaTransaction(
          ref: _favoritesRef,
          delta: pendingDelta,
          tag: 'favorites.delta.flush',
        );
        if (ok) await _clearPending(_kPendingFavoritesDeltaKey);
      }
    } finally {
      _flushing = false;
    }
  }


  Future<bool> _conflictSafeUpsertSettings(
    Map<String, dynamic> incoming, {
    required String tag,
  }) async {
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(_settingsRef);

        if (!snap.exists || snap.data() == null) {
          tx.set(_settingsRef, incoming);
          return;
        }

        final server = snap.data()!;
        final merged = _mergeSettings(server, incoming);
        merged['schemaVersion'] = _schemaVersion;
        merged['updatedAt'] = FieldValue.serverTimestamp();

        tx.set(_settingsRef, merged);
      });

      _log('☁️ $tag success');
      return true;
    } catch (e) {
      _log('🔴 $tag failed: $e');
      return false;
    }
  }

  Map<String, dynamic> _mergeSettings(
    Map<String, dynamic> server,
    Map<String, dynamic> incoming,
  ) {
    final sTs = _asInt(server['clientUpdatedAtMs']);
    final iTs = _asInt(incoming['clientUpdatedAtMs']);
    final chooseIncoming = (iTs ?? 0) >= (sTs ?? 0);
    return chooseIncoming
        ? <String, dynamic>{...server, ...incoming}
        : <String, dynamic>{...incoming, ...server};
  }


  /// Delta shape:
  /// {
  ///  "schemaVersion": 2,
  ///  "clientUpdatedAtMs": <int>,
  ///  "deviceId": <string>,
  ///  "upserts": { "articles": {k: map}, "magazines": {k: map}, "newspapers": {k: map} },
  ///  "deletes": { "articles": {k: ts},  "magazines": {k: ts},  "newspapers": {k: ts} }
  /// }
  Future<bool> _applyFavoritesDeltaTransaction({
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> delta,
    required String tag,
  }) async {
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final server = (snap.data() ?? <String, dynamic>{});

        final s = _ensureFavoritesNormalized(server);

        final deletes =
            (delta['deletes'] is Map)
                ? (delta['deletes'] as Map).cast<String, dynamic>()
                : <String, dynamic>{};
        final upserts =
            (delta['upserts'] is Map)
                ? (delta['upserts'] as Map).cast<String, dynamic>()
                : <String, dynamic>{};

        _applyDeletesToNormalized(s, deletes, delta);
        _applyUpsertsToNormalized(s, upserts, delta);

       
        s['schemaVersion'] = _schemaVersion;
        s['deviceId'] = delta['deviceId'] ?? s['deviceId'] ?? _deviceId;
        s['clientUpdatedAtMs'] =
            delta['clientUpdatedAtMs'] ?? s['clientUpdatedAtMs'];
        s['updatedAt'] = FieldValue.serverTimestamp();

        final legacy = _favoritesNormalizedToLegacyArrays(s);
        s.addAll(legacy);

        tx.set(ref, s);
      });

      _log('☁️ $tag success');
      return true;
    } catch (e) {
      _log('🔴 $tag failed: $e');
      return false;
    }
  }

  void _applyDeletesToNormalized(
    Map<String, dynamic> normalized,
    Map<String, dynamic> deletes,
    Map<String, dynamic> delta,
  ) {
    final tomb =
        (normalized['tombstones'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    void applyEntity(String entity) {
      final entityDeletes =
          (deletes[entity] is Map)
              ? (deletes[entity] as Map).cast<String, dynamic>()
              : <String, dynamic>{};
      if (entityDeletes.isEmpty) return;

      final tMap =
          (tomb[entity] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final storeMap =
          (normalized['${entity}ByKey'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      entityDeletes.forEach((key, tsVal) {
        final ts = _asInt(tsVal) ?? _asInt(delta['clientUpdatedAtMs']) ?? 0;

        final existingTs = _asInt(tMap[key]) ?? 0;
        if (ts >= existingTs) {
          tMap[key] = ts;
          storeMap.remove(key);
        }
      });

      tomb[entity] = tMap;
      normalized['${entity}ByKey'] = storeMap;
    }

    applyEntity('articles');
    applyEntity('magazines');
    applyEntity('newspapers');

    normalized['tombstones'] = tomb;
  }

  void _applyUpsertsToNormalized(
    Map<String, dynamic> normalized,
    Map<String, dynamic> upserts,
    Map<String, dynamic> delta,
  ) {
    final tomb =
        (normalized['tombstones'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    void applyEntity(String entity) {
      final entityUpserts =
          (upserts[entity] is Map)
              ? (upserts[entity] as Map).cast<String, dynamic>()
              : <String, dynamic>{};
      if (entityUpserts.isEmpty) return;

      final tMap =
          (tomb[entity] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final storeMap =
          (normalized['${entity}ByKey'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final incomingTs = _asInt(delta['clientUpdatedAtMs']) ?? 0;

      entityUpserts.forEach((key, value) {
        final tombTs = _asInt(tMap[key]) ?? 0;
        if (tombTs > incomingTs) {
          return; 
        }
        if (value is Map) {
          storeMap[key] = value.cast<String, dynamic>();
        }
      });

      normalized['${entity}ByKey'] = storeMap;
      normalized['tombstones'] = tomb;
    }

    applyEntity('articles');
    applyEntity('magazines');
    applyEntity('newspapers');
  }


  Map<String, dynamic> _computeFavoritesDelta({
    required Map<String, dynamic> previous,
    required Map<String, dynamic> current,
    required int nowMs,
  }) {
    final prevA = (previous['articlesByKey'] as Map).cast<String, dynamic>();
    final prevM = (previous['magazinesByKey'] as Map).cast<String, dynamic>();
    final prevN = (previous['newspapersByKey'] as Map).cast<String, dynamic>();

    final curA = (current['articlesByKey'] as Map).cast<String, dynamic>();
    final curM = (current['magazinesByKey'] as Map).cast<String, dynamic>();
    final curN = (current['newspapersByKey'] as Map).cast<String, dynamic>();

    final upserts = <String, dynamic>{
      'articles': <String, dynamic>{},
      'magazines': <String, dynamic>{},
      'newspapers': <String, dynamic>{},
    };
    final deletes = <String, dynamic>{
      'articles': <String, dynamic>{},
      'magazines': <String, dynamic>{},
      'newspapers': <String, dynamic>{},
    };

    void diffMaps(
      Map<String, dynamic> prev,
      Map<String, dynamic> cur,
      String entity,
    ) {
   
      for (final entry in cur.entries) {
        final k = entry.key;
        final v = entry.value;
        final pv = prev[k];
        if (pv == null || !_deepEqualsJson(pv, v)) {
          (upserts[entity] as Map<String, dynamic>)[k] = v;
        }
      }


      for (final entry in prev.entries) {
        final k = entry.key;
        if (!cur.containsKey(k)) {
          (deletes[entity] as Map<String, dynamic>)[k] = nowMs;
        }
      }
    }

    diffMaps(prevA, curA, 'articles');
    diffMaps(prevM, curM, 'magazines');
    diffMaps(prevN, curN, 'newspapers');

    return <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'clientUpdatedAtMs': nowMs,
      'deviceId': _deviceId,
      'upserts': upserts,
      'deletes': deletes,
    };
  }

  bool _deepEqualsJson(dynamic a, dynamic b) {
    try {
      return jsonEncode(a) == jsonEncode(b);
    } catch (_) {
      return a == b;
    }
  }

  bool _isEmptyDelta(Map<String, dynamic> delta) {
    final up = (delta['upserts'] as Map?) ?? const {};
    final del = (delta['deletes'] as Map?) ?? const {};
    bool emptyEntity(Map? m) =>
        (m == null) || m.values.every((v) => v is Map && v.isEmpty);

    return emptyEntity(up) && emptyEntity(del);
  }

  Future<void> _enqueuePendingDelta(
    String key,
    Map<String, dynamic> delta,
  ) async {
    final existing = _readPendingDelta(key);
    final merged = (existing == null) ? delta : _mergeDeltas(existing, delta);
    await _prefs!.setString(key, jsonEncode(merged));
  }

  Map<String, dynamic>? _readPendingDelta(String key) {
    final s = _prefs?.getString(key);
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      return v is Map ? v.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _mergeDeltas(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final out = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'clientUpdatedAtMs':
          (_asInt(b['clientUpdatedAtMs']) ??
              _asInt(a['clientUpdatedAtMs']) ??
              0),
      'deviceId': b['deviceId'] ?? a['deviceId'] ?? _deviceId,
      'upserts': <String, dynamic>{
        'articles': <String, dynamic>{},
        'magazines': <String, dynamic>{},
        'newspapers': <String, dynamic>{},
      },
      'deletes': <String, dynamic>{
        'articles': <String, dynamic>{},
        'magazines': <String, dynamic>{},
        'newspapers': <String, dynamic>{},
      },
    };

    void mergeEntity(String entity) {
      final aUp =
          ((a['upserts'] as Map?)?[entity] as Map?)?.cast<String, dynamic>() ??
          {};
      final bUp =
          ((b['upserts'] as Map?)?[entity] as Map?)?.cast<String, dynamic>() ??
          {};
      final aDel =
          ((a['deletes'] as Map?)?[entity] as Map?)?.cast<String, dynamic>() ??
          {};
      final bDel =
          ((b['deletes'] as Map?)?[entity] as Map?)?.cast<String, dynamic>() ??
          {};

      final up = <String, dynamic>{...aUp, ...bUp};

  
      final del = <String, dynamic>{...aDel};
      bDel.forEach((k, ts) {
        final cur = _asInt(del[k]) ?? 0;
        final nxt = _asInt(ts) ?? 0;
        if (nxt >= cur) del[k] = nxt;
      });


      for (final k in del.keys) {
        up.remove(k);
      }

      (out['upserts'] as Map<String, dynamic>)[entity] = up;
      (out['deletes'] as Map<String, dynamic>)[entity] = del;
    }

    mergeEntity('articles');
    mergeEntity('magazines');
    mergeEntity('newspapers');

    return out;
  }


  Map<String, dynamic> _normalizeFavoritesState({
    required List<NewsArticle> articles,
    required List<Map<String, dynamic>> magazines,
    required List<Map<String, dynamic>> newspapers,
    Map<String, dynamic>? baseTombstones,
  }) {
    final aBy = <String, dynamic>{};
    for (final a in articles) {
      final m = a.toMap();
      final k = _articleKey(m);
      if (k.isNotEmpty) aBy[k] = m;
    }

    final mBy = <String, dynamic>{};
    for (final m in magazines) {
      final k = _kvKey(m);
      if (k.isNotEmpty) mBy[k] = m;
    }

    final nBy = <String, dynamic>{};
    for (final n in newspapers) {
      final k = _kvKey(n);
      if (k.isNotEmpty) nBy[k] = n;
    }

    return <String, dynamic>{
      'articlesByKey': aBy,
      'magazinesByKey': mBy,
      'newspapersByKey': nBy,
      'tombstones':
          baseTombstones ??
          <String, dynamic>{
            'articles': <String, dynamic>{},
            'magazines': <String, dynamic>{},
            'newspapers': <String, dynamic>{},
          },
    };
  }

  String _articleKey(Map<String, dynamic> m) =>
      (m['url'] ?? m['link'] ?? m['id'] ?? m['title'] ?? '').toString().trim();

  String _kvKey(Map<String, dynamic> m) =>
      (m['url'] ?? m['name'] ?? m['id'] ?? '').toString().trim();

  Map<String, dynamic> _ensureFavoritesNormalized(Map<String, dynamic>? raw) {
    final r = raw ?? <String, dynamic>{};

    if (r['articlesByKey'] is Map && r['tombstones'] is Map) {
      return <String, dynamic>{
        'schemaVersion': r['schemaVersion'] ?? _schemaVersion,
        'clientUpdatedAtMs': r['clientUpdatedAtMs'],
        'deviceId': r['deviceId'],
        'articlesByKey': (r['articlesByKey'] as Map).cast<String, dynamic>(),
        'magazinesByKey':
            ((r['magazinesByKey'] as Map?) ?? {}).cast<String, dynamic>(),
        'newspapersByKey':
            ((r['newspapersByKey'] as Map?) ?? {}).cast<String, dynamic>(),
        'tombstones': (r['tombstones'] as Map).cast<String, dynamic>(),
      };
    }

    final legacyArticles = _asListMap(r['articles']);
    final legacyMag = _asListMap(r['magazines']);
    final legacyNews = _asListMap(r['newspapers']);

    final aBy = <String, dynamic>{};
    for (final m in legacyArticles) {
      final k = _articleKey(m);
      if (k.isNotEmpty) aBy[k] = m;
    }

    final mBy = <String, dynamic>{};
    for (final m in legacyMag) {
      final k = _kvKey(m);
      if (k.isNotEmpty) mBy[k] = m;
    }

    final nBy = <String, dynamic>{};
    for (final m in legacyNews) {
      final k = _kvKey(m);
      if (k.isNotEmpty) nBy[k] = m;
    }

    return <String, dynamic>{
      'schemaVersion': r['schemaVersion'] ?? _schemaVersion,
      'clientUpdatedAtMs': r['clientUpdatedAtMs'],
      'deviceId': r['deviceId'],
      'articlesByKey': aBy,
      'magazinesByKey': mBy,
      'newspapersByKey': nBy,
      'tombstones': <String, dynamic>{
        'articles': <String, dynamic>{},
        'magazines': <String, dynamic>{},
        'newspapers': <String, dynamic>{},
      },
    };
  }

  Map<String, dynamic> _favoritesNormalizedToLegacyArrays(
    Map<String, dynamic> norm,
  ) {
    final a =
        (norm['articlesByKey'] as Map).values
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
    final m =
        (norm['magazinesByKey'] as Map).values
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
    final n =
        (norm['newspapersByKey'] as Map).values
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
    return <String, dynamic>{'articles': a, 'magazines': m, 'newspapers': n};
  }

  Map<String, dynamic>? _favoritesServerToLegacy(Map<String, dynamic>? server) {
    if (server == null) return null;
    if (server['articles'] is List &&
        server['magazines'] is List &&
        server['newspapers'] is List) {
      return <String, dynamic>{
        'articles': server['articles'],
        'magazines': server['magazines'],
        'newspapers': server['newspapers'],
      };
    }
    final norm = _ensureFavoritesNormalized(server);
    return _favoritesNormalizedToLegacyArrays(norm);
  }

  Map<String, dynamic>? _favoritesShadowToLegacy(Map<String, dynamic>? shadow) {
    if (shadow == null) return null;
    return _favoritesServerToLegacy(shadow);
  }

 
  Future<void> _clearPending(String key) async {
    await _prefs!.remove(key);
  }

  List<Map<String, dynamic>> _asListMap(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _writeShadow(String key, Map<String, dynamic> payload) async {
    try {
      await _prefs!.setString(key, jsonEncode(_jsonSafe(payload)));
    } catch (e) {
      _logger.error('Failed to write shadow', e);
    }
  }

  Map<String, dynamic>? _readShadow(String key) {
    final s = _prefs?.getString(key);
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      return v is Map ? v.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _jsonSafe(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((k, v) {
      if (v is FieldValue) return;
      if (v is Map) {
        out[k] = _jsonSafe(v.cast<String, dynamic>());
      } else if (v is List) {
        out[k] =
            v.map((e) {
              if (e is Map) return _jsonSafe(e.cast<String, dynamic>());
              return e;
            }).toList();
      } else {
        out[k] = v;
      }
    });
    return out;
  }


  void _log(String msg) {
    _logger.info(msg);
  }
}
