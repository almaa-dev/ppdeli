// ============================================================================
//  Item List Cache Helper
// ----------------------------------------------------------------------------
//  Centralized, module-aware, Stale-While-Revalidate cache for *list* data
//  used by ItemController (popular / reviewed / discounted / featured /
//  recommended / basicMedicine / conditionWise / commonConditions).
//
//  Goals:
//    1. Eliminate code duplication across the 7+ list-fetching methods in
//       ItemController.
//    2. Make cache keys MODULE-aware so that switching the active module
//       (food → grocery → pharmacy) does NOT serve stale data from another
//       module.
//    3. Add a soft TTL (1h) and hard TTL (24h) so the cache is bounded in
//       time, not just in space.
//    4. Use the same LocalClient layer that ProductCacheHelper uses so all
//       caches share the same persistence story (SharedPreferences on web,
//       Drift on mobile).
//    5. Never crash the caller — every failure path logs and returns the
//       pre-existing data unchanged (or null on first load).
//    6. Provide an `invalidateAll()` for the logout flow.
// ============================================================================

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:pickles_and_pies/api/local_client.dart';
import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/item/domain/models/basic_medicine_model.dart';
import 'package:pickles_and_pies/features/item/domain/models/common_condition_model.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';

// ============================================================================
//  Public configuration
// ============================================================================
class ItemListCacheConfig {
  /// Bump whenever the envelope (key layout, schema) changes. Old entries
  /// are silently dropped on read.
  static const int cacheSchemaVersion = 1;

  /// Soft TTL – past this point the data is stale and a background refresh
  /// should fire, but we still serve the cached copy first (SWR).
  static const Duration softTtl = Duration(hours: 1);

  /// Hard TTL – past this point the cache is considered expired and the next
  /// read returns null, forcing a network call.
  static const Duration hardTtl = Duration(hours: 24);

  /// Maximum number of in-memory LRU entries. Per-item (NOT per-module) so
  /// this scales with browsing depth, not module count.
  static const int memoryCapacity = 20;
}

// ============================================================================
//  Public cache keys (single source of truth)
// ============================================================================
/// All known list-cache keys. Use these constants everywhere instead of
/// string literals so renames are refactor-safe.
class ItemListCacheKeys {
  ItemListCacheKeys._();

  static const String popularItems = 'cached_popular_items';
  static const String reviewedItems = 'cached_reviewed_items';
  static const String discountedItems = 'cached_discounted_items';
  static const String featuredItems = 'cached_featured_items';
  static const String recommendedItems = 'cached_recommended_items';
  static const String basicMedicine = 'cached_basic_medicine';
  static const String conditionsWiseItem = 'cached_conditions_wise_item';
  static const String commonConditions = 'cached_common_conditions';

  /// Returns every list-cache key. Useful for "clear all".
  static List<String> get all => const <String>[
        popularItems,
        reviewedItems,
        discountedItems,
        featuredItems,
        recommendedItems,
        basicMedicine,
        conditionsWiseItem,
        commonConditions,
      ];
}

// ============================================================================
//  Envelope that wraps the cached payload + meta.
// ============================================================================
class ItemListCacheEntry {
  final String cacheKey;
  final int? moduleId;
  final int schemaVersion;
  final DateTime cachedAt;
  final Map<String, dynamic> data;

  const ItemListCacheEntry({
    required this.cacheKey,
    required this.moduleId,
    required this.schemaVersion,
    required this.cachedAt,
    required this.data,
  });

  factory ItemListCacheEntry.fromApi({
    required String cacheKey,
    required int? moduleId,
    required Map<String, dynamic> data,
  }) {
    return ItemListCacheEntry(
      cacheKey: cacheKey,
      moduleId: moduleId,
      schemaVersion: ItemListCacheConfig.cacheSchemaVersion,
      cachedAt: DateTime.now(),
      data: data,
    );
  }

  factory ItemListCacheEntry.fromJson(Map<String, dynamic> json) {
    return ItemListCacheEntry(
      cacheKey: json['cache_key'] as String,
      moduleId: json['module_id'] as int?,
      schemaVersion: json['schema_version'] as int,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(json['cached_at'] as int),
      data: Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
        'cache_key': cacheKey,
        'module_id': moduleId,
        'schema_version': schemaVersion,
        'cached_at': cachedAt.millisecondsSinceEpoch,
        'data': data,
      };

  bool get isExpired =>
      DateTime.now().difference(cachedAt) >= ItemListCacheConfig.hardTtl;

  bool get isStale =>
      DateTime.now().difference(cachedAt) >= ItemListCacheConfig.softTtl;

  /// True if this entry belongs to a different module than [currentModuleId].
  bool isStaleForModule(int? currentModuleId) {
    if (moduleId == null) return false;
    return moduleId != currentModuleId;
  }
}

// ============================================================================
//  The helper itself
// ============================================================================
class ItemListCacheHelper {
  ItemListCacheHelper._();

  /// Bounded LRU keyed by `cacheKey` (already module-suffixed when written).
  static final LinkedHashMap<String, ItemListCacheEntry> _memory =
      LinkedHashMap<String, ItemListCacheEntry>();

  // -------------------------------------------------------------------------
  //  Public API
  // -------------------------------------------------------------------------

  /// Returns the on-disk key for a given (cacheKey, moduleId) pair.
  /// Module suffix prevents cross-module cache pollution.
  static String diskKey(String cacheKey, {int? moduleId}) {
    final suffix = (moduleId != null && moduleId > 0) ? '_m$moduleId' : '';
    return '$cacheKey$suffix';
  }

  /// Returns the active module id from SplashController (or null).
  static int? _currentModuleId() {
    try {
      if (Get.isRegistered<SplashController>()) {
        final splash = Get.find<SplashController>();
        return splash.module?.id ?? splash.cacheModule?.id;
      }
    } catch (_) {
      // ignore — caller should treat as no module.
    }
    return null;
  }

  /// Synchronous in-memory read. Returns null on miss / expired /
  /// module-mismatch / corruption.
  static ItemListCacheEntry? peekMemory(String cacheKey,
      {int? moduleId}) {
    final diskK = diskKey(cacheKey, moduleId: moduleId);
    final entry = _memory[diskK];
    if (entry == null) return null;
    if (entry.isExpired) {
      _memory.remove(diskK);
      return null;
    }
    if (entry.isStaleForModule(moduleId ?? _currentModuleId())) {
      _memory.remove(diskK);
      return null;
    }
    // LRU touch
    _memory.remove(diskK);
    _memory[diskK] = entry;
    return entry;
  }

  /// Disk read (async). On hit, the entry is also promoted to memory.
  static Future<ItemListCacheEntry?> readDisk(String cacheKey,
      {int? moduleId}) async {
    final module = moduleId ?? _currentModuleId();
    final key = diskKey(cacheKey, moduleId: module);
    String? raw;
    try {
      raw = await LocalClient.organize(
        DataSourceEnum.local,
        key,
        null,
        null,
      );
    } catch (e) {
      if (kDebugMode) print('ItemListCacheHelper.readDisk($key) failed: $e');
    }
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final entry = ItemListCacheEntry.fromJson(decoded);

      // Schema / version guard
      if (entry.schemaVersion != ItemListCacheConfig.cacheSchemaVersion) {
        await remove(cacheKey, moduleId: module);
        return null;
      }
      // Hard TTL guard
      if (entry.isExpired) {
        await remove(cacheKey, moduleId: module);
        return null;
      }
      // Module mismatch guard
      if (entry.isStaleForModule(module)) {
        await remove(cacheKey, moduleId: module);
        return null;
      }

      _putMemory(entry);
      return entry;
    } catch (e) {
      if (kDebugMode) print('ItemListCacheHelper corruption: $e');
      await remove(cacheKey, moduleId: module);
      return null;
    }
  }

  /// Combined read – memory then disk.
  static Future<ItemListCacheEntry?> get(String cacheKey,
      {int? moduleId}) async {
    final module = moduleId ?? _currentModuleId();
    final inMem = peekMemory(cacheKey, moduleId: module);
    if (inMem != null) return inMem;
    return await readDisk(cacheKey, moduleId: module);
  }

  /// Persist the envelope to BOTH memory and disk. The on-disk write is
  /// fire-and-forget – the caller's UI must not wait on it.
  static Future<void> save({
    required String cacheKey,
    required Map<String, dynamic> data,
    int? moduleId,
  }) async {
    if (data.isEmpty) return;
    final module = moduleId ?? _currentModuleId();
    final entry = ItemListCacheEntry.fromApi(
      cacheKey: cacheKey,
      moduleId: module,
      data: data,
    );

    // Memory first – instant.
    _putMemory(entry);

    // Disk – non-blocking.
    try {
      await LocalClient.organize(
        DataSourceEnum.client,
        diskKey(cacheKey, moduleId: module),
        jsonEncode(entry.toJson()),
        null,
      );
    } catch (e) {
      if (kDebugMode) print('ItemListCacheHelper.save disk failed: $e');
    }
  }

  /// Remove a single entry from both layers.
  static Future<void> remove(String cacheKey, {int? moduleId}) async {
    final module = moduleId ?? _currentModuleId();
    final key = diskKey(cacheKey, moduleId: module);
    _memory.remove(key);
    try {
      await LocalClient.organize(
        DataSourceEnum.client,
        key,
        '',
        null,
      );
    } catch (e) {
      if (kDebugMode) print('ItemListCacheHelper.remove failed: $e');
    }
  }

  /// Invalidate every list-cache entry (memory + disk). Call on logout or
  /// after an explicit user-triggered refresh.
  static Future<void> invalidateAll() async {
    _memory.clear();
    final module = _currentModuleId();
    for (final cacheKey in ItemListCacheKeys.all) {
      try {
        await LocalClient.organize(
          DataSourceEnum.client,
          diskKey(cacheKey, moduleId: module),
          '',
          null,
        );
      } catch (e) {
        if (kDebugMode) print('ItemListCacheHelper.invalidateAll failed: $e');
      }
    }
  }

  /// Approximate number of in-memory entries (for diagnostics/tests).
  static int get memorySize => _memory.length;

  // -------------------------------------------------------------------------
  //  Typed conveniences (deserialize into the model)
  // -------------------------------------------------------------------------

  /// Reads the cache and parses it into an `ItemModel`. Returns null on miss.
  static Future<ItemModel?> getItemModel(String cacheKey,
      {int? moduleId}) async {
    final entry = await get(cacheKey, moduleId: moduleId);
    if (entry == null) return null;
    try {
      return ItemModel.fromJson(entry.data);
    } catch (e) {
      if (kDebugMode) print('ItemListCacheHelper.getItemModel failed: $e');
      return null;
    }
  }

  /// Reads the cache and parses it into a list of `Item`.
  static Future<List<Item>?> getItemList(String cacheKey,
      {int? moduleId}) async {
    final entry = await get(cacheKey, moduleId: moduleId);
    if (entry == null) return null;
    try {
      final list = entry.data['items'];
      if (list is! List) return null;
      return list
          .map((v) => Item.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('ItemListCacheHelper.getItemList failed: $e');
      return null;
    }
  }

  /// Reads the cache and parses it into a `BasicMedicineModel`.
  static Future<BasicMedicineModel?> getBasicMedicine(
      {int? moduleId}) async {
    final entry =
        await get(ItemListCacheKeys.basicMedicine, moduleId: moduleId);
    if (entry == null) return null;
    try {
      return BasicMedicineModel.fromJson(entry.data);
    } catch (e) {
      if (kDebugMode) print('ItemListCacheHelper.getBasicMedicine failed: $e');
      return null;
    }
  }

  /// Reads the cache and parses it into a list of `CommonConditionModel`.
  static Future<List<CommonConditionModel>?> getCommonConditions(
      {int? moduleId}) async {
    final entry =
        await get(ItemListCacheKeys.commonConditions, moduleId: moduleId);
    if (entry == null) return null;
    try {
      final list = entry.data['conditions'];
      if (list is! List) return null;
      return list
          .map((v) => CommonConditionModel.fromJson(v as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('ItemListCacheHelper.getCommonConditions failed: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  //  Internal helpers
  // -------------------------------------------------------------------------

  static void _putMemory(ItemListCacheEntry entry) {
    final key = diskKey(entry.cacheKey, moduleId: entry.moduleId);
    // Evict oldest if at capacity.
    while (_memory.length >= ItemListCacheConfig.memoryCapacity) {
      final oldestKey = _memory.keys.first;
      _memory.remove(oldestKey);
    }
    // Refresh ordering on re-insert.
    _memory.remove(key);
    _memory[key] = entry;
  }
}