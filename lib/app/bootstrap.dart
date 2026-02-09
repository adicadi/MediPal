import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../services/notification_service.dart';

class AppBootstrap {
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    await _loadEnv();
    await _initializeSupabase();
    await _initializeTimezone();
    await _initializeNotifications();
  }

  static Future<void> _loadEnv() async {
    try {
      await dotenv.load(fileName: ".env");
      if (kDebugMode) {
        print('✅ .env loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Warning: .env file not found: $e');
      }
    }
  }

  static Future<void> _initializeSupabase() async {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';

    if (url.isEmpty || anonKey.isEmpty) {
      if (kDebugMode) {
        print(
            '⚠️ Supabase not initialized. Missing SUPABASE_URL or SUPABASE_ANON_KEY.');
      }
      return;
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    if (kDebugMode) {
      print('✅ Supabase initialized');
    }
  }

  static Future<void> _initializeTimezone() async {
    try {
      if (kDebugMode) {
        print('🌍 Initializing timezone database...');
      }
      tz.initializeTimeZones();

      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      if (kDebugMode) {
        print('📍 Device timezone: $timeZoneName');
      }

      final String normalizedTimeZone =
          timeZoneName == "Europe/Kiev" ? "Europe/Kyiv" : timeZoneName;

      tz.setLocalLocation(tz.getLocation(normalizedTimeZone));
      if (kDebugMode) {
        print('✅ Timezone set to: ${tz.local}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Timezone initialization failed, falling back to UTC: $e');
      }
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static Future<void> _initializeNotifications() async {
    try {
      if (kDebugMode) {
        print('🔔 Initializing notification service...');
      }
      await NotificationService.initialize();
      if (kDebugMode) {
        print('✅ Notification service initialized');
      }

      final hasPermission = await NotificationService.requestPermissions();
      if (kDebugMode) {
        print(hasPermission
            ? '✅ Notification permissions granted'
            : '⚠️ Notification permissions denied');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Notification service initialization failed: $e');
      }
    }
  }
}
