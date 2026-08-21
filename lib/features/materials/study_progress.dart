// lib/features/materials/study_progress.dart
//
// How far through a material's practice you are, and everything that follows
// from it.
//
// `materials.progress` was a column with a setter nothing ever called — it
// would have read 0% forever, and exam preparation (§5.7) is derived from it,
// so that zero would have spread. It is written now, from the one thing the
// app actually records: cards reviewed and quizzes attempted.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_providers.dart';
import '../exams/exams_view_model.dart';
import '../planner/planner_view_model.dart';
import '../home/home_view_model.dart';
import '../profile/profile_view_model.dart';
import 'materials_view_model.dart';

/// Practice done against practice generated, for one material.
class StudyProgress {
  const StudyProgress({required this.done, required this.total});

  static const none = StudyProgress(done: 0, total: 0);

  final int done;
  final int total;

  /// Null when there is nothing generated yet — **not zero**. "No cards or
  /// questions exist" and "none of them are done" are different things, and
  /// only the second one is a 0% worth drawing.
  double? get value => total == 0 ? null : done / total;

  bool get isComplete => total > 0 && done >= total;

  /// "3 of 8", or null when there is nothing to count.
  String? get label => total == 0 ? null : '$done of $total';
}

/// Every material's practice progress, keyed by material id.
final studyProgressProvider =
    FutureProvider<Map<String, StudyProgress>>((ref) async {
  final raw = await ref.watch(studyRepositoryProvider).progressByMaterial();
  return {
    for (final entry in raw.entries)
      entry.key: StudyProgress(
        done: entry.value.done,
        total: entry.value.total,
      ),
  };
});

/// One material's progress, or [StudyProgress.none] when it has no practice.
final materialProgressProvider =
    Provider.family<StudyProgress, String>((ref, materialId) {
  final all = ref.watch(studyProgressProvider).value ?? const {};
  return all[materialId] ?? StudyProgress.none;
});

/// Writes the derived progress back to `materials.progress`, then ticks off
/// any of today's blocks the material has just completed.
///
/// Called after a card review and after a finished quiz — the two moments the
/// number can change. Kept in one place so a second caller cannot do half of
/// it: the write and the tick belong together, because a task that stays
/// unticked at 100% is worse than no auto-tick at all.
final syncStudyProgressProvider =
    Provider<Future<void> Function(String materialId)>((ref) {
  return (materialId) async {
    ref.invalidate(studyProgressProvider);
    final all = await ref.read(studyProgressProvider.future);
    final progress = all[materialId] ?? StudyProgress.none;
    final value = progress.value;
    if (value == null) return;

    await ref.read(libraryRepositoryProvider).setMaterialProgress(
          materialId,
          value,
        );
    // The library feeds exam preparation and the resume card, so both follow.
    ref.invalidate(materialsProvider);
    ref.invalidate(examPrepsProvider);

    if (!progress.isComplete) return;

    // Auto-tick: any of today's blocks pointing at this material is finished
    // by definition, because the thing it asked you to do is done.
    final blocks = await ref.read(todayBlocksProvider.future);
    final finished = blocks
        .where((b) => b.materialId == materialId && !b.done)
        .toList();
    if (finished.isEmpty) return;

    final planner = ref.read(plannerRepositoryProvider);
    for (final block in finished) {
      await planner.setBlockDone(block.id, done: true);
    }
    ref
      ..invalidate(todayBlocksProvider)
      ..invalidate(plannerBlocksProvider)
      ..invalidate(profileStatsProvider)
      ..invalidate(weekActivityProvider);
  };
});
