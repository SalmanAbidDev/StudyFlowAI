// lib/main.dart
//
// StudyFlow AI — UI build.
//
// This app is presentation-only: there is no backend, no API client, and no
// AI service. Every list, chart, and chat reply comes from lib/data or from
// local widget state, so the whole flow is walkable end to end.

import 'package:flutter/material.dart';

import 'app/theme_controller.dart';
import 'screens/splash_screen.dart';
import 'theme/theme.dart';

void main() => runApp(const StudyFlowApp());

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'StudyFlow AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: const SplashScreen(),
      ),
    );
  }
}
