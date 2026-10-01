import '../../core/networking/api_client.dart';

class HabitAnswer {
  const HabitAnswer({required this.domain, required this.key, required this.value});

  final String domain;
  final String key;
  final String value;
}

class HabitRecord {
  const HabitRecord({
    required this.id,
    required this.domain,
    required this.key,
    required this.value,
  });

  factory HabitRecord.fromJson(Map<String, dynamic> json) {
    return HabitRecord(
      id: json['id'] as String,
      domain: json['domain'] as String,
      key: json['key'] as String,
      value: json['value'] as String,
    );
  }

  final String id;
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

  Future<List<HabitRecord>> fetchHabits() async {
    final results = await _apiClient.getList('/habits');
    return results
        .cast<Map<String, dynamic>>()
        .map(HabitRecord.fromJson)
        .toList();
  }

  Future<HabitRecord> updateHabit({
    required String id,
    required String domain,
    required String key,
    required String value,
  }) async {
    final response = await _apiClient.put('/habits/$id', {
      'domain': domain,
      'key': key,
      'value': value,
    });
    return HabitRecord.fromJson(response);
  }
}
