import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_notice.dart';
import '../../core/widgets/habitq_card.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/skeleton.dart';
import '../activity/tasks_service.dart';

/// "Tus tareas de hoy" on Inicio: a ring with the day's progress and the
/// first pending tasks. Read-only: tapping anywhere opens the Actividad tab,
/// where the tasks are completed.
class TodayTasksCard extends StatelessWidget {
  const TodayTasksCard({
    super.key,
    required this.tasks,
    required this.isLoading,
    required this.onOpen,
    this.errorMessage,
    this.isConnectionError = false,
    this.onRetry,
  });

  /// Today's tasks without the removed (archived) ones.
  final List<DayTask> tasks;
  final bool isLoading;
  final String? errorMessage;
  final bool isConnectionError;
  final VoidCallback onOpen;
  final VoidCallback? onRetry;

  static const _maxListed = 3;

  static const _titleStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  static const _mutedStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  static const _taskStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const KeyedSubtree(key: ValueKey('today-tasks-skeleton'), child: SkeletonCard());
    }
    if (errorMessage != null) {
      return ErrorNotice(message: errorMessage!, isConnection: isConnectionError, onRetry: onRetry);
    }
    if (tasks.isEmpty) return _empty();
    return _summary();
  }

  Widget _empty() {
    return HabitQCard(
      key: const ValueKey('today-tasks-empty'),
      onTap: onOpen,
      child: Row(
        children: [
          const Icon(Symbols.checklist_rounded, color: AppColors.skyDeep, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aún no tienes tareas', style: _titleStyle),
                const SizedBox(height: 2),
                const Text('Elige las de tu objetivo para ver tu avance aquí.', style: _mutedStyle),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: const StadiumBorder()),
                  child: const Text('Elegir tareas'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final done = tasks.where((task) => task.completed).length;
    // Pending first, so what is left to do is what you see.
    final ordered = [
      ...tasks.where((task) => !task.completed),
      ...tasks.where((task) => task.completed),
    ];
    final listed = ordered.take(_maxListed).toList();
    final hidden = ordered.length - listed.length;

    return HabitQCard(
      key: const ValueKey('today-tasks-card'),
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressRing(
            value: done / tasks.length,
            semanticLabel: '$done de ${tasks.length} tareas completadas',
            child: Text('$done/${tasks.length}', style: _titleStyle.copyWith(fontSize: 14)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tus tareas de hoy', style: _titleStyle),
                const SizedBox(height: 2),
                Text('$done de ${tasks.length} completadas', style: _mutedStyle),
                const SizedBox(height: 10),
                for (final task in listed) _TaskRow(task: task),
                if (hidden > 0) Text('+$hidden más', style: _mutedStyle),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const ExcludeSemantics(
            child: Icon(Symbols.chevron_right_rounded, color: AppColors.skyDeep, size: 28),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final DayTask task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              task.completed ? Symbols.check_circle_rounded : Symbols.radio_button_unchecked_rounded,
              fill: task.completed ? 1 : 0,
              size: 20,
              color: task.completed ? AppColors.primary : AppColors.skyDeep,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TodayTasksCard._taskStyle,
            ),
          ),
          if (task.isCounter) ...[
            const SizedBox(width: 8),
            Text('${task.progress}/${task.target}', style: TodayTasksCard._mutedStyle),
          ],
        ],
      ),
    );
  }
}
