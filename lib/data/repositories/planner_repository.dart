// lib/data/repositories/planner_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam.dart';
import '../models/study_block.dart';

const _blockSelect = '*, subjects(id, name, accent, icon)';
const _examSelect = '*, subjects(id, name, accent, icon)';

class PlannerRepository {
  const PlannerRepository(this._client);

  final SupabaseClient _client;

  /// Postgres `date` columns compare against a bare yyyy-MM-dd string.
  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

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
