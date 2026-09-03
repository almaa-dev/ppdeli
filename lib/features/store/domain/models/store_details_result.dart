import 'package:flutter/foundation.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_model.dart';

/// Full result of the dedicated store-details endpoint.
///
/// [rawJson] deliberately preserves every server field. [store] remains the
/// strongly typed view consumed by existing UI and business logic.
@immutable
class StoreDetailsResult {
  final Store store;
  final Map<String, dynamic> rawJson;

  const StoreDetailsResult({required this.store, required this.rawJson});
}
