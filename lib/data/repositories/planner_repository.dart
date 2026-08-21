// lib/data/repositories/planner_repository.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam.dart';
import '../models/study_block.dart';

const _blockSelect = '*, subjects(id, name, accent, icon)';
const _examSelect =
    '*, subjects(id, name, accent, icon), exam_materials(material_id)';

/// One study block, reduced to the three things the profile stats need.
///
/// Carries [done] rather than being pre-filtered to completed ones: the streak
/// counts days where **every** block was finished, which cannot be worked out
/// from the finished ones alone.
class PlannedBlock {
  const PlannedBlock({
    required this.day,
    required this.minutes,
    required this.done,
  });

  final DateTime day;
  final int minutes;
  final bool done;
}

class PlannerRepository {
  const PlannerRepository(this._client);

  final SupabaseClient _client;

  /// Postgres `date` columns compare against a bare yyyy-MM-dd string.
  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Every block in an inclusive date range, used by the week strip. Returns
  /// the raw rows grouped by day rather than one query per day.
  Future<Map<DateTime, List<StudyBlock>>> blocksBetween(
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _client
        .from('study_blocks')
        .select('$_blockSelect, scheduled_on')
        .gte('scheduled_on', _day(from))
        .lte('scheduled_on', _day(to))
        .order('position', ascending: true);

    final grouped = <DateTime, List<StudyBlock>>{};
    for (final row in rows) {
      final date = DateTime.parse(row['scheduled_on'] as String);
      final key = DateTime(date.year, date.month, date.day);
      (grouped[key] ??= []).add(StudyBlock.fromRow(row));
    }
    return grouped;
  }

  /// Every block the user has ever planned, as the day it was scheduled for,
  /// how long it ran, and whether it was finished.
  ///
  /// **Not filtered to `done = true`.** It used to be, which made a day with
  /// one block ticked indistinguishable from a day with all four ticked — and
  /// the streak counted both. Lifetime rather than a window: it backs the
  /// streak and the total hours studied, and a window would make either
  /// quietly wrong.
  Future<List<PlannedBlock>> blockHistory() async {
    final rows = await _client
        .from('study_blocks')
        .select('scheduled_on, starts_at, ends_at, done')
        .order('scheduled_on', ascending: false);

    return [
      for (final row in rows)
        () {
          final date = DateTime.parse(row['scheduled_on'] as String);
          return PlannedBlock(
            day: DateTime(date.year, date.month, date.day),
            minutes: _minutesBetween(
              row['starts_at'] as String?,
              row['ends_at'] as String?,
            ),
            done: (row['done'] as bool?) ?? false,
          );
        }(),
    ];
  }

  /// A block with no times contributes to the streak but not to the hours —
  /// it happened, we just cannot say for how long.
  static int _minutesBetween(String? from, String? to) {
    if (from == null || to == null) return 0;
    final start = _minutes(from);
    final end = _minutes(to);
    if (start == null || end == null || end <= start) return 0;
    return end - start;
  }

  static int? _minutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return (h == null || m == null) ? null : h * 60 + m;
  }

  Future<List<StudyBlock>> blocksOn(DateTime day) async {
    final rows = await _client
        .from('study_blocks')
        .select(_blockSelect)
        .eq('scheduled_on', _day(day))
        .order('position', ascending: true);
    return rows.map(StudyBlock.fromRow).toList();
  }

  /// Drag-to-reorder. Writes every row's new position in one request rather
  /// than one request per row, so a long list does not fire ten round trips.
  Future<void> saveOrder(List<StudyBlock> blocks) async {
    if (blocks.isEmpty) return;
    await Future.wait([
      for (var i = 0; i < blocks.length; i++)
        if (blocks[i].position != i)
          _client
              .from('study_blocks')
              .update({'position': i}).eq('id', blocks[i].id),
    ]);
  }

  Future<void> setBlockDone(String blockId, {required bool done}) {
    return _client.from('study_blocks').update({'done': done}).eq('id', blockId);
  }

  /// How many blocks sit on each day in a range, for the week strip's counts.
  ///
  /// Only the one column: the strip needs a number per day, and hydrating
  /// every block in a year to count them would be absurd.
  Future<Map<DateTime, int>> blockCountsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _client
        .from('study_blocks')
        .select('scheduled_on')
        .gte('scheduled_on', _day(from))
        .lte('scheduled_on', _day(to));

    final counts = <DateTime, int>{};
    for (final row in rows) {
      final date = DateTime.parse(row['scheduled_on'] as String);
      final key = DateTime(date.year, date.month, date.day);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Postgres `time` wants "08:00:00"; null clears it.
  static String? _clockOf(TimeOfDay? time) => time == null
      ? null
      : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}:00';

  /// [minutes] is what the editor collects; the end time is computed from it
  /// rather than picked, and stored so every existing duration and
  /// hours-studied calculation keeps working untouched.
  static TimeOfDay? _endOf(TimeOfDay? start, int minutes) {
    if (start == null || minutes <= 0) return null;
    final total = start.hour * 60 + start.minute + minutes;
    // A block running past midnight is clamped to 23:59 rather than wrapping
    // into a negative duration on the following day.
    if (total >= 24 * 60) return const TimeOfDay(hour: 23, minute: 59);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  Future<void> createBlock({
    required String userId,
    required String title,
    required DateTime day,
    TimeOfDay? startsAt,
    int minutes = 0,
    String? subjectId,
    String? materialId,
    String? examId,
    int position = 0,
  }) {
    return _client.from('study_blocks').insert({
      'user_id': userId,
      'title': title,
      'scheduled_on': _day(day),
      'position': position,
      'starts_at': _clockOf(startsAt),
      'ends_at': _clockOf(_endOf(startsAt, minutes)),
      'subject_id': ?subjectId,
      'material_id': ?materialId,
      'exam_id': ?examId,
    });
  }

  /// Every field is written, nullable ones included: this is an edit form
  /// saving what it shows, so clearing a time has to clear the column rather
  /// than leaving the old value behind.
  Future<void> updateBlock({
    required String blockId,
    required String title,
    required DateTime day,
    TimeOfDay? startsAt,
    int minutes = 0,
    String? subjectId,
    String? materialId,
    String? examId,
  }) {
    return _client.from('study_blocks').update({
      'title': title,
      'scheduled_on': _day(day),
      'starts_at': _clockOf(startsAt),
      'ends_at': _clockOf(_endOf(startsAt, minutes)),
      'subject_id': subjectId,
      'material_id': materialId,
      'exam_id': examId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', blockId);
  }

  Future<void> deleteBlock(String blockId) =>
      _client.from('study_blocks').delete().eq('id', blockId);

  /// Duplicates one day's blocks onto [targets].
  ///
  /// Copies the times, the links and the order; **`done` is not copied** —
  /// a plan for next Tuesday that arrives already ticked off would be a lie
  /// about work nobody has done.
  Future<void> copyDay({
    required String userId,
    required List<StudyBlock> blocks,
    required List<DateTime> targets,
  }) async {
    if (blocks.isEmpty || targets.isEmpty) return;
    await _client.from('study_blocks').insert([
      for (final day in targets)
        for (var i = 0; i < blocks.length; i++)
          {
            'user_id': userId,
            'title': blocks[i].title,
            'scheduled_on': _day(day),
            'position': i,
            'starts_at': _clockOf(blocks[i].startsAt),
            'ends_at': _clockOf(blocks[i].endsAt),
            'subject_id': ?blocks[i].subjectId,
            'material_id': ?blocks[i].materialId,
            'exam_id': ?blocks[i].examId,
          },
    ]);
  }

  /// Upcoming only — a finished exam is history, not a countdown.
  Future<List<Exam>> upcomingExams() async {
    final rows = await _client
        .from('exams')
        .select(_examSelect)
        .gte('exam_date', _day(DateTime.now()))
        .order('exam_date', ascending: true);
    return rows.map(Exam.fromRow).toList();
  }

  /// Postgres `time` wants "09:00:00"; null clears it.
  static String? _clock(TimeOfDay? time) => time == null
      ? null
      : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}:00';

  Future<String> createExam({
    required String userId,
    required String title,
    required DateTime examDate,
    TimeOfDay? examTime,
    ExamPriority priority = ExamPriority.normal,
    String? subjectId,
  }) async {
    final row = await _client
        .from('exams')
        .insert({
          'user_id': userId,
          'title': title,
          'exam_date': _day(examDate),
          'exam_time': _clock(examTime),
          'priority': priority.wire,
          'subject_id': ?subjectId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Every field is written, including the nullable ones — this is an edit
  /// form saving what it shows, so clearing the time has to clear the column
  /// rather than silently leaving the old value behind.
  Future<void> updateExam({
    required String examId,
    required String title,
    required DateTime examDate,
    TimeOfDay? examTime,
    ExamPriority priority = ExamPriority.normal,
    String? subjectId,
  }) {
    return _client.from('exams').update({
      'title': title,
      'exam_date': _day(examDate),
      'exam_time': _clock(examTime),
      'priority': priority.wire,
      'subject_id': subjectId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', examId);
  }

  /// The `exam_materials` rows cascade, so the attachments go with it.
  Future<void> deleteExam(String examId) =>
      _client.from('exams').delete().eq('id', examId);

  /// Replaces the whole attachment set for an exam.
  ///
  /// Delete-then-insert rather than diffing: the set is small, the screen
  /// hands over exactly what it wants attached, and a diff is three chances to
  /// leave a row behind for no saved round trip.
  Future<void> setExamMaterials({
    required String examId,
    required String userId,
    required List<String> materialIds,
  }) async {
    await _client.from('exam_materials').delete().eq('exam_id', examId);
    if (materialIds.isEmpty) return;
    await _client.from('exam_materials').insert([
      for (final materialId in materialIds)
        {'exam_id': examId, 'material_id': materialId, 'user_id': userId},
    ]);
  }
}
