import 'package:shared_preferences/shared_preferences.dart';
import '../models/wearable_summary.dart';

class WearableCacheService {
  static const String _wearableSummaryKey = 'wearable_summary';

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

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wearableSummaryKey);
  }
}
