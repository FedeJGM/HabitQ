import 'package:flutter/material.dart';

import '../../core/networking/api_client.dart';
import '../../core/widgets/error_notice.dart';
import '../../core/widgets/skeleton.dart';
import 'habit_questions.dart';
import 'habit_wizard.dart';
import 'habits_service.dart';

/// View/edit screen for the habits recorded during onboarding, shown as the
/// same step-by-step questionnaire. Each answer updates its existing
/// habit_records row (PUT /habits/{id}); a question with no matching record
/// yet is shown as unanswered and can be skipped (creation only happens
/// through the onboarding questionnaire).
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key, this.habitsService, this.initialStep = 0});

  final HabitsService? habitsService;

  /// Question to open first (0-based); the last step is the summary.
  final int initialStep;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late final HabitsService _habitsService;
  Map<String, HabitRecord> _recordByKey = {};
  bool _isLoading = true;
  String? _loadError;
  bool _loadErrorIsConnection = false;
  String? _saveError;

  static final List<HabitQuestion> _questions = [
    for (final section in habitDomainSections) ...section.questions,
  ];

  @override
  void initState() {
    super.initState();
    _habitsService = widget.habitsService ?? HabitsService();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final records = await _habitsService.fetchHabits();
      if (!mounted) return;
      setState(() {
        _recordByKey = {for (final record in records) record.key: record};
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadErrorIsConnection = e is ApiConnectionException;
        _isLoading = false;
      });
    }
  }

  /// Saves one pick. Returns whether it was accepted, so the wizard only
  /// celebrates and advances when the change really was stored.
  Future<bool> _handleSelect(HabitQuestion question, String value) async {
    final record = _recordByKey[question.key];
    if (record == null) return false;
    if (record.value == value) return true;

    setState(() => _saveError = null);
    try {
      final updated = await _habitsService.updateHabit(
        id: record.id,
        domain: question.domain,
        key: question.key,
        value: value,
      );
      if (!mounted) return false;
      setState(() => _recordByKey[question.key] = updated);
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      setState(() => _saveError = e.message);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis hábitos')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const SafeArea(
        child: Padding(padding: EdgeInsets.all(24), child: SkeletonList(count: 3)),
      );
    }
    if (_loadError != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorNotice(
            message: _loadError!,
            isConnection: _loadErrorIsConnection,
            onRetry: _loadHabits,
          ),
        ),
      );
    }
    return HabitWizard(
      answers: {for (final entry in _recordByKey.entries) entry.key: entry.value.value},
      lockedKeys: {
        for (final question in _questions)
          if (!_recordByKey.containsKey(question.key)) question.key,
      },
      initialStep: widget.initialStep,
      errorMessage: _saveError,
      finishLabel: 'Volver',
      onSelect: _handleSelect,
      onFinish: () => Navigator.of(context).maybePop(),
    );
  }
}
