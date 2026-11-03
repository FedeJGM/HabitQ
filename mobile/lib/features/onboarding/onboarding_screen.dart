import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/decor/background_shapes.dart';
import '../../core/widgets/step_flow.dart';
import '../profile/profile_options.dart';
import '../profile/profile_service.dart';

enum _ProfileStep { gender, age, height, weight, goal }

/// Perfil básico step of onboarding (plan section 11), asked one question at
/// a time with the same motion as the habit questionnaire: gender, age range,
/// height, weight and main goal. Nothing is stored until the last step, then
/// everything is persisted at once via PUT /profile. The per-domain habit
/// questions are a separate follow-up screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.profileService});

  final ProfileService? profileService;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = _ProfileStep.values;

  late final ProfileService _profileService;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  Timer? _advanceTimer;
  int _step = 0;
  int _direction = 1;
  String? _gender;
  String? _ageRange;
  String? _mainGoal;
  bool _isSaving = false;
  String? _errorMessage;

  _ProfileStep get _current => _steps[_step];
  bool get _isLast => _step == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  bool get _canGoNext {
    switch (_current) {
      case _ProfileStep.gender:
        return _gender != null;
      case _ProfileStep.age:
        return _ageRange != null;
      case _ProfileStep.height:
        return parseHeightCm(_heightController.text) != null;
      case _ProfileStep.weight:
        return parseWeightKg(_weightController.text) != null;
      case _ProfileStep.goal:
        return _mainGoal != null;
    }
  }

  void _goTo(int step) {
    _advanceTimer?.cancel();
    setState(() {
      _direction = step >= _step ? 1 : -1;
      _step = step.clamp(0, _steps.length - 1);
    });
  }

  /// Stores a tapped option and, except on the last question, moves on after a
  /// beat so the check animation of the tile is seen first.
  void _pick(void Function() store) {
    final pickedAt = _step;
    setState(store);
    if (_isLast) return;
    _advanceTimer?.cancel();
    final delay = AppMotion.reduce(context) ? Duration.zero : AppMotion.fast + const Duration(milliseconds: 150);
    _advanceTimer = Timer(delay, () {
      if (mounted && _step == pickedAt) _goTo(pickedAt + 1);
    });
  }

  Future<void> _handleContinue() async {
    final height = parseHeightCm(_heightController.text);
    final weight = parseWeightKg(_weightController.text);
    if (_gender == null || _ageRange == null || _mainGoal == null || height == null || weight == null) {
      setState(() => _errorMessage = 'Responde todas las preguntas para continuar.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _profileService.saveProfile(
        ageRange: _ageRange!,
        mainGoal: _mainGoal!,
        gender: _gender,
        heightCm: height,
        weightKg: weight,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboardingHabits);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuéntanos sobre ti')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            const Positioned.fill(child: BackgroundShapes()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: StepSwitcher(step: _step, direction: _direction, child: _question()),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontFamily: AppTheme.fontFamily),
                          ),
                        ),
                      ),
                    StepNavigation(
                      onBack: _step > 0 && !_isSaving ? () => _goTo(_step - 1) : null,
                      onForward: _isLast
                          ? (_canGoNext && !_isSaving ? _handleContinue : null)
                          : (_canGoNext ? () => _goTo(_step + 1) : null),
                      forwardLabel: _isLast ? 'Continuar' : 'Siguiente',
                      isLoading: _isLast && _isSaving,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Paso 1 de 2',
          style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tu perfil',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              'Pregunta ${_step + 1} de ${_steps.length}',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StepProgressBar(barKey: const ValueKey('profile-progress'), value: (_step + 1) / _steps.length),
      ],
    );
  }

  Widget _question() {
    switch (_current) {
      case _ProfileStep.gender:
        return _choices(
          prompt: '¿Cuál es tu género?',
          options: genderOptions,
          selected: _gender,
          onSelect: (value) => _pick(() => _gender = value),
        );
      case _ProfileStep.age:
        return _choices(
          prompt: '¿Cuál es tu rango de edad?',
          options: ageRangeOptions,
          selected: _ageRange,
          onSelect: (value) => _pick(() => _ageRange = value),
        );
      case _ProfileStep.height:
        return _measure(
          prompt: '¿Cuánto mides?',
          hint: 'En centímetros, por ejemplo 170.',
          fieldName: 'height',
          controller: _heightController,
          unit: 'cm',
          decimal: false,
          errorText: _heightController.text.trim().isNotEmpty && parseHeightCm(_heightController.text) == null
              ? heightErrorText
              : null,
        );
      case _ProfileStep.weight:
        return _measure(
          prompt: '¿Cuánto pesas?',
          hint: 'En kilogramos, por ejemplo 65 o 65,5.',
          fieldName: 'weight',
          controller: _weightController,
          unit: 'kg',
          decimal: true,
          errorText: _weightController.text.trim().isNotEmpty && parseWeightKg(_weightController.text) == null
              ? weightErrorText
              : null,
        );
      case _ProfileStep.goal:
        return _choices(
          prompt: '¿Cuál es tu objetivo principal?',
          options: mainGoalOptions,
          selected: _mainGoal,
          onSelect: (value) => _pick(() => _mainGoal = value),
        );
    }
  }

  Widget _prompt(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        height: 1.3,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _choices({
    required String prompt,
    required List<ProfileOption> options,
    required String? selected,
    required void Function(String value) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(prompt),
        const SizedBox(height: 20),
        for (final option in options) ...[
          OptionTile(
            key: ValueKey('profile:${option.value}'),
            label: option.label,
            selected: selected == option.value,
            onTap: (_) => onSelect(option.value),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _measure({
    required String prompt,
    required String hint,
    required String fieldName,
    required TextEditingController controller,
    required String unit,
    required bool decimal,
    required String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _prompt(prompt),
        const SizedBox(height: 6),
        Text(
          hint,
          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        TextField(
          key: ValueKey('profile-field:$fieldName'),
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
            LengthLimitingTextInputFormatter(decimal ? 6 : 3),
          ],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 18, color: AppColors.textPrimary),
          decoration: InputDecoration(
            suffixText: unit,
            errorText: errorText,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.sky),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.sky, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
