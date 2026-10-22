import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../core/networking/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/habitq_bottom_nav.dart';
import '../../core/widgets/habitq_card.dart';
import '../../core/widgets/habitq_shell.dart';
import '../activity/reminder_service.dart';
import '../auth/auth_service.dart';
import '../habits/habit_questions.dart';
import '../habits/habits_service.dart';
import 'stats_service.dart';

const _weekdayNames = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];
// Indexed by DateTime.weekday - 1; same letters as the Actividad week strip.
const _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'DOM'];

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// 2.5 -> "2,5", 3.0 -> "3".
String _number(double value) {
  final text = value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

const _titleStyle = TextStyle(
  fontFamily: AppTheme.fontFamily,
  fontWeight: FontWeight.w700,
  fontSize: 16,
  color: AppColors.textPrimary,
);
const _bodyStyle = TextStyle(
  fontFamily: AppTheme.fontFamily,
  fontSize: 14,
  color: AppColors.textPrimary,
);
const _mutedStyle = TextStyle(
  fontFamily: AppTheme.fontFamily,
  fontSize: 13,
  color: AppColors.textSecondary,
);

/// Estadísticas tab: completion of the daily checklist over the last seven
/// days and a read-only summary of the habits questionnaire (no history: the
/// answers are edited in place, so only their current value exists).
class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    this.statsService,
    this.habitsService,
    this.authService,
    this.reminderService,
    this.now,
  });

  final StatsService? statsService;
  final HabitsService? habitsService;
  final AuthService? authService;
  final ReminderService? reminderService;

  /// Clock used to find today; injectable so tests can fix the date.
  final DateTime Function()? now;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final StatsService _stats;
  late final HabitsService _habits;

  bool _isLoading = true;
  TaskStats? _taskStats;
  String? _statsError;
  List<HabitRecord> _records = const [];
  String? _habitsError;

  @override
  void initState() {
    super.initState();
    _stats = widget.statsService ?? StatsService();
    _habits = widget.habitsService ?? HabitsService();
    _load();
  }

  Future<void> _load() async {
    final today = _dateOnly((widget.now ?? DateTime.now)());
    await Future.wait([_loadStats(today), _loadHabits()]);
    if (mounted) setState(() => _isLoading = false);
  }

  // Each source fails on its own: a habits error must not hide the charts.
  Future<void> _loadStats(DateTime today) async {
    try {
      final stats = await _stats.fetchStats(today);
      if (mounted) setState(() => _taskStats = stats);
    } on ApiException catch (e) {
      if (mounted) setState(() => _statsError = e.message);
    }
  }

  Future<void> _loadHabits() async {
    try {
      final records = await _habits.fetchHabits();
      if (mounted) setState(() => _records = records);
    } on ApiException catch (e) {
      if (mounted) setState(() => _habitsError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HabitQShell(
      currentTab: HabitQTab.stats,
      onLogout: () => signOutAndGoToLogin(context, widget.authService, widget.reminderService),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'Tus estadísticas',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Últimos 7 días', style: _mutedStyle),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else ...[
            ..._tasksSection(),
            const SizedBox(height: 16),
            _habitsSection(),
          ],
        ],
      ),
    );
  }

  List<Widget> _tasksSection() {
    if (_statsError != null) {
      return [Text(_statsError!, style: const TextStyle(color: AppColors.error, fontSize: 14))];
    }
    final stats = _taskStats;
    if (stats == null) return const [];
    if (!stats.hasData) return [_emptyCard()];
    return [
      _completionCard(stats),
      if (stats.counters.isNotEmpty) ...[const SizedBox(height: 16), _countersCard(stats)],
    ];
  }

  Widget _emptyCard() {
    return HabitQCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aún no hay datos para mostrar', style: _titleStyle),
          const SizedBox(height: 8),
          const Text(
            'Elige tareas en Actividad y márcalas durante unos días para ver tu cumplimiento.',
            style: _mutedStyle,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed(AppRoutes.activity),
            child: const Text('Ir a Actividad'),
          ),
        ],
      ),
    );
  }

  Widget _completionCard(TaskStats stats) {
    final today = stats.days.last;
    final best = stats.bestDay;
    return HabitQCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cumplimiento por día', style: _titleStyle),
          const SizedBox(height: 4),
          Text('Hoy: ${today.completed} de ${today.active} tareas', style: _bodyStyle),
          if (best != null)
            Text(
              'Mejor día: ${_weekdayNames[best.weekday - 1]} ${best.day}',
              style: _mutedStyle,
            ),
          const SizedBox(height: 16),
          SizedBox(
            key: const ValueKey('stats-chart'),
            height: 180,
            child: BarChart(_chartData(stats)),
          ),
        ],
      ),
    );
  }

  BarChartData _chartData(TaskStats stats) {
    return BarChartData(
      minY: 0,
      maxY: 100,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surfaceMuted, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final day = stats.days[groupIndex];
            return BarTooltipItem(
              day.active == 0 ? 'Sin tareas' : '${day.completed} de ${day.active} (${day.percent.round()} %)',
              const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: Colors.white),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            interval: 25,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              // One line always: "100 %" must not drop the percent sign below.
              child: Text(
                '${value.round()} %',
                maxLines: 1,
                softWrap: false,
                style: _mutedStyle.copyWith(fontSize: 11),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final day = stats.days[value.toInt()].day;
              return SideTitleWidget(
                meta: meta,
                child: Text(_weekdayLabels[day.weekday - 1], style: _mutedStyle.copyWith(fontSize: 11)),
              );
            },
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < stats.days.length; i++)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: stats.days[i].percent,
                width: 18,
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 100,
                  color: AppColors.surfaceMuted.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _countersCard(TaskStats stats) {
    return HabitQCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Promedio de tus contadores', style: _titleStyle),
          for (final counter in stats.counters) ...[
            const SizedBox(height: 12),
            Column(
              key: ValueKey('counter-${counter.taskKey}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(counter.label, style: _bodyStyle),
                const SizedBox(height: 4),
                Text('${_number(counter.average)} de ${counter.target} ${counter.unit}', style: _mutedStyle),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (counter.average / counter.target).clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceMuted,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _habitsSection() {
    return HabitQCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen de tus hábitos', style: _titleStyle),
          const SizedBox(height: 4),
          const Text('Tus respuestas actuales del cuestionario.', style: _mutedStyle),
          const SizedBox(height: 12),
          if (_habitsError != null)
            Text(_habitsError!, style: const TextStyle(color: AppColors.error, fontSize: 14))
          else if (_records.isEmpty)
            const Text('Aún no respondes el cuestionario de hábitos.', style: _bodyStyle)
          else
            ..._habitAnswers(),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.habits),
            child: const Text('Editar hábitos'),
          ),
        ],
      ),
    );
  }

  List<Widget> _habitAnswers() {
    // Several records can exist per question (POST is an append-only log): the
    // last one is the current answer. Match on domain AND key, never key alone.
    final latest = <String, HabitRecord>{
      for (final record in _records) '${record.domain}/${record.key}': record,
    };
    return [
      for (final section in habitDomainSections) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(section.title, style: _titleStyle.copyWith(fontSize: 14, color: AppColors.primaryDark)),
        ),
        for (final question in section.questions)
          Padding(
            key: ValueKey('habit-${question.domain}-${question.key}'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.prompt, style: _mutedStyle),
                Text(_answerLabel(question, latest['${question.domain}/${question.key}']), style: _bodyStyle),
              ],
            ),
          ),
      ],
    ];
  }

  String _answerLabel(HabitQuestion question, HabitRecord? record) {
    if (record == null) return 'Sin responder';
    for (final option in question.options) {
      if (option.value == record.value) return option.label;
    }
    return 'Sin responder';
  }
}
