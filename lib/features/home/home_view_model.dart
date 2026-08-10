// lib/features/home/home_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';

final profileProvider = FutureProvider<Profile?>(
  (ref) => ref.watch(profileRepositoryProvider).current(),
);

final achievementsProvider = FutureProvider<List<Achievement>>(
  (ref) => ref.watch(profileRepositoryProvider).achievements(),
);

/// The "pick up where you left off" card.
final resumeMaterialProvider = FutureProvider<StudyMaterial?>(
  (ref) => ref.watch(libraryRepositoryProvider).latestMaterial(),
);

/// Fills a brand-new account with a walkable starter library, once. The
/// database function is idempotent, so a second call is a no-op — this
/// provider exists so the *first* screen after sign-up triggers it.
final starterContentProvider = FutureProvider<void>((ref) async {
  await ref.watch(profileRepositoryProvider).seedStarterContent();
  // Anything read before the seed committed is now stale.
  ref.invalidate(profileProvider);
  ref.invalidate(resumeMaterialProvider);
});
