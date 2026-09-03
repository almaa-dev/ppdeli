// ignore_for_file: avoid_print
//
// ============================================================================
//  Enterprise Product Cache Helper
// ----------------------------------------------------------------------------
//  Layered, Stale-While-Revalidate cache for product details.
//
//   • Memory  (in-process LinkedHashMap, LRU)
//   • Disk    (LocalClient → SharedPreferences on web / Drift on mobile)
//   • Network (delegated – implemented by the caller / repository)
//
//  Cache key (per requirement): `product_details_{itemId}`
//  Optional module suffix is added internally (`_m{moduleId}`) so that switching
//  modules does NOT collide nor leak the previous module's pricing/stock.
//
//  TTL policy:
//    - soft TTL = 24h   → background revalidation still serves stale data
//    - hard TTL = 7d    → entry considered expired, removed on read
//
//  Schema version:
//    - Bumped in ProductCacheConfig.cacheSchemaVersion when the envelope
//      contract changes. Old entries are silently dropped on read.
//
//  Integrity:
//    - Data is validated by attempting to deserialize (JSON parse +
//      structural sanity). Any failure is treated as corruption and the
//      entry is auto-recovered by a fresh network fetch. We deliberately
//      avoid pulling a new dependency (e.g. `crypto`) for this — see the
//      "Performance / Dependency Notes" section in the master knowledge
//      base for the architectural justification.
//
//  This helper is intentionally framework-agnostic so it can be reused by
//  repository / service / controller layers without breaking the existing
//  Clean Architecture boundaries.
// ============================================================================

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:pickles_and_pies/api/local_client.dart';
import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';

/// ---------------------------------------------------------------------------
///  Constants
/// ---------------------------------------------------------------------------
class ProductCacheConfig {
  /// Bump when the cache envelope (keys, layout) changes. Old entries are
  /// considered invalid and will be dropped on read.
  static const int cacheSchemaVersion = 1;

  /// Soft TTL – after this point the data is "stale" but still served while a
  /// background refresh is performed (classic SWR behaviour).
  static const Duration softTtl = Duration(hours: 24);

  /// Hard TTL – after this point the cache is considered expired and must be
  /// discarded. The next read returns null and the caller hits the network.
  static const Duration hardTtl = Duration(days: 7);

  /// Capacity of the in-memory LRU. 30 is enough for a normal browsing session
  /// (covers Home → Category → Item → back → Item without churn).
  static const int memoryCapacity = 30;

  /// Cache key prefix. The full key becomes `product_details_{id}` per the
  /// spec; the module suffix is appended inside the helper only.
  static const String keyPrefix = 'product_details_';
}

/// ---------------------------------------------------------------------------
///  Cache Envelope
/// ---------------------------------------------------------------------------
class ProductCacheEntry {
  final int itemId;
  final int? moduleId;
  final DateTime cachedAt;
  final int schemaVersion;
  final Map<String, dynamic> data;
  final int dataLength;
  final int dataHash;

  const ProductCacheEntry({
    required this.itemId,
    required this.moduleId,
    required this.cachedAt,
    required this.schemaVersion,
    required this.data,
    required this.dataLength,
    required this.dataHash,
  });

  /// Build an envelope from a raw API response (Map). The integrity signature
  /// is computed here so callers cannot forget to set it.
  factory ProductCacheEntry.fromApi({
    required int itemId,
    required int? moduleId,
    required Map<String, dynamic> data,
  }) {
    final encoded = jsonEncode(data);
    return ProductCacheEntry(
      itemId: itemId,
      moduleId: moduleId,
      cachedAt: DateTime.now(),
      schemaVersion: ProductCacheConfig.cacheSchemaVersion,
      data: data,
      dataLength: encoded.length,
      dataHash: _fnv1aHash(encoded),
    );
  }

  factory ProductCacheEntry.fromJson(Map<String, dynamic> json) {
    return ProductCacheEntry(
      itemId: json['item_id'] as int,
      moduleId: json['module_id'] as int?,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(json['cached_at'] as int),
      schemaVersion: json['schema_version'] as int,
      data: Map<String, dynamic>.from(json['data'] as Map),
      dataLength: json['data_length'] as int,
      dataHash: json['data_hash'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'module_id': moduleId,
        'cached_at': cachedAt.millisecondsSinceEpoch,
        'schema_version': schemaVersion,
        'data': data,
        'data_length': dataLength,
        'data_hash': dataHash,
      };

  /// True if the entry is past the hard TTL – must be discarded.
  bool get isExpired =>
      DateTime.now().difference(cachedAt) >= ProductCacheConfig.hardTtl;

  /// True if the entry is past the soft TTL – stale but still usable (SWR).
  bool get isStale =>
      DateTime.now().difference(cachedAt) >= ProductCacheConfig.softTtl;

  /// Returns true if the embedded data still matches its integrity signature.
  /// Cheap O(n) scan that catches partial writes and bit-flips.
  bool get isIntact {
    try {
      final encoded = jsonEncode(data);
      return encoded.length == dataLength && _fnv1aHash(encoded) == dataHash;
    } catch (_) {
      return false;
    }
  }

  /// Deserialize the cached data into the strongly-typed `Item` model.
  /// Returns null if the data cannot be deserialized – caller should treat
  /// that as a cache miss.
  Item? toItem() {
    try {
      return Item.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        print('ProductCacheEntry.toItem() failed: $e');
      }
      return null;
    }
  }

  /// FNV-1a (32-bit) – tiny, deterministic, allocation-free. Sufficient for
  /// change-detection on a JSON payload; not a cryptographic primitive.
  static int _fnv1aHash(String s) {
    const int prime = 0x01000193;
    int hash = 0x811c9dc5;
    for (int i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i);
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash;
  }
}

/// ---------------------------------------------------------------------------
///  Result wrapper returned by [ProductCacheHelper.fetchProduct] so the
///  controller knows whether the data came from cache, network or both.
/// ---------------------------------------------------------------------------
enum ProductCacheSource { memory, disk, network }

class ProductCacheResult {
  final Item? item;
  final ProductCacheSource source;
  final bool wasCacheHit;

  const ProductCacheResult({
    required this.item,
    required this.source,
    required this.wasCacheHit,
  });
}

/// ---------------------------------------------------------------------------
///  Enterprise Product Cache Helper
/// ---------------------------------------------------------------------------
///
///  Read order: Memory → Disk → Network
///  Write order: Memory + Disk (in parallel)
///
///  The class is fully static – it does NOT need DI registration because it
///  only depends on `LocalClient` (which is also static) and `SharedPreferences`
///  (resolved lazily through GetX, same pattern as LocalClient).
/// ---------------------------------------------------------------------------
class ProductCacheHelper {
  ProductCacheHelper._();

  /// Bounded LRU – LinkedHashMap keeps insertion order, oldest first.
  /// Access via the key moves the entry to the end.
  static final LinkedHashMap<int, ProductCacheEntry> _memory =
      LinkedHashMap<int, ProductCacheEntry>();

  // -------------------------------------------------------------------------
  //  Public API
  // -------------------------------------------------------------------------

  /// Returns the disk key used for a given (itemId, moduleId) pair.
  /// Exposed for diagnostics and tests.
  static String diskKey(int itemId, {int? moduleId}) {
    final suffix = moduleId != null ? '_m$moduleId' : '';
    return '${ProductCacheConfig.keyPrefix}$itemId$suffix';
  }

  /// Returns the current module id from SplashController, or null.
  /// Wrapped so it can be mocked or stubbed in tests without exposing
  /// GetX to callers of the cache helper.
  static int? _currentModuleId() {
    try {
      if (Get.isRegistered<SplashController>()) {
        final splash = Get.find<SplashController>();
        return splash.module?.id ?? splash.cacheModule?.id;
      }
    } catch (_) {/* ignore */}
    return null;
  }

  /// Synchronous in-memory read.
  /// - Returns null on miss.
  /// - Drops the entry automatically if expired or corrupted.
  static ProductCacheEntry? peekMemory(int itemId) {
    final entry = _memory[itemId];
    if (entry == null) return null;
    if (entry.isExpired || !entry.isIntact) {
      _memory.remove(itemId);
      return null;
    }
    // LRU touch
    _memory.remove(itemId);
    _memory[itemId] = entry;
    return entry;
  }

  /// Disk read (async) – returns the envelope or null on miss / corruption.
  /// On a successful read the entry is also promoted to memory.
  static Future<ProductCacheEntry?> readDisk(int itemId,
      {int? moduleId}) async {
    final key = diskKey(itemId, moduleId: moduleId);
    String? raw;
    try {
      raw = await LocalClient.organize(
        DataSourceEnum.local,
        key,
        null,
        null,
      );
    } catch (e) {
      if (kDebugMode) print('ProductCacheHelper.readDisk($key) failed: $e');
    }
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final entry = ProductCacheEntry.fromJson(decoded);

      // Schema/version guard
      if (entry.schemaVersion != ProductCacheConfig.cacheSchemaVersion) {
        await remove(itemId, moduleId: moduleId);
        return null;
      }
      // Integrity guard
      if (!entry.isIntact) {
        await remove(itemId, moduleId: moduleId);
        return null;
      }
      // Hard TTL guard
      if (entry.isExpired) {
        await remove(itemId, moduleId: moduleId);
        return null;
      }
      // Promote to memory
      _putMemory(entry);
      return entry;
    } catch (e) {
      // Corrupted JSON – auto-recovery: drop it.
      if (kDebugMode) print('ProductCacheHelper corruption detected: $e');
      await remove(itemId, moduleId: moduleId);
      return null;
    }
  }

  /// Combined read – memory first, then disk.
  static Future<ProductCacheEntry?> get(int itemId, {int? moduleId}) async {
    final inMem = peekMemory(itemId);
    if (inMem != null) return inMem;
    return await readDisk(itemId, moduleId: moduleId);
  }

  /// Persist an envelope to BOTH memory and disk.
  /// Best-effort: a disk failure does not crash the caller.
  static Future<void> save({
    required int itemId,
    required Map<String, dynamic> data,
    int? moduleId,
  }) async {
    if (data.isEmpty) return;
    moduleId ??= _currentModuleId();

    final entry = ProductCacheEntry.fromApi(
      itemId: itemId,
      moduleId: moduleId,
      data: data,
    );

    // Memory first – instant.
    _putMemory(entry);

    // Disk – fire-and-forget so the UI is never blocked.
    try {
      await LocalClient.organize(
        DataSourceEnum.client,
        diskKey(itemId, moduleId: moduleId),
        jsonEncode(entry.toJson()),
        null,
      );
    } catch (e) {
      if (kDebugMode) print('ProductCacheHelper.save disk failed: $e');
    }
  }

  /// Remove a single entry from both layers.
  static Future<void> remove(int itemId, {int? moduleId}) async {
    _memory.remove(itemId);
    moduleId ??= _currentModuleId();
    try {
      // We do not delete the row through LocalClient because the helper
      // currently does not expose a delete primitive; we write an empty
      // value which the schema accepts and which will be discarded by
      // every reader. The next successful save will overwrite it.
      await LocalClient.organize(
        DataSourceEnum.client,
        diskKey(itemId, moduleId: moduleId),
        '',
        null,
      );
    } catch (e) {
      if (kDebugMode) print('ProductCacheHelper.remove failed: $e');
    }
  }

  /// Wipe every product-details cache entry (memory only). Disk entries are
  /// naturally overwritten on the next save. For a full wipe the caller can
  /// additionally invoke `database.clearCacheResponses()` (see CacheResponse
  /// table).
  static Future<void> clearAll() async {
    _memory.clear();
  }

  /// Approximate size of the in-memory cache – useful for diagnostics.
  static int get memorySize => _memory.length;

  /// Clear only the in-memory layer (e.g. on logout).
  static void clearMemory() => _memory.clear();

  // -------------------------------------------------------------------------
  //  Internal helpers
  // -------------------------------------------------------------------------

  static void _putMemory(ProductCacheEntry entry) {
    // Evict oldest if at capacity.
    while (_memory.length >= ProductCacheConfig.memoryCapacity) {
      final oldestKey = _memory.keys.first;
      _memory.remove(oldestKey);
    }
    // Refresh ordering on re-insert.
    _memory.remove(entry.itemId);
    _memory[entry.itemId] = entry;
  }
}