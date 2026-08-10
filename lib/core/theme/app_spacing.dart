// lib/theme/app_spacing.dart
//
// StudyFlow AI — spacing scale (4-pt base, with named steps).
// Always reach for a token; never hardcode pixels in layout code.

import 'package:flutter/widgets.dart';

@immutable
class AppSpacing {
  const AppSpacing._();

  // Scale
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double xxl = 40;
  static const double section = 64;

  // Common composite paddings
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets screenAll =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets cardCompact = EdgeInsets.all(sm + 2); // 14
  static const EdgeInsets cardDefault = EdgeInsets.all(md); // 16
  static const EdgeInsets cardHero = EdgeInsets.all(lg); // 22
  static const EdgeInsets listRow =
      EdgeInsets.symmetric(horizontal: md, vertical: sm + 2);
  static const EdgeInsets buttonH =
      EdgeInsets.symmetric(horizontal: md + 2, vertical: 0);
  static const EdgeInsets sheet = EdgeInsets.fromLTRB(lg, lg, lg, xl);

  // Standard gap widgets — drop in to flex children to keep markup clean.
  static const SizedBox gapXxs = SizedBox(height: xxs, width: xxs);
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl, width: xxl);
}