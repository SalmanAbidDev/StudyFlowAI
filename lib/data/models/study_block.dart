// lib/data/models/study_block.dart

import 'package:flutter/material.dart';

import 'subject.dart';

class StudyBlock {
  const StudyBlock({
    required this.id,
    required this.title,
    required this.accent,
    required this.icon,
    required this.position,
    required this.done,
    this.startsAt,
    this.endsAt,
    this.materialId,
    this.examId,
    this.subjectId,
  });

  factory StudyBlock.fromRow(Map<String, dynamic> row) {
    final subject = row['subjects'] as Map<String, dynamic>?;
    return StudyBlock(
      id: row['id'] as String,
      title: row['title'] as String,
      accent: SubjectAccentColor.parse(subject?['accent'] as String?),
      icon: iconForKey(subject?['icon'] as String?),
      position: (row['position'] as int?) ?? 0,
      done: (row['done'] as bool?) ?? false,
      startsAt: _time(row['starts_at'] as String?),
      endsAt: _time(row['ends_at'] as String?),
      materialId: row['material_id'] as String?,
      examId: row['exam_id'] as String?,
      subjectId: row['subject_id'] as String?,
    );
  }

  /// Postgres `time` arrives as "08:00:00".
  static TimeOfDay? _time(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  final String id;
  final String title;
  final SubjectAccent accent;
  final IconData icon;
  final int position;
  final bool done;
  final TimeOfDay? startsAt;
  final TimeOfDay? endsAt;

  /// What the block is for: one document, one exam, or neither. Both are
  /// `ON DELETE SET NULL` — deleting a document must not take Thursday
  /// morning off the plan with it, so the block survives as plain text.
  final String? materialId;
  final String? examId;

  /// What colours the accent stripe. Inherited from the linked material when
  /// there is one, so a block about a Chemistry document reads as Chemistry.
  final String? subjectId;

  bool get isLinked => materialId != null || examId != null;

  /// Minutes this block occupies, or 0 when it has no times — an untimed
  /// block is a task for the day, and contributes nothing to a total of hours.
  int get minutes {
    final start = startsAt;
    final end = endsAt;
    if (start == null || end == null) return 0;
    final span =
        (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
    return span > 0 ? span : 0;
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  /// "08:00 – 09:30", or empty when the block has no times yet.
  String get window {
    if (startsAt == null) return '';
    if (endsAt == null) return _hhmm(startsAt!);
    return '${_hhmm(startsAt!)} – ${_hhmm(endsAt!)}';
  }

  /// "1h 30m". Derived from the window rather than stored, so editing a time
  /// can never leave a stale duration behind.
  String get duration => formatMinutes(minutes);

  /// "08:00 – 09:30 · 1h 30m", or "No time set" for an untimed block.
  String get schedule => scheduleOf(startsAt, minutes);
}

/// "08:00 – 09:30 · 1h 30m" for a start and a length, "No time set" without
/// one. The block row and the editor's live preview both call this, so the
/// preview cannot describe the block differently from the row that follows it.
String scheduleOf(TimeOfDay? start, int minutes) {
  if (start == null || minutes <= 0) return 'No time set';
  final total =
      (start.hour * 60 + start.minute + minutes).clamp(0, 24 * 60 - 1);
  String hhmm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
  return '${hhmm(start.hour * 60 + start.minute)} – ${hhmm(total)}'
      '  ·  ${formatMinutes(minutes)}';
}

/// "1h 30m" / "45m" / "" for nothing. Shared by the block row, the day summary
/// and the editor's length picker, so the three can never disagree.
String formatMinutes(int minutes) {
  if (minutes <= 0) return '';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
