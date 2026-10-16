import 'package:mobile/features/activity/reminder_service.dart';

class ScheduledCall {
  ScheduledCall(this.id, this.title, this.body, this.hour, this.minute);

  final int id;
  final String title;
  final String body;
  final int hour;
  final int minute;
}

class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({this.permissionGranted = true, this.failWith});

  bool permissionGranted;
  Object? failWith;
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  final List<ScheduledCall> scheduled = [];
  final List<String> order = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (failWith != null) throw failWith!;
    return permissionGranted;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    order.add('cancel');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    order.add('schedule');
    if (failWith != null) throw failWith!;
    scheduled.add(ScheduledCall(id, title, body, hour, minute));
  }
}
