import 'package:flutter/foundation.dart';

import 'local_notification_gateway.dart';
import 'tasks_service.dart';

/// What the app needs from the phone's notification system. The real one is
/// [LocalNotificationGateway]; tests use a fake.
abstract class NotificationGateway {
  /// Asks for the notification permission (Android 13+). True when granted.
  Future<bool> requestPermission();

  Future<void> cancelAll();

  /// A notification that repeats every day at [hour]:[minute] local time.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  });
}

/// Keeps the phone's daily reminders in line with the user's tasks. They are
/// plain local notifications at the time the user picked (D-25): no server and
/// nothing that decides when to notify. Failures never reach the UI: a task
/// works the same without its reminder.
class ReminderService {
  ReminderService({NotificationGateway? gateway}) : _gateway = gateway ?? LocalNotificationGateway();

  final NotificationGateway _gateway;

  Future<bool> requestPermission() async {
    try {
      return await _gateway.requestPermission();
    } catch (error) {
      debugPrint('Reminder permission request failed: $error');
      return false;
    }
  }

  /// Replaces every scheduled reminder with the ones in [tasks]. Rescheduling
  /// everything keeps removed tasks from leaving a stale notification behind.
  Future<void> sync(List<DayTask> tasks) async {
    try {
      await _gateway.cancelAll();
      var id = 0;
      for (final task in tasks) {
        final time = _parse(task.reminderTime);
        if (time == null) continue;
        await _gateway.scheduleDaily(
          id: ++id,
          title: 'HabitQ',
          body: 'Recordatorio: ${task.label}',
          hour: time.$1,
          minute: time.$2,
        );
      }
    } catch (error) {
      debugPrint('Reminder sync failed: $error');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _gateway.cancelAll();
    } catch (error) {
      debugPrint('Reminder cancel failed: $error');
    }
  }

  static (int, int)? _parse(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }
}
