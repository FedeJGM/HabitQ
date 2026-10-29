import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';

/// How the particles of an answer animation travel.
enum BurstMotion {
  /// Rise slowly and sway, like sleep or breath.
  floatUp,

  /// Fall from above, like drops.
  fall,

  /// Burst outward from the tapped answer.
  radial,
}

/// One kind of particle thrown when an answer is picked.
sealed class BurstParticle {
  const BurstParticle();
}

/// A text glyph, such as the "z" of sleep.
class LetterParticle extends BurstParticle {
  const LetterParticle(this.letter);

  final String letter;
}

/// An icon glyph.
class IconParticle extends BurstParticle {
  const IconParticle(this.icon);

  final IconData icon;
}

/// The look of one habit domain: the header badge and the particles that fly
/// when the user answers a question of that domain. The animation depends on
/// the category only, never on the answer, so it carries no judgement.
class DomainVisual {
  const DomainVisual({
    required this.badge,
    required this.motion,
    required this.particles,
    required this.colors,
    this.isFallback = false,
  });

  final IconData badge;
  final BurstMotion motion;
  final List<BurstParticle> particles;
  final List<Color> colors;
  final bool isFallback;

  static const _sleep = DomainVisual(
    badge: Symbols.bedtime_rounded,
    motion: BurstMotion.floatUp,
    particles: [LetterParticle('z'), LetterParticle('Z'), LetterParticle('z'), IconParticle(Symbols.bedtime_rounded)],
    colors: [AppColors.skyDeep, AppColors.sky, AppColors.primaryDark],
  );

  static const _nutrition = DomainVisual(
    badge: Symbols.nutrition_rounded,
    motion: BurstMotion.radial,
    particles: [IconParticle(Symbols.nutrition_rounded), IconParticle(Symbols.eco_rounded)],
    colors: [AppColors.primary, AppColors.primaryDark, AppColors.sun],
  );

  static const _activity = DomainVisual(
    badge: Symbols.directions_run_rounded,
    motion: BurstMotion.radial,
    particles: [IconParticle(Symbols.bolt_rounded), IconParticle(Symbols.directions_run_rounded)],
    colors: [AppColors.sun, AppColors.primary, AppColors.skyDeep],
  );

  static const _hydration = DomainVisual(
    badge: Symbols.water_drop_rounded,
    motion: BurstMotion.fall,
    particles: [IconParticle(Symbols.water_drop_rounded)],
    colors: [AppColors.skyDeep, AppColors.sky, AppColors.accent],
  );

  static const _screens = DomainVisual(
    badge: Symbols.smartphone_rounded,
    motion: BurstMotion.floatUp,
    particles: [IconParticle(Symbols.smartphone_rounded), IconParticle(Symbols.visibility_rounded)],
    colors: [AppColors.skyDeep, AppColors.accent, AppColors.sky],
  );

  static const _stress = DomainVisual(
    badge: Symbols.spa_rounded,
    motion: BurstMotion.floatUp,
    particles: [IconParticle(Symbols.spa_rounded), IconParticle(Symbols.eco_rounded)],
    colors: [AppColors.primary, AppColors.sky, AppColors.primaryDark],
  );

  static const _fallback = DomainVisual(
    badge: Symbols.auto_awesome_rounded,
    motion: BurstMotion.radial,
    particles: [IconParticle(Symbols.auto_awesome_rounded)],
    colors: [AppColors.primary, AppColors.sky],
    isFallback: true,
  );

  /// The visual for a habit `domain` key; a domain added later still animates.
  static DomainVisual of(String domain) => switch (domain) {
        'sleep' => _sleep,
        'nutrition' => _nutrition,
        'physical_activity' => _activity,
        'hydration' => _hydration,
        'screen_time' => _screens,
        'stress' => _stress,
        _ => _fallback,
      };
}
