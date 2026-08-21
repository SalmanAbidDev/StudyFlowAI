// lib/features/summaries/summaries_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/summary_section.dart';
import '../../data/supabase_providers.dart';
import '../materials/materials_view_model.dart';

// `selectedMaterialProvider` and `currentMaterialProvider` used to live here.
// They moved to materials_view_model.dart: "which document is open" is a fact
// about the library, and Documents, Flashcards and Quiz all need it too —
// keeping it under Summaries meant three features importing a fourth's file
// for something that was never about summaries.

final summarySectionsProvider =
    FutureProvider.autoDispose<List<SummarySection>>((ref) async {
  final material = await ref.watch(currentMaterialProvider.future);
  if (material == null) return const [];
  return ref.watch(libraryRepositoryProvider).summaryFor(material.id);
});

/// Index of the expanded section; -1 when every section is collapsed.
final openSummarySectionProvider =
    NotifierProvider.autoDispose<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);

// `summaryBookmarkedProvider` is gone along with the two bookmark icons it
// backed. It toggled a flag that was never persisted and never read, so the
// only thing it did was forget your bookmark as soon as you left the screen.
// Bookmarks are worth having — but as a column and a repository method, not as
// an icon that appears to work.
