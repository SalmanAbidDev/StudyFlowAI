// lib/app/theme_mode_view_model.dart
//
// App-scoped: the theme outlives every screen, so this sits beside the app
// widget rather than inside a feature.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// There is no preferences store yet, so the choice lives in memory for the
/// session. When persistence lands, this is the one place that has to change.
class ThemeModeViewModel extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void select(ThemeMode mode) => state = mode;
}

final themeModeProvider =
    NotifierProvider<ThemeModeViewModel, ThemeMode>(ThemeModeViewModel.new);

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
