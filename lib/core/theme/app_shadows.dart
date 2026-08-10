// lib/theme/app_shadows.dart
//
// StudyFlow AI — elevation tokens.
// Three steps + a brand glow. Shadow color is ink-tinted, never pure black.
// In dark mode, shadows are essentially invisible — pair with borderDark
// or surfaceAltDark for separation instead.

import 'package:flutter/widgets.dart';

@immutable
class AppShadows {
  const AppShadows._();

  /// Card resting state. Use under any standard card/list-row.
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A0F0F1E), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F0F1E), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// How far [sm] bleeds past the box it is cast from: `blurRadius - offset.dy`
  /// above, `blurRadius + offset.dy` below.
  ///
  /// A scroll view clips to its own bounds, so a content-sized rail of cards is
  /// exactly as tall as the cards and shears the shadow off — most visibly
  /// along the bottom. Rails reserve this much so the shadow has somewhere to
  /// land.
  static const double smBleedTop = 2;
  static const double smBleedBottom = 4;

  /// Hover, floating elements, raised cards.
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F0F0F1E), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A0F0F1E), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// Modals, bottom sheets, drag previews, flashcards.
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x2E0F0F1E),
      blurRadius: 48,
      spreadRadius: -16,
      offset: Offset(0, 24),
    ),
    BoxShadow(
      color: Color(0x140F0F1E),
      blurRadius: 16,
      spreadRadius: -8,
      offset: Offset(0, 8),
    ),
  ];

  /// Brand glow — primary CTAs and the Flow orb.
  static const List<BoxShadow> brandGlow = [
    BoxShadow(
      color: Color(0x592A2A6E),
      blurRadius: 40,
      spreadRadius: -12,
      offset: Offset(0, 18),
    ),
  ];

  /// Coral glow — destructive / urgent actions.
  static const List<BoxShadow> errorGlow = [
    BoxShadow(
      color: Color(0x4DFB7185),
      blurRadius: 20,
      spreadRadius: -6,
      offset: Offset(0, 8),
    ),
  ];

  /// In dark mode, return an empty list and rely on borders for separation.
  static List<BoxShadow> resolve(List<BoxShadow> light, Brightness brightness) {
    if (brightness == Brightness.dark) return const [];
    return light;
  }
}
