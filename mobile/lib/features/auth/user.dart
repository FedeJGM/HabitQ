class HabitQUser {
  const HabitQUser({
    required this.id,
    required this.email,
    required this.name,
    required this.onboardingCompleted,
  });

  factory HabitQUser.fromJson(Map<String, dynamic> json) {
    return HabitQUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      onboardingCompleted: json['onboarding_completed'] as bool,
    );
  }

  final String id;
  final String email;
  final String name;
  final bool onboardingCompleted;
}
