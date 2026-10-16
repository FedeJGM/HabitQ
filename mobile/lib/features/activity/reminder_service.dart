import 'package:flutter/foundation.dart';

import 'local_notification_gateway.dart';
import 'tasks_service.dart';

/// What the app needs from the phone's notification system. The real one is
/// [LocalNotificationGateway]; tests use a fake.
abstract class NotificationGateway {
  /// Asks for the notification permission (Android 13+). True when granted.
  Future<bool> requestPermission();

  /// Removes the reminders still waiting to fire. Notifications already shown
  /// in the tray stay there.
  Future<void> cancelPending();

  /// Removes everything: pending reminders and notifications already shown.
  Future<void> cancelAll();

  /// A one-time notification at [when] (the phone's local time).
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  });
}

/// Keeps the phone's reminders in line with the user's tasks. They are plain
/// local notifications at the time the user picked (D-25): no server and
/// nothing that decides when to notify. Failures never reach the UI: a task
/// works the same without its reminder.
///
/// Each reminder is scheduled as a separate notification for each of the next
/// [windowDays] days, not as one repeating alarm, so that today's can be left
/// out when the task is already done. The window is refreshed every time the
/// app syncs.
class ReminderService {
  ReminderService({NotificationGateway? gateway, DateTime Function()? now})
      : _gateway = gateway ?? LocalNotificationGateway(),
        _now = now ?? DateTime.now;

  /// Today plus the next six days.
  static const windowDays = 7;

  // 28 bits of the task id, shifted left 3 to leave room for the day offset
  // (0 to 7): the result always fits in a positive 32-bit notification id.
  static const _baseMask = 0xFFFFFFF;

  final NotificationGateway _gateway;
  final DateTime Function() _now;

  Future<bool> requestPermission() async {
    try {
      return await _gateway.requestPermission();
    } catch (error) {
      debugPrint('Reminder permission request failed: $error');
      return false;
    }
  }

  /// Replaces every pending reminder with the ones for [tasks], which must be
  /// today's list. Only the pending ones are cleared: a reminder that already
  /// fired keeps its notification until the user dismisses it. A task that is
  /// done today skips only today's reminder.
  Future<void> sync(List<DayTask> tasks) async {
    try {
      await _gateway.cancelPending();
      final now = _now();
      final usedBases = <int>{};
      for (final task in tasks) {
        final time = _parse(task.reminderTime);
        if (time == null) continue;

        var base = _baseId(task.id);
        while (!usedBases.add(base)) {
          base = (base + 1) & _baseMask;
          if (base == 0) base = 1;
        }

        for (var offset = 0; offset < windowDays; offset++) {
          if (offset == 0 && task.completed) continue;
          final when = DateTime(now.year, now.month, now.day + offset, time.$1, time.$2);
          if (!when.isAfter(now)) continue;
          await _gateway.scheduleAt(
            id: (base << 3) | offset,
            title: 'HabitQ',
            body: 'Recordatorio: ${task.label}',
            when: when,
          );
        }
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

  /// A stable positive 31-bit id for one task on one day of the window, taken
  /// from the task id (a UUID) so it does not depend on the task's position.
  static int notificationId(String taskId, [int dayOffset = 0]) =>
      (_baseId(taskId) << 3) | dayOffset;

  static int _baseId(String taskId) {
    final hex = taskId.replaceAll('-', '');
    final head = hex.length >= 7 ? hex.substring(0, 7) : hex;
    final parsed = int.tryParse(head, radix: 16);
    if (parsed != null) return parsed == 0 ? 1 : parsed;
    var hash = 17;
    for (final unit in taskId.codeUnits) {
      hash = (hash * 31 + unit) & _baseMask;
    }
    return hash == 0 ? 1 : hash;
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
