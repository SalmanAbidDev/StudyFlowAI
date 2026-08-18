// lib/data/repositories/analytics_repository.dart
//
// Everything Insights charts is derived from study_sessions and quiz_attempts
// rather than read from pre-aggregated counters, so the numbers can never
// drift from the rows they describe.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subject.dart';

class StudyStats {
  const StudyStats({
    required this.weeklyHours,
    required this.totalHours,
    required this.focusScore,
    required this.cardsMastered,
    required this.subjectSplit,
  });

  /// Seven entries, Monday first.
  final List<double> weeklyHours;
  final double totalHours;
  final double focusScore;
  final int cardsMastered;
  final List<SubjectShare> subjectSplit;

  bool get isEmpty => totalHours == 0 && cardsMastered == 0;
}

class SubjectShare {
  const SubjectShare({
    required this.label,
    required this.hours,
    required this.share,
    required this.accent,
  });

  final String label;
  final double hours;
  final double share;
  final SubjectAccent accent;

  String get hoursLabel => '${hours.toStringAsFixed(1)}h';
}

class AnalyticsRepository {
  const AnalyticsRepository(this._client);

  final SupabaseClient _client;

  Future<StudyStats> stats({int days = 7}) async {
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final startOfDay = DateTime(since.year, since.month, since.day);

    final sessions = await _client
        .from('study_sessions')
        .select('started_at, duration_minutes, focus_score, '
            'subjects(name, accent)')
        .gte('started_at', startOfDay.toIso8601String());

    // Bucket by weekday so the bar chart lines up with Mon–Sun labels.
    final buckets = List<double>.filled(7, 0);
    final perSubject = <String, ({double hours, SubjectAccent accent})>{};
    var focusTotal = 0.0;
    var focusCount = 0;

    for (final row in sessions) {
      final startedAt = DateTime.parse(row['started_at'] as String).toLocal();
      final minutes = (row['duration_minutes'] as int?) ?? 0;
      final hours = minutes / 60;

      buckets[startedAt.weekday - 1] += hours;

      final focus = (row['focus_score'] as num?)?.toDouble();
      if (focus != null) {
        focusTotal += focus;
        focusCount++;
      }

      final subject = row['subjects'] as Map<String, dynamic>?;
      final name = (subject?['name'] as String?) ?? 'Unfiled';
      final accent = SubjectAccentColor.parse(subject?['accent'] as String?);
      final existing = perSubject[name];
      perSubject[name] = (
        hours: (existing?.hours ?? 0) + hours,
        accent: accent,
      );
    }

    final total = buckets.fold<double>(0, (a, b) => a + b);
    final busiest = perSubject.values.fold<double>(
      0,
      (a, e) => e.hours > a ? e.hours : a,
    );

    final split = perSubject.entries
        .map(
          (e) => SubjectShare(
            label: e.key,
            hours: e.value.hours,
            // Relative to the busiest subject, so the longest bar is always
            // full rather than every bar being a sliver on a light week.
            share: busiest == 0 ? 0 : e.value.hours / busiest,
            accent: e.value.accent,
          ),
        )
        .toList()
      ..sort((a, b) => b.hours.compareTo(a.hours));

    final mastered = await masteredCount();

    return StudyStats(
      weeklyHours: buckets,
      totalHours: total,
      focusScore: focusCount == 0 ? 0 : focusTotal / focusCount,
      cardsMastered: mastered,
      subjectSplit: split,
    );
  }

  /// Cards whose review interval has reached three weeks — the usual line
  /// between "seen it" and "know it" in a spaced-repetition schedule.
  ///
  /// Deliberately not part of [stats]'s range filter: mastery is a running
  /// total, not something that happened this week, so it must not change when
  /// the Insights header switches between Week and Year.
  Future<int> masteredCount() {
    return _client
        .from('flashcards')
        .count(CountOption.exact)
        .gte('interval_days', 21);
  }

  Future<void> logSession({
    required String userId,
    required int durationMinutes,
    String? subjectId,
    double? focusScore,
  }) {
    return _client.from('study_sessions').insert({
      'user_id': userId,
      'duration_minutes': durationMinutes,
      'subject_id': ?subjectId,
      'focus_score': ?focusScore,
    });
  }
}
