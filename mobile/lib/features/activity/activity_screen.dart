import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/networking/api_client.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/celebration/celebration_overlay.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_notice.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/habitq_bottom_nav.dart';
import '../../core/widgets/habitq_card.dart';
import '../../core/widgets/habitq_shell.dart';
import '../../core/widgets/skeleton.dart';
import '../auth/auth_service.dart';
import 'reminder_service.dart';
import 'tasks_service.dart';

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
// Sunday-first, like the Figma week strip.
const _weekdayLabels = ['DOM', 'L', 'M', 'X', 'J', 'V', 'S'];

const _defaultReminder = TimeOfDay(hour: 8, minute: 0);

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _two(int value) => value.toString().padLeft(2, '0');

TimeOfDay? _parseReminder(String? time) {
  if (time == null) return null;
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour == null || minute == null
      ? null
      : TimeOfDay(hour: hour, minute: minute);
}

/// Actividad tab: the user's daily checklist. Shows the current week; today is
/// editable and past days are read-only. The day restarts at the user's local
/// midnight: the screen reloads when the app is resumed on a new date.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    this.tasksService,
    this.authService,
    this.reminderService,
    this.now,
  });

  final TasksService? tasksService;
  final AuthService? authService;
  final ReminderService? reminderService;

  /// Clock used to find today; injectable so tests can fix the date.
  final DateTime Function()? now;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with WidgetsBindingObserver {
  late final TasksService _service;
  late final ReminderService _reminders;
  late DateTime _today;
  late DateTime _selected;
  List<DayTask> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _errorIsConnection = false;
  int _requestId = 0;
  final Set<String> _pending = {};
  int _celebrationId = 0;
  bool _celebrating = false;
  bool _celebratingDay = false;

  bool get _isToday => _selected == _today;

  DateTime _clockToday() => _dateOnly((widget.now ?? DateTime.now)());

  @override
  void initState() {
    super.initState();
    _service = widget.tasksService ?? TasksService();
    _reminders = widget.reminderService ?? ReminderService();
    _today = _clockToday();
    _selected = _today;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = _clockToday();
    if (today == _today) {
      // Back from the background after a failed load: try again by itself.
      if (_errorMessage != null && !_isLoading) _load();
      return;
    }
    setState(() {
      _today = today;
      _selected = today;
    });
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final tasks = await _service.fetchTasks(_selected);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        // A removed task is only history: it shows on past days, never today.
        _tasks =
            _isToday ? tasks.where((task) => !task.archived).toList() : tasks;
        _isLoading = false;
      });
      _syncReminders();
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _errorMessage = e.message;
        _errorIsConnection = e is ApiConnectionException;
        _isLoading = false;
      });
    }
  }

  /// Only today's list drives the phone's reminders; a past day never does.
  void _syncReminders() {
    if (_isToday) unawaited(_reminders.sync(_tasks));
  }

  void _selectDay(DateTime day) {
    if (day.isAfter(_today) || day == _selected) return;
    setState(() => _selected = day);
    _load();
  }

  void _replace(DayTask updated) {
    setState(() {
      _tasks = [
        for (final task in _tasks) task.id == updated.id ? updated : task
      ];
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeProgress(DayTask task, int next) async {
    if (!_pending.add(task.id)) return;
    try {
      final updated = await _service.setProgress(task.id, _selected, next);
      if (!mounted) return;
      _replace(updated);
      // Only the move from pending to done celebrates: not loading, not unticking.
      if (_isToday && !task.completed && updated.completed) {
        _celebrate(dayComplete: _tasks.every((t) => t.completed));
      }
      // Today's reminder depends on whether the task is done.
      if (updated.completed != task.completed) _syncReminders();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      _pending.remove(task.id);
    }
  }

  void _celebrate({required bool dayComplete}) {
    unawaited(_haptic());
    setState(() {
      _celebrationId++;
      _celebrating = true;
      _celebratingDay = dayComplete;
    });
  }

  Future<void> _haptic() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // No vibration motor or no platform channel (tests): nothing to do.
    }
  }

  Future<void> _pickReminder(DayTask task) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseReminder(task.reminderTime) ?? _defaultReminder,
    );
    if (picked == null || !mounted) return;
    final value = '${_two(picked.hour)}:${_two(picked.minute)}';
    try {
      await _service.setReminder(task.id, value);
      if (!mounted) return;
      _replace(task.copyWith(reminderTime: value));
      final granted = await _reminders.requestPermission();
      if (!mounted) return;
      if (!granted) {
        _showError(
          'Activa las notificaciones de HabitQ en los ajustes del teléfono para recibir el recordatorio.',
        );
      }
      _syncReminders();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    }
  }

  Future<void> _clearReminder(DayTask task) async {
    try {
      await _service.setReminder(task.id, null);
      if (!mounted) return;
      _replace(task.copyWith(clearReminder: true));
      _syncReminders();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    }
  }

  Future<void> _openPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TaskPickerSheet(service: _service, today: _today),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return HabitQShell(
      currentTab: HabitQTab.activity,
      onLogout: () =>
          signOutAndGoToLogin(context, widget.authService, _reminders),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                '${_months[_selected.month - 1].toUpperCase()} ${_selected.year}',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _weekStrip(),
              const SizedBox(height: 16),
              if (!_isToday) ..._readOnlyNote(),
              ..._content(),
            ],
          ),
          if (_isToday)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: null,
                tooltip: 'Elegir tareas',
                onPressed: _openPicker,
                child: const Icon(Symbols.edit_rounded),
              ),
            ),
          if (_celebrating)
            Positioned.fill(
              child: CelebrationOverlay(
                key: ValueKey('celebration-$_celebrationId'),
                dayComplete: _celebratingDay,
                seed: _celebrationId,
                onFinished: () {
                  if (mounted) setState(() => _celebrating = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _readOnlyNote() => const [
        Text(
          'Solo lectura',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 12),
      ];

  List<Widget> _content() {
    if (_isLoading) return const [SkeletonList(count: 3)];
    if (_errorMessage != null) {
      return [
        ErrorNotice(
            message: _errorMessage!,
            isConnection: _errorIsConnection,
            onRetry: _load)
      ];
    }
    if (_tasks.isEmpty) {
      return [
        if (_isToday)
          EmptyState(
            icon: Symbols.checklist_rounded,
            title: 'Aún no tienes tareas',
            message: 'Toca el lápiz para elegir las de tu objetivo.',
            actionLabel: 'Elegir tareas',
            onAction: _openPicker,
          )
        else
          const EmptyState(
            icon: Symbols.event_busy_rounded,
            title: 'No hay tareas registradas este día.',
          ),
      ];
    }
    return [
      for (final (index, task) in _tasks.indexed) ...[
        FadeSlideIn(
          key: ValueKey('enter-${task.id}'),
          delay: Duration(milliseconds: 50 * math.min(index, 6)),
          child: _TaskCard(
            key: ValueKey('task-${task.id}'),
            task: task,
            editable: _isToday,
            onProgress: (next) => _changeProgress(task, next),
            onPickReminder: () => _pickReminder(task),
            onClearReminder: () => _clearReminder(task),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _weekStrip() {
    final start = _today.subtract(Duration(days: _today.weekday % 7));
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
              child: _dayChip(
                  DateTime(start.year, start.month, start.day + i), i)),
        ],
      ],
    );
  }

  Widget _dayChip(DateTime day, int index) {
    final selected = day == _selected;
    final isFuture = day.isAfter(_today);
    final textColor = selected
        ? Colors.white
        : (isFuture ? AppColors.textSecondary : AppColors.primary);
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isFuture ? AppColors.border : AppColors.primary, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('day-${TasksService.dayKey(day)}'),
          borderRadius: BorderRadius.circular(8),
          onTap: isFuture ? null : () => _selectDay(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style:
                  TextStyle(fontFamily: AppTheme.fontFamily, color: textColor),
              child: Column(
                children: [
                  Text(
                    _weekdayLabels[index],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.editable,
    required this.onProgress,
    required this.onPickReminder,
    required this.onClearReminder,
  });

  final DayTask task;
  final bool editable;
  final ValueChanged<int> onProgress;
  final VoidCallback onPickReminder;
  final VoidCallback onClearReminder;

  static const _titleStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  static const _subtitleStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final countText =
        '${task.progress}/${task.target}${task.unit.isEmpty ? '' : ' ${task.unit}'}';
    final reminder = task.reminderTime;
    return HabitQCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: AppMotion.medium,
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  task.completed
                      ? Symbols.check_circle_rounded
                      : Symbols.task_alt_rounded,
                  key: ValueKey(task.completed),
                  fill: task.completed ? 1 : 0,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.label, style: _titleStyle),
                    if (task.isCounter) Text(countText, style: _subtitleStyle),
                  ],
                ),
              ),
              if (!task.isCounter)
                Checkbox(
                  value: task.completed,
                  activeColor: AppColors.primary,
                  onChanged: editable
                      ? (value) => onProgress(value == true ? task.target : 0)
                      : null,
                )
              else if (editable) ...[
                IconButton(
                  tooltip: 'Restar',
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Symbols.remove_circle_rounded),
                  onPressed: task.progress > 0
                      ? () => onProgress(
                          (task.progress - task.step).clamp(0, task.target))
                      : null,
                ),
                IconButton(
                  tooltip: 'Sumar',
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Symbols.add_circle_rounded),
                  onPressed: task.progress < task.target
                      ? () => onProgress(
                          (task.progress + task.step).clamp(0, task.target))
                      : null,
                ),
              ],
            ],
          ),
          if (task.isCounter) ...[
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(end: task.progress / task.target),
              duration: AppMotion.medium,
              curve: AppMotion.enter,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
          if (editable || reminder != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (reminder != null)
                  Text(_parseReminder(reminder)?.format(context) ?? reminder,
                      style: _subtitleStyle),
                if (editable)
                  IconButton(
                    tooltip: 'Recordatorio',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Symbols.schedule_rounded, size: 20),
                    onPressed: onPickReminder,
                  ),
                if (editable && reminder != null)
                  IconButton(
                    tooltip: 'Quitar recordatorio',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Symbols.alarm_off_rounded, size: 20),
                    onPressed: onClearReminder,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet to switch catalog tasks on or off. Each switch saves right away.
class _TaskPickerSheet extends StatefulWidget {
  const _TaskPickerSheet({required this.service, required this.today});

  final TasksService service;
  final DateTime today;

  @override
  State<_TaskPickerSheet> createState() => _TaskPickerSheetState();
}

class _TaskPickerSheetState extends State<_TaskPickerSheet> {
  List<CatalogTask>? _catalog;
  String? _errorMessage;
  final Map<String, String> _activeIdByKey = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Reads the catalog and today's tasks fresh, so the switches never rely on
  /// a list the screen may have left behind.
  Future<void> _loadData() async {
    try {
      final catalog = await widget.service.fetchCatalog();
      final tasks = await widget.service.fetchTasks(widget.today);
      if (!mounted) return;
      setState(() {
        _activeIdByKey.addAll({
          for (final task in tasks)
            if (!task.archived) task.taskKey: task.id,
        });
        _catalog = catalog;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
  }

  Future<void> _toggle(CatalogTask item, bool on) async {
    if (!_busy.add(item.key)) return;
    setState(() => _errorMessage = null);
    try {
      if (on) {
        final task = await widget.service.activate(item.key);
        _activeIdByKey[item.key] = task.id;
      } else {
        await widget.service.archive(_activeIdByKey[item.key]!);
        _activeIdByKey.remove(item.key);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      _busy.remove(item.key);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Elegir tareas',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_errorMessage!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 14)),
              ),
            if (catalog == null && _errorMessage == null)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()))
            else if (catalog != null && catalog.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Completa tu perfil para ver las tareas de tu objetivo.'),
              )
            else if (catalog != null)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in catalog)
                      SwitchListTile(
                        title: Text(item.label),
                        subtitle: item.isCounter
                            ? Text(
                                'Meta: ${item.target}${item.unit.isEmpty ? '' : ' ${item.unit}'}')
                            : null,
                        value: _activeIdByKey.containsKey(item.key),
                        activeThumbColor: AppColors.primary,
                        onChanged: _busy.contains(item.key)
                            ? null
                            : (on) => _toggle(item, on),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Listo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
