import 'package:flutter/material.dart';

import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/habitq_bottom_nav.dart';
import '../../core/widgets/habitq_shell.dart';
import '../auth/auth_service.dart';
import '../auth/user.dart';
import 'profile_options.dart';
import 'profile_service.dart';

/// View/edit screen for the profile captured during onboarding. Age range
/// and main goal always save together (PUT /profile requires both), so
/// tapping either chip autosaves the current values for both fields.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.profileService, this.authService});

  final ProfileService? profileService;

  /// Optional: when provided, the screen also shows the user's name and email.
  final AuthService? authService;

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
  HabitQUser? _user;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
    _loadProfile();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = widget.authService;
    if (authService == null) return;
    try {
      final user = await authService.fetchCurrentUser();
      if (!mounted) return;
      setState(() => _user = user);
    } on ApiException {
      // Identity is decorative here; the profile edit flow keeps working.
    }
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'HQ';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }

  String? _labelFor(List<ProfileOption> options, String? value) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  Widget _infoRow(BuildContext context, String title, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value ?? '-', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return HabitQShell(
      currentTab: HabitQTab.profile,
      onLogout: () => signOutAndGoToLogin(context, widget.authService),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mi perfil',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: const Color(0xFFD9D9D9),
                      child: Text(
                        user == null ? 'HQ' : _initials(user.name),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 16),
                  ],
                  if (_ageRange != null && _mainGoal != null) ...[
                    _infoRow(context, 'Edad', _labelFor(ageRangeOptions, _ageRange)),
                    _infoRow(context, 'Objetivo principal', _labelFor(mainGoalOptions, _mainGoal)),
                    const Divider(height: 32),
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
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () => signOutAndGoToLogin(context, widget.authService),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
    );
  }
}
