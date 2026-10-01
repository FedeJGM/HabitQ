import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/habits/habits_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.error, this.listResponse});

  ApiException? error;
  List<dynamic>? listResponse;
  final List<Map<String, dynamic>> postedBodies = [];
  String? lastPutPath;
  Map<String, dynamic>? lastPutBody;

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    postedBodies.add(body);
    if (error != null) throw error!;
    return {
      'id': 'h${postedBodies.length}',
      'user_id': 'u1',
      'domain': body['domain'],
      'key': body['key'],
      'value': body['value'],
      'recorded_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    };
  }

  @override
  Future<Map<String, dynamic>> get(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    lastPutPath = path;
    lastPutBody = body;
    if (error != null) throw error!;
    return {
      'id': 'h1',
      'user_id': 'u1',
      'domain': body['domain'],
      'key': body['key'],
      'value': body['value'],
      'recorded_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    };
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    if (error != null) throw error!;
    return listResponse!;
  }

  @override
  Future<void> delete(String path) {
    throw UnimplementedError();
  }
}

void main() {
  group('HabitsService', () {
    test('submitAnswers posts each answer to /habits', () async {
      final fakeClient = _FakeApiClient();
      final service = HabitsService(apiClient: fakeClient);

      await service.submitAnswers(const [
        HabitAnswer(domain: 'sleep', key: 'hours', value: 'less_5'),
        HabitAnswer(domain: 'hydration', key: 'daily_intake', value: 'low'),
      ]);

      expect(fakeClient.postedBodies, hasLength(2));
      expect(fakeClient.postedBodies[0], {
        'domain': 'sleep',
        'key': 'hours',
        'value': 'less_5',
      });
      expect(fakeClient.postedBodies[1], {
        'domain': 'hydration',
        'key': 'daily_intake',
        'value': 'low',
      });
    });

    test('submitAnswers propagates ApiException on failure', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = HabitsService(apiClient: fakeClient);

      await expectLater(
        service.submitAnswers(const [
          HabitAnswer(domain: 'sleep', key: 'hours', value: 'less_5'),
        ]),
        throwsA(isA<ApiException>()),
      );
    });

    test('fetchHabits GETs /habits and parses each record', () async {
      final fakeClient = _FakeApiClient(listResponse: [
        {
          'id': 'h1',
          'user_id': 'u1',
          'domain': 'sleep',
          'key': 'hours',
          'value': '7_8',
          'recorded_at': '2026-09-01T00:00:00Z',
          'updated_at': '2026-09-01T00:00:00Z',
        },
      ]);
      final service = HabitsService(apiClient: fakeClient);

      final records = await service.fetchHabits();

      expect(records, hasLength(1));
      expect(records.single.id, 'h1');
      expect(records.single.domain, 'sleep');
      expect(records.single.key, 'hours');
      expect(records.single.value, '7_8');
    });

    test('fetchHabits propagates ApiException on failure', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = HabitsService(apiClient: fakeClient);

      await expectLater(service.fetchHabits(), throwsA(isA<ApiException>()));
    });

    test('updateHabit PUTs to /habits/{id} and returns the updated record', () async {
      final fakeClient = _FakeApiClient();
      final service = HabitsService(apiClient: fakeClient);

      final updated = await service.updateHabit(
        id: 'h1',
        domain: 'sleep',
        key: 'hours',
        value: '5_6',
      );

      expect(fakeClient.lastPutPath, '/habits/h1');
      expect(fakeClient.lastPutBody, {
        'domain': 'sleep',
        'key': 'hours',
        'value': '5_6',
      });
      expect(updated.value, '5_6');
    });

    test('updateHabit propagates ApiException on failure', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = HabitsService(apiClient: fakeClient);

      await expectLater(
        service.updateHabit(id: 'h1', domain: 'sleep', key: 'hours', value: '5_6'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
