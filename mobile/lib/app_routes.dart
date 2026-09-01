import 'package:flutter/material.dart';

import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_habits_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

/// Central route table. Add new named routes here as each feature screen
/// lands, instead of scattering Navigator.push calls with inline builders.
class AppRoutes {
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const onboardingHabits = '/onboarding/habits';
  static const home = '/home';

  static Map<String, WidgetBuilder> get table => {
        login: (_) => const LoginScreen(),
        onboarding: (_) => const OnboardingScreen(),
        onboardingHabits: (_) => const OnboardingHabitsScreen(),
        home: (_) => const HomeScreen(),
      };
}
