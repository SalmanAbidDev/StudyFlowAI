// lib/features/summaries/summaries_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/study_material.dart';
import '../../data/models/summary_section.dart';
import '../../data/supabase_providers.dart';

/// Which material the Summaries screen is showing. Set before pushing the
/// route; falls back to the most recent one when opened without a selection.
final selectedMaterialProvider =
    NotifierProvider<ValueViewModel<String?>, String?>(
  () => ValueViewModel(null),
);

final summaryMaterialProvider = FutureProvider.autoDispose<StudyMaterial?>(
  (ref) async {
    final repo = ref.watch(libraryRepositoryProvider);
    final selectedId = ref.watch(selectedMaterialProvider);
    if (selectedId == null) return repo.latestMaterial();

    final all = await repo.materials();
    return all.where((m) => m.id == selectedId).firstOrNull;
  },
);

final summarySectionsProvider =
    FutureProvider.autoDispose<List<SummarySection>>((ref) async {
  final material = await ref.watch(summaryMaterialProvider.future);
  if (material == null) return const [];
  return ref.watch(libraryRepositoryProvider).summaryFor(material.id);
});

/// Index of the expanded section; -1 when every section is collapsed.
final openSummarySectionProvider =
    NotifierProvider.autoDispose<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);

/// Whether the document is bookmarked. Not persisted yet — there is no
/// bookmarks table, and inventing one to back a single icon would be scope
/// the schema does not need.
final summaryBookmarkedProvider =
    NotifierProvider.autoDispose<FlagViewModel, bool>(
  () => FlagViewModel(initial: false),
);
