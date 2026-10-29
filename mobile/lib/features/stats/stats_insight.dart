import 'stats_service.dart';

const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// One neutral sentence about the week, computed from the same data as the
/// chart. It describes how much of what the person chose to do was done; it
/// never judges their health (a 100 % only means they did what they chose).
/// Null when no day had tasks.
String? weeklyInsight(TaskStats stats) {
  final withTasks = stats.days.where((day) => day.active > 0).toList();
  if (withTasks.isEmpty) return null;

  final active = withTasks.fold<int>(0, (sum, day) => sum + day.active);
  final completed = withTasks.fold<int>(0, (sum, day) => sum + day.completed);
  final percent = (completed / active * 100).round();
  final head = 'Completaste el $percent % de las tareas que elegiste esta semana.';

  // A trend needs enough days to mean something.
  if (withTasks.length < 4) return head;
  final half = withTasks.length ~/ 2;
  final first = _rate(withTasks.take(half));
  final last = _rate(withTasks.skip(withTasks.length - half));
  if (last - first >= 0.15) return '$head Tus últimos días fueron mejor que los primeros.';
  if (first - last >= 0.15) return '$head Tus últimos días cumplieron menos que los primeros.';
  return head;
}

double _rate(Iterable<StatsDay> days) {
  final active = days.fold<int>(0, (sum, day) => sum + day.active);
  if (active == 0) return 0;
  return days.fold<int>(0, (sum, day) => sum + day.completed) / active;
}

/// The chart read aloud: each day with its weekday and how many tasks it had.
String chartSummary(TaskStats stats) {
  final days = [
    for (final day in stats.days)
      day.active == 0
          ? '${_weekdays[day.day.weekday - 1]} ${day.day.day}: sin tareas'
          : '${_weekdays[day.day.weekday - 1]} ${day.day.day}: ${day.completed} de ${day.active}',
  ];
  return 'Cumplimiento por día de los últimos 7 días. ${days.join('. ')}.';
}
