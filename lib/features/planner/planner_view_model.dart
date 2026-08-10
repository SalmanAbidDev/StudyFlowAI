// lib/features/planner/planner_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/exam.dart';
import '../../data/models/study_block.dart';
import '../../data/supabase_providers.dart';

/// Index into the week strip, Monday first.
final selectedDayProvider = NotifierProvider<ValueViewModel<int>, int>(
  () => ValueViewModel(DateTime.now().weekday - 1),
);

/// The date the strip's selected column refers to, in the current week.
final selectedDateProvider = Provider<DateTime>((ref) {
  final index = ref.watch(selectedDayProvider);
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  return monday.add(Duration(days: index));
});

/// The day's blocks in drag order.
class PlannerBlocks extends AsyncNotifier<List<StudyBlock>> {
  @override
  Future<List<StudyBlock>> build() {
    final day = ref.watch(selectedDateProvider);
    return ref.watch(plannerRepositoryProvider).blocksOn(day);
  }

  /// `onReorderItem` hands back a [newIndex] that already accounts for the row
  /// being lifted out, so no off-by-one correction is needed here.
  ///
  /// The list is reordered locally first: waiting for the round trip would
  /// leave the row snapping back under the user's finger.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null) return;

    final next = [...current];
    next.insert(newIndex, next.removeAt(oldIndex));
    state = AsyncData(next);

    try {
      await ref.read(plannerRepositoryProvider).saveOrder(next);
    } catch (_) {
      // Put the server's order back rather than leaving the UI claiming a
      // change that was never persisted.
      ref.invalidateSelf();
    }
  }

  Future<void> toggleDone(StudyBlock block) async {
    await ref
        .read(plannerRepositoryProvider)
        .setBlockDone(block.id, done: !block.done);
    ref.invalidateSelf();
  }
}

final plannerBlocksProvider =
    AsyncNotifierProvider<PlannerBlocks, List<StudyBlock>>(PlannerBlocks.new);

/// Today specifically. Home shows today's plan and must not follow the
/// Planner's day selection around.
final todayBlocksProvider = FutureProvider<List<StudyBlock>>(
  (ref) => ref.watch(plannerRepositoryProvider).blocksOn(DateTime.now()),
);

/// Ticking a task off Home writes through, then refreshes both views of the
/// same rows.
final toggleBlockDoneProvider =
    Provider<Future<void> Function(StudyBlock)>((ref) {
  return (block) async {
    await ref
        .read(plannerRepositoryProvider)
        .setBlockDone(block.id, done: !block.done);
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(plannerBlocksProvider);
  };
});

final upcomingExamsProvider = FutureProvider<List<Exam>>(
  (ref) => ref.watch(plannerRepositoryProvider).upcomingExams(),
);

/// The single exam Home counts down to.
final nextExamProvider = Provider<Exam?>((ref) {
  final exams = ref.watch(upcomingExamsProvider).value;
  return (exams == null || exams.isEmpty) ? null : exams.first;
});
