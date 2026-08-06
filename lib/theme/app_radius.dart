// lib/theme/app_radius.dart
//
// StudyFlow AI — corner radius system. Soft, generous, consistent.

import 'package:flutter/widgets.dart';

@immutable
class AppRadius {
  const AppRadius._();

  // Raw values
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  static const double pill = 9999;

  // Radius
  static const Radius rxs = Radius.circular(xs);
  static const Radius rsm = Radius.circular(sm);
  static const Radius rmd = Radius.circular(md);
  static const Radius rlg = Radius.circular(lg);
  static const Radius rxl = Radius.circular(xl);
  static const Radius rxxl = Radius.circular(xxl);
  static const Radius rpill = Radius.circular(pill);

  // BorderRadius (most common usage)
  static const BorderRadius brXs = BorderRadius.all(rxs);
  static const BorderRadius brSm = BorderRadius.all(rsm);
  static const BorderRadius brMd = BorderRadius.all(rmd);
  static const BorderRadius brLg = BorderRadius.all(rlg);
  static const BorderRadius brXl = BorderRadius.all(rxl);
  static const BorderRadius brXxl = BorderRadius.all(rxxl);
  static const BorderRadius brPill = BorderRadius.all(rpill);

  /// Top-only rounding for bottom sheets, modals, drawers.
  static const BorderRadius brSheetTop = BorderRadius.only(
    topLeft: rxxl,
    topRight: rxxl,
  );
}
