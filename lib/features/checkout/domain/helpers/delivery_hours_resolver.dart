import 'package:flutter/foundation.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/delivery_service_hours_model.dart';

/// Computed snapshot of availability for a given [now] moment.
///
/// [schedule] is intentionally optional: a `null` schedule means
/// "use the default 08:00-18:00 fallback for every day".
@immutable
class DeliveryAvailability {
  final bool isDeliveryAvailable;
  final String currentDay;
  final String? openingTime;
  final String? closingTime;
  final bool dayIsActive;
  final bool usedFallback;

  const DeliveryAvailability({
    required this.isDeliveryAvailable,
    required this.currentDay,
    this.openingTime,
    this.closingTime,
    required this.dayIsActive,
    required this.usedFallback,
  });

  /// Render helper: returns the same `(opens, closes)` pair that the UI
  /// label needs to show, or `null` if the day is fully disabled.
  ({String opensAt, String closesAt})? get labelTimes {
    if (!dayIsActive) return null;
    return (
      opensAt: openingTime ?? DeliveryHoursResolver.defaultOpening,
      closesAt: closingTime ?? DeliveryHoursResolver.defaultClosing,
    );
  }
}

/// Single source of truth for Delivery Service Hours availability.
///
/// All checkout screens compute availability through this resolver so the
/// UI, the controller, and the cart logic can never disagree.
///
/// Boundary rules (must match the Laravel backend exactly):
///   * opening time is INCLUSIVE
///   * closing time is EXCLUSIVE
///   * day disabled (`is_active == false`) -> unavailable, regardless of time
///   * unknown / malformed day -> default 08:00-18:00 window
class DeliveryHoursResolver {
  static const String defaultOpening = '08:00';
  static const String defaultClosing = '18:00';

  static const List<String> weekdayKeys = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// Resolves availability for the moment [now] using the given [schedule].
  /// Pure function - no side effects.
  DeliveryAvailability resolveAvailability({
    required DateTime now,
    DeliveryServiceHours? schedule,
  }) {
    final String currentDayKey = _weekdayKey(now.weekday);

    final DeliveryDayHours? day = _findDay(schedule, currentDayKey);
    if (day == null) {
      // No schedule (cache miss before any server data, OR schedule does
      // not contain an entry for today's weekday) -> apply the default
      // 08:00-18:00 window. We treat the default as "active".
      final int defaultOpeningMinutes = _parseTimeOfDay(defaultOpening)!;
      final int defaultClosingMinutes = _parseTimeOfDay(defaultClosing)!;
      final int nowMinutes = now.hour * 60 + now.minute;
      final bool available = nowMinutes >= defaultOpeningMinutes &&
          nowMinutes < defaultClosingMinutes;
      return DeliveryAvailability(
        isDeliveryAvailable: available,
        currentDay: currentDayKey,
        openingTime: defaultOpening,
        closingTime: defaultClosing,
        dayIsActive: true,
        usedFallback: true,
      );
    }

    if (!day.isActive) {
      return DeliveryAvailability(
        isDeliveryAvailable: false,
        currentDay: currentDayKey,
        openingTime: day.openingTime,
        closingTime: day.closingTime,
        dayIsActive: false,
        usedFallback: false,
      );
    }

    final int? opening = _parseTimeOfDay(day.openingTime);
    final int? closing = _parseTimeOfDay(day.closingTime);
    if (opening == null || closing == null) {
      // Malformed schedule -> fall back to the default 08-18 window.
      final int defaultOpeningMinutes = _parseTimeOfDay(defaultOpening)!;
      final int defaultClosingMinutes = _parseTimeOfDay(defaultClosing)!;
      final int nowMinutes = now.hour * 60 + now.minute;
      final bool available = nowMinutes >= defaultOpeningMinutes &&
          nowMinutes < defaultClosingMinutes;
      return DeliveryAvailability(
        isDeliveryAvailable: available,
        currentDay: currentDayKey,
        openingTime: defaultOpening,
        closingTime: defaultClosing,
        dayIsActive: true,
        usedFallback: true,
      );
    }

    final int nowMinutes = now.hour * 60 + now.minute;
    final bool available = nowMinutes >= opening && nowMinutes < closing;
    return DeliveryAvailability(
      isDeliveryAvailable: available,
      currentDay: currentDayKey,
      openingTime: day.openingTime,
      closingTime: day.closingTime,
      dayIsActive: true,
      usedFallback: false,
    );
  }

  /// Returns the default 08:00-18:00 schedule (one entry per weekday).
  static List<DeliveryDayHours> defaultSchedule() {
    return weekdayKeys
        .map((String day) => DeliveryDayHours(
              day: day,
              isActive: true,
              openingTime: defaultOpening,
              closingTime: defaultClosing,
            ))
        .toList(growable: false);
  }

  DeliveryDayHours? _findDay(DeliveryServiceHours? schedule, String dayKey) {
    if (schedule == null) return null;
    for (final DeliveryDayHours d in schedule.days) {
      if (d.day.toLowerCase() == dayKey) return d;
    }
    return null;
  }

  String _weekdayKey(int weekday) {
    // DateTime.weekday: 1 = Monday .. 7 = Sunday
    return weekdayKeys[(weekday - 1) % 7];
  }

  static int? _parseTimeOfDay(String value) {
    if (value.length < 4) return null;
    final String normalized = value.trim();
    final List<String> parts = normalized.split(':');
    if (parts.length < 2) return null;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  /// Exposed only for tests.
  @visibleForTesting
  static int? debugParseTimeOfDay(String value) => _parseTimeOfDay(value);
}