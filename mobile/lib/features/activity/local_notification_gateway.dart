import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

/// Android implementation over flutter_local_notifications. Reminders use an
/// inexact alarm: Android may delay them a little to save battery, and that
/// avoids asking for the exact-alarm permission (D-25).
class LocalNotificationGateway implements NotificationGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'task_reminders',
    'Recordatorios de tareas',
    channelDescription: 'Avisos diarios de las tareas que elegiste.',
  );

  /// The scheduled times are read in the phone's own timezone.
  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureReady();
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _ensureReady();
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: next,
      notificationDetails: const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
