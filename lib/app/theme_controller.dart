// lib/app/theme_controller.dart
//
// The design ships light and dark. There is no preferences store yet, so the
// choice lives in memory for the session; swap this notifier for a persisted
// setting when the data layer lands.

import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
