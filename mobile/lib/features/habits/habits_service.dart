import '../../core/networking/api_client.dart';

class HabitAnswer {
  const HabitAnswer({required this.domain, required this.key, required this.value});

  final String domain;
  final String key;
  final String value;
}

class HabitsService {
  HabitsService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// POST /habits creates one record per answer (append-only log), so
  /// answers are submitted sequentially and the first failure aborts.
  Future<void> submitAnswers(List<HabitAnswer> answers) async {
    for (final answer in answers) {
      await _apiClient.post('/habits', {
        'domain': answer.domain,
        'key': answer.key,
        'value': answer.value,
      });
    }
  }
}
