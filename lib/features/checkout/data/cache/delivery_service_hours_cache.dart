import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache for `delivery_service_hours` keyed by Store ID.
///
/// This helper mirrors the design of `StoreCacheService`:
///   * Sync, preloaded SharedPreferences (safe to call from controller init).
///   * Store-scoped keys so two different stores cannot share data.
///   * Envelope validation: malformed entries are silently dropped and
///     the caller falls back to the default 08:00-18:00 window.
class DeliveryServiceHoursCache {
  final SharedPreferences sharedPreferences;

  DeliveryServiceHoursCache({required this.sharedPreferences});

  static const String _keyPrefix = 'delivery_service_hours_';

  String _keyFor(int storeId) => '$_keyPrefix$storeId';

  String? readSync(int storeId) {
    final String raw = sharedPreferences.getString(_keyFor(storeId)) ?? '';
    if (raw.isEmpty) {
      _log('MISS store=$storeId');
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Envelope is not a JSON object');
      }
      final dynamic schemaVersion = decoded['schema_version'];
      if (schemaVersion is! int || schemaVersion != 1) {
        throw const FormatException('Schema mismatch');
      }
      _log('HIT store=$storeId');
      return raw;
    } catch (error) {
      _log('CORRUPTED store=$storeId error=$error');
      sharedPreferences.remove(_keyFor(storeId));
      return null;
    }
  }

  Future<void> write(int storeId, String encodedJson) async {
    if (storeId <= 0) return;
    await sharedPreferences.setString(_keyFor(storeId), encodedJson);
    _log('WRITTEN store=$storeId bytes=${encodedJson.length}');
  }

  Future<void> clear(int storeId) async {
    await sharedPreferences.remove(_keyFor(storeId));
    _log('CLEARED store=$storeId');
  }

  Future<void> clearAll() async {
    final Iterable<String> keys = sharedPreferences
        .getKeys()
        .where((String k) => k.startsWith(_keyPrefix));
    for (final String key in keys) {
      await sharedPreferences.remove(key);
    }
    _log('CLEARED_ALL');
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[DeliveryServiceHoursCache] $message');
    }
  }
}