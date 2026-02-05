import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/wearable_summary.dart';
import 'wearable_cache_service.dart';

class WearableHealthService {
  static final Health _health = Health();
  static bool _configured = false;
  static const List<HealthDataType> _summaryTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
  ];

  static Future<bool> isHealthConnectAvailable() async {
    await _ensureConfigured();
    return _health.isHealthConnectAvailable();
  }

  static Future<void> installHealthConnect() async {
    await _health.installHealthConnect();
  }

  static Future<bool> hasRequiredPermissions() async {
    await _ensureConfigured();
    final availableTypes = _summaryTypes
        .where((type) => _health.isDataTypeAvailable(type))
        .toList();
    if (availableTypes.isEmpty) return false;

    final permissions =
        availableTypes.map((_) => HealthDataAccess.READ).toList();
    final hasPermissions = await _health.hasPermissions(
      availableTypes,
      permissions: permissions,
    );
    return hasPermissions == true;
  }

  static Future<bool> requestRequiredPermissions() async {
    await _ensureConfigured();
    final isAvailable = await _health.isHealthConnectAvailable();
    if (!isAvailable) {
      return false;
    }

    await Permission.activityRecognition.request();
    final availableTypes = _summaryTypes
        .where((type) => _health.isDataTypeAvailable(type))
        .toList();
    if (availableTypes.isEmpty) return false;

    final permissions =
        availableTypes.map((_) => HealthDataAccess.READ).toList();
    final authorized = await _health.requestAuthorization(
      availableTypes,
      permissions: permissions,
    );
    return authorized;
  }

  static Future<bool> ensurePermissions() async {
    final hasPermissions = await hasRequiredPermissions();
    if (hasPermissions) return true;
    return requestRequiredPermissions();
  }

  static Future<WearableSummary?> fetchAndCacheSummary() async {
    await _ensureConfigured();
    final bool isAvailable = await _health.isHealthConnectAvailable();
    if (!isAvailable) {
      return WearableCacheService.loadSummary();
    }

    // Activity recognition permission for steps/activity on Android
    await Permission.activityRecognition.request();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final availableTypes = <HealthDataType>[];
    for (final type in _summaryTypes) {
      if (_health.isDataTypeAvailable(type)) {
        availableTypes.add(type);
      }
    }

    if (availableTypes.isEmpty) {
      return WearableCacheService.loadSummary();
    }

    final permissions =
        availableTypes.map((_) => HealthDataAccess.READ).toList();
    final hasPermissions =
        await _health.hasPermissions(availableTypes, permissions: permissions);
    if (hasPermissions != true) {
      return WearableCacheService.loadSummary();
    }

    final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;

    final avgHeartRate = await _averageNumericFromTypes(
      startOfDay,
      now,
      _filterTypes(availableTypes, [HealthDataType.HEART_RATE]),
    );

    final restingHeartRate = await _averageNumericFromTypes(
      startOfDay,
      now,
      _filterTypes(availableTypes, [HealthDataType.RESTING_HEART_RATE]),
    );

    double? asleepMinutes;
    if (availableTypes.contains(HealthDataType.SLEEP_ASLEEP)) {
      asleepMinutes = await _sumMergedDurationFromTypes(
        startOfDay,
        now,
        [HealthDataType.SLEEP_ASLEEP],
      );
    }
    if ((asleepMinutes == null || asleepMinutes == 0) &&
        availableTypes.contains(HealthDataType.SLEEP_SESSION)) {
      asleepMinutes = await _sumMergedDurationFromTypes(
        startOfDay,
        now,
        [HealthDataType.SLEEP_SESSION],
      );
    }

    final sleepHours = asleepMinutes != null ? asleepMinutes / 60.0 : null;

    final summary = WearableSummary(
      updatedAt: now,
      stepsToday: steps,
      avgHeartRate: avgHeartRate,
      restingHeartRate: restingHeartRate,
      sleepHours: sleepHours,
      stressScore: null,
    );

    await WearableCacheService.saveSummary(summary);
    return summary;
  }

  static Future<List<SleepSegmentDebug>> fetchSleepSegmentsLast24h() async {
    await _ensureConfigured();
    final bool isAvailable = await _health.isHealthConnectAvailable();
    if (!isAvailable) return [];

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final debugTypes = <HealthDataType>[
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_UNKNOWN,
      HealthDataType.SLEEP_OUT_OF_BED,
    ];

    final availableTypes =
        debugTypes.where((type) => _health.isDataTypeAvailable(type)).toList();
    if (availableTypes.isEmpty) return [];

    final permissions =
        availableTypes.map((_) => HealthDataAccess.READ).toList();
    final hasPermissions =
        await _health.hasPermissions(availableTypes, permissions: permissions);
    if (hasPermissions != true) {
      final authorized = await _health.requestAuthorization(
        availableTypes,
        permissions: permissions,
      );
      if (!authorized) return [];
    }

    final points = await _safeGetHealthDataFromTypes(
      types: availableTypes,
      start: startOfDay,
      end: now,
    );
    if (points.isEmpty) return [];

    final unique = _health.removeDuplicates(points);
    final segments = <SleepSegmentDebug>[];
    for (final point in unique) {
      final windowStart =
          point.dateFrom.isAfter(startOfDay) ? point.dateFrom : startOfDay;
      final windowEnd = point.dateTo.isBefore(now) ? point.dateTo : now;
      if (!windowEnd.isAfter(windowStart)) continue;
      final minutes = windowEnd.difference(windowStart).inMinutes;
      if (minutes <= 0) continue;

      segments.add(SleepSegmentDebug(
        type: point.typeString,
        start: windowStart,
        end: windowEnd,
        minutes: minutes,
        sourceName: point.sourceName,
        sourceId: point.sourceId,
      ));
    }

    segments.sort((a, b) => a.start.compareTo(b.start));
    return segments;
  }

  static List<HealthDataType> _filterTypes(
      List<HealthDataType> available, List<HealthDataType> desired) {
    return desired.where(available.contains).toList();
  }

  static Future<double?> _averageNumericFromTypes(
    DateTime start,
    DateTime end,
    List<HealthDataType> types,
  ) async {
    if (types.isEmpty) return null;
    final points = await _safeGetHealthDataFromTypes(
      types: types,
      start: start,
      end: end,
    );
    final unique = _health.removeDuplicates(points);
    double sum = 0;
    int count = 0;
    for (final point in unique) {
      final value = _numericValue(point);
      if (value == null) continue;
      sum += value;
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  static Future<double?> _sumMergedDurationFromTypes(
    DateTime start,
    DateTime end,
    List<HealthDataType> types,
  ) async {
    if (types.isEmpty) return null;
    final points = await _safeGetHealthDataFromTypes(
      types: types,
      start: start,
      end: end,
    );
    if (points.isEmpty) return null;
    final unique = _health.removeDuplicates(points);

    final intervals = <_Interval>[];
    for (final point in unique) {
      final windowStart =
          point.dateFrom.isAfter(start) ? point.dateFrom : start;
      final windowEnd = point.dateTo.isBefore(end) ? point.dateTo : end;
      if (!windowEnd.isAfter(windowStart)) continue;
      intervals.add(_Interval(windowStart, windowEnd));
    }
    if (intervals.isEmpty) return null;

    intervals.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_Interval>[];
    for (final interval in intervals) {
      if (merged.isEmpty) {
        merged.add(interval);
        continue;
      }
      final last = merged.last;
      if (interval.start.isAfter(last.end)) {
        merged.add(interval);
      } else if (interval.end.isAfter(last.end)) {
        merged[merged.length - 1] = _Interval(last.start, interval.end);
      }
    }

    double minutes = 0;
    for (final interval in merged) {
      minutes += interval.end.difference(interval.start).inMinutes;
    }
    return minutes == 0 ? null : minutes;
  }

  static double? _numericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    final valueString = value.toString();
    return double.tryParse(valueString);
  }

  static Future<List<HealthDataPoint>> _safeGetHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime start,
    required DateTime end,
  }) async {
    if (types.isEmpty) return <HealthDataPoint>[];
    try {
      return await _health.getHealthDataFromTypes(
        types: types,
        startTime: start,
        endTime: end,
      );
    } catch (e) {
      // Some OEM Health Connect builds throw for unsupported data types.
      // Retry per-type to salvage partial results.
      final results = <HealthDataPoint>[];
      for (final type in types) {
        try {
          final points = await _health.getHealthDataFromTypes(
            types: [type],
            startTime: start,
            endTime: end,
          );
          results.addAll(points);
        } catch (_) {
          // Ignore unsupported type.
        }
      }
      return results;
    }
  }

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }
}

class _Interval {
  final DateTime start;
  final DateTime end;

  const _Interval(this.start, this.end);
}

class SleepSegmentDebug {
  final String type;
  final DateTime start;
  final DateTime end;
  final int minutes;
  final String sourceName;
  final String sourceId;

  const SleepSegmentDebug({
    required this.type,
    required this.start,
    required this.end,
    required this.minutes,
    required this.sourceName,
    required this.sourceId,
  });
}
