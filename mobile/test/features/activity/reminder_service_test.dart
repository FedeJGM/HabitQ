import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activity/reminder_service.dart';
import 'package:mobile/features/activity/tasks_service.dart';

import 'fake_notification_gateway.dart';

DayTask _task(String id, String label, {String? reminder}) => DayTask(
      id: id,
      taskKey: 'key-$id',
      label: label,
      target: 1,
      unit: '',
      step: 1,
      progress: 0,
      reminderTime: reminder,
    );

void main() {
  test('sync clears the old schedule first and then schedules each reminder', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([
      _task('a', 'Tomar agua', reminder: '08:30'),
      _task('b', 'Desayunar', reminder: '07:05'),
    ]);

    expect(gateway.order, ['cancelPending', 'schedule', 'schedule']);
    expect(gateway.scheduled.map((c) => (c.hour, c.minute)), [(8, 30), (7, 5)]);
  });

  test('every reminder gets its own notification id', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([
      _task('a', 'Uno', reminder: '08:00'),
      _task('b', 'Dos', reminder: '09:00'),
      _task('c', 'Tres', reminder: '10:00'),
    ]);

    final ids = gateway.scheduled.map((c) => c.id).toList();
    expect(ids.toSet().length, 3);
  });

  test('the notification names the task and stays neutral', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([_task('a', 'Tomar agua', reminder: '08:30')]);

    expect(gateway.scheduled.single.title, 'HabitQ');
    expect(gateway.scheduled.single.body, 'Recordatorio: Tomar agua');
  });

  test('tasks without a reminder are not scheduled', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([
      _task('a', 'Tomar agua'),
      _task('b', 'Desayunar', reminder: '07:05'),
    ]);

    expect(gateway.scheduled.map((c) => c.body), ['Recordatorio: Desayunar']);
  });

  test('syncing no tasks still clears the pending reminders', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([]);

    expect(gateway.cancelPendingCalls, 1);
    expect(gateway.scheduled, isEmpty);
  });

  test('sync leaves the notifications already in the tray alone', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([_task('a', 'Tomar agua', reminder: '08:30')]);

    expect(gateway.cancelAllCalls, 0);
  });

  test('a task keeps the same notification id whatever the list looks like', () async {
    final first = FakeNotificationGateway();
    final second = FakeNotificationGateway();
    final target = _task('0a1b2c3d-1111-2222-3333-444455556666', 'Tomar agua', reminder: '08:30');

    await ReminderService(gateway: first).sync([target]);
    await ReminderService(gateway: second).sync([
      _task('ffffffff-1111-2222-3333-444455556666', 'Otra', reminder: '07:00'),
      target,
    ]);

    final idInFirst = first.scheduled.single.id;
    final idInSecond = second.scheduled.firstWhere((c) => c.body.contains('Tomar agua')).id;
    expect(idInSecond, idInFirst);
  });

  test('two tasks whose ids start the same still get different notification ids', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([
      _task('aaaaaaaa-0000-0000-0000-000000000001', 'Uno', reminder: '08:00'),
      _task('aaaaaaaa-0000-0000-0000-000000000002', 'Dos', reminder: '09:00'),
    ]);

    expect(gateway.scheduled.map((c) => c.id).toSet().length, 2);
  });

  test('notification ids are positive 31-bit numbers', () {
    final id = ReminderService.notificationId('ffffffff-ffff-ffff-ffff-ffffffffffff');

    expect(id, greaterThan(0));
    expect(id, lessThanOrEqualTo(0x7fffffff));
  });

  test('a malformed reminder time is skipped instead of breaking the sync', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([
      _task('a', 'Roto', reminder: 'abc'),
      _task('b', 'Desayunar', reminder: '07:05'),
    ]);

    expect(gateway.scheduled.map((c) => c.body), ['Recordatorio: Desayunar']);
  });

  test('a notification failure never throws into the app', () async {
    final gateway = FakeNotificationGateway(failWith: StateError('plugin down'));
    final service = ReminderService(gateway: gateway);

    await service.sync([_task('a', 'Tomar agua', reminder: '08:30')]);
    await service.cancelAll();
  });

  test('requestPermission returns what the system answered', () async {
    expect(await ReminderService(gateway: FakeNotificationGateway()).requestPermission(), isTrue);
    expect(
      await ReminderService(gateway: FakeNotificationGateway(permissionGranted: false))
          .requestPermission(),
      isFalse,
    );
  });

  test('requestPermission counts as denied when the plugin fails', () async {
    final gateway = FakeNotificationGateway(failWith: StateError('plugin down'));

    expect(await ReminderService(gateway: gateway).requestPermission(), isFalse);
  });

  test('cancelAll clears the schedule', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).cancelAll();

    expect(gateway.cancelAllCalls, 1);
  });
}
