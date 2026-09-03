import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/features/store/data/cache/store_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StoreCacheService cacheService;
  late SharedPreferences prefs;

  // Raw server payloads frequently expose latitude/longitude as strings; the
  // cache layer treats them as opaque JSON and only delegates parsing to the
  // model when a request actually needs the typed object. The tests therefore
  // do not require the data to round-trip through `Store.fromJson`.
  Map<String, dynamic> sampleStoreJson({int id = 42, String name = 'Cafe 42'}) =>
      <String, dynamic>{
        'id': id,
        'name': name,
        'address': 'Test street',
        'cover_photo_full_url': 'https://cdn/$id/cover.png',
        'logo_full_url': 'https://cdn/$id/logo.png',
        'latitude': '24.7136',
        'longitude': '46.6753',
        'active': true,
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    cacheService = StoreCacheService(sharedPreferences: prefs);
  });

  test('cache miss returns null', () {
    final identity = StoreCacheIdentity.current(storeId: 1);
    expect(cacheService.getSync(identity), isNull);
  });

  test('saves and reads back the full JSON envelope', () async {
    final identity = StoreCacheIdentity.current(storeId: 7);
    final payload = sampleStoreJson(id: 7, name: 'Seven');
    await cacheService.save(identity: identity, fullJson: payload);

    final entry = cacheService.getSync(identity);
    expect(entry, isNotNull,
        reason: 'L1/L2 must round-trip the JSON envelope');
    expect(entry!.data['id'], 7);
    expect(entry.data['name'], 'Seven');
    expect(entry.isIntact, isTrue);
  });

  test('corrupted JSON is auto-evicted and treated as miss', () async {
    final identity = StoreCacheIdentity.current(storeId: 9);
    await prefs.setString(identity.diskKey, 'not a json envelope');

    expect(cacheService.getSync(identity), isNull);
    expect(prefs.getString(identity.diskKey), isNull);
  });

  test('schema mismatch drops the entry', () async {
    final identity = StoreCacheIdentity.current(storeId: 11);
    final futureVersion = StoreCacheConfig.cacheSchemaVersion + 1;
    final envelope = <String, dynamic>{
      'identity': identity.toJson(),
      'cached_at': DateTime.now().millisecondsSinceEpoch,
      'schema_version': futureVersion,
      'data': sampleStoreJson(id: 11, name: 'Wrong'),
      'data_length': 10,
      'data_hash': 0,
    };
    await prefs.setString(identity.diskKey, jsonEncode(envelope));
    expect(cacheService.getSync(identity), isNull);
    expect(prefs.getString(identity.diskKey), isNull);
  });

  test('context fingerprint isolates stores in different zones', () {
    final a = StoreCacheIdentity(
      storeId: 1,
      moduleId: 1,
      languageCode: 'en',
      zoneIds: const <int>[1],
      latitude: '24.7',
      longitude: '46.6',
    );
    final b = StoreCacheIdentity(
      storeId: 1,
      moduleId: 1,
      languageCode: 'en',
      zoneIds: const <int>[2],
      latitude: '24.7',
      longitude: '46.6',
    );
    expect(a, isNot(equals(b)));
    expect(a.diskKey, isNot(equals(b.diskKey)));
  });

  test('invalidate marks entry as stale but keeps it readable', () async {
    final identity = StoreCacheIdentity.current(storeId: 5);
    final payload = sampleStoreJson(id: 5, name: 'Live');
    await cacheService.save(identity: identity, fullJson: payload);
    await cacheService.invalidateStoreCache(5);

    final entry = cacheService.getSync(identity);
    expect(entry, isNotNull,
        reason: 'Stale entries must remain readable for offline mode');
    expect(entry!.isStale, isTrue);
    expect(entry.data['name'], 'Live');
  });

  test('legacy controller cache is removed after a fresh save', () async {
    final legacyKey = '${StoreCacheConfig.legacyKeyPrefix}13';
    await prefs.setString(
      legacyKey,
      jsonEncode(sampleStoreJson(id: 13, name: 'Legacy')),
    );
    expect(prefs.getString(legacyKey), isNotNull);

    final identity = StoreCacheIdentity.current(storeId: 13);
    await cacheService.save(
      identity: identity,
      fullJson: sampleStoreJson(id: 13, name: 'Fresh'),
    );
    expect(prefs.getString(legacyKey), isNull);
  });

  test('clearAllStoreDetailsCache wipes the namespace only', () async {
    await cacheService.save(
      identity: StoreCacheIdentity.current(storeId: 21),
      fullJson: sampleStoreJson(id: 21, name: 'A'),
    );
    await cacheService.save(
      identity: StoreCacheIdentity.current(storeId: 22),
      fullJson: sampleStoreJson(id: 22, name: 'B'),
    );
    // A neighbour key outside the namespace must survive a global clear.
    await prefs.setString('unrelated_preference', 'keep me');

    await cacheService.clearAllStoreDetailsCache();

    expect(prefs.getString('unrelated_preference'), 'keep me');
    expect(
      cacheService.getSync(StoreCacheIdentity.current(storeId: 21)),
      isNull,
    );
    expect(
      cacheService.getSync(StoreCacheIdentity.current(storeId: 22)),
      isNull,
    );
  });
}
