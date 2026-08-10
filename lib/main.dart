// lib/main.dart
//
// StudyFlow AI — UI build.
//
// This app is presentation-only: there is no backend, no API client, and no
// AI service. Every list, chart, and chat reply comes from lib/data or from a
// feature's view model, so the whole flow is walkable end to end.
//
// Layout is MVVM, feature-first:
//   lib/app       — root widget and app-scoped view models
//   lib/core      — design tokens, shared widgets, view-model bases
//   lib/data      — models and the static sample content
//   lib/features  — one folder per screen: <name>_screen.dart (View) beside
//                   <name>_view_model.dart (ViewModel)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() => runApp(const ProviderScope(child: StudyFlowApp()));
