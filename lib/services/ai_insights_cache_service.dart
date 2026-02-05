import 'package:shared_preferences/shared_preferences.dart';

class AiInsightsCacheService {
  static const String _payloadKey = 'ai_insights_payload';
  static const String _insightsKey = 'ai_insights_text';
  static const String _updatedAtKey = 'ai_insights_updated_at';

  static Future<void> save(String payloadJson, String insights) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_payloadKey, payloadJson);
    await prefs.setString(_insightsKey, insights);
    await prefs.setString(
        _updatedAtKey, DateTime.now().toIso8601String());
  }

  static Future<CachedAiInsights?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_payloadKey);
    final insights = prefs.getString(_insightsKey);
    if (payload == null || insights == null) return null;
    final updatedAt = prefs.getString(_updatedAtKey);
    return CachedAiInsights(
      payloadJson: payload,
      insights: insights,
      updatedAt: updatedAt,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_payloadKey);
    await prefs.remove(_insightsKey);
    await prefs.remove(_updatedAtKey);
  }
}

class CachedAiInsights {
  final String payloadJson;
  final String insights;
  final String? updatedAt;

  CachedAiInsights({
    required this.payloadJson,
    required this.insights,
    required this.updatedAt,
  });
}
