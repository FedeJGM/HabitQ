import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/celebration/celebration_overlay.dart';
import '../../core/widgets/decor/background_shapes.dart';
import 'domain_burst.dart';
import 'habit_domain_visuals.dart';
import 'habit_questions.dart';

/// Habit questionnaire shown one question at a time, with a progress bar and
/// an animation of the question's category when an answer is picked (zzz for
/// sleep, drops for hydration...). Shared by the onboarding and by Mis hábitos.
///
/// The parent owns the data: [answers] holds the current answers by question
/// key, and [onSelect] stores a pick and returns whether it was accepted (an
/// unaccepted pick neither animates nor advances). Questions in [lockedKeys]
/// cannot be answered here and show "Sin responder".
class HabitWizard extends StatefulWidget {
  const HabitWizard({
    super.key,
    required this.answers,
    required this.onSelect,
    required this.onFinish,
    required this.finishLabel,
    this.lockedKeys = const {},
    this.initialStep = 0,
    this.errorMessage,
    this.isFinishing = false,
  });

  final Map<String, String> answers;
  final Future<bool> Function(HabitQuestion question, String value) onSelect;
  final VoidCallback onFinish;
  final String finishLabel;
  final Set<String> lockedKeys;
  final int initialStep;
  final String? errorMessage;
  final bool isFinishing;

  @override
  State<HabitWizard> createState() => _HabitWizardState();
}

class _Step {
  const _Step(this.domainTitle, this.question);

  final String domainTitle;
  final HabitQuestion question;
}

class _HabitWizardState extends State<HabitWizard> with SingleTickerProviderStateMixin {
  static final List<_Step> _steps = [
    for (final section in habitDomainSections)
      for (final question in section.questions) _Step(section.title, question),
  ];

  final _stackKey = GlobalKey();
  late final AnimationController _advance;
  late int _step;
  int _direction = 1;
  bool _busy = false;
  int _burstId = 0;
  bool _showBurst = false;
  String _burstDomain = '';
  Offset _burstOrigin = Offset.zero;

  int get _total => _steps.length;
  bool get _onSummary => _step >= _total;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, _total);
    _advance = AnimationController(vsync: this, duration: AppMotion.slow + AppMotion.medium);
  }

  @override
  void dispose() {
    _advance.dispose();
    super.dispose();
  }

  bool get _allAnswered => _steps.every((s) => widget.answers.containsKey(s.question.key));

  bool get _canGoNext {
    if (_busy || _onSummary) return false;
    final question = _steps[_step].question;
    return widget.answers.containsKey(question.key) || widget.lockedKeys.contains(question.key);
  }

  void _goTo(int step) {
    _advance.stop();
    setState(() {
      _direction = step >= _step ? 1 : -1;
      _step = step.clamp(0, _total);
    });
  }

  Future<void> _pick(HabitQuestion question, String value, Offset globalCenter) async {
    if (_busy) return;
    _advance.stop();
    final pickedAt = _step;
    setState(() => _busy = true);
    bool accepted;
    try {
      accepted = await widget.onSelect(question, value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || !accepted) return;

    unawaited(_haptic());
    if (AppMotion.reduce(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == pickedAt) _goTo(pickedAt + 1);
      });
      return;
    }

    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    setState(() {
      _burstId++;
      _showBurst = true;
      _burstDomain = question.domain;
      _burstOrigin = box == null ? globalCenter : box.globalToLocal(globalCenter);
    });
    _advance
      ..reset()
      ..addStatusListener(_onAdvanceStatus);
    _advancingFrom = pickedAt;
    _advance.forward();
  }

  int _advancingFrom = 0;

  void _onAdvanceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _advance.removeStatusListener(_onAdvanceStatus);
    if (mounted && _step == _advancingFrom) _goTo(_advancingFrom + 1);
  }

  Future<void> _haptic() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // No vibration motor or no platform channel (tests): nothing to do.
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Stack(
        key: _stackKey,
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
                    child: AnimatedSwitcher(
                      duration: AppMotion.medium,
                      switchInCurve: AppMotion.enter,
                      transitionBuilder: (child, animation) {
                        final entering = child.key == ValueKey(_step);
                        final offset = Tween<Offset>(
                          begin: Offset(entering ? 0.12 * _direction : -0.12 * _direction, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: SingleChildScrollView(
                          child: _onSummary ? _summary() : _question(_steps[_step].question),
                        ),
                      ),
                    ),
                  ),
                  if (widget.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontFamily: AppTheme.fontFamily),
                        ),
                      ),
                    ),
                  _navigation(),
                ],
              ),
            ),
          ),
          if (_onSummary && _allAnswered && !AppMotion.reduce(context))
            const Positioned.fill(
              child: CelebrationOverlay(key: ValueKey('wizard-summary-fireworks')),
            ),
          if (_showBurst)
            Positioned.fill(
              child: DomainBurst(
                key: ValueKey('burst-$_burstId'),
                domain: _burstDomain,
                origin: _burstOrigin,
                seed: _burstId,
                onFinished: () {
                  if (mounted) setState(() => _showBurst = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    final onQuestion = !_onSummary;
    final step = onQuestion ? _steps[_step] : null;
    final visual = step == null ? null : DomainVisual.of(step.question.domain);
    final progress = onQuestion ? (_step + 1) / _total : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (visual != null)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.sky.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: Icon(visual.badge, fill: 1, size: 22, color: AppColors.textPrimary),
                ),
              ),
            if (visual != null) const SizedBox(width: 12),
            Expanded(
              child: Text(
                step?.domainTitle ?? 'Resumen',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              onQuestion ? 'Pregunta ${_step + 1} de $_total' : 'Último paso',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: AppMotion.reduce(context) ? Duration.zero : AppMotion.medium,
          curve: AppMotion.enter,
          builder: (context, value, _) => LinearProgressIndicator(
            key: const ValueKey('wizard-progress'),
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: AppColors.primary,
            backgroundColor: AppColors.sky.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _question(HabitQuestion question) {
    final locked = widget.lockedKeys.contains(question.key);
    final current = widget.answers[question.key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question.prompt,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            height: 1.3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        if (locked) ...[
          const Text(
            'Sin responder',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Esta pregunta se responde al completar tu perfil.',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppColors.textSecondary),
          ),
        ] else
          for (final option in question.options) ...[
            HabitOptionTile(
              key: ValueKey('${question.key}:${option.value}'),
              label: option.label,
              selected: current == option.value,
              enabled: !_busy,
              onTap: (center) => _pick(question, option.value, center),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _summary() {
    final answered = _steps.where((s) => widget.answers.containsKey(s.question.key)).length;
    final all = answered == _total;
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: AppColors.sky.withValues(alpha: 0.6), shape: BoxShape.circle),
          child: const ExcludeSemantics(
            child: Icon(Symbols.check_circle_rounded, fill: 1, size: 48, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '¡Listo!',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          all ? 'Respondiste las $_total preguntas.' : 'Respondiste $answered de $_total preguntas.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _navigation() {
    final back = TextButton(
      onPressed: _step > 0 && !_busy && !widget.isFinishing ? () => _goTo(_step - 1) : null,
      style: TextButton.styleFrom(minimumSize: const Size(96, 48), foregroundColor: AppColors.textPrimary),
      child: const Text('Atrás'),
    );
    final forward = _onSummary
        ? FilledButton(
            onPressed: widget.isFinishing ? null : widget.onFinish,
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48), shape: const StadiumBorder()),
            child: widget.isFinishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(widget.finishLabel),
          )
        : FilledButton(
            onPressed: _canGoNext ? () => _goTo(_step + 1) : null,
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48), shape: const StadiumBorder()),
            child: const Text('Siguiente'),
          );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [back, forward],
    );
  }
}

/// A large tappable answer. Reports the center of the tile (in global
/// coordinates) so the category animation can start from it.
class HabitOptionTile extends StatelessWidget {
  const HabitOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      onTap: enabled ? () => onTap(_center(context)) : null,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.14) : Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.sky,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? () => onTap(_center(context)) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: AppMotion.fast,
                      curve: Curves.easeOutBack,
                      child: const Icon(Symbols.check_circle_rounded, fill: 1, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _center(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }
}
