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
  String get duration {
    if (startsAt == null || endsAt == null) return '';
    final minutes = (endsAt!.hour * 60 + endsAt!.minute) -
        (startsAt!.hour * 60 + startsAt!.minute);
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
