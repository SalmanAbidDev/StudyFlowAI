// lib/data/models/exam.dart

import 'package:flutter/material.dart';

import 'subject.dart';

/// How much the exam matters. The design was already drawing "High priority"
/// on the featured card — for every exam, whether or not it was one.
enum ExamPriority {
  normal('normal', 'Normal'),
  high('high', 'High priority');

  const ExamPriority(this.wire, this.label);

  /// The value the `exam_priority` enum uses in Postgres.
  final String wire;
  final String label;

  static ExamPriority parse(String? value) => ExamPriority.values
      .firstWhere((p) => p.wire == value, orElse: () => ExamPriority.normal);
}

class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.examDate,
    required this.accent,
    this.examTime,
    this.priority = ExamPriority.normal,
    this.subjectId,
    this.materialIds = const [],
  });

  factory Exam.fromRow(Map<String, dynamic> row) {
    final subject = row['subjects'] as Map<String, dynamic>?;
    return Exam(
      id: row['id'] as String,
      title: row['title'] as String,
      examDate: DateTime.parse(row['exam_date'] as String),
      examTime: _time(row['exam_time'] as String?),
      priority: ExamPriority.parse(row['priority'] as String?),
      accent: SubjectAccentColor.parse(subject?['accent'] as String?),
      subjectId: row['subject_id'] as String?,
      // Embedded by the select, so an exam arrives knowing what it is revised
      // from without a second request per card.
      materialIds: ((row['exam_materials'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((r) => r['material_id'] as String)
          .toList(),
    );
  }

  /// Postgres `time` arrives as "09:00:00".
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
  final DateTime examDate;
  final TimeOfDay? examTime;
  final ExamPriority priority;
  final SubjectAccent accent;
  final String? subjectId;

  /// The materials this exam is revised from. **Preparation is computed from
  /// these**, in `examPrepProvider` — there is no stored percentage, because a
  /// stored one would sit at whatever it was last set to.
  final List<String> materialIds;

  /// Computed, never stored — a persisted countdown is wrong by morning.
  int get daysLeft {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    return examDate.difference(midnight).inDays;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const _weekdays = [
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  ];

  /// "May 15".
  String get date =>
      '${_months[examDate.month - 1]} ${examDate.day.toString().padLeft(2, '0')}';

  /// "9:00 AM", or empty when no time was set — an exam with only a date is a
  /// perfectly ordinary thing to have entered.
  String get time {
    final t = examTime;
    if (t == null) return '';
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  /// "THU · MAY 15 · 9:00 AM", dropping the last part when there is no time.
  /// This was hard-coded on the featured card, that exact string, for whatever
  /// exam happened to be next.
  String get schedule {
    final parts = [
      _weekdays[examDate.weekday - 1],
      '${_months[examDate.month - 1].toUpperCase()} ${examDate.day}',
      if (examTime != null) time,
    ];
    return parts.join(' · ');
  }

  /// "in 14 days" / "tomorrow" / "today". The countdown reads as a number on
  /// the cards; this is for prose.
  String get countdown => switch (daysLeft) {
        <= 0 => 'today',
        1 => 'tomorrow',
        final d => 'in $d days',
      };
}
