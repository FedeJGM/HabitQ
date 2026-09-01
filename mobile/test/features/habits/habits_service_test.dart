import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/habits/habits_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.error});

  ApiException? error;
  final List<Map<String, dynamic>> postedBodies = [];

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
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
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
  });
}
