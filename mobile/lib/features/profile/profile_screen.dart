import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/habitq_bottom_nav.dart';
import '../../core/widgets/habitq_shell.dart';
import '../auth/auth_service.dart';
import '../auth/user.dart';
import 'profile_options.dart';
import 'profile_service.dart';

/// View/edit screen for the profile captured during onboarding. PUT /profile
/// replaces the whole profile, so every save sends the current values of all
/// fields: tapping a chip autosaves, and height and weight are saved together
/// with "Guardar medidas".
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
  String? _gender;
  int? _heightCm;
  double? _weightKg;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
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

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _applyProfile(UserProfile profile) {
    _ageRange = profile.ageRange;
    _mainGoal = profile.mainGoal;
    _gender = profile.gender;
    _heightCm = profile.heightCm;
    _weightKg = profile.weightKg;
    _heightController.text = profile.heightCm == null ? '' : formatMeasure(profile.heightCm!);
    _weightController.text = profile.weightKg == null ? '' : formatMeasure(profile.weightKg!);
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
        _applyProfile(profile);
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

  /// Saves the whole profile: the given fields replace the current ones, the
  /// rest keep their last saved value.
  Future<void> _save({
    String? ageRange,
    String? mainGoal,
    String? gender,
    int? heightCm,
    double? weightKg,
  }) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileService.saveProfile(
        ageRange: ageRange ?? _ageRange!,
        mainGoal: mainGoal ?? _mainGoal!,
        gender: gender ?? _gender,
        heightCm: heightCm ?? _heightCm,
        weightKg: weightKg ?? _weightKg,
      );
      if (!mounted) return;
      setState(() => _applyProfile(profile));
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

  bool get _canSaveMeasures =>
      !_isSaving &&
      parseHeightCm(_heightController.text) != null &&
      parseWeightKg(_weightController.text) != null;

  void _saveMeasures() {
    _save(
      heightCm: parseHeightCm(_heightController.text),
      weightKg: parseWeightKg(_weightController.text),
    );
  }

  Widget _measureField({
    required String fieldName,
    required String label,
    required String unit,
    required TextEditingController controller,
    required bool decimal,
    required String? errorText,
  }) {
    return TextField(
      key: ValueKey('profile-field:$fieldName'),
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
        LengthLimitingTextInputFormatter(decimal ? 6 : 3),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, suffixText: unit, errorText: errorText),
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
                    _infoRow(context, 'Género', _labelFor(genderOptions, _gender)),
                    _infoRow(context, 'Edad', _labelFor(ageRangeOptions, _ageRange)),
                    _infoRow(context, 'Altura', _heightCm == null ? null : '$_heightCm cm'),
                    _infoRow(context, 'Peso', _weightKg == null ? null : '${formatMeasure(_weightKg!)} kg'),
                    _infoRow(context, 'Objetivo principal', _labelFor(mainGoalOptions, _mainGoal)),
                    const Divider(height: 32),
                    Text(
                      '¿Cuál es tu género?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: genderOptions.map((option) {
                        return ChoiceChip(
                          key: ValueKey('gender:${option.value}'),
                          label: Text(option.label),
                          selected: _gender == option.value,
                          onSelected: _isSaving ? null : (_) => _save(gender: option.value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
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
                              : (_) => _save(ageRange: option.value),
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
                              : (_) => _save(mainGoal: option.value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Altura y peso',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _measureField(
                      fieldName: 'height',
                      label: 'Altura',
                      unit: 'cm',
                      controller: _heightController,
                      decimal: false,
                      errorText: _heightController.text.trim().isNotEmpty &&
                              parseHeightCm(_heightController.text) == null
                          ? heightErrorText
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _measureField(
                      fieldName: 'weight',
                      label: 'Peso',
                      unit: 'kg',
                      controller: _weightController,
                      decimal: true,
                      errorText: _weightController.text.trim().isNotEmpty &&
                              parseWeightKg(_weightController.text) == null
                          ? weightErrorText
                          : null,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _canSaveMeasures ? _saveMeasures : null,
                      child: const Text('Guardar medidas'),
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
