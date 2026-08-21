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
import 'core/startup_failure_app.dart';
import 'core/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nothing before `runApp` may throw.
  //
  // It used to: `assertConfigured()` threw on a build with no
  // `--dart-define-from-file`, so no frame was ever drawn and Android kept its
  // launch window on screen — the app icon, forever, indistinguishable from a
  // freeze. It cost two debugging sessions to identify, both times by pulling
  // `libapp.so` out of the APK. Whatever goes wrong now, *something* renders
  // and says what it was.
  if (!SupabaseConfig.isConfigured) {
    runApp(const StartupFailureApp(
      title: 'Supabase is not configured',
      detail: 'This build was compiled without the project URL and '
          'publishable key, so it cannot reach the backend. They are '
          'compile-time values: a build that omits them succeeds and then '
          'fails here, which is why nothing warned you earlier.\n\n'
          'Rebuild with the credentials flag:',
      fix: 'flutter build apk --release \\\n'
          '  --dart-define-from-file=dart_define.json',
    ));
    return;
  }

  try {
    // Both are awaited before the first frame: Supabase so a stored session is
    // restored in time for Splash to route on it, preferences so the saved
    // theme is applied without a flash of the wrong one.
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
  } catch (error) {
    // A malformed URL, a revoked key, a plugin that failed to register. The
    // message is shown verbatim — whoever is looking at this screen is trying
    // to fix it, and a friendly summary would remove the only clue.
    runApp(StartupFailureApp(
      title: "Couldn't start",
      detail: 'Supabase failed to initialise.\n\n$error',
    ));
  }
}
