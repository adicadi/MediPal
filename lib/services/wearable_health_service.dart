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
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.EXERCISE_TIME,
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
    final availableTypes =
        _summaryTypes.where((type) => _health.isDataTypeAvailable(type)).toList();
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
    final availableTypes =
        _summaryTypes.where((type) => _health.isDataTypeAvailable(type)).toList();
    if (availableTypes.isEmpty) return false;

    final permissions =
        availableTypes.map((_) => HealthDataAccess.READ).toList();
    final authorized = await _health.requestAuthorization(
      availableTypes,
      permissions: permissions,
    );
    return authorized;
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
    final yesterday = now.subtract(const Duration(days: 1));

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
      final authorized = await _health.requestAuthorization(
        availableTypes,
        permissions: permissions,
      );
      if (!authorized) {
        return WearableCacheService.loadSummary();
      }
    }

    final steps =
        await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;

    final activeMinutes = await _sumNumericFromTypes(
      startOfDay,
      now,
      _filterTypes(availableTypes, [
        HealthDataType.EXERCISE_TIME,
      ]),
    );

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

    final asleepMinutes = await _sumDurationFromTypes(
      yesterday,
      now,
      _filterTypes(availableTypes, [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_SESSION,
      ]),
    );
    final inBedMinutes = await _sumDurationFromTypes(
      yesterday,
      now,
      _filterTypes(availableTypes, [HealthDataType.SLEEP_IN_BED]),
    );

    final sleepHours =
        asleepMinutes != null ? asleepMinutes / 60.0 : null;
    final sleepEfficiency = (asleepMinutes != null && inBedMinutes != null)
        ? (inBedMinutes == 0 ? null : (asleepMinutes / inBedMinutes) * 100.0)
        : null;

    final summary = WearableSummary(
      updatedAt: now,
      stepsToday: steps,
      activeMinutesToday: activeMinutes?.round(),
      avgHeartRate: avgHeartRate,
      restingHeartRate: restingHeartRate,
      sleepHours: sleepHours,
      sleepEfficiency: sleepEfficiency,
      stressScore: null,
    );

    await WearableCacheService.saveSummary(summary);
    return summary;
  }

  static List<HealthDataType> _filterTypes(
      List<HealthDataType> available, List<HealthDataType> desired) {
    return desired.where(available.contains).toList();
  }

  static Future<double?> _sumNumericFromTypes(
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
    return count == 0 ? null : sum;
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

  static Future<double?> _sumDurationFromTypes(
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
    double minutes = 0;
    for (final point in unique) {
      final duration = point.dateTo.difference(point.dateFrom);
      minutes += duration.inMinutes;
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
