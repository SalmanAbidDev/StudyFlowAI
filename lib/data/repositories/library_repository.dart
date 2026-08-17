// lib/data/repositories/library_repository.dart
//
// Materials, their summaries, and the subjects they hang off.
//
// RLS scopes every one of these to the signed-in user, so none of the queries
// carry an explicit `user_id` filter — the database applies it. Writes still
// set user_id because the insert policy's WITH CHECK requires it.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/study_material.dart';
import '../models/subject.dart';
import '../models/summary_section.dart';

/// Pulled into a constant because every material query needs the same subject
/// fields embedded, and drift between them would give different screens
/// different accents for the same subject.
const _materialSelect = '*, subjects(id, name, accent, icon)';

class LibraryRepository {
  const LibraryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Subject>> subjects() async {
    final rows = await _client.from('subjects').select().order('name');
    return rows.map(Subject.fromRow).toList();
  }

  Future<List<StudyMaterial>> materials() async {
    final rows = await _client
        .from('materials')
        .select(_materialSelect)
        .order('created_at', ascending: false);
    return rows.map(StudyMaterial.fromRow).toList();
  }

  Future<StudyMaterial?> latestMaterial() async {
    final row = await _client
        .from('materials')
        .select(_materialSelect)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : StudyMaterial.fromRow(row);
  }

  /// The document to offer as "pick up where you left off": genuinely started
  /// but not finished, most recently touched first.
  ///
  /// Null is the normal answer for a new account, and the caller is expected to
  /// hide the section rather than show an empty card — you cannot resume
  /// something you never began.
  Future<StudyMaterial?> resumeMaterial() async {
    final row = await _client
        .from('materials')
        .select(_materialSelect)
        .gt('progress', 0)
        .lt('progress', 1)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : StudyMaterial.fromRow(row);
  }

  /// The least-progressed unfinished document — what a "study this next"
  /// suggestion falls back to when there is no quiz history to go on.
  Future<StudyMaterial?> leastProgressed() async {
    final row = await _client
        .from('materials')
        .select(_materialSelect)
        .lt('progress', 1)
        .order('progress')
        .limit(1)
        .maybeSingle();
    return row == null ? null : StudyMaterial.fromRow(row);
  }

  Future<List<SummarySection>> summaryFor(String materialId) async {
    final rows = await _client
        .from('summary_sections')
        .select()
        .eq('material_id', materialId)
        .order('position');
    return rows.map(SummarySection.fromRow).toList();
  }

  Future<void> setSectionRead(String sectionId, {required bool read}) {
    return _client
        .from('summary_sections')
        .update({'read': read}).eq('id', sectionId);
  }

  Future<void> setMaterialProgress(String materialId, double progress) {
    return _client
        .from('materials')
        .update({'progress': progress.clamp(0, 1)}).eq('id', materialId);
  }

  Future<StudyMaterial> createMaterial({
    required String userId,
    required String title,
    String? subjectId,
    String? storagePath,
    String? mimeType,
    int? byteSize,
    int? pageCount,
  }) async {
    final row = await _client
        .from('materials')
        .insert({
          'user_id': userId,
          'title': title,
          'subject_id': ?subjectId,
          'storage_path': ?storagePath,
          'mime_type': ?mimeType,
          'byte_size': ?byteSize,
          'page_count': ?pageCount,
        })
        .select(_materialSelect)
        .single();
    return StudyMaterial.fromRow(row);
  }

  Future<void> deleteMaterial(String materialId) {
    return _client.from('materials').delete().eq('id', materialId);
  }
}
