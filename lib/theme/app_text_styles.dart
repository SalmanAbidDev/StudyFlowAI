// lib/theme/app_text_styles.dart
//
// StudyFlow AI — typography scale.
// Geist (UI/body) + GeistMono (data labels, eyebrows).
// Sizes are intentionally tight; line-heights and letter-spacing are tuned
// for mobile reading at 1x density.
//
// NOTE: the Geist / GeistMono TTFs are not bundled in this repo. Until they
// are dropped into assets/fonts and declared in pubspec.yaml, Flutter falls
// back to the platform UI font — the scale, weights, and tracking below still
// apply, so layout is unaffected.

import 'package:flutter/material.dart';
import 'app_colors.dart';

@immutable
class AppTextStyles {
  const AppTextStyles._();

  static const String fontUi = 'Geist';
  static const String fontMono = 'GeistMono';

  // Display
  static const TextStyle displayXL = TextStyle(
    fontFamily: fontUi,
    fontSize: 38,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayL = TextStyle(
    fontFamily: fontUi,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  // Heading / title
  static const TextStyle heading = TextStyle(
    fontFamily: fontUi,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontUi,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontUi,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  // Body
  static const TextStyle body = TextStyle(
    fontFamily: fontUi,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyS = TextStyle(
    fontFamily: fontUi,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  // Meta / supporting
  static const TextStyle caption = TextStyle(
    fontFamily: fontUi,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textMuted,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontUi,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontUi,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textOnPrimary,
  );

  // Mono — eyebrows, timestamps, numeric data
  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontMono,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.indigo,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: fontMono,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle monoStat = TextStyle(
    fontFamily: fontMono,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  /// Build a Material 3 [TextTheme] for the given [brightness].
  /// Maps our scale onto the standard `displayLarge` / `headlineLarge` / …
  /// slots so default Material widgets (AppBar, ListTile, etc.) inherit
  /// correctly.
  static TextTheme textThemeFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final muted = isDark ? AppColors.textMutedDark : AppColors.textMuted;

    return TextTheme(
      displayLarge: displayXL.copyWith(color: primary),
      displayMedium: displayL.copyWith(color: primary),
      displaySmall: heading.copyWith(color: primary),
      headlineLarge: heading.copyWith(color: primary),
      headlineMedium: title.copyWith(color: primary),
      headlineSmall: subtitle.copyWith(color: primary),
      titleLarge: title.copyWith(color: primary),
      titleMedium: subtitle.copyWith(color: primary),
      titleSmall: label.copyWith(color: primary),
      bodyLarge: body.copyWith(color: secondary),
      bodyMedium: bodyS.copyWith(color: secondary),
      bodySmall: caption.copyWith(color: muted),
      labelLarge: button.copyWith(color: primary),
      labelMedium: label.copyWith(color: primary),
      labelSmall: caption.copyWith(color: muted),
    );
  }
}
