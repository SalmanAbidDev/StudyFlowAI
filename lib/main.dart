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
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.assertConfigured();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const ProviderScope(child: StudyFlowApp()));
}
