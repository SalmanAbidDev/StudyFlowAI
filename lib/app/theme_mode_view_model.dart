// lib/app/theme_mode_view_model.dart
//
// App-scoped: the theme outlives every screen, so this sits beside the app
// widget rather than inside a feature.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences.dart';

/// The choice survives a restart. It is stored locally rather than on the
/// profile row on purpose: the theme has to be right on the very first frame,
/// including on Splash and Auth where there is no session to read a profile
/// with.
class ThemeModeViewModel extends Notifier<ThemeMode> {
  static const storageKey = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = ref.read(preferencesProvider).getString(storageKey);
    // An unrecognised value falls back rather than throwing — a key written by
    // a newer build should not brick an older one.
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode mode) async {
    // Apply first, persist second: the UI should not wait on a disk write.
    state = mode;
    await ref.read(preferencesProvider).setString(storageKey, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeViewModel, ThemeMode>(ThemeModeViewModel.new);

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
