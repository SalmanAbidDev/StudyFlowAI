// lib/core/config/supabase_config.dart
//
// Credentials come in at build time via --dart-define, not from source.
//
//   flutter run --dart-define-from-file=dart_define.json
//
// The publishable key is a *public* key — it is designed to ship inside
// clients and is useless without the Row Level Security policies that gate
// every table. Keeping it out of git is still worth doing: it makes swapping
// dev/staging/prod a build flag rather than an edit, and it keeps project
// identifiers out of a repo's permanent history. The service_role key must
// never appear in this app at all — it bypasses RLS entirely.

class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');

  /// The `sb_publishable_…` key. This supersedes the legacy JWT "anon" key,
  /// which the SDK now deprecates; publishable keys can be rotated on their
  /// own without reissuing every other key in the project.
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// Thrown at startup rather than letting the SDK fail later with something
  /// unhelpful about a malformed URL.
  static void assertConfigured() {
    if (isConfigured) return;
    throw StateError(
      'Supabase is not configured.\n\n'
      'Copy dart_define.example.json to dart_define.json, fill in your '
      'project URL and publishable key, then run:\n\n'
      '  flutter run --dart-define-from-file=dart_define.json\n\n'
      'Both values are on the Supabase dashboard under Project Settings → '
      'API keys. Use the publishable key, never the service_role key.',
    );
  }
}
