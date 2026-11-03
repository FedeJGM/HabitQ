import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/stats/stats_insight.dart';
import 'package:mobile/features/stats/stats_service.dart';

TaskStats _week(List<(int active, int completed)> days) {
  final first = DateTime(2026, 10, 9);
  return TaskStats(
    days: [
      for (var i = 0; i < days.length; i++)
        StatsDay(day: first.add(Duration(days: i)), active: days[i].$1, completed: days[i].$2),
    ],
    counters: const [],
    bestDay: null,
  );
}

void main() {
  group('weeklyInsight', () {
    test('is null when no day had tasks', () {
      expect(weeklyInsight(_week([for (var i = 0; i < 7; i++) (0, 0)])), isNull);
    });

    test('reports the share of chosen tasks completed over the week', () {
      final insight = weeklyInsight(_week([(4, 2), (4, 2), (4, 2), (4, 2), (4, 2), (4, 2), (4, 2)]));

      expect(insight, startsWith('Completaste el 50 % de las tareas que elegiste'));
    });

    test('rounds the percentage', () {
      final insight = weeklyInsight(_week([(3, 1), (3, 1), (3, 1), (3, 1), (3, 1), (3, 1), (3, 1)]));

      expect(insight, contains('33 %'));
    });

    test('ignores days without tasks', () {
      final insight = weeklyInsight(_week([(0, 0), (0, 0), (2, 2), (0, 0), (2, 2), (0, 0), (0, 0)]));

      expect(insight, contains('100 %'));
    });

    test('notes a rising week when the last days beat the first ones', () {
      final insight = weeklyInsight(_week([(4, 0), (4, 1), (4, 1), (4, 2), (4, 3), (4, 4), (4, 4)]));

      expect(insight, contains('últimos días'));
      expect(insight, contains('mejor'));
    });

    test('notes a falling week without judging health', () {
      final insight = weeklyInsight(_week([(4, 4), (4, 4), (4, 3), (4, 2), (4, 1), (4, 0), (4, 0)]));

      expect(insight, contains('últimos días'));
      expect(insight, contains('menos'));
      expect(insight!.toLowerCase(), isNot(contains('salud')));
    });

    test('says nothing about the trend when the week is steady', () {
      final insight = weeklyInsight(_week([(4, 2), (4, 2), (4, 2), (4, 2), (4, 2), (4, 2), (4, 2)]));

      expect(insight, isNot(contains('últimos días')));
    });

    test('needs at least four days with tasks to talk about a trend', () {
      final insight = weeklyInsight(_week([(0, 0), (0, 0), (0, 0), (4, 0), (4, 4), (0, 0), (0, 0)]));

      expect(insight, isNot(contains('últimos días')));
    });
  });

  group('chartSummary', () {
    test('lists each day with its weekday and completion for screen readers', () {
      final summary = chartSummary(_week([(3, 0), (3, 1), (3, 3), (0, 0), (3, 3), (3, 1), (3, 2)]));

      expect(summary, startsWith('Cumplimiento por día de los últimos 7 días.'));
      expect(summary, contains('viernes 9: 0 de 3'));
      expect(summary, contains('domingo 11: 3 de 3'));
      expect(summary, contains('lunes 12: sin tareas'));
    });
  });
}
