import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:pickles_and_pies/features/address/domain/models/address_model.dart';
import 'package:pickles_and_pies/features/language/controllers/language_controller.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_model.dart';
import 'package:pickles_and_pies/helper/address_helper.dart';
import 'package:pickles_and_pies/helper/module_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for the store-details cache.
class StoreCacheConfig {
  StoreCacheConfig._();

  /// Bump whenever the persisted envelope contract changes.
  static const int cacheSchemaVersion = 1;

  /// A stale entry is still displayed and revalidated in the background.
  /// Expiry never deletes an otherwise valid store-details snapshot.
  static const Duration cacheTtl = Duration(hours: 24);

  /// Keeps repeated store visits instant without retaining unbounded payloads.
  static const int memoryCapacity = 20;

  static const String keyPrefix = 'store_details_';
  static const String legacyKeyPrefix = 'cached_store_details_';
}

/// Every request input proven by the current API headers to affect the response.
@immutable
class StoreCacheIdentity {
  final int storeId;
  final int? moduleId;
  final String languageCode;
  final List<int> zoneIds;
  final String latitude;
  final String longitude;

  const StoreCacheIdentity({
    required this.storeId,
    required this.moduleId,
    required this.languageCode,
    required this.zoneIds,
    required this.latitude,
    required this.longitude,
  });

  factory StoreCacheIdentity.current({
    required int storeId,
    String? languageCode,
    int? moduleId,
    AddressModel? address,
  }) {
    AddressModel? resolvedAddress = address;
    try {
      resolvedAddress ??= AddressHelper.getUserAddressFromSharedPref();
    } catch (_) {
      resolvedAddress = null;
    }

    String resolvedLanguage = languageCode ?? 'en';
    try {
      if (languageCode == null && Get.isRegistered<LocalizationController>()) {
        resolvedLanguage = Get.find<LocalizationController>().locale.languageCode;
      }
    } catch (_) {
      // The explicit/default language is sufficient during early startup.
    }

    int? resolvedModule = moduleId;
    try {
      resolvedModule ??=
          ModuleHelper.getModule()?.id ?? ModuleHelper.getCacheModule()?.id;
    } catch (_) {
      // A null module is a valid context and receives its own identity.
    }

    final zones = List<int>.from(resolvedAddress?.zoneIds ?? const <int>[])
      ..sort();
    return StoreCacheIdentity(
      storeId: storeId,
      moduleId: resolvedModule,
      languageCode: resolvedLanguage.toLowerCase(),
      zoneIds: List<int>.unmodifiable(zones),
      latitude: _normalizeCoordinate(resolvedAddress?.latitude),
      longitude: _normalizeCoordinate(resolvedAddress?.longitude),
    );
  }

  static String _normalizeCoordinate(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null ? '0' : number.toStringAsFixed(4);
  }

  String get contextFingerprint {
    final canonical = '${moduleId ?? 0}|$languageCode|${zoneIds.join(',')}|'
        '$latitude|$longitude';
    return _fnv1aHash(canonical).toRadixString(16).padLeft(8, '0');
  }

  String get diskKey =>
      '${StoreCacheConfig.keyPrefix}${storeId}_c${contextFingerprint}_v${StoreCacheConfig.cacheSchemaVersion}';

  String get storeKeyPrefix => '${StoreCacheConfig.keyPrefix}${storeId}_';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'store_id': storeId,
        'module_id': moduleId,
        'language_code': languageCode,
        'zone_ids': zoneIds,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory StoreCacheIdentity.fromJson(Map<String, dynamic> json) {
    final rawZones = json['zone_ids'];
    return StoreCacheIdentity(
      storeId: _requiredInt(json['store_id']),
      moduleId: _optionalInt(json['module_id']),
      languageCode: json['language_code'] as String,
      zoneIds: List<int>.unmodifiable(
        rawZones is List
            ? rawZones.map<int>((dynamic value) => _requiredInt(value)).toList()
            : const <int>[],
      ),
      latitude: json['latitude'] as String,
      longitude: json['longitude'] as String,
    );
  }

  bool matches(StoreCacheIdentity other) =>
      storeId == other.storeId && contextFingerprint == other.contextFingerprint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreCacheIdentity &&
          storeId == other.storeId &&
          contextFingerprint == other.contextFingerprint;

  @override
  int get hashCode => Object.hash(storeId, contextFingerprint);

  static int _requiredInt(dynamic value) {
    if (value is int) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) throw const FormatException('Expected integer');
    return parsed;
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) return null;
    return _requiredInt(value);
  }
}

/// Schema-versioned, integrity-checked envelope containing the full API JSON.
@immutable
class StoreCacheEntry {
  final StoreCacheIdentity identity;
  final DateTime cachedAt;
  final int schemaVersion;
  final Map<String, dynamic> data;
  final int dataLength;
  final int dataHash;
  final bool invalidated;

  const StoreCacheEntry({
    required this.identity,
    required this.cachedAt,
    required this.schemaVersion,
    required this.data,
    required this.dataLength,
    required this.dataHash,
    this.invalidated = false,
  });

  factory StoreCacheEntry.fromApi({
    required StoreCacheIdentity identity,
    required Map<String, dynamic> data,
    DateTime? cachedAt,
  }) {
    final immutableData = Map<String, dynamic>.from(data);
    final encoded = _canonicalJson(immutableData);
    return StoreCacheEntry(
      identity: identity,
      cachedAt: cachedAt ?? DateTime.now(),
      schemaVersion: StoreCacheConfig.cacheSchemaVersion,
      data: immutableData,
      dataLength: encoded.length,
      dataHash: _fnv1aHash(encoded),
    );
  }

  factory StoreCacheEntry.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final rawIdentity = json['identity'];
    if (rawData is! Map || rawIdentity is! Map) {
      throw const FormatException('Invalid store cache envelope');
    }
    return StoreCacheEntry(
      identity: StoreCacheIdentity.fromJson(
        Map<String, dynamic>.from(rawIdentity),
      ),
      cachedAt: DateTime.fromMillisecondsSinceEpoch(
        StoreCacheIdentity._requiredInt(json['cached_at']),
      ),
      schemaVersion: StoreCacheIdentity._requiredInt(json['schema_version']),
      data: Map<String, dynamic>.from(rawData),
      dataLength: StoreCacheIdentity._requiredInt(json['data_length']),
      dataHash: StoreCacheIdentity._requiredInt(json['data_hash']),
      invalidated: json['invalidated'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'identity': identity.toJson(),
        'cached_at': cachedAt.millisecondsSinceEpoch,
        'schema_version': schemaVersion,
        'data': data,
        'data_length': dataLength,
        'data_hash': dataHash,
        'invalidated': invalidated,
      };

  bool get isStale =>
      invalidated ||
      DateTime.now().difference(cachedAt) >= StoreCacheConfig.cacheTtl;

  bool get isIntact {
    try {
      final encoded = _canonicalJson(data);
      return encoded.length == dataLength && _fnv1aHash(encoded) == dataHash;
    } catch (_) {
      return false;
    }
  }

  Store? toStore() {
    try {
      return Store.fromJson(Map<String, dynamic>.from(data));
    } catch (error) {
      _log('CORRUPTED model=${identity.storeId} error=$error');
      return null;
    }
  }

  StoreCacheEntry invalidate() => StoreCacheEntry(
        identity: identity,
        cachedAt: cachedAt,
        schemaVersion: schemaVersion,
        data: data,
        dataLength: dataLength,
        dataHash: dataHash,
        invalidated: true,
      );
}

/// L1 memory + L2 SharedPreferences cache for full store-detail responses.
class StoreCacheService extends GetxService {
  final SharedPreferences sharedPreferences;

  StoreCacheService({required this.sharedPreferences});

  final LinkedHashMap<String, StoreCacheEntry> _memory =
      LinkedHashMap<String, StoreCacheEntry>();

  StoreCacheEntry? peekMemory(StoreCacheIdentity identity) {
    final key = identity.diskKey;
    final entry = _memory[key];
    if (entry == null) {
      _log('MISS layer=L1 store=${identity.storeId}');
      return null;
    }
    if (!_validateEntry(entry, identity)) {
      _memory.remove(key);
      _log('CORRUPTED layer=L1 store=${identity.storeId}');
      return null;
    }
    _memory.remove(key);
    _memory[key] = entry;
    _log('${entry.isStale ? 'STALE' : 'HIT'} layer=L1 store=${identity.storeId}');
    return entry;
  }

  /// SharedPreferences is preloaded before runApp, so this L2 read is sync and
  /// can populate the controller before StoreScreen's first build.
  StoreCacheEntry? readDiskSync(StoreCacheIdentity identity) {
    final key = identity.diskKey;
    final raw = sharedPreferences.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      _log('MISS layer=L2 store=${identity.storeId}');
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Envelope is not an object');
      final entry = StoreCacheEntry.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (!_validateEntry(entry, identity)) {
        throw const FormatException('Entry validation failed');
      }
      _putMemory(entry);
      _log('${entry.isStale ? 'STALE' : 'HIT'} layer=L2 store=${identity.storeId}');
      return entry;
    } catch (error) {
      sharedPreferences.remove(key);
      _memory.remove(key);
      _log('CORRUPTED layer=L2 store=${identity.storeId} error=$error');
      return null;
    }
  }

  StoreCacheEntry? getSync(StoreCacheIdentity identity) =>
      peekMemory(identity) ?? readDiskSync(identity);

  Future<bool> save({
    required StoreCacheIdentity identity,
    required Map<String, dynamic> fullJson,
  }) async {
    if (!_validatePayload(fullJson, identity.storeId)) {
      _log('WRITE_REJECTED store=${identity.storeId}');
      return false;
    }

    final entry = StoreCacheEntry.fromApi(identity: identity, data: fullJson);
    final encodedEnvelope = jsonEncode(entry.toJson());

    _putMemory(entry);
    try {
      final saved = await sharedPreferences.setString(identity.diskKey, encodedEnvelope);
      if (saved) {
        // Remove the old lossy controller cache only after a full entry exists.
        await sharedPreferences.remove(
          '${StoreCacheConfig.legacyKeyPrefix}${identity.storeId}',
        );
        _log('UPDATED store=${identity.storeId} bytes=${encodedEnvelope.length}');
      }
      return saved;
    } catch (error) {
      _log('WRITE_FAILED store=${identity.storeId} error=$error');
      return false;
    }
  }

  Future<void> clearStoreCache(int storeId) async {
    _memory.removeWhere((String key, StoreCacheEntry entry) =>
        entry.identity.storeId == storeId);
    final keys = sharedPreferences
        .getKeys()
        .where((String key) =>
            key.startsWith('${StoreCacheConfig.keyPrefix}${storeId}_') ||
            key == '${StoreCacheConfig.legacyKeyPrefix}$storeId')
        .toList(growable: false);
    await Future.wait(keys.map(sharedPreferences.remove));
    _log('CLEARED store=$storeId');
  }

  /// Marks all contexts for one store stale while preserving offline data.
  Future<void> invalidateStoreCache(int storeId) async {
    final keys = sharedPreferences
        .getKeys()
        .where((String key) =>
            key.startsWith('${StoreCacheConfig.keyPrefix}${storeId}_'))
        .toList(growable: false);

    for (final key in keys) {
      final raw = sharedPreferences.getString(key);
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) throw const FormatException();
        final invalidated = StoreCacheEntry.fromJson(
          Map<String, dynamic>.from(decoded),
        ).invalidate();
        _memory[key] = invalidated;
        await sharedPreferences.setString(key, jsonEncode(invalidated.toJson()));
      } catch (_) {
        _memory.remove(key);
        await sharedPreferences.remove(key);
      }
    }
    _log('INVALIDATED store=$storeId');
  }

  Future<void> clearAllStoreDetailsCache() async {
    _memory.clear();
    final keys = sharedPreferences
        .getKeys()
        .where((String key) =>
            key.startsWith(StoreCacheConfig.keyPrefix) ||
            key.startsWith(StoreCacheConfig.legacyKeyPrefix))
        .toList(growable: false);
    await Future.wait(keys.map(sharedPreferences.remove));
    _log('CLEARED_ALL');
  }

  void clearMemory() {
    _memory.clear();
    _log('CLEARED_MEMORY');
  }

  int get memorySize => _memory.length;

  bool _validateEntry(
    StoreCacheEntry entry,
    StoreCacheIdentity expectedIdentity,
  ) {
    return entry.schemaVersion == StoreCacheConfig.cacheSchemaVersion &&
        entry.identity.matches(expectedIdentity) &&
        entry.isIntact &&
        _validatePayload(entry.data, expectedIdentity.storeId) &&
        entry.toStore() != null;
  }

  bool _validatePayload(Map<String, dynamic> data, int expectedStoreId) {
    if (data.isEmpty) return false;
    final id = int.tryParse(data['id']?.toString() ?? '');
    final name = data['name'];
    return id != null &&
        id > 0 &&
        id == expectedStoreId &&
        name is String &&
        name.trim().isNotEmpty;
  }

  void _putMemory(StoreCacheEntry entry) {
    final key = entry.identity.diskKey;
    _memory.remove(key);
    while (_memory.length >= StoreCacheConfig.memoryCapacity) {
      _memory.remove(_memory.keys.first);
    }
    _memory[key] = entry;
  }
}

String _canonicalJson(Object? value) => jsonEncode(value);

int _fnv1aHash(String value) {
  const int prime = 0x01000193;
  int hash = 0x811c9dc5;
  for (int index = 0; index < value.length; index++) {
    hash ^= value.codeUnitAt(index);
    hash = (hash * prime) & 0xFFFFFFFF;
  }
  return hash;
}

void _log(String message) {
  if (kDebugMode) debugPrint('[StoreCache] $message');
}
