import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_page_transitions.dart';

/// Palette taken from the Figma design (HabitQ): brand green, navy text,
/// link blue and accent blue, extended with a sky blue so the app reads as sky
/// blue, white and green. `legacy*` values keep the pre-redesign look for
/// screens that must not change (consent).
class AppColors {
  static const primary = Color(0xFF0CBC8B);
  static const primaryDark = Color(0xFF0A9C73);
  static const accent = Color(0xFF0088FF);
  static const link = Color(0xFF0856CF);
  static const background = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF161938);
  static const textSecondary = Color(0xFF5F6280);
  static const border = Color(0xFFCECECE);
  static const error = Color(0xFFDC2626);
  static const navActive = Color(0xFFBFE6F9);
  static const surfaceMuted = Color(0xFFE3E3E3);

  /// Sky blue family. Text on any of these is always [textPrimary] (navy):
  /// green on sky does not reach readable contrast.
  static const sky = Color(0xFF8FD3F4);
  static const skyLight = Color(0xFFE6F6FD);

  /// Deeper sky for icons and chart details only, never for text.
  static const skyDeep = Color(0xFF2E9BD6);

  /// White fading into the lightest sky, behind every tab.
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, skyLight],
  );

  /// Warm yellow of the Figma illustrations (the sun, the bike wheels). Used
  /// only for celebration accents, never for text or controls.
  static const sun = Color(0xFFF2C94C);

  static const legacyPrimary = Color(0xFF1BA97F);
  static const legacyAccent = Color(0xFFF2C94C);
  static const legacyTextPrimary = Color(0xFF1F2937);
  static const legacyTextSecondary = Color(0xFF6B7280);
  static const legacyBorder = Color(0xFFD1D5DB);
}

class AppShadows {
  /// Figma "shadow-4" card shadow.
  static const card = [
    BoxShadow(color: Color(0x1C000000), offset: Offset(0, 1.6), blurRadius: 3.6),
    BoxShadow(color: Color(0x12000000), offset: Offset(0, 0.3), blurRadius: 0.9),
  ];
}

class AppTheme {
  static const fontFamily = 'Lexend';

  /// Fade + short rise everywhere except iOS, which keeps its swipe-back push.
  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeSlideTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeSlideTransitionsBuilder(),
      TargetPlatform.linux: FadeSlideTransitionsBuilder(),
      TargetPlatform.macOS: FadeSlideTransitionsBuilder(),
      TargetPlatform.windows: FadeSlideTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData get light {
    const radius = 12.0;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      error: AppColors.error,
      surface: AppColors.background,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      pageTransitionsTheme: _pageTransitions,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 28,
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: 0.2,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: AppColors.primary,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: Color(0x33000000), width: 0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(40),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.navActive,
        height: 64,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
            // 11 sp so "Estadísticas" fits its slot with five tabs on a 360 dp phone.
            fontSize: 11,
            letterSpacing: 0.2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// The pre-redesign theme. Used only to keep the consent screen unchanged.
  static ThemeData get legacy {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.legacyPrimary,
        primary: AppColors.legacyPrimary,
        secondary: AppColors.legacyAccent,
        error: AppColors.error,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.legacyTextPrimary,
        ),
        bodyMedium: TextStyle(color: AppColors.legacyTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.legacyPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.legacyTextPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.legacyBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }
}
