// lib/features/planner/planner_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/exam.dart';
import '../../data/models/study_block.dart';
import '../../data/supabase_providers.dart';
import '../home/home_view_model.dart';
import '../materials/materials_view_model.dart';
import '../profile/profile_view_model.dart';

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
    // Same fan-out as `toggleBlockDoneProvider` — ticking a block from the
    // Planner has to move the streak just as ticking it from Home does.
    ref.invalidate(todayBlocksProvider);
    ref.invalidate(profileStatsProvider);
    ref.invalidate(weekActivityProvider);
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
    // The streak, the hours studied and the week strip are all counts of
    // completed blocks — one of which just changed.
    ref.invalidate(profileStatsProvider);
    ref.invalidate(weekActivityProvider);
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

// ─── Flow's note on the Planner ───────────────────────────────────────────

/// The two-tone line under the week strip. [lead] is drawn in the brand
/// colour, [detail] in ink — the same split the hard-coded version had.
class PlannerNote {
  const PlannerNote({required this.lead, required this.detail});

  final String lead;
  final String detail;
}

/// What Flow says above the day's blocks, or nothing at all.
///
/// Like Home's suggestion this is a **rule, not a model** (§9 of
/// CluadeWork.md). It used to read "Flow planned your day around your Organic
/// Chem final in 9d" on every account, including empty ones that had never
/// uploaded a thing — a claim about work Flow had not done, about an exam that
/// did not exist.
///
/// The gate is having uploaded something: with no material there is nothing to
/// plan *from*, so the banner is absent rather than aspirational.
final plannerNoteProvider = FutureProvider<PlannerNote?>((ref) async {
  // Watches the library rather than asking for the latest material on its own,
  // so deleting everything takes this banner with it. See
  // `resumeMaterialProvider` for why every library question is derived.
  final materials = await ref.watch(materialsProvider.future);
  if (materials.isEmpty) return null;

  final exams = await ref.watch(upcomingExamsProvider.future);
  if (exams.isEmpty) {
    return const PlannerNote(
      lead: 'Flow can plan your week ',
      detail: 'once you add an exam date to work back from.',
    );
  }

  final exam = exams.first;
  return PlannerNote(
    lead: 'Flow is planning around ',
    detail: 'your ${exam.title} ${_when(exam.daysLeft)}.',
  );
});

/// "in 9d" reads fine at a distance and badly up close — "in 0d" is today.
String _when(int daysLeft) => switch (daysLeft) {
      <= 0 => 'today',
      1 => 'tomorrow',
      _ => 'in ${daysLeft}d',
    };
