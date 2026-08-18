// lib/data/repositories/planner_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam.dart';
import '../models/study_block.dart';

const _blockSelect = '*, subjects(id, name, accent, icon)';
const _examSelect = '*, subjects(id, name, accent, icon)';

/// One finished study block, reduced to the two things the profile stats need.
class CompletedBlock {
  const CompletedBlock({required this.day, required this.minutes});

  final DateTime day;
  final int minutes;
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
        .order('position');

    final grouped = <DateTime, List<StudyBlock>>{};
    for (final row in rows) {
      final date = DateTime.parse(row['scheduled_on'] as String);
      final key = DateTime(date.year, date.month, date.day);
      (grouped[key] ??= []).add(StudyBlock.fromRow(row));
    }
    return grouped;
  }

  /// Every block the user has ticked off, newest first, as the day it was
  /// scheduled for and how long it ran.
  ///
  /// Lifetime rather than a window: it backs both the streak and the total
  /// hours studied, and a window would make either quietly wrong. Only the
  /// three columns needed, because this is the whole history rather than one
  /// screen's worth.
  Future<List<CompletedBlock>> completedBlocks() async {
    final rows = await _client
        .from('study_blocks')
        .select('scheduled_on, starts_at, ends_at')
        .eq('done', true)
        .order('scheduled_on', ascending: false);

    return [
      for (final row in rows)
        () {
          final date = DateTime.parse(row['scheduled_on'] as String);
          return CompletedBlock(
            day: DateTime(date.year, date.month, date.day),
            minutes: _minutesBetween(
              row['starts_at'] as String?,
              row['ends_at'] as String?,
            ),
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
        .order('position');
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

  Future<void> createBlock({
    required String userId,
    required String title,
    required DateTime day,
    String? subjectId,
    int position = 0,
  }) {
    return _client.from('study_blocks').insert({
      'user_id': userId,
      'title': title,
      'scheduled_on': _day(day),
      'position': position,
      'subject_id': ?subjectId,
    });
  }

  /// Upcoming only — a finished exam is history, not a countdown.
  Future<List<Exam>> upcomingExams() async {
    final rows = await _client
        .from('exams')
        .select(_examSelect)
        .gte('exam_date', _day(DateTime.now()))
        .order('exam_date');
    return rows.map(Exam.fromRow).toList();
  }
}
