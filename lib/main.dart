// lib/main.dart
//
// StudyFlow AI.
//
// Layout is MVVM, feature-first:
//   lib/app       — root widget and app-scoped view models
//   lib/core      — config, design tokens, shared widgets, view-model bases
//   lib/data      — models and repositories
//   lib/features  — one folder per screen: <name>_screen.dart (View) beside
//                   <name>_view_model.dart (ViewModel)
//
// Run with credentials supplied at build time:
//   flutter run --dart-define-from-file=dart_define.json

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.assertConfigured();

  // Both are awaited before the first frame: Supabase so a stored session is
  // restored in time for Splash to route on it, preferences so the saved theme
  // is applied without a flash of the wrong one.
  final results = await Future.wait([
    Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    ),
    SharedPreferences.getInstance(),
  ]);
  final prefs = results[1] as SharedPreferences;

  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(PreferencesStore(prefs)),
      ],
      child: const StudyFlowApp(),
    ),
  );
}
