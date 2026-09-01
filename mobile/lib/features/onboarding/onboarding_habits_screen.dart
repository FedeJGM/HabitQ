import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../habits/habits_service.dart';
import 'onboarding_service.dart';

class _HabitOption {
  const _HabitOption(this.value, this.label);

  final String value;
  final String label;
}

class _HabitQuestion {
  const _HabitQuestion({
    required this.domain,
    required this.key,
    required this.prompt,
    required this.options,
  });

  final String domain;
  final String key;
  final String prompt;
  final List<_HabitOption> options;
}

class _HabitDomainSection {
  const _HabitDomainSection({required this.title, required this.questions});

  final String title;
  final List<_HabitQuestion> questions;
}

/// The six habit domains from plan section 11, one question set each.
const _sections = [
  _HabitDomainSection(
    title: 'Sueño',
    questions: [
      _HabitQuestion(
        domain: 'sleep',
        key: 'hours',
        prompt: '¿Cuántas horas duermes normalmente?',
        options: [
          _HabitOption('less_5', 'Menos de 5'),
          _HabitOption('5_6', '5–6'),
          _HabitOption('7_8', '7–8'),
          _HabitOption('more_8', 'Más de 8'),
        ],
      ),
      _HabitQuestion(
        domain: 'sleep',
        key: 'screen_before_bed',
        prompt: '¿Usas pantallas durante la última hora antes de dormir?',
        options: [
          _HabitOption('never', 'Nunca'),
          _HabitOption('sometimes', 'A veces'),
          _HabitOption('often', 'Frecuentemente'),
        ],
      ),
    ],
  ),
  _HabitDomainSection(
    title: 'Alimentación',
    questions: [
      _HabitQuestion(
        domain: 'nutrition',
        key: 'fruits_vegetables',
        prompt: '¿Con qué frecuencia consumes frutas o verduras?',
        options: [
          _HabitOption('rarely', 'Rara vez'),
          _HabitOption('some_days', 'Algunos días'),
          _HabitOption('almost_daily', 'Casi todos los días'),
        ],
      ),
      _HabitQuestion(
        domain: 'nutrition',
        key: 'fast_food',
        prompt: '¿Con qué frecuencia consumes comida rápida o ultraprocesados?',
        options: [
          _HabitOption('rarely', 'Rara vez'),
          _HabitOption('weekly_1_2', '1–2 veces por semana'),
          _HabitOption('weekly_3_plus', '3 o más veces por semana'),
        ],
      ),
    ],
  ),
  _HabitDomainSection(
    title: 'Actividad física',
    questions: [
      _HabitQuestion(
        domain: 'physical_activity',
        key: 'days_per_week',
        prompt: '¿Cuántos días por semana realizas actividad física?',
        options: [
          _HabitOption('0', '0'),
          _HabitOption('1_2', '1–2'),
          _HabitOption('3_4', '3–4'),
          _HabitOption('5_plus', '5 o más'),
        ],
      ),
      _HabitQuestion(
        domain: 'physical_activity',
        key: 'sedentary_hours',
        prompt: '¿Pasas varias horas seguidas sentado?',
        options: [
          _HabitOption('yes', 'Sí'),
          _HabitOption('no', 'No'),
        ],
      ),
    ],
  ),
  _HabitDomainSection(
    title: 'Hidratación',
    questions: [
      _HabitQuestion(
        domain: 'hydration',
        key: 'daily_intake',
        prompt: '¿Cómo describirías tu consumo diario de agua?',
        options: [
          _HabitOption('low', 'Bajo'),
          _HabitOption('moderate', 'Moderado'),
          _HabitOption('adequate', 'Adecuado'),
        ],
      ),
    ],
  ),
  _HabitDomainSection(
    title: 'Uso de pantallas',
    questions: [
      _HabitQuestion(
        domain: 'screen_time',
        key: 'recreational_hours',
        prompt: '¿Cuánto tiempo recreativo pasas frente a pantallas?',
        options: [
          _HabitOption('less_2h', 'Menos de 2 horas'),
          _HabitOption('2_4h', '2–4 horas'),
          _HabitOption('more_4h', 'Más de 4 horas'),
        ],
      ),
    ],
  ),
  _HabitDomainSection(
    title: 'Manejo del estrés',
    questions: [
      _HabitQuestion(
        domain: 'stress',
        key: 'frequency',
        prompt: '¿Con qué frecuencia sientes estrés durante tu rutina?',
        options: [
          _HabitOption('rarely', 'Rara vez'),
          _HabitOption('sometimes', 'A veces'),
          _HabitOption('often', 'Frecuentemente'),
        ],
      ),
    ],
  ),
];

/// Per-domain habit questions step of onboarding, following the perfil
/// básico step. Answers become one habit_records row each via POST /habits.
class OnboardingHabitsScreen extends StatefulWidget {
  const OnboardingHabitsScreen({super.key, this.habitsService, this.onboardingService});

  final HabitsService? habitsService;
  final OnboardingService? onboardingService;

  @override
  State<OnboardingHabitsScreen> createState() => _OnboardingHabitsScreenState();
}

class _OnboardingHabitsScreenState extends State<OnboardingHabitsScreen> {
  late final HabitsService _habitsService;
  late final OnboardingService _onboardingService;
  final Map<String, String> _answers = {};
  bool _isSaving = false;
  String? _errorMessage;

  static final int _totalQuestions =
      _sections.fold(0, (sum, section) => sum + section.questions.length);

  @override
  void initState() {
    super.initState();
    _habitsService = widget.habitsService ?? HabitsService();
    _onboardingService = widget.onboardingService ?? OnboardingService();
  }

  Future<void> _handleContinue() async {
    if (_answers.length < _totalQuestions) {
      setState(() => _errorMessage = 'Responde todas las preguntas para continuar.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final answers = [
        for (final section in _sections)
          for (final question in section.questions)
            HabitAnswer(
              domain: question.domain,
              key: question.key,
              value: _answers[question.key]!,
            ),
      ];
      await _habitsService.submitAnswers(answers);
      await _onboardingService.completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tus hábitos')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in _sections) ...[
                Text(section.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final question in section.questions) ...[
                  Text(question.prompt, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: question.options.map((option) {
                      return ChoiceChip(
                        key: ValueKey('${question.key}:${option.value}'),
                        label: Text(option.label),
                        selected: _answers[question.key] == option.value,
                        onSelected: (_) =>
                            setState(() => _answers[question.key] = option.value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
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
                    : const Text('Finalizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
