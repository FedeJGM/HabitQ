import 'package:mobile/features/activity/reminder_service.dart';

class ScheduledCall {
  ScheduledCall(this.id, this.title, this.body, this.when);

  final int id;
  final String title;
  final String body;
  final DateTime when;

  int get hour => when.hour;
  int get minute => when.minute;
}

class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({this.permissionGranted = true, this.failWith});

  bool permissionGranted;
  Object? failWith;
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  int cancelPendingCalls = 0;
  final List<ScheduledCall> scheduled = [];
  final List<String> order = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (failWith != null) throw failWith!;
    return permissionGranted;
  }

  @override
  Future<void> cancelPending() async {
    cancelPendingCalls++;
    order.add('cancelPending');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    order.add('cancel');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    order.add('schedule');
    if (failWith != null) throw failWith!;
    scheduled.add(ScheduledCall(id, title, body, when));
  }
}
