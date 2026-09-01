import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/auth/auth_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.response, this.error});

  Map<String, dynamic>? response;
  ApiException? error;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    throw UnimplementedError();
  }
}

void main() {
  group('AuthService.fetchCurrentUser', () {
    test('GETs /auth/me and parses the user', () async {
      final fakeClient = _FakeApiClient(response: {
        'id': 'u1',
        'email': 'test@example.com',
        'name': 'Alice',
        'onboarding_completed': true,
      });
      final service = AuthService(apiClient: fakeClient);

      final user = await service.fetchCurrentUser();

      expect(user.id, 'u1');
      expect(user.name, 'Alice');
      expect(user.onboardingCompleted, isTrue);
    });

    test('propagates ApiException from the backend', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = AuthService(apiClient: fakeClient);

      await expectLater(service.fetchCurrentUser(), throwsA(isA<ApiException>()));
    });
  });
}
