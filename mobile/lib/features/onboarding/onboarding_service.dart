import '../../core/networking/api_client.dart';

class OnboardingService {
  OnboardingService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Marks the current user's onboarding as done so future logins land on
  /// Home instead of routing back through onboarding.
  Future<void> completeOnboarding() => _apiClient.post('/auth/onboarding-complete', const {});
}
