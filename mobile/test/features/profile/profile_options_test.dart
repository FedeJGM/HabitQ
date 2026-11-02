import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/profile_options.dart';

void main() {
  test('gender options match the backend codes', () {
    expect([for (final o in genderOptions) o.value], ['female', 'male', 'other', 'prefer_not_to_say']);
    expect([for (final o in genderOptions) o.label], ['Femenino', 'Masculino', 'Otro', 'Prefiero no decir']);
  });

  group('parseHeightCm', () {
    test('accepts whole centimeters within 100-250', () {
      expect(parseHeightCm('170'), 170);
      expect(parseHeightCm(' 100 '), 100);
      expect(parseHeightCm('250'), 250);
    });

    test('rejects empty, non numeric, decimals and out of range values', () {
      expect(parseHeightCm(''), isNull);
      expect(parseHeightCm('abc'), isNull);
      expect(parseHeightCm('99'), isNull);
      expect(parseHeightCm('251'), isNull);
      expect(parseHeightCm('170.5'), isNull);
    });
  });

  group('parseWeightKg', () {
    test('accepts values within 20-300 with dot or comma', () {
      expect(parseWeightKg('70'), 70.0);
      expect(parseWeightKg('70.5'), 70.5);
      expect(parseWeightKg('70,5'), 70.5);
      expect(parseWeightKg('20'), 20.0);
      expect(parseWeightKg('300'), 300.0);
    });

    test('rejects empty, non numeric and out of range values', () {
      expect(parseWeightKg(''), isNull);
      expect(parseWeightKg('abc'), isNull);
      expect(parseWeightKg('19.9'), isNull);
      expect(parseWeightKg('300.1'), isNull);
    });
  });
}
