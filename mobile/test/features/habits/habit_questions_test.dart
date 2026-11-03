import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/habits/habit_questions.dart';

void main() {
  final questions = [for (final s in habitDomainSections) ...s.questions];
  HabitQuestion byKey(String key) => questions.firstWhere((q) => q.key == key);
  List<String> labels(String key) => [for (final o in byKey(key).options) o.label];
  List<String> values(String key) => [for (final o in byKey(key).options) o.value];

  test('there are nine questions with unique keys', () {
    expect(questions, hasLength(9));
    expect({for (final q in questions) q.key}, hasLength(9));
  });

  test('every question has its own distinct icon', () {
    expect({for (final q in questions) q.icon}, hasLength(9));
  });

  test('every question offers distinct, non-empty options', () {
    for (final q in questions) {
      expect(q.options.length, greaterThanOrEqualTo(3), reason: q.key);
      expect({for (final o in q.options) o.value}, hasLength(q.options.length), reason: q.key);
      expect({for (final o in q.options) o.label}, hasLength(q.options.length), reason: q.key);
    }
  });

  test('sleep and screens-before-bed keep their codes', () {
    expect(byKey('hours').prompt, '¿Cuántas horas de sueño tienes en promedio diariamente?');
    expect(values('hours'), ['less_5', '5_6', '7_8', 'more_8']);
    expect(values('screen_before_bed'), ['never', 'sometimes', 'often']);
  });

  test('fruits and vegetables ask for times per day', () {
    expect(byKey('fruits_vegetables').prompt,
        '¿Cuántas veces al día incluyes frutas o verduras en tus comidas?');
    expect(labels('fruits_vegetables'), ['Ninguna', '1 vez', '2 veces', '3 o más veces']);
    expect(values('fruits_vegetables'), ['none', '1', '2', '3_plus']);
  });

  test('fast food asks for a weekly frequency', () {
    expect(byKey('fast_food').prompt,
        '¿Con qué frecuencia consumes comida rápida o ultraprocesados a la semana?');
    expect(labels('fast_food'), ['Nunca', '1–3 veces', '4–6 veces', 'Todos los días']);
    expect(values('fast_food'), ['never', 'weekly_1_3', 'weekly_4_6', 'daily']);
  });

  test('exercise asks for days per week', () {
    expect(byKey('days_per_week').prompt,
        '¿Cuántos días a la semana haces ejercicio (gimnasio, trotar, deporte)?');
    expect(labels('days_per_week'), ['Ninguno', '1–2', '3–4', '5 o más']);
    expect(values('days_per_week'), ['0', '1_2', '3_4', '5_plus']);
  });

  test('sitting time keeps its key but now uses hour ranges', () {
    expect(byKey('sedentary_hours').prompt,
        '¿Cuántas horas al día pasas sentado (estudio, trabajo, transporte u ocio)?');
    expect(labels('sedentary_hours'), ['Menos de 4 h', '4–6 h', '7–9 h', 'Más de 9 h']);
    expect(values('sedentary_hours'), ['less_4h', '4_6h', '7_9h', 'more_9h']);
  });

  test('water asks for liters without gaps or overlaps and explains a glass', () {
    final water = byKey('daily_intake');
    expect(water.prompt, '¿Cuántos litros de agua tomas al día?');
    expect(water.hint, '1 vaso ≈ 250 ml');
    expect(labels('daily_intake'), ['Menos de 1 L', '1–2 L', '2–3 L', 'Más de 3 L']);
    expect(values('daily_intake'), ['less_1l', '1_2l', '2_3l', 'more_3l']);
  });

  test('only the water question has a hint', () {
    expect([for (final q in questions) if (q.hint != null) q.key], ['daily_intake']);
  });

  test('screen time covers every kind of device', () {
    expect(byKey('recreational_hours').prompt,
        '¿Cuánto tiempo diario pasas frente a dispositivos electrónicos (portátiles, celular, tablet, televisor)?');
    expect(labels('recreational_hours'), ['Menos de 2 h', '2–4 h', '4–6 h', 'Más de 6 h']);
    expect(values('recreational_hours'), ['less_2h', '2_4h', '4_6h', 'more_6h']);
  });

  test('stress asks for days per week during the last month', () {
    expect(byKey('frequency').prompt,
        'En el último mes, ¿cuántos días a la semana sientes estrés que afecta tu rutina?');
    expect(labels('frequency'), ['Ninguno', '1–2 días', '3–4 días', '5 o más días']);
    expect(values('frequency'), ['none', '1_2', '3_4', '5_plus']);
  });
}
