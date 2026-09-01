import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../habits/habit_questions.dart';
import '../habits/habits_service.dart';
import 'onboarding_service.dart';

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
      habitDomainSections.fold(0, (sum, section) => sum + section.questions.length);

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
        for (final section in habitDomainSections)
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
              for (final section in habitDomainSections) ...[
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
