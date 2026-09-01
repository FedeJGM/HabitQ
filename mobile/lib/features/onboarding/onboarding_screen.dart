import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_options.dart';
import '../profile/profile_service.dart';

/// Perfil básico step of onboarding (plan section 11): age range + main
/// goal, persisted via PUT /profile. The per-domain habit questions are a
/// separate follow-up screen once this step is confirmed.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.profileService});

  final ProfileService? profileService;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final ProfileService _profileService;
  String? _selectedAgeRange;
  String? _selectedGoal;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
  }

  Future<void> _handleContinue() async {
    if (_selectedAgeRange == null || _selectedGoal == null) {
      setState(() => _errorMessage = 'Selecciona tu rango de edad y tu objetivo principal.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _profileService.saveProfile(
        ageRange: _selectedAgeRange!,
        mainGoal: _selectedGoal!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingHabits);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuéntanos sobre ti')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Cuál es tu rango de edad?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ageRangeOptions.map((option) {
                  return ChoiceChip(
                    label: Text(option.label),
                    selected: _selectedAgeRange == option.value,
                    onSelected: (_) => setState(() => _selectedAgeRange = option.value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                '¿Cuál es tu objetivo principal?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mainGoalOptions.map((option) {
                  return ChoiceChip(
                    label: Text(option.label),
                    selected: _selectedGoal == option.value,
                    onSelected: (_) => setState(() => _selectedGoal = option.value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isSaving ? null : _handleContinue,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
