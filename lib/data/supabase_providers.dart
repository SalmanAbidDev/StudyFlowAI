// lib/data/supabase_providers.dart
//
// The one place the rest of the app reaches the Supabase client through.
// Everything else depends on a repository, and repositories depend on this —
// which is what makes them overridable in tests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/analytics_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/library_repository.dart';
import 'repositories/planner_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/storage_repository.dart';
import 'repositories/study_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

/// The signed-in user's id. Every write needs it, and every read is scoped to
/// it by RLS. Throws rather than returning null: reaching a repository while
/// signed out is a routing bug, not a state the data layer should paper over.
final currentUserIdProvider = Provider<String>((ref) {
  final id = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (id == null) {
    throw StateError('No signed-in user — a signed-out route reached the data '
        'layer.');
  }
  return id;
});

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(ref.watch(supabaseClientProvider)),
);

final plannerRepositoryProvider = Provider<PlannerRepository>(
  (ref) => PlannerRepository(ref.watch(supabaseClientProvider)),
);

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => StudyRepository(ref.watch(supabaseClientProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(supabaseClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(supabaseClientProvider)),
);

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => StorageRepository(ref.watch(supabaseClientProvider)),
);
