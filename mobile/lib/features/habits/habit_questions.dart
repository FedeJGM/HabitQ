import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

class HabitOption {
  const HabitOption(this.value, this.label);

  final String value;
  final String label;
}

class HabitQuestion {
  const HabitQuestion({
    required this.domain,
    required this.key,
    required this.prompt,
    required this.options,
    required this.icon,
    this.hint,
  });

  final String domain;
  final String key;
  final String prompt;
  final List<HabitOption> options;

  /// Icon specific to this question, shown above the prompt (distinct from
  /// the category badge in the wizard header).
  final IconData icon;

  /// Optional clarification shown under the prompt (e.g. what a glass is).
  final String? hint;
}

class HabitDomainSection {
  const HabitDomainSection({required this.title, required this.questions});

  final String title;
  final List<HabitQuestion> questions;
}

/// The six habit domains from plan section 11, one question set each.
/// Shared by the onboarding questionnaire and the "Mis hábitos" edit
/// screen so both stay in sync on prompts/options. Every answer is a
/// measurable, mutually exclusive range. Keep the labels in sync with
/// backend/app/services/user_context_labels.py (D-26).
const habitDomainSections = [
  HabitDomainSection(
    title: 'Sueño',
    questions: [
      HabitQuestion(
        domain: 'sleep',
        key: 'hours',
        icon: Symbols.hotel_rounded,
        prompt: '¿Cuántas horas de sueño tienes en promedio diariamente?',
        options: [
          HabitOption('less_5', 'Menos de 5'),
          HabitOption('5_6', '5–6'),
          HabitOption('7_8', '7–8'),
          HabitOption('more_8', 'Más de 8'),
        ],
      ),
      HabitQuestion(
        domain: 'sleep',
        key: 'screen_before_bed',
        icon: Symbols.phone_android_rounded,
        prompt: '¿Usas pantallas durante la última hora antes de dormir?',
        options: [
          HabitOption('never', 'Nunca'),
          HabitOption('sometimes', 'A veces'),
          HabitOption('often', 'Frecuentemente'),
        ],
      ),
    ],
  ),
  HabitDomainSection(
    title: 'Alimentación',
    questions: [
      HabitQuestion(
        domain: 'nutrition',
        key: 'fruits_vegetables',
        icon: Symbols.eco_rounded,
        prompt: '¿Cuántas veces al día incluyes frutas o verduras en tus comidas?',
        options: [
          HabitOption('none', 'Ninguna'),
          HabitOption('1', '1 vez'),
          HabitOption('2', '2 veces'),
          HabitOption('3_plus', '3 o más veces'),
        ],
      ),
      HabitQuestion(
        domain: 'nutrition',
        key: 'fast_food',
        icon: Symbols.fastfood_rounded,
        prompt: '¿Con qué frecuencia consumes comida rápida o ultraprocesados a la semana?',
        options: [
          HabitOption('never', 'Nunca'),
          HabitOption('weekly_1_3', '1–3 veces'),
          HabitOption('weekly_4_6', '4–6 veces'),
          HabitOption('daily', 'Todos los días'),
        ],
      ),
    ],
  ),
  HabitDomainSection(
    title: 'Actividad física',
    questions: [
      HabitQuestion(
        domain: 'physical_activity',
        key: 'days_per_week',
        icon: Symbols.fitness_center_rounded,
        prompt: '¿Cuántos días a la semana haces ejercicio (gimnasio, trotar, deporte)?',
        options: [
          HabitOption('0', 'Ninguno'),
          HabitOption('1_2', '1–2'),
          HabitOption('3_4', '3–4'),
          HabitOption('5_plus', '5 o más'),
        ],
      ),
      HabitQuestion(
        domain: 'physical_activity',
        key: 'sedentary_hours',
        icon: Symbols.chair_rounded,
        prompt: '¿Cuántas horas al día pasas sentado (estudio, trabajo, transporte u ocio)?',
        options: [
          HabitOption('less_4h', 'Menos de 4 h'),
          HabitOption('4_6h', '4–6 h'),
          HabitOption('7_9h', '7–9 h'),
          HabitOption('more_9h', 'Más de 9 h'),
        ],
      ),
    ],
  ),
  HabitDomainSection(
    title: 'Hidratación',
    questions: [
      HabitQuestion(
        domain: 'hydration',
        key: 'daily_intake',
        icon: Symbols.local_drink_rounded,
        prompt: '¿Cuántos litros de agua tomas al día?',
        hint: '1 vaso ≈ 250 ml',
        options: [
          HabitOption('less_1l', 'Menos de 1 L'),
          HabitOption('1_2l', '1–2 L'),
          HabitOption('2_3l', '2–3 L'),
          HabitOption('more_3l', 'Más de 3 L'),
        ],
      ),
    ],
  ),
  HabitDomainSection(
    title: 'Uso de pantallas',
    questions: [
      HabitQuestion(
        domain: 'screen_time',
        key: 'recreational_hours',
        icon: Symbols.devices_rounded,
        prompt:
            '¿Cuánto tiempo diario pasas frente a dispositivos electrónicos (portátiles, celular, tablet, televisor)?',
        options: [
          HabitOption('less_2h', 'Menos de 2 h'),
          HabitOption('2_4h', '2–4 h'),
          HabitOption('4_6h', '4–6 h'),
          HabitOption('more_6h', 'Más de 6 h'),
        ],
      ),
    ],
  ),
  HabitDomainSection(
    title: 'Manejo del estrés',
    questions: [
      HabitQuestion(
        domain: 'stress',
        key: 'frequency',
        icon: Symbols.sentiment_stressed_rounded,
        prompt: 'En el último mes, ¿cuántos días a la semana sientes estrés que afecta tu rutina?',
        options: [
          HabitOption('none', 'Ninguno'),
          HabitOption('1_2', '1–2 días'),
          HabitOption('3_4', '3–4 días'),
          HabitOption('5_plus', '5 o más días'),
        ],
      ),
    ],
  ),
];
