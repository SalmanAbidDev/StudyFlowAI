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

  Future<List<Achievement>> achievements() async {
    final rows = await _client
        .from('achievements')
        // Earned badges first, matching how the rail reads.
        .select()
        .order('earned_at', ascending: false, nullsFirst: false);
    return rows.map(Achievement.fromRow).toList();
  }

  /// Fills a brand-new account with a walkable starter library. Idempotent in
  /// the database, so calling it twice is harmless.
  Future<void> seedStarterContent() {
    return _client.rpc<void>('seed_starter_content');
  }
}
