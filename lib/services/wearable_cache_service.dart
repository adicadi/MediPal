import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/wearable_summary.dart';

class WearableCacheService {
  static const String _wearableSummaryKey = 'wearable_summary';
  static const String _wearableHistoryKey = 'wearable_history';
  static const int _maxHistoryDays = 30;

  static Future<void> saveSummary(WearableSummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wearableSummaryKey, summary.toJson());
  }

  static Future<WearableSummary?> loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_wearableSummaryKey);
    if (json == null || json.isEmpty) return null;
    return WearableSummary.fromJson(json);
  }

  static Future<List<WearableSummary>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_wearableHistoryKey);
    if (json == null || json.isEmpty) return [];
    final list = (jsonDecode(json) as List)
        .whereType<Map>()
        .map((item) =>
            WearableSummary.fromMap(item.cast<String, dynamic>()))
        .toList();
    return list;
  }

  static Future<void> upsertHistory(WearableSummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    final dayKey = _dayKey(summary.updatedAt);

    final existingIndex =
        history.indexWhere((item) => _dayKey(item.updatedAt) == dayKey);
    if (existingIndex >= 0) {
      history[existingIndex] = summary;
    } else {
      history.add(summary);
    }

    history.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    if (history.length > _maxHistoryDays) {
      history.removeRange(0, history.length - _maxHistoryDays);
    }

    await prefs.setString(
      _wearableHistoryKey,
      jsonEncode(history.map((item) => item.toMap()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wearableSummaryKey);
    await prefs.remove(_wearableHistoryKey);
  }

  static String _dayKey(DateTime time) {
    return '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')}';
  }
}
