// lib/data/models/flashcard.dart

class Deck {
  const Deck({required this.id, required this.title, required this.cards});

  final String id;
  final String title;
  final List<Flashcard> cards;
}

class Flashcard {
  const Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    required this.source,
    this.ease = 2.5,
    this.intervalDays = 0,
    this.difficulty,
  });

  factory Flashcard.fromRow(Map<String, dynamic> row) => Flashcard(
        id: row['id'] as String,
        question: row['question'] as String,
        answer: row['answer'] as String,
        source: (row['source'] as String?) ?? '',
        ease: (row['ease'] as num?)?.toDouble() ?? 2.5,
        intervalDays: (row['interval_days'] as int?) ?? 0,
        difficulty: (row['difficulty'] as num?)?.toInt(),
      );

  final String id;
  final String question;
  final String answer;
  final String source;

  /// The SM-2 state `reviewCard` advances. `intervalDays > 0` is also how the
  /// app knows a card has been *seen* — there is no separate "reviewed" flag,
  /// and progress is counted from this (see `study_progress.dart`).
  final double ease;
  final int intervalDays;

  bool get reviewed => intervalDays > 0;

  /// How hard the card is, 1 (easiest) to 5 (hardest), judged by the model
  /// that wrote it. **Null when unrated** — cards generated before the column
  /// existed have no rating, and the screen says so rather than inventing one.
  ///
  /// It is a property of the card rather than of your history with it, because
  /// the buttons under a card say Next and Previous: they record where you are
  /// going, not whether you knew the answer, so there is no correctness signal
  /// to infer difficulty from.
  final int? difficulty;

  /// The word for [difficulty], or null when there is nothing to say.
  String? get difficultyLabel => switch (difficulty) {
        1 => 'Easy',
        2 => 'Fairly easy',
        3 => 'Moderate',
        4 => 'Hard',
        5 => 'Very hard',
        _ => null,
      };
}
