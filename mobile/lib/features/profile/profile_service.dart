import '../../core/networking/api_client.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.userId,
    required this.ageRange,
    required this.mainGoal,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      ageRange: json['age_range'] as String,
      mainGoal: json['main_goal'] as String,
    );
  }

  final String id;
  final String userId;
  final String ageRange;
  final String mainGoal;
}

class ProfileService {
  ProfileService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Creates or updates the current user's profile (PUT /profile upserts).
  Future<UserProfile> saveProfile({required String ageRange, required String mainGoal}) async {
    final response = await _apiClient.put('/profile', {
      'age_range': ageRange,
      'main_goal': mainGoal,
    });
    return UserProfile.fromJson(response);
  }
}
