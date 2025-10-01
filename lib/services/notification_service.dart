import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

    // Simple callback - handles all action button clicks
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('🔔 Notification response received');
        print('   Action ID: ${response.actionId}');
        print('   Payload: ${response.payload}');

        await _handleAction(response);
      },
    );

    _initialized = true;
    print('✅ NotificationService initialized');
  }

  static Future<void> _handleAction(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;

    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final medicationId = data['medicationId'] as String;
      final medicationName = data['medicationName'] as String?;

      print('📋 Processing: $actionId for $medicationId');

      switch (actionId) {
        case 'take_action':
          await _takeMedication(medicationId, medicationName);
          break;

        case 'snooze_action':
          await _snoozeMedication(medicationId, medicationName);
          break;

        case 'skip_action':
          await _showConfirmation(
              '⏭️ Skipped', '$medicationName reminder dismissed');
          break;

        default:
          print('📱 Notification body tapped');
          break;
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  static Future<void> _takeMedication(
      String medicationId, String? medicationName) async {
    print('✅ Taking medication: $medicationId');

    try {
      final prefs = await SharedPreferences.getInstance();
      final medicationsJson = prefs.getString('medications');

      if (medicationsJson != null) {
        final List<dynamic> medicationsList = jsonDecode(medicationsJson);

        for (var i = 0; i < medicationsList.length; i++) {
          final medData = medicationsList[i] as Map<String, dynamic>;
          if (medData['id'] == medicationId) {
            final currentQuantity = medData['currentQuantity'] as int? ?? 30;
            medData['currentQuantity'] = (currentQuantity - 1).clamp(0, 999);

            await prefs.setString('medications', jsonEncode(medicationsList));

            await _showConfirmation(
              '✅ Dose Taken',
              '${medicationName ?? 'Medication'} logged. ${medData['currentQuantity']} remaining.',
            );

            print('✅ Updated quantity: ${medData['currentQuantity']}');
            break;
          }
        }
      }
    } catch (e) {
      print('❌ Error updating: $e');
    }
  }

  static Future<void> _snoozeMedication(
      String medicationId, String? medicationName) async {
    print('⏰ Snoozing for 15 minutes');

    try {
      final snoozeTime =
          tz.TZDateTime.now(tz.local).add(const Duration(minutes: 15));

      const actions = <AndroidNotificationAction>[
        AndroidNotificationAction(
          'take_action',
          '✓ Take',
          cancelNotification: true,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'skip_action',
          '✕ Skip',
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ];

      await _notifications.zonedSchedule(
        999993,
        '⏰ Snooze Reminder',
        'Time to take ${medicationName ?? 'your medication'}',
        snoozeTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            actions: actions,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({
          'type': 'medication',
          'medicationId': medicationId,
          'medicationName': medicationName,
        }),
      );

      await _showConfirmation('⏰ Snoozed', 'Reminder in 15 minutes');
    } catch (e) {
      print('❌ Error snoozing: $e');
    }
  }

  static Future<void> _showConfirmation(String title, String body) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_confirmations',
          'Confirmations',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<bool> canScheduleExactAlarms() async {
    try {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();
      return result ?? true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> requestExactAlarmPermission() async {
    try {
      final canSchedule = await canScheduleExactAlarms();
      if (canSchedule) return true;

      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

      return result ?? false;
    } catch (e) {
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
          print('❌ Error scheduling: $e');
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
    final scheduledDate = _nextInstanceOfDayAndTime(dayOfWeek, reminder.time);

    final title = medication.isEssential
        ? '🚨 Essential Medication'
        : '💊 Medication Reminder';
    final body = reminder.customMessage ??
        'Time to take ${medication.name} ${medication.dosage}';

    const actions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        'take_action',
        '✓ Take',
        cancelNotification: true,
        showsUserInterface: true, // MUST be true
      ),
      AndroidNotificationAction(
        'snooze_action',
        '⏰ Snooze',
        cancelNotification: true,
        showsUserInterface: true, // MUST be true
      ),
      AndroidNotificationAction(
        'skip_action',
        '✕ Skip',
        cancelNotification: true,
        showsUserInterface: true, // MUST be true
      ),
    ];

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
              ? 'Essential Medication'
              : 'Medication Reminders',
          channelDescription: 'Reminders to take medications',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          actions: actions,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: jsonEncode({
        'type': 'medication',
        'medicationId': medication.id,
        'medicationName': medication.name,
        'dosage': medication.dosage,
      }),
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

      print('✅ Cancelled $cancelledCount reminders');
    } catch (e) {
      print('❌ Error cancelling: $e');
    }
  }

  static int _generateNotificationId(
      String medicationId, String reminderId, int dayOfWeek) {
    return (medicationId.hashCode + reminderId.hashCode + dayOfWeek).abs() %
        2147483647;
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(
      int dayOfWeek, TimeOfDay time) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);

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

    int daysToAdd = (dayOfWeek - now.weekday) % 7;

    if (daysToAdd == 0 && scheduledDate.isBefore(now)) {
      daysToAdd = 7;
    }

    if (daysToAdd > 0) {
      scheduledDate = scheduledDate.add(Duration(days: daysToAdd));
    }

    return scheduledDate;
  }

  static Future<void> showTestNotification() async {
    await initialize();
    await _notifications.show(
      999999,
      '🧪 Test',
      'Testing notification system',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> scheduleTestNotificationIn30Seconds() async {
    await initialize();

    final scheduledDate =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 30));

    const actions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        'take_action',
        '✓ Take',
        cancelNotification: true,
        showsUserInterface: true, // CRITICAL
      ),
      AndroidNotificationAction(
        'snooze_action',
        '⏰ Snooze',
        cancelNotification: true,
        showsUserInterface: true, // CRITICAL
      ),
    ];

    await _notifications.zonedSchedule(
      777777,
      '🧪 Test with Actions',
      'Click the buttons to test!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          actions: actions,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'medication',
        'medicationId': 'test_123',
        'medicationName': 'Test Med',
      }),
    );

    print('✅ Test scheduled');
  }

  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> cancelAllMedicationNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<void> scheduleRefillReminder(Medication medication) async {
    // Add implementation if needed
  }
}
