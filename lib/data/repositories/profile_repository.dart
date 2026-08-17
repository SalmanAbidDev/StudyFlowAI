// lib/data/repositories/profile_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  /// Null only in the window between sign-up and the `handle_new_user` trigger
  /// committing, which callers treat as "still loading" rather than an error.
  Future<Profile?> current() async {
    final row = await _client.from('profiles').select().maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  }

  Future<void> updateName(String fullName) {
    return _client
        .from('profiles')
        .update({'full_name': fullName}).eq('id', _client.auth.currentUser!.id);
  }

  /// Which badges this user has earned, keyed by code. The catalogue lives in
  /// the app; this is only the progress against it.
  Future<Map<String, DateTime>> earnedAchievements() async {
    final rows = await _client
        .from('achievements')
        .select('code, earned_at')
        .not('earned_at', 'is', null);

    return {
      for (final row in rows)
        row['code'] as String: DateTime.parse(row['earned_at'] as String),
    };
  }

  /// Fills a brand-new account with a walkable starter library. Idempotent in
  /// the database, so calling it twice is harmless.
  Future<void> seedStarterContent() {
    return _client.rpc<void>('seed_starter_content');
  }
}
