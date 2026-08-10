// lib/data/models/exam.dart

import 'subject.dart';

class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.examDate,
    required this.preparation,
    required this.accent,
  });

  factory Exam.fromRow(Map<String, dynamic> row) {
    final subject = row['subjects'] as Map<String, dynamic>?;
    return Exam(
      id: row['id'] as String,
      title: row['title'] as String,
      examDate: DateTime.parse(row['exam_date'] as String),
      preparation: (row['preparation'] as num?)?.toDouble() ?? 0,
      accent: SubjectAccentColor.parse(subject?['accent'] as String?),
    );
  }

  final String id;
  final String title;
  final DateTime examDate;
  final double preparation;
  final SubjectAccent accent;

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

  /// "May 15".
  String get date =>
      '${_months[examDate.month - 1]} ${examDate.day.toString().padLeft(2, '0')}';
}
