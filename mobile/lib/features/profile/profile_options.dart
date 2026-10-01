class ProfileOption {
  const ProfileOption(this.value, this.label);

  final String value;
  final String label;
}

/// Shared by the onboarding perfil básico step and the Perfil edit screen
/// so both stay in sync on the available choices.
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
