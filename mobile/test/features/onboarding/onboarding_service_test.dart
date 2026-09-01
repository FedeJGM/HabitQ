import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/networking/api_client.dart';
import 'package:mobile/features/onboarding/onboarding_service.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.error});

  ApiException? error;
  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    lastPath = path;
    lastBody = body;
    if (error != null) throw error!;
    return {
      'id': 'u1',
      'email': 'test@example.com',
      'name': 'Test User',
      'onboarding_completed': true,
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
  group('OnboardingService', () {
    test('completeOnboarding POSTs to /auth/onboarding-complete', () async {
      final fakeClient = _FakeApiClient();
      final service = OnboardingService(apiClient: fakeClient);

      await service.completeOnboarding();

      expect(fakeClient.lastPath, '/auth/onboarding-complete');
    });

    test('completeOnboarding propagates ApiException from the backend', () async {
      final fakeClient = _FakeApiClient(error: ApiException('boom'));
      final service = OnboardingService(apiClient: fakeClient);

      await expectLater(service.completeOnboarding(), throwsA(isA<ApiException>()));
    });
  });
}
