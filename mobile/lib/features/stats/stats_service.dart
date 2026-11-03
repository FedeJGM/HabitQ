import '../../core/networking/api_client.dart';
import '../activity/tasks_service.dart';

DateTime _parseDay(String value) {
  final parts = value.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// One day of the window: [active] tasks counted that day and how many of them
/// reached their target ([completed]).
class StatsDay {
  const StatsDay({required this.day, required this.active, required this.completed});

  factory StatsDay.fromJson(Map<String, dynamic> json) => StatsDay(
        day: _parseDay(json['day'] as String),
        active: json['active'] as int,
        completed: json['completed'] as int,
      );

  final DateTime day;
  final int active;
  final int completed;

  /// Completion of the day, 0 to 100. A day without tasks is 0, not "no data":
  /// use [active] to tell them apart.
  double get percent => active == 0 ? 0 : completed * 100 / active;
}

/// Mean progress of a counter task over the days of the window it counted.
class CounterStat {
  const CounterStat({
    required this.taskKey,
    required this.label,
    required this.unit,
    required this.target,
    required this.days,
    required this.average,
  });

  factory CounterStat.fromJson(Map<String, dynamic> json) => CounterStat(
        taskKey: json['task_key'] as String,
        label: json['label'] as String,
        unit: json['unit'] as String,
        target: json['target'] as int,
        days: json['days'] as int,
        average: (json['average'] as num).toDouble(),
      );

  final String taskKey;
  final String label;
  final String unit;
  final int target;
  final int days;
  final double average;
}

/// The last seven days ending on the requested local day (GET /tasks/stats).
class TaskStats {
  const TaskStats({required this.days, required this.counters, required this.bestDay});

  factory TaskStats.fromJson(Map<String, dynamic> json) {
    final bestDay = json['best_day'] as String?;
    return TaskStats(
      days: (json['days'] as List).cast<Map<String, dynamic>>().map(StatsDay.fromJson).toList(),
      counters:
          (json['counters'] as List).cast<Map<String, dynamic>>().map(CounterStat.fromJson).toList(),
      bestDay: bestDay == null ? null : _parseDay(bestDay),
    );
  }

  final List<StatsDay> days;
  final List<CounterStat> counters;
  final DateTime? bestDay;

  /// False when no day of the window had any task.
  bool get hasData => days.any((day) => day.active > 0);
}

/// Wraps GET /tasks/stats. [day] is the user's local calendar date, like in
/// [TasksService]: the server counts the window that ends on it.
class StatsService {
  StatsService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<TaskStats> fetchStats(DateTime day) async {
    final response = await _apiClient.get('/tasks/stats?day=${TasksService.dayKey(day)}');
    return TaskStats.fromJson(response);
  }
}
