import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/reminder_service.dart';
import 'package:mobile/features/activity/tasks_service.dart';

import 'fake_notification_gateway.dart';

DayTask _task(
  String id,
  String label, {
  String? reminder,
  int progress = 0,
  int target = 1,
}) =>
    DayTask(
      id: id,
      taskKey: 'key-$id',
      label: label,
      target: target,
      unit: '',
      step: 1,
      progress: progress,
      reminderTime: reminder,
    );

// Thursday 2026-10-15, 10:00 on the phone.
final _now = DateTime(2026, 10, 15, 10);

ReminderService _service(FakeNotificationGateway gateway) =>
    ReminderService(gateway: gateway, now: () => _now);

void main() {
  group('what gets scheduled', () {
    test('a reminder later today is scheduled for today and the next six days', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([_task('a', 'Tomar agua', reminder: '11:00')]);

      expect(gateway.scheduled.map((c) => c.when), [
        for (var day = 15; day <= 21; day++) DateTime(2026, 10, day, 11),
      ]);
    });

    test('a time that already passed today starts tomorrow', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([_task('a', 'Tomar agua', reminder: '09:00')]);

      expect(gateway.scheduled.first.when, DateTime(2026, 10, 16, 9));
      expect(gateway.scheduled, hasLength(6));
    });

    test('exactly now counts as passed', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([_task('a', 'Tomar agua', reminder: '10:00')]);

      expect(gateway.scheduled.first.when, DateTime(2026, 10, 16, 10));
    });

    test('a task already done today skips only today\'s reminder', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([_task('a', 'Desayunar', reminder: '11:00', progress: 1)]);

      expect(gateway.scheduled.first.when, DateTime(2026, 10, 16, 11));
      expect(gateway.scheduled, hasLength(6));
    });

    test('a counter only counts as done once it reaches its target', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([
        _task('a', 'Tomar agua', reminder: '11:00', progress: 7, target: 8),
        _task('b', 'Respirar', reminder: '12:00', progress: 3, target: 3),
      ]);

      final today = gateway.scheduled.where((c) => c.when.day == 15).map((c) => c.body);
      expect(today, ['Recordatorio: Tomar agua']);
    });

    test('unticking a task brings back today\'s reminder', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([_task('a', 'Desayunar', reminder: '11:00')]);

      expect(gateway.scheduled.first.when, DateTime(2026, 10, 15, 11));
    });

    test('tasks without a reminder are not scheduled', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([
        _task('a', 'Tomar agua'),
        _task('b', 'Desayunar', reminder: '07:05'),
      ]);

      expect(gateway.scheduled.map((c) => c.body).toSet(), {'Recordatorio: Desayunar'});
    });

    test('the notification names the task and stays neutral', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([_task('a', 'Tomar agua', reminder: '11:00')]);

      expect(gateway.scheduled.first.title, 'HabitQ');
      expect(gateway.scheduled.first.body, 'Recordatorio: Tomar agua');
    });

    test('a malformed reminder time is skipped instead of breaking the sync', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([
        _task('a', 'Roto', reminder: 'abc'),
        _task('b', 'Desayunar', reminder: '07:05'),
      ]);

      expect(gateway.scheduled.map((c) => c.body).toSet(), {'Recordatorio: Desayunar'});
    });

    test('the month rolls over correctly', () async {
      final gateway = FakeNotificationGateway();
      final service = ReminderService(gateway: gateway, now: () => DateTime(2026, 10, 29, 22));

      await service.sync([_task('a', 'Tomar agua', reminder: '23:00')]);

      expect(gateway.scheduled.map((c) => c.when).last, DateTime(2026, 11, 4, 23));
    });
  });

  group('clearing and ids', () {
    test('sync clears only the pending reminders, first', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([_task('a', 'Tomar agua', reminder: '11:00')]);

      expect(gateway.order.first, 'cancelPending');
      expect(gateway.cancelAllCalls, 0);
    });

    test('syncing no tasks still clears the pending reminders', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([]);

      expect(gateway.cancelPendingCalls, 1);
      expect(gateway.scheduled, isEmpty);
    });

    test('every scheduled notification has its own id', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([
        _task('a', 'Uno', reminder: '11:00'),
        _task('b', 'Dos', reminder: '12:00'),
        _task('c', 'Tres', reminder: '13:00'),
      ]);

      final ids = gateway.scheduled.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('a task day keeps the same id whatever else is in the list', () async {
      final alone = FakeNotificationGateway();
      final crowded = FakeNotificationGateway();
      final target = _task('0a1b2c3d-1111-2222-3333-444455556666', 'Tomar agua', reminder: '11:00');

      await _service(alone).sync([target]);
      await _service(crowded).sync([
        _task('ffffffff-1111-2222-3333-444455556666', 'Otra', reminder: '07:00'),
        target,
      ]);

      Set<int> idsOf(FakeNotificationGateway g) =>
          g.scheduled.where((c) => c.body.contains('Tomar agua')).map((c) => c.id).toSet();
      expect(idsOf(crowded), idsOf(alone));
    });

    test('two tasks whose ids start the same still never share a notification id', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).sync([
        _task('aaaaaaaa-0000-0000-0000-000000000001', 'Uno', reminder: '11:00'),
        _task('aaaaaaaa-0000-0000-0000-000000000002', 'Dos', reminder: '12:00'),
      ]);

      final ids = gateway.scheduled.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('notification ids are positive 31-bit numbers', () {
      for (var offset = 0; offset < ReminderService.windowDays; offset++) {
        final id = ReminderService.notificationId('ffffffff-ffff-ffff-ffff-ffffffffffff', offset);

        expect(id, greaterThan(0));
        expect(id, lessThanOrEqualTo(0x7fffffff));
      }
    });

    test('each day of the window gets a different id for the same task', () {
      final ids = {
        for (var offset = 0; offset < ReminderService.windowDays; offset++)
          ReminderService.notificationId('0a1b2c3d-1111-2222-3333-444455556666', offset),
      };

      expect(ids.length, ReminderService.windowDays);
    });
  });

  group('failures and permission', () {
    test('a notification failure never throws into the app', () async {
      final gateway = FakeNotificationGateway(failWith: StateError('plugin down'));
      final service = _service(gateway);

      await service.sync([_task('a', 'Tomar agua', reminder: '11:00')]);
      await service.cancelAll();
    });

    test('requestPermission returns what the system answered', () async {
      expect(await _service(FakeNotificationGateway()).requestPermission(), isTrue);
      expect(
        await _service(FakeNotificationGateway(permissionGranted: false)).requestPermission(),
        isFalse,
      );
    });

    test('requestPermission counts as denied when the plugin fails', () async {
      final gateway = FakeNotificationGateway(failWith: StateError('plugin down'));

      expect(await _service(gateway).requestPermission(), isFalse);
    });

    test('cancelAll clears pending reminders and the tray', () async {
      final gateway = FakeNotificationGateway();

      await _service(gateway).cancelAll();

      expect(gateway.cancelAllCalls, 1);
    });
  });
}
