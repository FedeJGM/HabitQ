import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

/// Android implementation over flutter_local_notifications. Reminders use an
/// exact alarm so they arrive at the minute the user picked: an inexact one can
/// be delayed up to an hour (D-25). The manifest declares USE_EXACT_ALARM, which
/// Android 13+ grants at install time; if it is ever missing the reminder falls
/// back to an inexact alarm.
class LocalNotificationGateway implements NotificationGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Error code the plugin raises when exact alarms are not allowed.
  static const _exactAlarmsNotPermitted = 'exact_alarms_not_permitted';

  static const _channel = AndroidNotificationDetails(
    'task_reminders',
    'Recordatorios de tareas',
    channelDescription: 'Avisos de las tareas que elegiste.',
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
  Future<void> cancelPending() => _plugin.cancelAllPendingNotifications();

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await _ensureReady();
    final date = tz.TZDateTime(tz.local, when.year, when.month, when.day, when.hour, when.minute);

    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: date,
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: mode,
        );

    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (error) {
      // Without the exact-alarm permission a late reminder beats no reminder.
      if (error.code != _exactAlarmsNotPermitted) rethrow;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }
}
