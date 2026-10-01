import 'package:flutter/material.dart';

import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'profile_options.dart';
import 'profile_service.dart';

/// View/edit screen for the profile captured during onboarding. Age range
/// and main goal always save together (PUT /profile requires both), so
/// tapping either chip autosaves the current values for both fields.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.profileService});

  final ProfileService? profileService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileService _profileService;
  String? _ageRange;
  String? _mainGoal;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        _ageRange = profile.ageRange;
        _mainGoal = profile.mainGoal;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _save({required String ageRange, required String mainGoal}) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileService.saveProfile(ageRange: ageRange, mainGoal: mainGoal);
      if (!mounted) return;
      setState(() {
        _ageRange = profile.ageRange;
        _mainGoal = profile.mainGoal;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                    ],
                    if (_ageRange != null && _mainGoal != null) ...[
                      Text(
                        '¿Cuál es tu rango de edad?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ageRangeOptions.map((option) {
                          return ChoiceChip(
                            key: ValueKey('age:${option.value}'),
                            label: Text(option.label),
                            selected: _ageRange == option.value,
                            onSelected: _isSaving
                                ? null
                                : (_) => _save(ageRange: option.value, mainGoal: _mainGoal!),
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
                            key: ValueKey('goal:${option.value}'),
                            label: Text(option.label),
                            selected: _mainGoal == option.value,
                            onSelected: _isSaving
                                ? null
                                : (_) => _save(ageRange: _ageRange!, mainGoal: option.value),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
