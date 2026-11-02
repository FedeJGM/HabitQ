class ProfileOption {
  const ProfileOption(this.value, this.label);

  final String value;
  final String label;
}

/// Shared by the onboarding perfil básico step and the Perfil edit screen
/// so both stay in sync on the available choices.
const genderOptions = [
  ProfileOption('female', 'Femenino'),
  ProfileOption('male', 'Masculino'),
  ProfileOption('other', 'Otro'),
  ProfileOption('prefer_not_to_say', 'Prefiero no decir'),
];

const ageRangeOptions = [
  ProfileOption('18-24', '18-24'),
  ProfileOption('25-34', '25-34'),
  ProfileOption('35-44', '35-44'),
  ProfileOption('45-54', '45-54'),
  ProfileOption('55+', '55+'),
];

const mainGoalOptions = [
  ProfileOption('sleep_better', 'Dormir mejor'),
  ProfileOption('eat_better', 'Alimentarme mejor'),
  ProfileOption('move_more', 'Moverme más'),
  ProfileOption('hydrate_more', 'Hidratarme mejor'),
  ProfileOption('reduce_screen_time', 'Reducir el uso de pantallas'),
  ProfileOption('manage_stress', 'Manejar mejor el estrés'),
];

// Ranges accepted by the backend (schemas/profile.py).
const minHeightCm = 100;
const maxHeightCm = 250;
const minWeightKg = 20.0;
const maxWeightKg = 300.0;

const heightErrorText = 'Ingresa una altura entre 100 y 250 cm.';
const weightErrorText = 'Ingresa un peso entre 20 y 300 kg.';

/// Whole centimeters within [minHeightCm]..[maxHeightCm], or null.
int? parseHeightCm(String text) {
  final value = int.tryParse(text.trim());
  if (value == null || value < minHeightCm || value > maxHeightCm) return null;
  return value;
}

/// Kilograms within [minWeightKg]..[maxWeightKg] (comma or dot as decimal
/// separator), or null.
double? parseWeightKg(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value < minWeightKg || value > maxWeightKg) return null;
  return value;
}

/// "60.5" / "70": drops a pointless ".0".
String formatMeasure(num value) => value % 1 == 0 ? value.toInt().toString() : value.toString();
