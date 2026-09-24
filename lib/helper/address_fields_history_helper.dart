import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickles_and_pies/util/app_constants.dart';

/// Helper used to persist a per-field history of previously-entered
/// `house`, `street` and `floor` (ZIP) values on the user's device, so
/// the matching address forms can offer those values through a
/// `flutter_typeahead` dropdown the next time the user opens them.
///
/// The history is stored in `SharedPreferences` as a JSON-encoded `List<String>`
/// and is capped to a reasonable maximum length so it never grows unbounded.
class AddressFieldsHistoryHelper {
  AddressFieldsHistoryHelper._();

  static const int _maxHistoryLength = 15;

  // ---------------------------------------------------------------------------
  //  Public API
  // ---------------------------------------------------------------------------

  /// Persists `value` into the house-history list.
  ///
  /// - Empty / whitespace-only values are ignored.
  /// - If the value already exists it is moved to the top of the list
  ///   (most-recent-first ordering) instead of being duplicated.
  static Future<void> saveHouseToHistory(String value) =>
      _saveValue(AppConstants.houseHistoryList, value);

  /// Persists `value` into the street-history list.
  static Future<void> saveStreetToHistory(String value) =>
      _saveValue(AppConstants.streetHistoryList, value);

  /// Persists `value` into the floor/ZIP-history list.
  static Future<void> saveFloorToHistory(String value) =>
      _saveValue(AppConstants.floorHistoryList, value);

  /// Returns the saved house values (most-recent-first). Always returns a
  /// non-null list, even when no history exists yet.
  static List<String> getHouseHistory() =>
      _readValue(AppConstants.houseHistoryList);

  /// Returns the saved street values (most-recent-first).
  static List<String> getStreetHistory() =>
      _readValue(AppConstants.streetHistoryList);

  /// Returns the saved floor/ZIP values (most-recent-first).
  static List<String> getFloorHistory() =>
      _readValue(AppConstants.floorHistoryList);

  // ---------------------------------------------------------------------------
  //  Convenience wrappers that save all three fields in a single call. Use
  //  these from screens that want to record every field after a save/update.
  // ---------------------------------------------------------------------------
  static Future<void> saveAddressDetailHistory({
    String? house,
    String? street,
    String? floor,
  }) async {
    if (house != null) await saveHouseToHistory(house);
    if (street != null) await saveStreetToHistory(street);
    if (floor != null) await saveFloorToHistory(floor);
  }

  /// Clears the cached history for all three fields.
  static Future<void> clearAll() async {
    final SharedPreferences prefs = Get.find<SharedPreferences>();
    await prefs.remove(AppConstants.houseHistoryList);
    await prefs.remove(AppConstants.streetHistoryList);
    await prefs.remove(AppConstants.floorHistoryList);
  }

  // ---------------------------------------------------------------------------
  //  Internal helpers
  // ---------------------------------------------------------------------------

  static Future<void> _saveValue(String key, String rawValue) async {
    final String value = rawValue.trim();
    if (value.isEmpty) return;

    try {
      final SharedPreferences prefs = Get.find<SharedPreferences>();
      final List<String> current = _readValue(key);

      // Move existing entry to the top, or insert at the top if new.
      current.removeWhere((element) =>
          element.toLowerCase() == value.toLowerCase());
      current.insert(0, value);

      // Cap history length.
      if (current.length > _maxHistoryLength) {
        current.removeRange(_maxHistoryLength, current.length);
      }

      await prefs.setString(key, jsonEncode(current));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AddressFieldsHistoryHelper save failed for $key: $e');
      }
    }
  }

  static List<String> _readValue(String key) {
    try {
      final SharedPreferences prefs = Get.find<SharedPreferences>();
      return _readValueInternal(prefs, key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AddressFieldsHistoryHelper read failed for $key: $e');
      }
      return <String>[];
    }
  }

  static List<String> _readValueInternal(SharedPreferences prefs, String key) {
    final String? raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((String e) => e.trim())
            .where((String e) => e.isNotEmpty)
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'AddressFieldsHistoryHelper decode failed for $key: $e');
      }
    }
    return <String>[];
  }
}
