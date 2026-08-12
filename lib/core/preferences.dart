// lib/core/preferences.dart
//
// A thin seam over SharedPreferences.
//
// The wrapper exists so the rest of the app depends on something fakeable,
// the same way it depends on repositories rather than on SupabaseClient. That
// keeps the test suite free of the shared_preferences plugin entirely.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  const PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}

/// Overridden in `main()` with an instance loaded before `runApp`, so reads
/// are synchronous and the first frame already has the right theme — no flash
/// of the wrong one while a future resolves.
final preferencesProvider = Provider<PreferencesStore>(
  (_) => throw StateError(
    'preferencesProvider was not overridden. main() must load '
    'SharedPreferences and provide it, and tests must supply a fake.',
  ),
);
