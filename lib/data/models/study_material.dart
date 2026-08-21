// lib/data/models/study_material.dart

import 'package:flutter/material.dart';

import 'subject.dart';

/// What kind of thing a material actually is, which decides how the document
/// screen renders it and what its header calls it.
enum MaterialKind {
  pdf('PDF'),
  image('Image'),
  text('Text'),
  link('Link');

  const MaterialKind(this.label);

  /// Shown in place of the old hard-coded "Summary" eyebrow.
  final String label;
}

class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.title,
    required this.progress,
    required this.accent,
    required this.icon,
    required this.subjectName,
    required this.pageCount,
    this.subjectId,
    this.storagePath,
    this.sourceUrl,
    this.mimeType,
    this.updatedAt,
  });

  /// [row] is expected to carry an embedded `subjects` object from a
  /// `select('*, subjects(...)')` — one round trip instead of two.
  factory StudyMaterial.fromRow(Map<String, dynamic> row) {
    final subject = row['subjects'] as Map<String, dynamic>?;
    return StudyMaterial(
      id: row['id'] as String,
      title: row['title'] as String,
      progress: (row['progress'] as num?)?.toDouble() ?? 0,
      accent: SubjectAccentColor.parse(subject?['accent'] as String?),
      icon: iconForKey(subject?['icon'] as String?),
      subjectName: (subject?['name'] as String?) ?? 'Unfiled',
      subjectId: row['subject_id'] as String?,
      pageCount: row['page_count'] as int?,
      storagePath: row['storage_path'] as String?,
      sourceUrl: row['source_url'] as String?,
      mimeType: row['mime_type'] as String?,
      updatedAt: switch (row['updated_at']) {
        final String at => DateTime.tryParse(at),
        _ => null,
      },
    );
  }

  final String id;
  final String title;
  final double progress;
  final SubjectAccent accent;
  final IconData icon;
  final String subjectName;

  /// Carried so a study block built from this material can inherit its
  /// subject, which is what colours the block's accent stripe.
  final String? subjectId;

  final int? pageCount;
  final String? storagePath;

  /// Where this came from, for a material added from the web. Null for
  /// uploads — those have a [storagePath] instead. The two are the two ways a
  /// material can have a source, and no material has both.
  final String? sourceUrl;

  /// What was uploaded. Null on rows written before it was recorded, which is
  /// why [kind] falls back to the file extension rather than trusting it.
  final String? mimeType;

  /// Last touched. Carried on the model so "pick up where you left off" can be
  /// derived from the library list instead of a separate ordered query — see
  /// `resumeMaterialProvider`.
  final DateTime? updatedAt;

  /// Mime type first, extension second, PDF last.
  ///
  /// A link is unambiguous — it has no file at all. Everything else is decided
  /// by what was stored, and the extension fallback matters because older rows
  /// predate `mime_type` being written.
  MaterialKind get kind {
    if (sourceUrl != null && storagePath == null) return MaterialKind.link;

    final mime = mimeType ?? '';
    if (mime.startsWith('image/')) return MaterialKind.image;
    if (mime == 'application/pdf') return MaterialKind.pdf;
    if (mime.startsWith('text/')) return MaterialKind.text;

    return switch (_extension) {
      'png' || 'jpg' || 'jpeg' || 'webp' || 'gif' => MaterialKind.image,
      'txt' || 'md' => MaterialKind.text,
      _ => MaterialKind.pdf,
    };
  }

  String get _extension {
    final path = storagePath;
    if (path == null) return '';
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
  }

  /// The "Organic Chem · 14 pages" line. Derived rather than stored, so it
  /// cannot drift from the values it describes.
  String get meta =>
      pageCount == null ? subjectName : '$subjectName · $pageCount pages';

  String get tag => subjectName;
}
