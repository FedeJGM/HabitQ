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
  });

  final String domain;
  final String key;
  final String prompt;
  final List<HabitOption> options;
}

class HabitDomainSection {
  const HabitDomainSection({required this.title, required this.questions});

  final String title;
  final List<HabitQuestion> questions;
}

/// The six habit domains from plan section 11, one question set each.
/// Shared by the onboarding questionnaire and the "Mis hábitos" edit
/// screen so both stay in sync on prompts/options.
const habitDomainSections = [
  HabitDomainSection(
    title: 'Sueño',
    questions: [
      HabitQuestion(
        domain: 'sleep',
        key: 'hours',
        prompt: '¿Cuántas horas duermes normalmente?',
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
        prompt: '¿Con qué frecuencia consumes frutas o verduras?',
        options: [
          HabitOption('rarely', 'Rara vez'),
          HabitOption('some_days', 'Algunos días'),
          HabitOption('almost_daily', 'Casi todos los días'),
        ],
      ),
      HabitQuestion(
        domain: 'nutrition',
        key: 'fast_food',
        prompt: '¿Con qué frecuencia consumes comida rápida o ultraprocesados?',
        options: [
          HabitOption('rarely', 'Rara vez'),
          HabitOption('weekly_1_2', '1–2 veces por semana'),
          HabitOption('weekly_3_plus', '3 o más veces por semana'),
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
        prompt: '¿Cuántos días por semana realizas actividad física?',
        options: [
          HabitOption('0', '0'),
          HabitOption('1_2', '1–2'),
          HabitOption('3_4', '3–4'),
          HabitOption('5_plus', '5 o más'),
        ],
      ),
      HabitQuestion(
        domain: 'physical_activity',
        key: 'sedentary_hours',
        prompt: '¿Pasas varias horas seguidas sentado?',
        options: [
          HabitOption('yes', 'Sí'),
          HabitOption('no', 'No'),
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
        prompt: '¿Cómo describirías tu consumo diario de agua?',
        options: [
          HabitOption('low', 'Bajo'),
          HabitOption('moderate', 'Moderado'),
          HabitOption('adequate', 'Adecuado'),
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
        prompt: '¿Cuánto tiempo recreativo pasas frente a pantallas?',
        options: [
          HabitOption('less_2h', 'Menos de 2 horas'),
          HabitOption('2_4h', '2–4 horas'),
          HabitOption('more_4h', 'Más de 4 horas'),
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
        prompt: '¿Con qué frecuencia sientes estrés durante tu rutina?',
        options: [
          HabitOption('rarely', 'Rara vez'),
          HabitOption('sometimes', 'A veces'),
          HabitOption('often', 'Frecuentemente'),
        ],
      ),
    ],
  ),
];
