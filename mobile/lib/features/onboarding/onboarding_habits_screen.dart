import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../habits/habit_questions.dart';
import '../habits/habit_wizard.dart';
import '../habits/habits_service.dart';
import 'onboarding_service.dart';

/// Per-domain habit questions step of onboarding, following the perfil
/// básico step, asked one question at a time. Answers become one
/// habit_records row each via POST /habits, all at once when the user
/// finishes (nothing is stored while they are still answering).
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
  Map<String, String> _answers = {};
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

  Future<bool> _handleSelect(HabitQuestion question, String value) async {
    setState(() => _answers = {..._answers, question.key: value});
    return true;
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
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tus hábitos')),
      body: HabitWizard(
        answers: _answers,
        errorMessage: _errorMessage,
        isFinishing: _isSaving,
        finishLabel: 'Finalizar',
        onSelect: _handleSelect,
        onFinish: _handleContinue,
      ),
    );
  }
}
