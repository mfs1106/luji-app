import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

/// System-scheduled time reminders, with an inexact fallback where required.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  final _notifications = FlutterLocalNotificationsPlugin();
  static const _native = MethodChannel('luji/files');
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _notifications.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null)
      return await android.requestNotificationsPermission() ?? false;
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null)
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    return false;
  }

  Future<bool> requestExactPermission() async {
    await init();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestExactAlarmsPermission() ?? false;
  }

  Future<void> cancel(int id) async {
    await init();
    await _notifications.cancel(id);
    try {
      await _native.invokeMethod<bool>('removeGeofence', {'id': id});
    } on MissingPluginException {
      // The Android cleanup hook is absent on other platforms.
    } on PlatformException {
      // Alarm cancellation above still succeeds when Play Services is absent.
    }
  }

  Future<void> register(Reminder reminder) async {
    await init();
    final id = reminder.id;
    if (id == null) return;
    await cancel(id);
    if (!reminder.enabled) return;
    if (reminder.isGeo) return;
    final trigger = reminder.triggerTime;
    if (trigger == null) return;
    var when = reminder.type == 'depart'
        ? trigger.subtract(Duration(minutes: reminder.advanceMinutes))
        : trigger;
    final daily = reminder.repeatRule == 'daily';
    if (daily) {
      final now = DateTime.now();
      when = DateTime(now.year, now.month, now.day, when.hour, when.minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    } else if (!when.isAfter(DateTime.now())) {
      return;
    }
    final target = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        'luji_reminder',
        '时间提醒',
        channelDescription: '旅记的定时提醒',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(subtitle: reminder.subtitle),
    );
    Future<void> schedule(AndroidScheduleMode mode) =>
        _notifications.zonedSchedule(
          id,
          reminder.title,
          reminder.subtitle,
          target,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: mode,
          matchDateTimeComponents: daily ? DateTimeComponents.time : null,
        );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  Future<void> resyncAll(List<Reminder> reminders) async {
    await init();
    for (final reminder in reminders) {
      if (!reminder.isGeo) await register(reminder);
    }
  }
}
