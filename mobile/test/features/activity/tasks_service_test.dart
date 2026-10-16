import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/activity/tasks_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.error, this.listResponse, this.mapResponse});

  ApiException? error;
  List<dynamic>? listResponse;
  Map<String, dynamic>? mapResponse;
  String? lastPath;
  Map<String, dynamic>? lastBody;
  String? lastMethod;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = body;
    if (error != null) throw error!;
    return mapResponse!;
  }

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    lastMethod = 'PUT';
    lastPath = path;
    lastBody = body;
    if (error != null) throw error!;
    return mapResponse!;
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    lastMethod = 'GET';
    lastPath = path;
    if (error != null) throw error!;
    return listResponse!;
  }

  @override
  Future<void> delete(String path) async {
    lastMethod = 'DELETE';
    lastPath = path;
    if (error != null) throw error!;
  }

  @override
  Future<Map<String, dynamic>> get(String path) {
    throw UnimplementedError();
  }
}

Map<String, dynamic> _taskJson({
  String id = 't1',
  String key = 'hydrate_water',
  String label = 'Tomar agua',
  int target = 8,
  String unit = 'vasos',
  int step = 1,
  String? reminder,
  int? progress,
  bool? completed,
}) =>
    {
      'id': id,
      'task_key': key,
      'label': label,
      'target': target,
      'unit': unit,
      'step': step,
      'reminder_time': reminder,
      if (progress != null) 'progress': progress,
      if (completed != null) 'completed': completed,
    };

void main() {
  group('TasksService', () {
    test('dayKey formats a date as zero-padded YYYY-MM-DD', () {
      expect(TasksService.dayKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    });

    test('fetchCatalog parses the tasks offered for the goal', () async {
      final client = _FakeApiClient(listResponse: [
        {'key': 'hydrate_water', 'label': 'Tomar agua', 'target': 8, 'unit': 'vasos', 'step': 1},
        {'key': 'hydrate_morning', 'label': 'Vaso al despertar', 'target': 1, 'unit': '', 'step': 1},
      ]);

      final catalog = await TasksService(apiClient: client).fetchCatalog();

      expect(client.lastPath, '/tasks/catalog');
      expect(catalog.map((t) => t.key), ['hydrate_water', 'hydrate_morning']);
      expect(catalog.first.target, 8);
      expect(catalog.first.unit, 'vasos');
      expect(catalog.first.isCounter, isTrue);
      expect(catalog.last.isCounter, isFalse);
    });

    test('fetchTasks asks for the given local day and parses progress', () async {
      final client = _FakeApiClient(listResponse: [
        _taskJson(reminder: '08:30:00', progress: 2, completed: false),
        _taskJson(id: 't2', key: 'stress_breathing', target: 3, progress: 3, completed: true),
      ]);

      final tasks = await TasksService(apiClient: client).fetchTasks(DateTime(2026, 10, 5, 14));

      expect(client.lastMethod, 'GET');
      expect(client.lastPath, '/tasks?day=2026-10-05');
      expect(tasks.first.id, 't1');
      expect(tasks.first.progress, 2);
      expect(tasks.first.completed, isFalse);
      expect(tasks.first.reminderTime, '08:30');
      expect(tasks.last.reminderTime, isNull);
      expect(tasks.last.completed, isTrue);
    });

    test('activate posts the task key and returns it with zero progress', () async {
      final client = _FakeApiClient(mapResponse: _taskJson());

      final task = await TasksService(apiClient: client).activate('hydrate_water');

      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/tasks');
      expect(client.lastBody, {'task_key': 'hydrate_water'});
      expect(task.progress, 0);
      expect(task.completed, isFalse);
      expect(task.label, 'Tomar agua');
    });

    test('activate sends the reminder time when given', () async {
      final client = _FakeApiClient(mapResponse: _taskJson(reminder: '09:15:00'));

      final task =
          await TasksService(apiClient: client).activate('hydrate_water', reminderTime: '09:15');

      expect(client.lastBody, {'task_key': 'hydrate_water', 'reminder_time': '09:15'});
      expect(task.reminderTime, '09:15');
    });

    test('setReminder puts the time, or null to clear it', () async {
      final client = _FakeApiClient(mapResponse: _taskJson());
      final service = TasksService(apiClient: client);

      await service.setReminder('t1', '07:45');
      expect(client.lastMethod, 'PUT');
      expect(client.lastPath, '/tasks/t1');
      expect(client.lastBody, {'reminder_time': '07:45'});

      await service.setReminder('t1', null);
      expect(client.lastBody, {'reminder_time': null});
    });

    test('archive deletes the task', () async {
      final client = _FakeApiClient();

      await TasksService(apiClient: client).archive('t1');

      expect(client.lastMethod, 'DELETE');
      expect(client.lastPath, '/tasks/t1');
    });

    test('setProgress puts the local day and the count and parses the result', () async {
      final client = _FakeApiClient(mapResponse: _taskJson(progress: 3, completed: false));

      final task = await TasksService(apiClient: client).setProgress('t1', DateTime(2026, 10, 5), 3);

      expect(client.lastMethod, 'PUT');
      expect(client.lastPath, '/tasks/t1/progress');
      expect(client.lastBody, {'day': '2026-10-05', 'progress': 3});
      expect(task.progress, 3);
    });

    test('propagates API errors', () async {
      final client = _FakeApiClient(error: ApiException('boom'));
      final service = TasksService(apiClient: client);

      expect(service.fetchCatalog(), throwsA(isA<ApiException>()));
      expect(service.fetchTasks(DateTime(2026, 10, 5)), throwsA(isA<ApiException>()));
      expect(service.activate('x'), throwsA(isA<ApiException>()));
      expect(service.archive('t1'), throwsA(isA<ApiException>()));
    });
  });

  group('DayTask', () {
    test('copyWith changes only the progress and recomputes completion', () {
      final task = DayTask.fromJson(_taskJson(progress: 2, completed: false));

      final done = task.copyWith(progress: 8);

      expect(done.progress, 8);
      expect(done.completed, isTrue);
      expect(done.id, task.id);
      expect(task.progress, 2);
    });

    test('isCounter is true only when the target is above one', () {
      expect(DayTask.fromJson(_taskJson(target: 8, progress: 0, completed: false)).isCounter, isTrue);
      expect(DayTask.fromJson(_taskJson(target: 1, progress: 0, completed: false)).isCounter, isFalse);
    });
  });
}
