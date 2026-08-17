// lib/data/models/quiz.dart

class QuizOption {
  const QuizOption({
    required this.id,
    required this.label,
    required this.body,
    required this.correct,
  });

  factory QuizOption.fromRow(Map<String, dynamic> row) => QuizOption(
        id: row['id'] as String,
        label: row['label'] as String,
        body: row['body'] as String,
        correct: (row['is_correct'] as bool?) ?? false,
      );

  final String id;
  final String label;
  final String body;
  final bool correct;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.explanation,
    required this.options,
  });

  factory QuizQuestion.fromRow(Map<String, dynamic> row) {
    final options = ((row['quiz_options'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(QuizOption.fromRow)
        .toList();
    return QuizQuestion(
      id: row['id'] as String,
      prompt: row['prompt'] as String,
      explanation: (row['explanation'] as String?) ?? '',
      options: options,
    );
  }

  final String id;
  final String prompt;
  final String explanation;
  final List<QuizOption> options;
}

class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    required this.questions,
  });

  final String id;
  final String title;
  final List<QuizQuestion> questions;
}

class QuizAttempt {
  const QuizAttempt({
    required this.correct,
    required this.total,
    required this.missed,
  });

  factory QuizAttempt.fromRow(Map<String, dynamic> row) => QuizAttempt(
        correct: (row['correct'] as int?) ?? 0,
        total: (row['total'] as int?) ?? 0,
        missed: ((row['missed'] as List?) ?? const [])
            .map((m) => m as String)
            .toList(),
      );

  final int correct;
  final int total;
  final List<String> missed;

  double get score => total == 0 ? 0 : correct / total;

  /// "Q3 · Assigning R/S priority" → "Assigning R/S priority". The question
  /// number is meaningless outside the run it came from.
  String? get firstMissedTopic {
    if (missed.isEmpty) return null;
    final parts = missed.first.split(' · ');
    return parts.length > 1 ? parts.sublist(1).join(' · ') : parts.first;
  }
}
