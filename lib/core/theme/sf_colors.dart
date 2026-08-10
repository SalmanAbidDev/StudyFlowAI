// lib/theme/sf_colors.dart
//
// StudyFlow AI — expressive palette exposed as a ThemeExtension.
//
// `app_colors.dart` carries the structural tokens (surfaces, ink, semantic
// accents). This extension adds the *decorative* half of the design system —
// the soft accent washes behind chips and stat tiles, the brand gradient
// anchors, and the on-soft ink colors — each with an explicit dark variant.
//
// Read it with `context.sf` (see the extension at the bottom of this file).

import 'package:flutter/material.dart';
import 'app_colors.dart';

@immutable
class SfColors extends ThemeExtension<SfColors> {
  /// Gradient anchors. These stay saturated in both modes — they paint white
  /// text on a filled surface, so they must not follow the ink inversion.
  final Color brand; // deep royal indigo
  final Color brandMid;
  final Color brandLight;
  final Color lavender;

  /// Accent hues at full strength (icon glyphs, progress fills, bar charts).
  final Color emerald;
  final Color coral;
  final Color amber;
  final Color violet;

  /// Accent washes — the tinted background behind a chip or stat tile.
  final Color indigoSoft;
  final Color lavenderSoft;
  final Color emeraldSoft;
  final Color coralSoft;
  final Color amberSoft;

  /// Ink to place *on* the matching soft wash. Darker than the raw accent in
  /// light mode; brighter in dark mode.
  final Color emeraldInk;
  final Color coralInk;
  final Color amberInk;
  final Color violetInk;

  /// Four-step ink ramp, mirroring the design tokens' ink / ink2 / ink3 / ink4.
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;

  /// Warm highlight used on the streak hero (reads on indigo in both modes).
  final Color streak;

  const SfColors({
    required this.brand,
    required this.brandMid,
    required this.brandLight,
    required this.lavender,
    required this.emerald,
    required this.coral,
    required this.amber,
    required this.violet,
    required this.indigoSoft,
    required this.lavenderSoft,
    required this.emeraldSoft,
    required this.coralSoft,
    required this.amberSoft,
    required this.emeraldInk,
    required this.coralInk,
    required this.amberInk,
    required this.violetInk,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.streak,
  });

  static const SfColors light = SfColors(
    brand: AppColors.indigo,
    brandMid: Color(0xFF4D3DCB),
    brandLight: Color(0xFF6D5DD3),
    lavender: AppColors.lavender,
    emerald: AppColors.success,
    coral: AppColors.error,
    amber: AppColors.warning,
    violet: Color(0xFF6D5DD3),
    indigoSoft: AppColors.indigoSoft,
    lavenderSoft: AppColors.lavenderSoft,
    emeraldSoft: AppColors.successSoft,
    coralSoft: AppColors.errorSoft,
    amberSoft: AppColors.warningSoft,
    emeraldInk: AppColors.success,
    coralInk: Color(0xFFD14B62),
    amberInk: Color(0xFFA86A04),
    violetInk: Color(0xFF6D5DD3),
    ink: AppColors.textPrimary,
    ink2: AppColors.textSecondary,
    ink3: AppColors.textMuted,
    ink4: AppColors.textDisabled,
    streak: Color(0xFFFFB562),
  );

  static const SfColors dark = SfColors(
    brand: AppColors.indigo,
    brandMid: Color(0xFF4D3DCB),
    brandLight: Color(0xFF6D5DD3),
    lavender: AppColors.lavender,
    emerald: AppColors.successDark,
    coral: AppColors.errorDark,
    amber: AppColors.warningDark,
    violet: Color(0xFFA78BFA),
    indigoSoft: Color(0xFF1F1F3D),
    lavenderSoft: Color(0xFF26213D),
    emeraldSoft: Color(0xFF0D2A22),
    coralSoft: Color(0xFF3A1820),
    amberSoft: Color(0xFF3A2A0E),
    emeraldInk: AppColors.successDark,
    coralInk: AppColors.errorDark,
    amberInk: AppColors.warningDark,
    violetInk: Color(0xFFA78BFA),
    ink: AppColors.textPrimaryDark,
    ink2: AppColors.textSecondaryDark,
    ink3: AppColors.textMutedDark,
    ink4: AppColors.textDisabledDark,
    streak: Color(0xFFFFB562),
  );

  /// The signature indigo → violet sweep used on hero cards, the splash mark,
  /// the flashcard reverse, and the primary CTA.
  List<Color> get brandSweep => [brand, brandMid, brandLight];

  @override
  SfColors copyWith({
    Color? brand,
    Color? brandMid,
    Color? brandLight,
    Color? lavender,
    Color? emerald,
    Color? coral,
    Color? amber,
    Color? violet,
    Color? indigoSoft,
    Color? lavenderSoft,
    Color? emeraldSoft,
    Color? coralSoft,
    Color? amberSoft,
    Color? emeraldInk,
    Color? coralInk,
    Color? amberInk,
    Color? violetInk,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? ink4,
    Color? streak,
  }) {
    return SfColors(
      brand: brand ?? this.brand,
      brandMid: brandMid ?? this.brandMid,
      brandLight: brandLight ?? this.brandLight,
      lavender: lavender ?? this.lavender,
      emerald: emerald ?? this.emerald,
      coral: coral ?? this.coral,
      amber: amber ?? this.amber,
      violet: violet ?? this.violet,
      indigoSoft: indigoSoft ?? this.indigoSoft,
      lavenderSoft: lavenderSoft ?? this.lavenderSoft,
      emeraldSoft: emeraldSoft ?? this.emeraldSoft,
      coralSoft: coralSoft ?? this.coralSoft,
      amberSoft: amberSoft ?? this.amberSoft,
      emeraldInk: emeraldInk ?? this.emeraldInk,
      coralInk: coralInk ?? this.coralInk,
      amberInk: amberInk ?? this.amberInk,
      violetInk: violetInk ?? this.violetInk,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      ink4: ink4 ?? this.ink4,
      streak: streak ?? this.streak,
    );
  }

  @override
  SfColors lerp(ThemeExtension<SfColors>? other, double t) {
    if (other is! SfColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SfColors(
      brand: c(brand, other.brand),
      brandMid: c(brandMid, other.brandMid),
      brandLight: c(brandLight, other.brandLight),
      lavender: c(lavender, other.lavender),
      emerald: c(emerald, other.emerald),
      coral: c(coral, other.coral),
      amber: c(amber, other.amber),
      violet: c(violet, other.violet),
      indigoSoft: c(indigoSoft, other.indigoSoft),
      lavenderSoft: c(lavenderSoft, other.lavenderSoft),
      emeraldSoft: c(emeraldSoft, other.emeraldSoft),
      coralSoft: c(coralSoft, other.coralSoft),
      amberSoft: c(amberSoft, other.amberSoft),
      emeraldInk: c(emeraldInk, other.emeraldInk),
      coralInk: c(coralInk, other.coralInk),
      amberInk: c(amberInk, other.amberInk),
      violetInk: c(violetInk, other.violetInk),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      ink4: c(ink4, other.ink4),
      streak: c(streak, other.streak),
    );
  }
}

/// Ergonomic accessors used throughout the screens.
extension SfThemeContext on BuildContext {
  /// Decorative palette (soft washes, gradient anchors, ink ramp).
  SfColors get sf => Theme.of(this).extension<SfColors>() ?? SfColors.light;

  /// Structural Material colors (surface, outline, primary, …).
  ColorScheme get scheme => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
