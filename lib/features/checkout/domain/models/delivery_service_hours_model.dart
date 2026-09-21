import 'package:flutter/foundation.dart';

/// Delivery Service Hours data models.
///
/// These models are decoupled from the existing `Store` model and persist
/// independently per-store through the LocalCache. They are intentionally
/// additive-only: any future server field is preserved verbatim in the raw
/// cache envelope, so legacy entries remain forward-compatible.

/// A single weekday's delivery schedule.
///
/// Times are 24-hour `HH:mm` strings (e.g. `08:00`, `18:00`).
/// Validation must reject malformed values; the resolver falls back to the
/// default 08:00-18:00 window when invalid.
@immutable
class DeliveryDayHours {
  final String day; // monday, tuesday, wednesday, thursday, friday, saturday, sunday
  final bool isActive;
  final String openingTime; // HH:mm
  final String closingTime; // HH:mm

  const DeliveryDayHours({
    required this.day,
    required this.isActive,
    required this.openingTime,
    required this.closingTime,
  });

  factory DeliveryDayHours.fromJson(Map<String, dynamic> json) {
    return DeliveryDayHours(
      day: (json['day'] ?? '').toString().toLowerCase(),
      isActive: json['is_active'] == true,
      openingTime: (json['opening_time'] ?? '').toString(),
      closingTime: (json['closing_time'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'day': day,
        'is_active': isActive,
        'opening_time': openingTime,
        'closing_time': closingTime,
      };
}

/// Full delivery schedule for a single store (one entry per day).
@immutable
class DeliveryServiceHours {
  final int storeId;
  final List<DeliveryDayHours> days;

  const DeliveryServiceHours({
    required this.storeId,
    required this.days,
  });

  factory DeliveryServiceHours.fromJson(
    int storeId,
    Map<String, dynamic> json,
  ) {
    final List<dynamic> rawList =
        (json['delivery_service_hours'] ?? json['hours'] ?? const <dynamic>[])
            as List<dynamic>;
    final List<DeliveryDayHours> parsed = <DeliveryDayHours>[];
    for (final dynamic entry in rawList) {
      if (entry is Map) {
        try {
          parsed.add(
            DeliveryDayHours.fromJson(Map<String, dynamic>.from(entry)),
          );
        } catch (_) {
          // Skip malformed entries; the resolver will fall back to default.
        }
      }
    }
    return DeliveryServiceHours(storeId: storeId, days: parsed);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'delivery_service_hours': days.map((DeliveryDayHours d) => d.toJson()).toList(),
      };
}

/// Live delivery-service snapshot returned by the server.
///
/// This is informational only - the schedule returned in
/// [DeliveryServiceHours] remains the source of truth for time-window
/// validation. This snapshot is kept for the day-level "available" hint.
@immutable
class DeliveryServiceInfo {
  final bool available;
  final String? opensAt; // HH:mm
  final String? closesAt; // HH:mm
  final String? day; // monday..sunday

  const DeliveryServiceInfo({
    required this.available,
    this.opensAt,
    this.closesAt,
    this.day,
  });

  factory DeliveryServiceInfo.fromJson(Map<String, dynamic> json) {
    final dynamic service = json['delivery_service'];
    if (service is! Map) {
      return const DeliveryServiceInfo(available: false);
    }
    return DeliveryServiceInfo(
      available: service['available'] == true,
      opensAt: service['opens_at']?.toString(),
      closesAt: service['closes_at']?.toString(),
      day: service['day']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> service = <String, dynamic>{
      'available': available,
      if (opensAt != null) 'opens_at': opensAt,
      if (closesAt != null) 'closes_at': closesAt,
      if (day != null) 'day': day,
    };
    return <String, dynamic>{'delivery_service': service};
  }
}

/// Combined cache envelope persisted per-store in SharedPreferences.
///
/// Both fields are optional: the schedule alone is sufficient to compute
/// availability, and the snapshot alone is not. The resolver will fall back
/// to the default window when both are absent.
@immutable
class DeliveryServiceHoursEnvelope {
  final int storeId;
  final DeliveryServiceHours schedule;
  final DeliveryServiceInfo info;
  final int schemaVersion;

  static const int currentSchemaVersion = 1;

  const DeliveryServiceHoursEnvelope({
    required this.storeId,
    required this.schedule,
    required this.info,
    required this.schemaVersion,
  });

  factory DeliveryServiceHoursEnvelope.fromJson(Map<String, dynamic> json) {
    final int storeId = (json['store_id'] as num?)?.toInt() ?? 0;
    final int schemaVersion =
        (json['schema_version'] as num?)?.toInt() ?? currentSchemaVersion;
    final Map<String, dynamic> scheduleJson = json['schedule'] is Map
        ? Map<String, dynamic>.from(json['schedule'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> infoJson = json['info'] is Map
        ? Map<String, dynamic>.from(json['info'] as Map)
        : <String, dynamic>{};

    return DeliveryServiceHoursEnvelope(
      storeId: storeId,
      schemaVersion: schemaVersion,
      schedule: DeliveryServiceHours.fromJson(storeId, scheduleJson),
      info: DeliveryServiceInfo.fromJson(infoJson),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'store_id': storeId,
        'schema_version': schemaVersion,
        'schedule': schedule.toJson(),
        'info': info.toJson(),
      };

  bool get isIntact => schemaVersion == currentSchemaVersion && storeId > 0;
}