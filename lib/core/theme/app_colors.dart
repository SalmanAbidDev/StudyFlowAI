// lib/theme/app_colors.dart
//
// StudyFlow AI — color tokens.
// All values are `const Color` so they can be used in `const` constructors.
// Semantic getters (textPrimary, success, etc.) resolve against the active
// brightness via `AppColors.of(context)`.

import 'package:flutter/material.dart';

@immutable
class AppColors {
  const AppColors._();

  // ────────────────────────────────────────────────────────────────────────
  // Brand
  // ────────────────────────────────────────────────────────────────────────
  static const Color indigo = Color(0xFF2A2A6E);
  static const Color indigoDeep = Color(0xFF1B1B52);
  static const Color indigoSoft = Color(0xFFEDEBF7);
  static const Color lavender = Color(0xFFC4B5FD);
  static const Color lavenderSoft = Color(0xFFF2EEFE);

  // ────────────────────────────────────────────────────────────────────────
  // Semantic accents
  // ────────────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF059669); // emerald
  static const Color successSoft = Color(0xFFE6F4EE);
  static const Color warning = Color(0xFFF59E0B); // amber
  static const Color warningSoft = Color(0xFFFEF3D7);
  static const Color error = Color(0xFFFB7185); // coral
  static const Color errorSoft = Color(0xFFFEEDF0);
  static const Color info = Color(0xFF2A2A6E); // alias of indigo
  static const Color infoSoft = Color(0xFFEDEBF7);

  // ────────────────────────────────────────────────────────────────────────
  // Light surfaces & ink
  // ────────────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFFAFAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF4F4F7);
  static const Color surfaceInverse = Color(0xFF0E0E14);
  static const Color border = Color(0xFFECECF1);
  static const Color borderStrong = Color(0xFFE0E0E8);
  static const Color divider = Color(0xFFECECF1);
  static const Color overlay = Color(0x520E0E14); // 32% ink

  static const Color textPrimary = Color(0xFF0E0E14);
  static const Color textSecondary = Color(0xFF3A3A46);
  static const Color textMuted = Color(0xFF74747F);
  static const Color textDisabled = Color(0xFFA0A0AB);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ────────────────────────────────────────────────────────────────────────
  // Dark surfaces & ink
  // ────────────────────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0B0B10);
  static const Color surfaceDark = Color(0xFF15151C);
  static const Color surfaceAltDark = Color(0xFF1E1E27);
  static const Color surfaceInverseDark = Color(0xFFFAFAFB);
  static const Color borderDark = Color(0xFF23232E);
  static const Color borderStrongDark = Color(0xFF2E2E3B);
  static const Color dividerDark = Color(0xFF23232E);
  static const Color overlayDark = Color(0x99000000);

  static const Color textPrimaryDark = Color(0xFFFAFAFB);
  static const Color textSecondaryDark = Color(0xFFC8C8D2);
  static const Color textMutedDark = Color(0xFF8A8A96);
  static const Color textDisabledDark = Color(0xFF55555F);

  // Dark-tuned accents (slightly desaturated for legibility on dark surfaces)
  static const Color indigoDark = Color(0xFF7C7CE0);
  static const Color successDark = Color(0xFF34D399);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color errorDark = Color(0xFFFB7185);

  // ────────────────────────────────────────────────────────────────────────
  // Brightness-aware resolver
  // ────────────────────────────────────────────────────────────────────────
  static AppColorsResolved of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColorsResolved.dark : AppColorsResolved.light;
  }
}

/// Pre-resolved color set for a single brightness. Use via `AppColors.of(ctx)`
/// when you need the *active* value rather than naming the variant explicitly.
@immutable
class AppColorsResolved {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceInverse;
  final Color border;
  final Color borderStrong;
  final Color divider;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  final Color primary;
  final Color success;
  final Color warning;
  final Color error;

  const AppColorsResolved({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceInverse,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.primary,
    required this.success,
    required this.warning,
    required this.error,
  });

  static const light = AppColorsResolved(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt,
    surfaceInverse: AppColors.surfaceInverse,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    textDisabled: AppColors.textDisabled,
    primary: AppColors.indigo,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
  );

  static const dark = AppColorsResolved(
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surfaceAlt: AppColors.surfaceAltDark,
    surfaceInverse: AppColors.surfaceInverseDark,
    border: AppColors.borderDark,
    borderStrong: AppColors.borderStrongDark,
    divider: AppColors.dividerDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textMuted: AppColors.textMutedDark,
    textDisabled: AppColors.textDisabledDark,
    primary: AppColors.indigoDark,
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    error: AppColors.errorDark,
  );
}