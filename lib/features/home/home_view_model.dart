// lib/features/home/home_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/achievement.dart';
import '../../data/models/profile.dart';
import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';
import '../planner/planner_view_model.dart';

final profileProvider = FutureProvider<Profile?>(
  (ref) => ref.watch(profileRepositoryProvider).current(),
);

/// The full catalogue, each paired with whether this user has earned it.
/// Never empty — an unearned badge is still worth showing, and the list no
/// longer vanishes if the rows are deleted.
final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final earned = await ref.watch(profileRepositoryProvider).earnedAchievements();

  final all = [
    for (final def in achievementCatalogue)
      Achievement(def: def, earnedAt: earned[def.code]),
  ];

  // Earned first, newest first within that — the rail reads left to right.
  all.sort((a, b) {
    if (a.earned != b.earned) return a.earned ? -1 : 1;
    if (!a.earned) return 0;
    return b.earnedAt!.compareTo(a.earnedAt!);
  });
  return all;
});

/// The "pick up where you left off" document, or null when there is nothing to
/// resume. Home hides the whole section on null — an empty resume card is a
/// promise the app cannot keep.
final resumeMaterialProvider = FutureProvider<StudyMaterial?>(
  (ref) => ref.watch(libraryRepositoryProvider).resumeMaterial(),
);

/// Fills a brand-new account with a walkable starter library, once. The
/// database function is idempotent, so a second call is a no-op — this
/// provider exists so the *first* screen after sign-up triggers it.
final starterContentProvider = FutureProvider<void>((ref) async {
  await ref.watch(profileRepositoryProvider).seedStarterContent();
  // Anything read before the seed committed is now stale.
  ref
    ..invalidate(profileProvider)
    ..invalidate(resumeMaterialProvider)
    ..invalidate(achievementsProvider);
});

// ─── Streak week strip ────────────────────────────────────────────────────

/// Monday of the current week, at midnight.
DateTime currentMonday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
}

enum DayState {
  /// At least one scheduled block was completed.
  done,

  /// Today, with nothing completed yet.
  today,

  /// Scheduled but nothing done, or a day with no plan at all.
  idle,

  /// Later this week — not yet judgeable.
  upcoming,
}

/// Seven entries, Monday first. Replaces a hard-coded "first five ticked" row
/// that claimed a streak nobody had earned.
final weekActivityProvider = FutureProvider<List<DayState>>((ref) async {
  final monday = currentMonday();
  final sunday = monday.add(const Duration(days: 6));
  final byDay =
      await ref.watch(plannerRepositoryProvider).blocksBetween(monday, sunday);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return [
    for (var i = 0; i < 7; i++)
      switch (monday.add(Duration(days: i))) {
        final day when day.isAfter(today) => DayState.upcoming,
        final day when (byDay[day] ?? const []).any((b) => b.done) =>
          DayState.done,
        final day when day == today => DayState.today,
        _ => DayState.idle,
      },
  ];
});

// ─── Today's summary ──────────────────────────────────────────────────────

class TodaySummary {
  const TodaySummary({required this.taskCount, required this.minutes});

  final int taskCount;
  final int minutes;

  bool get isEmpty => taskCount == 0;

  /// "3 tasks · 2h 15m", or null when there is nothing to describe. The header
  /// used to say that verbatim whether or not anything was scheduled.
  String? get label {
    if (isEmpty) return null;
    final tasks = taskCount == 1 ? '1 task' : '$taskCount tasks';
    if (minutes <= 0) return tasks;

    final h = minutes ~/ 60;
    final m = minutes % 60;
    final span = h == 0 ? '${m}m' : (m == 0 ? '${h}h' : '${h}h ${m}m');
    return '$tasks · $span';
  }
}

final todaySummaryProvider = Provider<TodaySummary>((ref) {
  final blocks = ref.watch(todayBlocksProvider).value ?? const [];
  var minutes = 0;
  for (final block in blocks) {
    final start = block.startsAt;
    final end = block.endsAt;
    if (start == null || end == null) continue;
    minutes += (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
  }
  return TodaySummary(taskCount: blocks.length, minutes: minutes);
});

// ─── Flow suggestion ──────────────────────────────────────────────────────

class FlowSuggestion {
  const FlowSuggestion({required this.text, required this.action});

  final String text;

  /// The button label. Null hides the button, for the nothing-to-suggest case.
  final String? action;
}

/// What Home's "Flow suggests" card says.
///
/// This is a **rule, not a model** — there is no AI wired up (see §9 of
/// CluadeWork.md). It reasons from real rows in priority order: a weak quiz
/// result first, then the least-progressed document, then nothing. Saying
/// nothing is a valid outcome; inventing a suggestion would be a lie dressed
/// as intelligence.
final flowSuggestionProvider = FutureProvider<FlowSuggestion?>((ref) async {
  final attempt = await ref.watch(studyRepositoryProvider).latestAttempt();
  if (attempt != null && attempt.score < 0.8) {
    final topic = attempt.firstMissedTopic;
    final scored = '${(attempt.score * 100).round()}%';
    return FlowSuggestion(
      text: topic == null
          ? 'Retry your last quiz — you scored $scored.'
          : 'Review **$topic** — you scored $scored last time.',
      action: 'Start review',
    );
  }

  final material = await ref.watch(libraryRepositoryProvider).leastProgressed();
  if (material != null) {
    return FlowSuggestion(
      text: '**${material.title}** is your least-read material.',
      action: 'Open it',
    );
  }

  return null;
});
