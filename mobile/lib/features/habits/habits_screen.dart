import 'package:flutter/material.dart';

import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'habit_questions.dart';
import 'habits_service.dart';

/// View/edit screen for the habits recorded during onboarding. Each answer
/// updates its existing habit_records row (PUT /habits/{id}); a question
/// with no matching record yet is shown as unanswered rather than creating
/// one here (creation only happens through the onboarding questionnaire).
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key, this.habitsService});

  final HabitsService? habitsService;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late final HabitsService _habitsService;
  Map<String, HabitRecord> _recordByKey = {};
  final Set<String> _savingKeys = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _habitsService = widget.habitsService ?? HabitsService();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
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
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSelect(HabitQuestion question, String value) async {
    final record = _recordByKey[question.key];
    if (record == null || record.value == value) return;

    setState(() {
      _savingKeys.add(question.key);
      _errorMessage = null;
    });

    try {
      final updated = await _habitsService.updateHabit(
        id: record.id,
        domain: question.domain,
        key: question.key,
        value: value,
      );
      if (!mounted) return;
      setState(() => _recordByKey[question.key] = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _savingKeys.remove(question.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis hábitos')),
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
                    for (final section in habitDomainSections) ...[
                      Text(section.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      for (final question in section.questions) ...[
                        Text(question.prompt, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _recordByKey.containsKey(question.key)
                            ? Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: question.options.map((option) {
                                  final currentValue = _recordByKey[question.key]!.value;
                                  return ChoiceChip(
                                    key: ValueKey('${question.key}:${option.value}'),
                                    label: Text(option.label),
                                    selected: currentValue == option.value,
                                    onSelected: _savingKeys.contains(question.key)
                                        ? null
                                        : (_) => _handleSelect(question, option.value),
                                  );
                                }).toList(),
                              )
                            : const Text(
                                'Sin responder',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
