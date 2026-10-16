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

    expect(gateway.order, ['cancel', 'schedule', 'schedule']);
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

  test('syncing no tasks still clears whatever was scheduled before', () async {
    final gateway = FakeNotificationGateway();

    await ReminderService(gateway: gateway).sync([]);

    expect(gateway.cancelAllCalls, 1);
    expect(gateway.scheduled, isEmpty);
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
