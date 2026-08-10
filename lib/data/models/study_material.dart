// lib/data/models/study_material.dart

import 'package:flutter/material.dart';

import 'subject.dart';

class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.title,
    required this.progress,
    required this.accent,
    required this.icon,
    required this.subjectName,
    required this.pageCount,
    this.storagePath,
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
      pageCount: row['page_count'] as int?,
      storagePath: row['storage_path'] as String?,
    );
  }

  final String id;
  final String title;
  final double progress;
  final SubjectAccent accent;
  final IconData icon;
  final String subjectName;
  final int? pageCount;
  final String? storagePath;

  /// The "Organic Chem · 14 pages" line. Derived rather than stored, so it
  /// cannot drift from the values it describes.
  String get meta =>
      pageCount == null ? subjectName : '$subjectName · $pageCount pages';

  String get tag => subjectName;
}
