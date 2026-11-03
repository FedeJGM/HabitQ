import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';

double _luminance(Color color) {
  double channel(double value) =>
      value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('the palette adds a sky blue next to the brand green', () {
    expect(AppColors.sky, const Color(0xFF8FD3F4));
    expect(AppColors.skyLight, const Color(0xFFE6F6FD));
    expect(AppColors.skyDeep, const Color(0xFF2E9BD6));
    expect(AppColors.primary, const Color(0xFF0CBC8B));
  });

  test('body text stays readable on every sky surface (WCAG AA, 4.5:1)', () {
    for (final surface in [AppColors.sky, AppColors.skyLight, AppColors.navActive]) {
      expect(_contrast(AppColors.textPrimary, surface), greaterThanOrEqualTo(4.5));
    }
    expect(_contrast(AppColors.textSecondary, AppColors.skyLight), greaterThanOrEqualTo(4.5));
  });

  test('the green wordmark is large text, so it needs 3:1 on the sky header', () {
    expect(_contrast(AppColors.primaryDark, AppColors.skyLight), greaterThanOrEqualTo(3));
  });

  test('the navigation pill is sky blue, no longer lilac', () {
    expect(AppTheme.light.navigationBarTheme.indicatorColor, AppColors.navActive);
    expect(AppColors.navActive, isNot(const Color(0xFFE8DEF8)));
  });

  test('the background gradient runs from white to the lightest sky', () {
    expect(AppColors.backgroundGradient.colors.first, AppColors.background);
    expect(AppColors.backgroundGradient.colors.last, AppColors.skyLight);
  });
}
