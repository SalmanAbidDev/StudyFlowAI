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

  // `resumeMaterial()` and `leastProgressed()` used to live here, each its own
  // ordered query. They are gone on purpose: a second source of truth about
  // the library is a second thing every writer has to remember to invalidate,
  // and the one that got forgotten left Home recommending a deleted document.
  // Both answers are now derived from `materials()` — see
  // `resumeMaterialProvider` and `flowSuggestionProvider`.

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
    String? sourceUrl,
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
          'source_url': ?sourceUrl,
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

  /// The subject called [name], creating it if this user has no such row yet.
  ///
  /// Matching happens in Dart rather than with `ilike`, for two reasons: the
  /// list is a handful of rows, and a name containing `%` or `_` would be read
  /// as a wildcard by the server. `subjects` has no unique constraint on
  /// (user_id, name), so this is the only thing standing between the library
  /// and two categories with the same label.
  Future<Subject> ensureSubject({
    required String userId,
    required String name,
    SubjectAccent accent = SubjectAccent.indigo,
    String iconKey = 'book',
  }) async {
    final trimmed = name.trim();
    final existing = await subjects();
    for (final subject in existing) {
      if (subject.name.toLowerCase() == trimmed.toLowerCase()) return subject;
    }

    final row = await _client
        .from('subjects')
        .insert({
          'user_id': userId,
          'name': trimmed,
          'accent': accent.wireName,
          'icon': iconKey,
        })
        .select()
        .single();
    return Subject.fromRow(row);
  }

  Future<void> setMaterialSubject(String materialId, String subjectId) {
    return _client
        .from('materials')
        .update({'subject_id': subjectId}).eq('id', materialId);
  }
}
