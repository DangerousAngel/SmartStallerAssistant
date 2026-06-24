import 'package:alarm/alarm.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static int _notificationMinutesBefore = 15;

  static Future<void> initialize() async {
    // 1. Initialize Timezones
    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(timeZoneName);
      tz.setLocalLocation(location);
      print("✅ Timezone set to: $timeZoneName");
    } catch (e) {
      print("⚠️ Could not set local location, using local: $e");
      tz.setLocalLocation(tz.local);
    }

    // 2. Initialize Notifications Plugin
    // We strictly use LocalNotifications for REMINDERS now.
    // ALARMS are handled by the 'alarm' package.

    const AndroidNotificationChannel reminderChannel =
        AndroidNotificationChannel(
      'lecture_channel',
      'Lecture Reminders',
      description: 'Notifications for upcoming lectures',
      importance: Importance.max,
      playSound: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(reminderChannel);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      linux: const LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        print("🔔 Notification clicked: ${response.payload}");
      },
    );

    // 3. Initialize Alarm Package
    await Alarm.init();

    print("✅ NotificationService & Alarm initialized");
  }

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } else if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  static void setNotificationMinutesBefore(int minutes) {
    _notificationMinutesBefore = minutes;
  }

  static int getNotificationMinutesBefore() => _notificationMinutesBefore;

  static Future<void> scheduleLectureNotification(
      Map<String, dynamic> lecture, AppLocalizations? l10n) async {
    final subject = lecture['subject'] as String? ?? '';
    final room = lecture['room'] as String? ?? '';
    final timeString = lecture['time'] as String? ?? '';
    final dayString = lecture['day'] as String? ?? '';
    final professor = lecture['professor'] as String? ?? '';

    final parsedTime = _parseTimeString(timeString);
    if (parsedTime == null) return;

    // Base scheduled time (Lecture Start Time)
    tz.TZDateTime scheduledDate = _nextInstanceOfDayAndTime(
      dayString,
      parsedTime['hour']!,
      parsedTime['minute']!,
    );

    final now = tz.TZDateTime.now(tz.local);
    final reminderDuration = Duration(minutes: _notificationMinutesBefore);

    // --- 1. SCHEDULE REMINDER (Before class) - Using LocalNotifications ---
    final int reminderId = _generateNotificationId(lecture, type: 'reminder');
    tz.TZDateTime reminderTime = scheduledDate.subtract(reminderDuration);

    // bool isLateReminder = false; // Unused
    tz.TZDateTime finalReminderTime = reminderTime;

    // Logic for past/late reminders
    if (reminderTime.isBefore(now)) {
      if (scheduledDate.isAfter(now)) {
        // Late Reminder for THIS week
        print("⚠️ Late Reminder for $subject");
        final minutesRemaining = scheduledDate.difference(now).inMinutes;
        final displayMinutes = minutesRemaining > 0 ? minutesRemaining : 0;
        final body = l10n != null
            ? l10n.lectureStartsIn(subject, room, displayMinutes)
            : '$subject in $room starts in $displayMinutes minutes';

        await _showNotificationImmediately(
            id: reminderId + 900000,
            title: l10n?.lectureReminder ?? 'Lecture Reminder',
            body: body,
            channelId: 'lecture_channel');

        // Schedule next one for next week
        final nextWeekDate = scheduledDate.add(const Duration(days: 7));
        finalReminderTime = nextWeekDate.subtract(reminderDuration);
      } else {
        // Lecture passed, schedule for next week
        final nextWeekDate = scheduledDate.add(const Duration(days: 7));
        finalReminderTime = nextWeekDate.subtract(reminderDuration);
      }
    } else {
      finalReminderTime = reminderTime;
    }

    await _scheduleExactReminder(
        id: reminderId,
        title: l10n?.lectureReminder ?? 'Lecture Reminder',
        body: l10n != null
            ? l10n.lectureStartsIn(subject, room, _notificationMinutesBefore)
            : '$subject in $room starts in $_notificationMinutesBefore minutes',
        time: finalReminderTime,
        channelId: 'lecture_channel');

    // --- 2. SCHEDULE ALARM (At Exact Start Time) - Using Alarm Package ---
    final int alarmId = _generateNotificationId(lecture, type: 'alarm');
    tz.TZDateTime alarmTime = scheduledDate;

    // If lecture start time is already in the past, move to next week
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 7));
    }

    // Set up Alarm Settings
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: alarmTime,
      assetAudioPath: 'assets/notify_da.mp3', // User must have this in assets!
      loopAudio: true,
      vibrate: true,
      volume: 1.0,
      fadeDuration: 3.0,
      notificationTitle: subject,
      notificationBody:
          '$room\n ${professor.isNotEmpty ? "• ${l10n?.dr ?? 'Dr.'} $professor" : ""}',
      enableNotificationOnKill: true,
      androidFullScreenIntent: true,
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      print("⏰ Alarm Set for $subject at $alarmTime (ID: $alarmId)");
    } catch (e) {
      print("❌ Error setting Alarm: $e");
    }

    print(
        "📆 Scheduled: Reminder @ $finalReminderTime | Alarm @ $alarmTime for $subject");
  }

  static Future<void> _scheduleExactReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime time,
    required String channelId,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        time,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lecture_channel',
            'Lecture Reminders',
            channelDescription: 'Notifications for upcoming lectures',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      print("❌ Error scheduling reminder $id: $e");
    }
  }

  static Future<void> _showNotificationImmediately(
      {required int id,
      required String title,
      required String body,
      required String channelId}) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> showNearestLectureNow(
      List<Map<String, dynamic>> timetable, AppLocalizations? l10n) async {
    if (timetable.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);
    Map<String, dynamic>? nearestLecture;
    Duration? shortestDiff;

    for (var lecture in timetable) {
      // final subject = lecture['subject'] as String? ?? '';
      final timeString = lecture['time'] as String? ?? '';
      final dayString = lecture['day'] as String? ?? '';

      final parsedTime = _parseTimeString(timeString);
      if (parsedTime == null) continue;

      tz.TZDateTime scheduledDate = _nextInstanceOfDayAndTime(
        dayString,
        parsedTime['hour']!,
        parsedTime['minute']!,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      }

      final diff = scheduledDate.difference(now);
      if (shortestDiff == null || diff < shortestDiff) {
        shortestDiff = diff;
        nearestLecture = lecture;
      }
    }

    if (nearestLecture != null) {
      final subject = nearestLecture['subject'];
      final room = nearestLecture['room'];
      final minutes = shortestDiff!.inMinutes;

      await _showNotificationImmediately(
        id: 888888,
        title: l10n?.nextLecture ?? 'Next Lecture',
        body: l10n != null
            ? l10n.lectureStartsIn(subject, room, minutes)
            : '$subject in $room starts in $minutes minutes',
        channelId: 'lecture_channel',
      );
    }
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    await Alarm.stopAll();
    print("🛑 All notifications and alarms cancelled");
  }

  static Future<void> cancelLectureNotification(
      Map<String, dynamic> lecture) async {
    final int reminderId = _generateNotificationId(lecture, type: 'reminder');
    final int alarmId = _generateNotificationId(lecture, type: 'alarm');

    await _notificationsPlugin.cancel(reminderId);
    await Alarm.stop(alarmId);
    print("🔕 Cancelled notifications for ${lecture['subject']}");
  }

  // --- HELPERS ---

  static int _generateNotificationId(Map<String, dynamic> lecture,
      {String type = 'reminder'}) {
    final key =
        '${lecture['day']}_${lecture['time']}_${lecture['subject']}_$type'
            .trim();
    return key.hashCode & 0x7FFFFFFF;
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(
      String dayName, int hour, int minute) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    int targetWeekday = _getWeekdayIndex(dayName);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.weekday == targetWeekday) {
      return scheduledDate;
    }

    while (scheduledDate.weekday != targetWeekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static int _getWeekdayIndex(String dayName) {
    final day = dayName.trim().toLowerCase();
    if (day.contains('mon') || day.contains('الإثنين')) return DateTime.monday;
    if (day.contains('tue') || day.contains('الثلاثاء'))
      return DateTime.tuesday;
    if (day.contains('wed') || day.contains('الأربعاء'))
      return DateTime.wednesday;
    if (day.contains('thu') || day.contains('الخميس')) return DateTime.thursday;
    if (day.contains('fri') || day.contains('الجمعة')) return DateTime.friday;
    if (day.contains('sat') || day.contains('السبت')) return DateTime.saturday;
    if (day.contains('sun') || day.contains('الأحد')) return DateTime.sunday;
    return DateTime.monday;
  }

  static Map<String, int>? _parseTimeString(String time) {
    try {
      final cleaned = time.trim().toUpperCase();
      final cleared = cleaned
          .replaceAll(RegExp(r'AM|PM|ص|م', caseSensitive: false), '')
          .trim();

      final parts = cleared.split(':');
      if (parts.length != 2) return null;

      int? hour = int.tryParse(parts[0]);
      int? minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;

      final is12Hour =
          RegExp(r'AM|PM|ص|م', caseSensitive: false).hasMatch(cleaned);

      if (is12Hour) {
        final isPM = RegExp(r'PM|م', caseSensitive: false).hasMatch(cleaned);
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
      }

      return {'hour': hour, 'minute': minute};
    } catch (_) {
      return null;
    }
  }
}
