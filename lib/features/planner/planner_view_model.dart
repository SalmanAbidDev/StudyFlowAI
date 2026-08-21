// lib/features/planner/planner_view_model.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/exam.dart';
import '../../data/models/study_block.dart';
import '../../data/supabase_providers.dart';
import '../home/home_view_model.dart';
import '../materials/materials_view_model.dart';
import '../profile/profile_view_model.dart';

/// Midnight today, the origin the strip is measured from.
DateTime plannerToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// How far the strip scrolls either side of today.
///
/// Bounded rather than infinite, and bounded at exactly the range the day
/// counts are loaded for — a cell showing no count outside that range would be
/// claiming "nothing planned" about a day nobody had asked the database about.
const plannerDaysBack = 60;
const plannerDaysForward = 365;

DateTime plannerRangeStart() =>
    plannerToday().subtract(const Duration(days: plannerDaysBack));
DateTime plannerRangeEnd() =>
    plannerToday().add(const Duration(days: plannerDaysForward));

/// The day being shown. A real date, not an index into the current week —
/// the strip scrolls through months, so "day 3" stopped meaning anything.
final selectedDateProvider = NotifierProvider<ValueViewModel<DateTime>, DateTime>(
  () => ValueViewModel(plannerToday()),
);

/// How many blocks sit on each day, for the strip's counts. One query for the
/// whole scrollable range.
final blockCountsProvider = FutureProvider<Map<DateTime, int>>(
  (ref) => ref
      .watch(plannerRepositoryProvider)
      .blockCountsBetween(plannerRangeStart(), plannerRangeEnd()),
);

/// "1h 30m · 2 tasks · 1 of 3 done", or "nothing planned".
///
/// Every part is conditional, because every part can be absent: a day of
/// untimed tasks has no hours, a day of timed blocks has no "tasks", and a day
/// with nothing on it has neither.
String daySummary(List<StudyBlock> blocks) {
  if (blocks.isEmpty) return 'nothing planned';

  final minutes = blocks.fold<int>(0, (sum, b) => sum + b.minutes);
  final untimed = blocks.where((b) => b.minutes == 0).length;
  final done = blocks.where((b) => b.done).length;

  return [
    if (minutes > 0) formatMinutes(minutes),
    if (untimed > 0) '$untimed ${untimed == 1 ? 'task' : 'tasks'}',
    '$done of ${blocks.length} done',
  ].join(' · ');
}

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

// ─── The block editor ─────────────────────────────────────────────────────

/// What a block is for. Free-text blocks are gone: a plan made of loose
/// sentences cannot be opened, cannot inherit a subject colour, and cannot
/// tell an exam what it is revising. Every block now points at something.
enum BlockTarget { material, exam }

class BlockDraft {
  const BlockDraft({
    this.title = '',
    this.day,
    this.startsAt,
    this.minutes = 0,
    this.target,
    this.materialId,
    this.examId,
    this.subjectId,
    this.autoTitle,
  });

  final String title;
  final DateTime? day;
  final TimeOfDay? startsAt;

  /// 0 means untimed. The end time is computed from this at save.
  final int minutes;

  /// Null until something is picked — the editor opens with neither chosen.
  final BlockTarget? target;

  final String? materialId;
  final String? examId;
  final String? subjectId;

  /// The last title [BlockEditor.link] filled in.
  ///
  /// It is how the editor tells a title it wrote itself from one you typed: an
  /// auto-filled title is replaced when you pick something else, a typed one
  /// survives. Without it, typing "Past paper" and then attaching the document
  /// silently threw the typing away.
  final String? autoTitle;

  /// A title, a day, and something to point at. Times stay optional by design
  /// — a block with no clock on it is a task for that day.
  bool get isValid =>
      title.trim().isNotEmpty &&
      day != null &&
      (materialId != null || examId != null);

  BlockDraft copyWith({
    String? title,
    DateTime? day,
    TimeOfDay? startsAt,
    bool clearStart = false,
    int? minutes,
    BlockTarget? target,
    String? materialId,
    String? examId,
    String? subjectId,
    bool clearLinks = false,
    String? autoTitle,
  }) =>
      BlockDraft(
        autoTitle: autoTitle ?? this.autoTitle,
        title: title ?? this.title,
        day: day ?? this.day,
        startsAt: clearStart ? null : (startsAt ?? this.startsAt),
        minutes: minutes ?? this.minutes,
        target: target ?? this.target,
        materialId: clearLinks ? null : (materialId ?? this.materialId),
        examId: clearLinks ? null : (examId ?? this.examId),
        subjectId: clearLinks ? null : (subjectId ?? this.subjectId),
      );
}

class BlockEditor extends Notifier<BlockDraft> {
  @override
  BlockDraft build() => const BlockDraft();

  /// Seeds the form: an existing block to edit, or a blank one on [day].
  void start({StudyBlock? block, required DateTime day}) {
    state = block == null
        ? BlockDraft(day: day)
        : BlockDraft(
            title: block.title,
            day: day,
            startsAt: block.startsAt,
            minutes: block.minutes,
            target: block.materialId != null
                ? BlockTarget.material
                : block.examId != null
                    ? BlockTarget.exam
                    : null,
            materialId: block.materialId,
            examId: block.examId,
            subjectId: block.subjectId,
          );
  }

  void title(String value) => state = state.copyWith(title: value);
  void day(DateTime value) => state = state.copyWith(day: value);
  void minutes(int value) => state = state.copyWith(minutes: value);

  void startsAt(TimeOfDay? value) => state = state.copyWith(
        startsAt: value,
        clearStart: value == null,
        // Clearing the start makes the block untimed; a length with nothing to
        // start from is not a duration.
        minutes: value == null ? 0 : null,
      );

  /// Linking fills the title from what was picked, and inherits its subject so
  /// the block's accent stripe means something. An edited title is kept.
  void link({
    required BlockTarget target,
    String? materialId,
    String? examId,
    String? subjectId,
    String? suggestedTitle,
  }) {
    // A title you typed is yours. A title the editor filled in last time is
    // not, and gets replaced when you point the block somewhere else.
    final typed = state.title.trim().isNotEmpty && state.title != state.autoTitle;

    state = BlockDraft(
      title: typed ? state.title : (suggestedTitle ?? ''),
      autoTitle: suggestedTitle,
      day: state.day,
      startsAt: state.startsAt,
      minutes: state.minutes,
      target: target,
      materialId: materialId,
      examId: examId,
      subjectId: subjectId,
    );
  }
}

final blockEditorProvider =
    NotifierProvider.autoDispose<BlockEditor, BlockDraft>(BlockEditor.new);

/// Everything that changes when the set of blocks does. One place, so a new
/// writer cannot forget half of it.
void _refreshPlanner(Ref ref) {
  ref
    ..invalidate(plannerBlocksProvider)
    ..invalidate(todayBlocksProvider)
    ..invalidate(blockCountsProvider)
    ..invalidate(profileStatsProvider)
    ..invalidate(weekActivityProvider);
}

/// Saves the draft, creating or updating.
final saveBlockProvider =
    Provider<Future<void> Function({String? blockId})>((ref) {
  return ({String? blockId}) async {
    final draft = ref.read(blockEditorProvider);
    final repo = ref.read(plannerRepositoryProvider);

    if (blockId == null) {
      // Appended, not prepended: a new block joins the end of the day's order,
      // which the user then drags where they want it.
      final existing = ref.read(plannerBlocksProvider).value ?? const [];
      await repo.createBlock(
        userId: ref.read(currentUserIdProvider),
        title: draft.title.trim(),
        day: draft.day!,
        startsAt: draft.startsAt,
        minutes: draft.minutes,
        subjectId: draft.subjectId,
        materialId: draft.materialId,
        examId: draft.examId,
        position: existing.length,
      );
    } else {
      await repo.updateBlock(
        blockId: blockId,
        title: draft.title.trim(),
        day: draft.day!,
        startsAt: draft.startsAt,
        minutes: draft.minutes,
        subjectId: draft.subjectId,
        materialId: draft.materialId,
        examId: draft.examId,
      );
    }
    _refreshPlanner(ref);
  };
});

final deleteBlockProvider = Provider<Future<void> Function(String)>((ref) {
  return (blockId) async {
    await ref.read(plannerRepositoryProvider).deleteBlock(blockId);
    _refreshPlanner(ref);
  };
});

/// Duplicates the day on screen onto other dates.
final copyDayProvider =
    Provider<Future<void> Function(List<DateTime>)>((ref) {
  return (targets) async {
    final blocks = ref.read(plannerBlocksProvider).value ?? const [];
    await ref.read(plannerRepositoryProvider).copyDay(
          userId: ref.read(currentUserIdProvider),
          blocks: blocks,
          targets: targets,
        );
    _refreshPlanner(ref);
  };
});

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
/// ClaudeWork.md). It used to read "Flow planned your day around your Organic
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
