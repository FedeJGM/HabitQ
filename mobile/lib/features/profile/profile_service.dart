import '../../core/networking/api_client.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.userId,
    required this.ageRange,
    required this.mainGoal,
    this.gender,
    this.heightCm,
    this.weightKg,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      ageRange: json['age_range'] as String,
      mainGoal: json['main_goal'] as String,
      gender: json['gender'] as String?,
      heightCm: (json['height_cm'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String userId;
  final String ageRange;
  final String mainGoal;

  /// Null for profiles created before gender, height and weight were asked.
  final String? gender;
  final int? heightCm;
  final double? weightKg;
}

class ProfileService {
  ProfileService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Creates or updates the current user's profile (PUT /profile upserts).
  Future<UserProfile> saveProfile({
    required String ageRange,
    required String mainGoal,
    String? gender,
    int? heightCm,
    double? weightKg,
  }) async {
    final response = await _apiClient.put('/profile', {
      'age_range': ageRange,
      'main_goal': mainGoal,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
    });
    return UserProfile.fromJson(response);
  }

  Future<UserProfile> getProfile() async {
    final response = await _apiClient.get('/profile');
    return UserProfile.fromJson(response);
  }
}
