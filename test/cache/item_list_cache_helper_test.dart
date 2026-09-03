import 'package:flutter_test/flutter_test.dart';

import 'package:pickles_and_pies/features/item/data/cache/item_list_cache_helper.dart';

void main() {
  group('ItemListCacheConfig', () {
    test('softTtl is shorter than hardTtl', () {
      expect(ItemListCacheConfig.softTtl, lessThan(ItemListCacheConfig.hardTtl));
    });

    test('cacheSchemaVersion is positive', () {
      expect(ItemListCacheConfig.cacheSchemaVersion, greaterThan(0));
    });

    test('memoryCapacity is positive and bounded', () {
      expect(ItemListCacheConfig.memoryCapacity, greaterThan(0));
      expect(ItemListCacheConfig.memoryCapacity, lessThanOrEqualTo(1000));
    });
  });

  group('ItemListCacheKeys', () {
    test('all exposes every cache key', () {
      expect(ItemListCacheKeys.all, contains(ItemListCacheKeys.popularItems));
      expect(ItemListCacheKeys.all, contains(ItemListCacheKeys.reviewedItems));
      expect(ItemListCacheKeys.all, contains(ItemListCacheKeys.discountedItems));
      expect(ItemListCacheKeys.all, contains(ItemListCacheKeys.featuredItems));
      expect(ItemListCacheKeys.all, contains(ItemListCacheKeys.recommendedItems));
      expect(ItemListCacheKeys.all, contains(ItemListCacheKeys.basicMedicine));
      expect(ItemListCacheKeys.all, contains(ItemListCacheKeys.conditionsWiseItem));
      expect(ItemListCacheKeys.all, contains(ItemListCacheKeys.commonConditions));
    });

    test('all keys are unique', () {
      expect(ItemListCacheKeys.all.toSet().length, ItemListCacheKeys.all.length);
    });
  });

  group('ItemListCacheEntry', () {
    test('isExpired returns false for a fresh entry', () {
      final entry = ItemListCacheEntry.fromApi(
        cacheKey: 'k',
        moduleId: 1,
        data: {'x': 1},
      );
      expect(entry.isExpired, false);
    });

    test('isStale returns false for a fresh entry', () {
      final entry = ItemListCacheEntry.fromApi(
        cacheKey: 'k',
        moduleId: 1,
        data: {'x': 1},
      );
      expect(entry.isStale, false);
    });

    test('isStaleForModule returns false when entry has no moduleId', () {
      final entry = ItemListCacheEntry.fromApi(
        cacheKey: 'k',
        moduleId: null,
        data: {},
      );
      expect(entry.isStaleForModule(5), false);
      expect(entry.isStaleForModule(null), false);
    });

    test('isStaleForModule returns false when modules match', () {
      final entry = ItemListCacheEntry.fromApi(
        cacheKey: 'k',
        moduleId: 5,
        data: {},
      );
      expect(entry.isStaleForModule(5), false);
    });

    test('isStaleForModule returns true when modules differ', () {
      final entry = ItemListCacheEntry.fromApi(
        cacheKey: 'k',
        moduleId: 5,
        data: {},
      );
      expect(entry.isStaleForModule(6), true);
    });

    test('fromJson / toJson roundtrip preserves all fields', () {
      // Use a millisecond-aligned DateTime so the roundtrip is exact.
      final now = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
      );
      final original = ItemListCacheEntry(
        cacheKey: 'cached_popular_items',
        moduleId: 7,
        schemaVersion: ItemListCacheConfig.cacheSchemaVersion,
        cachedAt: now,
        data: {'items': [1, 2, 3]},
      );

      final json = original.toJson();
      final restored = ItemListCacheEntry.fromJson(json);

      expect(restored.cacheKey, original.cacheKey);
      expect(restored.moduleId, original.moduleId);
      expect(restored.schemaVersion, original.schemaVersion);
      expect(restored.cachedAt, original.cachedAt);
      expect(restored.data, original.data);
    });
  });

  group('ItemListCacheHelper.diskKey', () {
    test('omits suffix when moduleId is null', () {
      expect(ItemListCacheHelper.diskKey('cached_popular_items'),
          'cached_popular_items');
    });

    test('omits suffix when moduleId is zero', () {
      expect(ItemListCacheHelper.diskKey('cached_popular_items', moduleId: 0),
          'cached_popular_items');
    });

    test('omits suffix when moduleId is negative', () {
      expect(ItemListCacheHelper.diskKey('cached_popular_items', moduleId: -1),
          'cached_popular_items');
    });

    test('appends _m suffix when moduleId is positive', () {
      expect(ItemListCacheHelper.diskKey('cached_popular_items', moduleId: 4),
          'cached_popular_items_m4');
    });

    test('different module ids produce different keys (no cross-module collision)', () {
      final food = ItemListCacheHelper.diskKey('cached_popular_items', moduleId: 1);
      final grocery = ItemListCacheHelper.diskKey('cached_popular_items', moduleId: 2);
      expect(food, isNot(grocery));
    });
  });

  group('ItemListCacheHelper in-memory cache', () {
    test('peekMemory returns null on a fresh key', () {
      ItemListCacheHelper.invalidateAll();
      final key = 'nonexistent_${DateTime.now().microsecondsSinceEpoch}';
      expect(ItemListCacheHelper.peekMemory(key), isNull);
    });

    test('memorySize is non-negative and starts at 0 after invalidation', () {
      ItemListCacheHelper.invalidateAll();
      expect(ItemListCacheHelper.memorySize, 0);
    });
  });
}