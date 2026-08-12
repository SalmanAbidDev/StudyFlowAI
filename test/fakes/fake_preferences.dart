// test/fakes/fake_preferences.dart

import 'package:ai_study_helper/core/preferences.dart';

/// In-memory preferences. Keeps the shared_preferences plugin — and its
/// platform channel — out of the test suite entirely.
class FakePreferencesStore implements PreferencesStore {
  FakePreferencesStore([Map<String, String>? initial])
      : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
