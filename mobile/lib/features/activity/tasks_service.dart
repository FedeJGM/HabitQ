import '../../core/networking/api_client.dart';

/// A task the user can activate for their goal (GET /tasks/catalog).
class CatalogTask {
  const CatalogTask({
    required this.key,
    required this.label,
    required this.target,
    required this.unit,
    required this.step,
  });

  factory CatalogTask.fromJson(Map<String, dynamic> json) => CatalogTask(
        key: json['key'] as String,
        label: json['label'] as String,
        target: json['target'] as int,
        unit: json['unit'] as String,
        step: json['step'] as int,
      );

  final String key;
  final String label;
  final int target;
  final String unit;
  final int step;

  bool get isCounter => target > 1;
}

/// An activated task as it looks on one day: [progress] is that day's count and
/// [reminderTime] is "HH:mm" or null.
class DayTask {
  const DayTask({
    required this.id,
    required this.taskKey,
    required this.label,
    required this.target,
    required this.unit,
    required this.step,
    required this.progress,
    this.reminderTime,
  });

  factory DayTask.fromJson(Map<String, dynamic> json) => DayTask(
        id: json['id'] as String,
        taskKey: json['task_key'] as String,
        label: json['label'] as String,
        target: json['target'] as int,
        unit: json['unit'] as String,
        step: json['step'] as int,
        progress: (json['progress'] as int?) ?? 0,
        reminderTime: _hourMinute(json['reminder_time'] as String?),
      );

  final String id;
  final String taskKey;
  final String label;
  final int target;
  final String unit;
  final int step;
  final int progress;
  final String? reminderTime;

  bool get isCounter => target > 1;
  bool get completed => progress >= target;

  DayTask copyWith({int? progress}) => DayTask(
        id: id,
        taskKey: taskKey,
        label: label,
        target: target,
        unit: unit,
        step: step,
        progress: progress ?? this.progress,
        reminderTime: reminderTime,
      );

  /// The backend returns "08:30:00"; the app works with "08:30".
  static String? _hourMinute(String? time) =>
      time == null ? null : (time.length >= 5 ? time.substring(0, 5) : time);
}

/// Wraps the /tasks endpoints. Days are the user's local calendar date: the
/// backend stores progress per date and the new day starts at local midnight.
class TasksService {
  TasksService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static String dayKey(DateTime day) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';
  }

  Future<List<CatalogTask>> fetchCatalog() async {
    final results = await _apiClient.getList('/tasks/catalog');
    return results.cast<Map<String, dynamic>>().map(CatalogTask.fromJson).toList();
  }

  Future<List<DayTask>> fetchTasks(DateTime day) async {
    final results = await _apiClient.getList('/tasks?day=${dayKey(day)}');
    return results.cast<Map<String, dynamic>>().map(DayTask.fromJson).toList();
  }

  Future<DayTask> activate(String taskKey, {String? reminderTime}) async {
    final response = await _apiClient.post('/tasks', {
      'task_key': taskKey,
      if (reminderTime != null) 'reminder_time': reminderTime,
    });
    return DayTask.fromJson(response);
  }

  /// [reminderTime] "HH:mm", or null to remove the reminder.
  Future<void> setReminder(String id, String? reminderTime) async {
    await _apiClient.put('/tasks/$id', {'reminder_time': reminderTime});
  }

  Future<void> archive(String id) => _apiClient.delete('/tasks/$id');

  Future<DayTask> setProgress(String id, DateTime day, int progress) async {
    final response = await _apiClient.put('/tasks/$id/progress', {
      'day': dayKey(day),
      'progress': progress,
    });
    return DayTask.fromJson(response);
  }
}
