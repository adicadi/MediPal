import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/medication.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    print('✅ NotificationService initialized');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  static Future<bool> canScheduleExactAlarms() async {
    try {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();

      return result ?? true;
    } catch (e) {
      print('⚠️ Error checking exact alarm permission: $e');
      return false;
    }
  }

  static Future<bool> requestExactAlarmPermission() async {
    try {
      final canSchedule = await canScheduleExactAlarms();
      if (canSchedule) {
        print('✅ Exact alarm permission already granted');
        return true;
      }

      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

      print(result == true
          ? '✅ Exact alarm permission granted'
          : '⚠️ Exact alarm permission denied');

      return result ?? false;
    } catch (e) {
      print('❌ Error requesting exact alarm permission: $e');
      return false;
    }
  }

  static Future<bool> requestPermissions() async {
    await initialize();

    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      return await androidImplementation.requestNotificationsPermission() ??
          false;
    }

    final iosImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      return await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  static Future<void> scheduleMedicationReminders(Medication medication) async {
    if (!medication.remindersEnabled || medication.reminders.isEmpty) return;

    await initialize();

    final canSchedule = await canScheduleExactAlarms();
    if (!canSchedule) {
      print('⚠️ Cannot schedule - exact alarm permission not granted');
      throw Exception('Exact alarm permission required');
    }

    await cancelMedicationReminders(medication.id);

    int scheduledCount = 0;
    for (final reminder in medication.reminders) {
      if (!reminder.enabled) continue;

      for (final dayOfWeek in reminder.daysOfWeek) {
        try {
          await _scheduleWeeklyNotification(
            medication: medication,
            reminder: reminder,
            dayOfWeek: dayOfWeek,
          );
          scheduledCount++;
        } catch (e) {
          print('❌ Error scheduling notification for day $dayOfWeek: $e');
        }
      }
    }

    print('✅ Scheduled $scheduledCount reminders for ${medication.name}');
  }

  static Future<void> _scheduleWeeklyNotification({
    required Medication medication,
    required MedicationReminder reminder,
    required int dayOfWeek,
  }) async {
    final notificationId =
        _generateNotificationId(medication.id, reminder.id, dayOfWeek);

    // FIXED: Use tz.local for proper timezone handling
    final scheduledDate = _nextInstanceOfDayAndTime(dayOfWeek, reminder.time);

    // Debug logging with local timezone
    final now = tz.TZDateTime.now(tz.local);
    print('📅 Scheduling notification for ${medication.name}:');
    print('   ID: $notificationId');
    print('   Day: $dayOfWeek (${_getDayName(dayOfWeek)})');
    //print('   Time: ${reminder.time.format(null)}');
    print('   Scheduled for: $scheduledDate (LOCAL TIME)');
    print('   Current time: $now (LOCAL TIME)');
    print(
        '   Time until notification: ${scheduledDate.difference(now).inMinutes} minutes');

    final title = medication.isEssential
        ? '🚨 Essential Medication'
        : '💊 Medication Reminder';

    final body = reminder.customMessage ??
        'Time to take ${medication.name} ${medication.dosage}';

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          medication.isEssential
              ? 'essential_medication_reminders'
              : 'medication_reminders',
          medication.isEssential
              ? 'Essential Medication Reminders'
              : 'Medication Reminders',
          channelDescription: 'Reminders to take medications on time',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFF2196F3),
          ledOnMs: 1000,
          ledOffMs: 500,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'medication_reminder',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // CRITICAL FIX: Use alarmClock for most reliable delivery
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'medication:${medication.id}',
    );
  }

  static Future<void> scheduleRefillReminder(Medication medication) async {
    if (medication.currentQuantity > medication.refillThreshold) return;

    await initialize();

    final notificationId = int.parse(medication.id) + 100000;

    await _notifications.show(
      notificationId,
      '🏥 Refill Reminder',
      '${medication.name} is running low (${medication.currentQuantity} left). Time to refill!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'refill_reminders',
          'Refill Reminders',
          channelDescription: 'Reminders to refill medications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'refill_reminder',
        ),
      ),
      payload: 'refill:${medication.id}',
    );
  }

  static Future<void> cancelMedicationReminders(String medicationId) async {
    try {
      final pendingNotifications =
          await _notifications.pendingNotificationRequests();

      int cancelledCount = 0;
      for (final notification in pendingNotifications) {
        if (notification.payload?.contains('medication:$medicationId') ==
            true) {
          await _notifications.cancel(notification.id);
          cancelledCount++;
        }
      }

      print(
          '✅ Cancelled $cancelledCount reminders for medication $medicationId');
    } catch (e) {
      print('❌ Error cancelling reminders: $e');
    }
  }

  static Future<void> cancelAllMedicationNotifications() async {
    await _notifications.cancelAll();
    print('✅ Cancelled all notifications');
  }

  static int _generateNotificationId(
      String medicationId, String reminderId, int dayOfWeek) {
    return (medicationId.hashCode + reminderId.hashCode + dayOfWeek).abs() %
        2147483647;
  }

  // FIXED: Proper timezone handling for weekly notifications
  static tz.TZDateTime _nextInstanceOfDayAndTime(
      int dayOfWeek, TimeOfDay time) {
    // Get current time in LOCAL timezone
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Create scheduled time for TODAY at the specified hour/minute
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
      0,
      0,
    );

    // Calculate days until target day of week
    int daysToAdd = (dayOfWeek - now.weekday) % 7;

    // If it's today but time has passed, schedule for next week
    if (daysToAdd == 0 && scheduledDate.isBefore(now)) {
      daysToAdd = 7;
    }

    // Add the calculated days
    if (daysToAdd > 0) {
      scheduledDate = scheduledDate.add(Duration(days: daysToAdd));
    }

    return scheduledDate;
  }

  static String _getDayName(int dayOfWeek) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayOfWeek];
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      print('📋 Found ${pending.length} pending notifications:');
      for (var notification in pending) {
        print('   - ID: ${notification.id}');
        print('     Title: ${notification.title}');
        print('     Body: ${notification.body}');
      }
      return pending;
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  static Future<void> showTestNotification() async {
    await initialize();
    await _notifications.show(
      999999,
      '🧪 Test Notification',
      'Your medication reminder system is working! Time: ${DateTime.now().toString()}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notifications for development',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    print('✅ Test notification sent');
  }

  // Schedule test notification 1 minute from now
  static Future<void> scheduleTestNotificationIn1Minute() async {
    await initialize();

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(const Duration(minutes: 1));

    print('⏰ Scheduling 1-minute test:');
    print('   Current time: $now');
    print('   Scheduled for: $scheduledDate');

    await _notifications.zonedSchedule(
      888888,
      '🧪 1-Minute Test',
      'This notification was scheduled at ${now.toString()}',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // Use alarmClock for most reliable delivery
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('✅ Test notification scheduled');
  }

  // NEW: Schedule test for 30 seconds from now
  static Future<void> scheduleTestNotificationIn30Seconds() async {
    await initialize();

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(const Duration(seconds: 30));

    print('⏰ Scheduling 30-second test:');
    print('   Current time: $now');
    print('   Scheduled for: $scheduledDate');
    print('   Timezone: ${tz.local}');

    await _notifications.zonedSchedule(
      777777,
      '🧪 30-Second Test',
      'If you see this, weekly reminders will work! Scheduled at: ${now.hour}:${now.minute}:${now.second}',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('✅ 30-second test scheduled');
  }
}
