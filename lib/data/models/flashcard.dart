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
  });

  factory Flashcard.fromRow(Map<String, dynamic> row) => Flashcard(
        id: row['id'] as String,
        question: row['question'] as String,
        answer: row['answer'] as String,
        source: (row['source'] as String?) ?? '',
      );

  final String id;
  final String question;
  final String answer;
  final String source;
}
