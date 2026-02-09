import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingKey = 'onboarding_completed';
  static const String _legacyOwnerKey = 'onboarding_completed_owner';

  static String _scopedKey(String? userId) {
    final trimmed = userId?.trim() ?? '';
    if (trimmed.isEmpty) return _onboardingKey;
    return '${_onboardingKey}_$trimmed';
  }

  // Check if onboarding is completed
  static Future<bool> isOnboardingCompleted({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _scopedKey(userId);
    final scopedValue = prefs.getBool(scopedKey);
    if (scopedValue != null) {
      return scopedValue;
    }

    // Migration: old single-device key becomes owned by the first authenticated user.
    final legacy = prefs.getBool(_onboardingKey) ?? false;
    if (!legacy) return false;

    final trimmedUserId = userId?.trim() ?? '';
    if (trimmedUserId.isEmpty) {
      return legacy;
    }

    final owner = prefs.getString(_legacyOwnerKey);
    if (owner == null || owner == trimmedUserId) {
      await prefs.setBool(scopedKey, true);
      await prefs.setString(_legacyOwnerKey, trimmedUserId);
      return true;
    }

    return false;
  }

  // Mark onboarding as completed
  static Future<void> completeOnboarding({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _scopedKey(userId);
    await prefs.setBool(scopedKey, true);

    final trimmedUserId = userId?.trim() ?? '';
    if (trimmedUserId.isNotEmpty) {
      await prefs.setString(_legacyOwnerKey, trimmedUserId);
    } else {
      await prefs.setBool(_onboardingKey, true);
    }
  }

  // Reset onboarding (for testing)
  static Future<void> resetOnboarding({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedUserId = userId?.trim() ?? '';
    if (trimmedUserId.isEmpty) {
      await prefs.remove(_onboardingKey);
      await prefs.remove(_legacyOwnerKey);
      return;
    }
    await prefs.remove(_scopedKey(trimmedUserId));
  }
}
