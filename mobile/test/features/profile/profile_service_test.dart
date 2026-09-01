import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/profile/profile_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.response, this.error});

  Map<String, dynamic>? response;
  ApiException? error;
  Map<String, dynamic>? lastBody;
  String? lastPath;

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    lastPath = path;
    lastBody = body;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    lastPath = path;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<List<dynamic>> getList(String path) {
    throw UnimplementedError();
  }
}

void main() {
  group('ProfileService', () {
    test('saveProfile PUTs to /profile and parses the response', () async {
      final fakeClient = _FakeApiClient(response: {
        'id': 'p1',
        'user_id': 'u1',
        'age_range': '25-34',
        'main_goal': 'sleep_better',
      });
      final service = ProfileService(apiClient: fakeClient);

      final profile = await service.saveProfile(ageRange: '25-34', mainGoal: 'sleep_better');

      expect(fakeClient.lastPath, '/profile');
      expect(fakeClient.lastBody, {'age_range': '25-34', 'main_goal': 'sleep_better'});
      expect(profile.ageRange, '25-34');
      expect(profile.mainGoal, 'sleep_better');
      expect(profile.userId, 'u1');
    });

    test('saveProfile propagates ApiException from the backend', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = ProfileService(apiClient: fakeClient);

      await expectLater(
        service.saveProfile(ageRange: '25-34', mainGoal: 'sleep_better'),
        throwsA(isA<ApiException>()),
      );
    });

    test('getProfile GETs /profile and parses the response', () async {
      final fakeClient = _FakeApiClient(response: {
        'id': 'p1',
        'user_id': 'u1',
        'age_range': '25-34',
        'main_goal': 'sleep_better',
      });
      final service = ProfileService(apiClient: fakeClient);

      final profile = await service.getProfile();

      expect(fakeClient.lastPath, '/profile');
      expect(profile.ageRange, '25-34');
      expect(profile.mainGoal, 'sleep_better');
    });

    test('getProfile propagates ApiException (e.g. 404 before onboarding)', () async {
      final fakeClient = _FakeApiClient(error: ApiException('Profile not found'));
      final service = ProfileService(apiClient: fakeClient);

      await expectLater(service.getProfile(), throwsA(isA<ApiException>()));
    });
  });
}
