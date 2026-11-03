import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/stats/stats_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.error, this.response});

  ApiException? error;
  Map<String, dynamic>? response;
  String? lastPath;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    lastPath = path;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<List<dynamic>> getList(String path) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String path) {
    throw UnimplementedError();
  }
}

Map<String, dynamic> _json() => {
      'days': [
        {'day': '2026-10-14', 'active': 3, 'completed': 2},
        {'day': '2026-10-15', 'active': 0, 'completed': 0},
      ],
      'counters': [
        {
          'task_key': 'hydrate_water',
          'label': 'Tomar agua',
          'unit': 'vasos',
          'target': 8,
          'days': 4,
          'average': 2.5,
        },
      ],
      'best_day': '2026-10-14',
    };

void main() {
  group('StatsService', () {
    test('fetchStats asks for the window ending on the given local day', () async {
      final client = _FakeApiClient(response: _json());

      await StatsService(apiClient: client).fetchStats(DateTime(2026, 3, 5, 23, 59));

      expect(client.lastPath, '/tasks/stats?day=2026-03-05');
    });

    test('fetchStats parses days, counters and the best day', () async {
      final client = _FakeApiClient(response: _json());

      final stats = await StatsService(apiClient: client).fetchStats(DateTime(2026, 10, 15));

      expect(stats.days.map((d) => d.day), [DateTime(2026, 10, 14), DateTime(2026, 10, 15)]);
      expect(stats.days.first.active, 3);
      expect(stats.days.first.completed, 2);
      expect(stats.counters.single.taskKey, 'hydrate_water');
      expect(stats.counters.single.label, 'Tomar agua');
      expect(stats.counters.single.unit, 'vasos');
      expect(stats.counters.single.target, 8);
      expect(stats.counters.single.days, 4);
      expect(stats.counters.single.average, 2.5);
      expect(stats.bestDay, DateTime(2026, 10, 14));
    });

    test('a null best_day parses as null', () async {
      final json = _json()..['best_day'] = null;
      final client = _FakeApiClient(response: json);

      final stats = await StatsService(apiClient: client).fetchStats(DateTime(2026, 10, 15));

      expect(stats.bestDay, isNull);
    });

    test('an integer average from the server is read as a double', () async {
      final json = _json();
      (json['counters'] as List).first['average'] = 3;
      final client = _FakeApiClient(response: json);

      final stats = await StatsService(apiClient: client).fetchStats(DateTime(2026, 10, 15));

      expect(stats.counters.single.average, 3.0);
    });

    test('percent is the share of completed tasks and zero without tasks', () async {
      final client = _FakeApiClient(response: _json());

      final stats = await StatsService(apiClient: client).fetchStats(DateTime(2026, 10, 15));

      expect(stats.days.first.percent, closeTo(66.67, 0.01));
      expect(stats.days.last.percent, 0);
    });

    test('hasData is false when no day had tasks', () async {
      final empty = _json()
        ..['days'] = [
          {'day': '2026-10-15', 'active': 0, 'completed': 0},
        ]
        ..['counters'] = []
        ..['best_day'] = null;

      final withTasks = await StatsService(apiClient: _FakeApiClient(response: _json()))
          .fetchStats(DateTime(2026, 10, 15));
      final withoutTasks = await StatsService(apiClient: _FakeApiClient(response: empty))
          .fetchStats(DateTime(2026, 10, 15));

      expect(withTasks.hasData, isTrue);
      expect(withoutTasks.hasData, isFalse);
    });

    test('propagates ApiException from the backend', () async {
      final client = _FakeApiClient(error: ApiException('sin conexión'));

      expect(
        () => StatsService(apiClient: client).fetchStats(DateTime(2026, 10, 15)),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
