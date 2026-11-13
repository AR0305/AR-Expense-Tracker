import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../database/expense_database.dart';
import '../models/custom_reminder.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'expense_reminder_channel';
  static const String channelName = 'Daily Expense Reminders';
  static const String channelDescription =
      'Reminds you at scheduled times if no expenses are logged';

  static const int reminderNotificationId = 777;
  static const String reminderTag = 'expense_reminder';

  // Timely Checkpoint hours: 12 PM (12), 4 PM (16), 7 PM (19), 9 PM (21)
  static const List<int> reminderHours = [12, 16, 19, 21];
  static const Map<int, int> hourToAlarmId = {
    12: 1001,
    16: 1002,
    19: 1003,
    21: 1004,
  };

  static bool _initialized = false;
  static void Function(Uri uri)? onNotificationTap;

  /// Initializes timezone data, notification channels, and notification tap callbacks
  static Future<void> initialize({void Function(Uri uri)? onDeepLink}) async {
    if (_initialized) return;
    onNotificationTap = onDeepLink;

    _initTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          final uri = Uri.tryParse(payload);
          if (uri != null) {
            onNotificationTap?.call(uri);
          }
        }
      },
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();

      // Create high importance notification channel
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidImpl?.createNotificationChannel(channel);

      await androidImpl?.requestExactAlarmsPermission();
    }

    _initialized = true;

    // Check if the app was launched by tapping a notification
    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          final uri = Uri.tryParse(payload);
          if (uri != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              onNotificationTap?.call(uri);
            });
          }
        }
      }
    } catch (_) {}
  }

  /// Configures timezone offset to match the device's local clock accurately
  static void _initTimeZone() {
    tz.initializeTimeZones();
    final now = DateTime.now();

    // 1. Try direct location lookup by IANA name if available
    final name = now.timeZoneName;
    if (tz.timeZoneDatabase.locations.containsKey(name)) {
      tz.setLocalLocation(tz.getLocation(name));
      return;
    }

    // 2. Otherwise match location by offset in SECONDS
    final offsetSec = now.timeZoneOffset.inSeconds;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.currentTimeZone.offset == offsetSec) {
        tz.setLocalLocation(loc);
        return;
      }
    }
  }

  /// Retrieves the active book info (name and ID) for notification text and deep links
  static Future<Map<String, String>> _getCurrentBookInfo(ExpenseDatabase db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('group_id');
      final savedName = prefs.getString('group_name');

      if (savedId != null && savedId.isNotEmpty && savedName != null && savedName.isNotEmpty) {
        return {'id': savedId, 'name': savedName};
      }

      final groups = await db.fetchGroups();
      if (groups.isNotEmpty) {
        return {
          'id': groups.first.id.toString(),
          'name': groups.first.name,
        };
      }
    } catch (_) {}
    return {'id': '1', 'name': 'Expense Book'};
  }

  /// Checks settings and synchronizes active notification and alarms
  static Future<void> checkAndScheduleReminders(ExpenseDatabase db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      if (!notificationsEnabled) {
        await cancelAllNotifications();
        return;
      }

      final timelyRemindersEnabled = prefs.getBool('timely_reminders_enabled') ?? true;
      final now = DateTime.now();
      final hasExpenseToday = await db.hasExpensesOnDate(now);

      if (timelyRemindersEnabled) {
        if (hasExpenseToday) {
          await cancelReminderNotification();
          await _scheduleRemindersForTomorrow(db);
        } else {
          final bookInfo = await _getCurrentBookInfo(db);
          final currentHour = now.hour;

          if (currentHour >= 12) {
            await showPermanentReminder(
              groupId: bookInfo['id']!,
              groupName: bookInfo['name']!,
              checkpointHour: _getLatestPassedHour(currentHour),
            );
          }

          await _scheduleUpcomingReminders(db, now);
        }
      } else {
        await cancelReminderNotification();
      }

      // Schedule Custom Reminders without duplication
      await _scheduleCustomReminders(db);
    } catch (_) {}
  }

  /// Returns the highest checkpoint hour that has passed today
  static int _getLatestPassedHour(int currentHour) {
    for (int i = reminderHours.length - 1; i >= 0; i--) {
      if (currentHour >= reminderHours[i]) {
        return reminderHours[i];
      }
    }
    return 12;
  }

  /// Formats checkpoint hour to user-friendly label (e.g. "12 PM", "4 PM")
  static String _formatHourLabel(int hour) {
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }

  /// Displays the persistent, ongoing notification that cannot be swiped away
  static Future<void> showPermanentReminder({
    required String groupId,
    required String groupName,
    int? checkpointHour,
  }) async {
    final payload = 'expensetracker://addExpense?groupId=$groupId';
    final timeLabel = checkpointHour != null ? _formatHourLabel(checkpointHour) : '12 PM';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      tag: reminderTag,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      actions: const [
        AndroidNotificationAction(
          'add_expense_action',
          'Add Expense',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      reminderNotificationId,
      'Expense Reminder ($timeLabel)',
      'No expenses logged yet today for "$groupName". Tap to log an expense.',
      notificationDetails,
      payload: payload,
    );
  }

  /// Cancels the ongoing reminder notification and any duplicate reminder slots
  static Future<void> cancelReminderNotification() async {
    try {
      await _plugin.cancel(reminderNotificationId, tag: reminderTag);
      await _plugin.cancel(reminderNotificationId);
      for (final alarmId in hourToAlarmId.values) {
        await _plugin.cancel(alarmId, tag: reminderTag);
        await _plugin.cancel(alarmId);
      }
    } catch (_) {}
  }

  /// Cancels all notifications and alarms across the application
  static Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// Schedules future alarms for timely checkpoints today and tomorrow
  static Future<void> _scheduleUpcomingReminders(
    ExpenseDatabase db,
    DateTime now,
  ) async {
    _initTimeZone();
    final bookInfo = await _getCurrentBookInfo(db);
    final groupId = bookInfo['id']!;
    final groupName = bookInfo['name']!;
    final nowTz = tz.TZDateTime.now(tz.local);

    for (final hour in reminderHours) {
      final alarmId = hourToAlarmId[hour]!;
      var checkpoint = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        0,
      );

      if (!checkpoint.isAfter(nowTz)) {
        checkpoint = checkpoint.add(const Duration(days: 1));
      }

      await _scheduleAlarm(
        alarmId: alarmId,
        hour: hour,
        scheduledDate: checkpoint,
        groupId: groupId,
        groupName: groupName,
      );
    }
  }

  /// Schedules all timely checkpoints for tomorrow
  static Future<void> _scheduleRemindersForTomorrow(ExpenseDatabase db) async {
    _initTimeZone();
    final now = DateTime.now();
    final bookInfo = await _getCurrentBookInfo(db);
    final groupId = bookInfo['id']!;
    final groupName = bookInfo['name']!;

    for (final hour in reminderHours) {
      final alarmId = hourToAlarmId[hour]!;
      final tomorrowCheckpoint = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        0,
      ).add(const Duration(days: 1));

      await _scheduleAlarm(
        alarmId: alarmId,
        hour: hour,
        scheduledDate: tomorrowCheckpoint,
        groupId: groupId,
        groupName: groupName,
      );
    }
  }

  /// Schedules custom reminders configured by the user with clean slot management to avoid duplicates
  static Future<void> _scheduleCustomReminders(ExpenseDatabase db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString('custom_reminders_json') ?? '';
      final reminders = CustomReminder.decodeList(customJson);
      final bookInfo = await _getCurrentBookInfo(db);
      final groupId = bookInfo['id']!;
      final groupName = bookInfo['name']!;

      _initTimeZone();
      final now = DateTime.now();
      final nowTz = tz.TZDateTime.now(tz.local);

      // Wipes previous custom reminder slots (IDs 2000 to 2099) to prevent duplication
      for (int id = 2000; id < 2100; id++) {
        await _plugin.cancel(id);
      }

      for (int i = 0; i < reminders.length && i < 100; i++) {
        final reminder = reminders[i];
        final alarmId = 2000 + i;

        if (!reminder.isEnabled) continue;

        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          reminder.hour,
          reminder.minute,
        );

        if (!scheduledDate.isAfter(nowTz)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        final payload = 'expensetracker://addExpense?groupId=$groupId';

        const androidDetails = AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          actions: [
            AndroidNotificationAction(
              'add_expense_action',
              'Add Expense',
              showsUserInterface: true,
              cancelNotification: false,
            ),
          ],
        );

        const notificationDetails = NotificationDetails(android: androidDetails);

        try {
          await _plugin.zonedSchedule(
            alarmId,
            reminder.title.isNotEmpty ? reminder.title : 'Expense Reminder',
            'Time to log your expenses for "$groupName".',
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payload,
          );
        } catch (_) {
          await _plugin.zonedSchedule(
            alarmId,
            reminder.title.isNotEmpty ? reminder.title : 'Expense Reminder',
            'Time to log your expenses for "$groupName".',
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payload,
          );
        }
      }
    } catch (_) {}
  }

  /// Schedules an exact alarm with Android AlarmManager for timely reminders
  static Future<void> _scheduleAlarm({
    required int alarmId,
    required int hour,
    required tz.TZDateTime scheduledDate,
    required String groupId,
    required String groupName,
  }) async {
    final payload = 'expensetracker://addExpense?groupId=$groupId';
    final timeLabel = _formatHourLabel(hour);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      tag: reminderTag,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      actions: const [
        AndroidNotificationAction(
          'add_expense_action',
          'Add Expense',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        alarmId,
        'Expense Reminder ($timeLabel)',
        'No expenses logged yet today for "$groupName". Tap to log an expense.',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          alarmId,
          'Expense Reminder ($timeLabel)',
          'No expenses logged yet today for "$groupName". Tap to log an expense.',
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } catch (_) {}
    }
  }

  /// Called whenever an expense is created, updated, or deleted anywhere in the app
  static Future<void> onExpenseAdded(ExpenseDatabase db) async {
    await checkAndScheduleReminders(db);
  }
}
